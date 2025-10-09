variable "master_cpus" {
  description = "Número de CPUs del nodo master"
  default     = 4
}

variable "master_memory" {
  description = "Memoria RAM del master"
  default     = "4G"
}

variable "master_disk" {
  description = "Tamaño del disco del master"
  default     = "20G"
}

variable "worker_cpus" {
  description = "Número de CPUs por nodo worker"
  default     = 2
}

variable "worker_memory" {
  description = "Memoria RAM por nodo worker"
  default     = "2G"
}

variable "worker_disk" {
  description = "Tamaño del disco por nodo worker"
  default     = "10G"
}

variable "worker_count" {
  description = "Cantidad de nodos worker a crear"
  default     = 4
}
