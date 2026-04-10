# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  MODULE : elasticache                                                       │
# │                                                                             │
# │  Redis pour cache applicatif (sessions, résultats de requêtes)             │
# │  Dev : cache.t3.micro single node (Free Tier 12 mois)                      │
# │  Prod : cluster mode avec réplication multi-AZ                             │
# └─────────────────────────────────────────────────────────────────────────────┘

locals {
  name        = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Module = "elasticache" })
}

resource "aws_elasticache_subnet_group" "this" {
  name        = "${local.name}-redis-subnet-group"
  description = "Subnet group Redis ${local.name}"
  subnet_ids  = var.database_subnet_ids
  tags        = local.common_tags
}

resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Security group Redis — accès EKS nodes uniquement"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis depuis EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.eks_nodes_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-redis-sg" })
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${local.name}-redis"
  description          = "Redis cluster pour ${local.name}"

  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_clusters
  port                 = 6379
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [aws_security_group.redis.id]

  # Chiffrement en transit et au repos
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  automatic_failover_enabled = var.num_cache_clusters > 1 ? true : false
  multi_az_enabled           = var.num_cache_clusters > 1 ? true : false

  snapshot_retention_limit = var.snapshot_retention_days
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "Mon:06:00-Mon:07:00"

  tags = local.common_tags
}
