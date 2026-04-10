variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }

variable "database_subnet_ids" {
  description = "Subnets database (tier isolé, pas de route internet)"
  type        = list(string)
}

variable "eks_nodes_security_group_id" {
  description = "SG des EKS nodes — seul autorisé à accéder RDS"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN de la clé KMS pour chiffrer le stockage RDS"
  type        = string
  default     = null
}

variable "instance_class" {
  description = "Classe d'instance RDS (db.t3.micro = Free Tier)"
  type        = string
  default     = "db.t3.micro"
}

variable "database_name" {
  description = "Nom de la base de données initiale"
  type        = string
  default     = "appdb"
}

variable "database_username" {
  description = "Username administrateur PostgreSQL"
  type        = string
  default     = "dbadmin"
}

variable "database_password" {
  description = "Mot de passe administrateur (utiliser Secrets Manager en prod)"
  type        = string
  sensitive   = true
}

variable "allocated_storage" {
  description = "Stockage initial (GB) — 20 GB inclus dans Free Tier"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Stockage max pour autoscaling (0 = désactivé)"
  type        = number
  default     = 100
}

variable "multi_az" {
  description = "true = Multi-AZ (prod, HA) | false = single-AZ (dev, Free Tier)"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protection contre la suppression accidentelle"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "true en dev pour permettre destroy rapide"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Rétention des backups automatiques (jours)"
  type        = number
  default     = 7
}

variable "performance_insights_enabled" {
  description = "Performance Insights (gratuit 7 jours)"
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
