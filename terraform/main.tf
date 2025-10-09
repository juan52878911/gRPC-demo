# Nodo Master (Rancher o K3s server)
resource "multipass_instance" "rancher_master" {
  name   = "rancher-master"
  cpus   = var.master_cpus
  memory = var.master_memory
  disk   = var.master_disk
  image  = "22.04"

  # Puedes usar cloud-init inline si quieres instalar cosas luego
  cloudinit_file = ""
}

# Crear nodos worker
resource "multipass_instance" "rancher_workers" {
  count = var.worker_count

  name   = "rancher-worker-${count.index + 1}"
  cpus   = var.worker_cpus
  memory = var.worker_memory
  disk   = var.worker_disk
  image  = "jammy"
}