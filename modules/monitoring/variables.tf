variable "project" { type = string }
variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "oidc_provider_arn" { type = string }
variable "oidc_provider_url" { type = string }

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "alarm_email" {
  type    = string
  default = ""
}

variable "cpu_threshold_percent" {
  type    = number
  default = 80
}

variable "memory_threshold_percent" {
  type    = number
  default = 80
}

variable "tags" {
  type    = map(string)
  default = {}
}
