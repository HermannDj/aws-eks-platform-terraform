variable "project" {
  type = string
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment doit être dev, staging ou prod."
  }
}

variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "Subnets privés pour les worker nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Subnets publics (inclus dans la config VPC du cluster)"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Version Kubernetes (ex: \"1.29\")"
  type        = string
  default     = "1.29"
}

variable "endpoint_public_access" {
  description = "true = API server accessible depuis internet (dev) | false = privé uniquement (prod)"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs autorisés à accéder à l'API server public"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "Types de logs control plane à envoyer dans CloudWatch"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "node_instance_types" {
  description = "Types d'instances pour les worker nodes"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "node_disk_size" {
  description = "Taille du disque EBS des nodes (GB)"
  type        = number
  default     = 20
}

variable "node_desired_size" {
  description = "Nombre de nodes souhaité"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Nombre minimum de nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Nombre maximum de nodes"
  type        = number
  default     = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}
