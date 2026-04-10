variable "project" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }

variable "database_subnet_ids" {
  type = list(string)
}

variable "eks_nodes_security_group_id" {
  type = string
}

variable "node_type" {
  description = "cache.t3.micro = Free Tier | cache.r6g.large = prod"
  type        = string
  default     = "cache.t3.micro"
}

variable "num_cache_clusters" {
  description = "1 = single node (dev) | 2+ = réplication multi-AZ (prod)"
  type        = number
  default     = 1
}

variable "snapshot_retention_days" {
  description = "Rétention des snapshots Redis (0 = désactivé)"
  type        = number
  default     = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}
