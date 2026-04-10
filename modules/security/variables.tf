variable "project" { type = string }
variable "environment" { type = string }

variable "use_kms_cmk" {
  description = "true = KMS CMK ($1/mois) | false = AWS managed key (gratuit, dev)"
  type        = bool
  default     = false
}

variable "kms_deletion_window_days" {
  type    = number
  default = 7
}

variable "secret_recovery_window_days" {
  description = "0 = suppression immédiate (dev) | 7-30 = récupération possible (prod)"
  type        = number
  default     = 0
}

variable "db_username" { type = string }
variable "db_password" { type = string; sensitive = true }
variable "db_host"     { type = string }
variable "db_name"     { type = string; default = "appdb" }

variable "oidc_provider_arn" {
  description = "ARN OIDC provider EKS (output du module eks)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL OIDC provider sans https:// (output du module eks)"
  type        = string
}

variable "app_namespace" {
  description = "Namespace Kubernetes de l'application"
  type        = string
  default     = "app"
}

variable "app_service_account" {
  description = "ServiceAccount Kubernetes autorisé à lire les secrets"
  type        = string
  default     = "app-sa"
}

variable "tags" {
  type    = map(string)
  default = {}
}
