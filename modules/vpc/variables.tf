variable "project" {
  description = "Nom du projet — préfixe toutes les ressources"
  type        = string
}

variable "environment" {
  description = "Environnement : dev, staging, prod"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment doit être dev, staging ou prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block du VPC (ex: 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr doit être un CIDR valide."
  }
}

variable "availability_zones" {
  description = "Liste des AZs à utiliser (ex: [\"ca-central-1a\", \"ca-central-1b\"])"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "Au moins 2 AZs requises pour la haute disponibilité."
  }
}

variable "single_nat_gateway" {
  description = "true = 1 NAT Gateway partagé (dev, économique) | false = 1 NAT/AZ (prod, HA)"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Rétention des VPC Flow Logs dans CloudWatch (jours)"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.flow_logs_retention_days)
    error_message = "flow_logs_retention_days doit être une valeur CloudWatch valide."
  }
}

variable "tags" {
  description = "Tags communs appliqués à toutes les ressources"
  type        = map(string)
  default     = {}
}
