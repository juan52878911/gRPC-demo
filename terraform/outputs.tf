# Outputs para facilitar el acceso a la información del cluster

output "master_name" {
  description = "Nombre del nodo master"
  value       = multipass_instance.rancher_master.name
}

output "master_ip" {
  description = "Dirección IP del nodo master"
  value       = data.external.master_ip.result.ip
}

output "worker_names" {
  description = "Nombres de los nodos worker"
  value       = [for worker in multipass_instance.rancher_workers : worker.name]
}

output "worker_ips" {
  description = "Direcciones IP de los nodos worker"
  value       = { for idx, worker in multipass_instance.rancher_workers : worker.name => data.external.worker_ips[idx].result.ip }
}

output "rancher_url" {
  description = "URL de acceso a Rancher"
  value       = "https://${data.external.master_ip.result.ip}"
}

output "ansible_inventory_path" {
  description = "Ruta al archivo de inventario de Ansible"
  value       = local_file.ansible_inventory.filename
}
