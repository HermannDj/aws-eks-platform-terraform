variable "aws_region" {
  type    = string
  default = "ca-central-1"
}

variable "project" {
  type    = string
  default = "eks-platform"
}

variable "owner" {
  type    = string
  default = "devops-team"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "dbadmin"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "alarm_email" {
  type    = string
  default = ""
}
