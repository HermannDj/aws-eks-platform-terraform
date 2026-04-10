variable "aws_region" { type = string; default = "ca-central-1" }
variable "project" { type = string; default = "eks-platform" }
variable "db_password" { type = string; sensitive = true }
