# Nodo Master (Rancher o K3s server)
resource "multipass_instance" "rancher_master" {
  name   = "rancher-master"
  cpus   = var.master_cpus
  memory = var.master_memory
  disk   = var.master_disk
  image  = "22.04"

  # Puedes usar cloud-init inline si quieres instalar cosas luego
  cloudinit_file = local_file.cloudinit_master.filename

  depends_on = [local_file.cloudinit_master]
}

# Crear nodos worker
resource "multipass_instance" "rancher_workers" {
  count = var.worker_count

  name   = "worker-${count.index + 1}"
  cpus   = var.worker_cpus
  memory = var.worker_memory
  disk   = var.worker_disk
  image  = "jammy"

  cloudinit_file = local_file.cloudinit_worker.filename

  depends_on = [local_file.cloudinit_worker]
}

# Leer la llave pública SSH desde el archivo
locals {
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
}

# Crear directorio para archivos cloud-init generados
resource "null_resource" "create_generated_dir" {
  provisioner "local-exec" {
    command = "mkdir -p ${path.module}/cloud-init-scripts/generated"
  }
}

# Generar cloud-init para master dinámicamente
resource "local_file" "cloudinit_master" {
  filename = "${path.module}/cloud-init-scripts/generated/cloud-init-master.yaml"
  content = templatefile("${path.module}/cloud-init-scripts/cloud-init-master.tpl", {
    ssh_public_key = local.ssh_public_key
  })

  depends_on = [null_resource.create_generated_dir]
}

# Generar cloud-init para workers dinámicamente
resource "local_file" "cloudinit_worker" {
  filename = "${path.module}/cloud-init-scripts/generated/cloud-init-worker.yaml"
  content = templatefile("${path.module}/cloud-init-scripts/cloud-init-worker.tpl", {
    ssh_public_key = local.ssh_public_key
  })

  depends_on = [null_resource.create_generated_dir]
}

# Obtener IP del master usando multipass info
data "external" "master_ip" {
  program = ["bash", "-c", "multipass info ${multipass_instance.rancher_master.name} --format json | jq -r '.info.\"${multipass_instance.rancher_master.name}\".ipv4[0] | {\"ip\": .}'"]

  depends_on = [multipass_instance.rancher_master]
}

# Obtener IPs de los workers
data "external" "worker_ips" {
  for_each = { for idx, worker in multipass_instance.rancher_workers : idx => worker }

  program = ["bash", "-c", "multipass info ${each.value.name} --format json | jq -r '.info.\"${each.value.name}\".ipv4[0] | {\"ip\": .}'"]

  depends_on = [multipass_instance.rancher_workers]
}

# Generar inventario de Ansible dinámicamente
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible/inventory.ini"
  content = templatefile("${path.module}/ansible/inventory.ini.template", {
    master_name = multipass_instance.rancher_master.name
    master_ip   = data.external.master_ip.result.ip
    workers = [
      for idx, worker in multipass_instance.rancher_workers : {
        name = worker.name
        ip   = data.external.worker_ips[idx].result.ip
      }
    ]
  })

  depends_on = [
    data.external.master_ip,
    data.external.worker_ips
  ]
}