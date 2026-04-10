# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  MODULE : rds                                                               │
# │                                                                             │
# │  Dev  : PostgreSQL t3.micro (Free Tier 12 mois) — single-AZ               │
# │  Prod : Aurora PostgreSQL (multi-AZ, auto-scaling, ~$60/mois)             │
# │                                                                             │
# │  Ce module déploie RDS PostgreSQL standard (pas Aurora) pour               │
# │  rester dans le Free Tier en dev. Le code prod montre Aurora.              │
# └─────────────────────────────────────────────────────────────────────────────┘

locals {
  name        = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Module = "rds" })
}

# ─── Subnet Group ─────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name        = "${local.name}-db-subnet-group"
  description = "Subnet group pour RDS ${local.name}"
  subnet_ids  = var.database_subnet_ids

  tags = merge(local.common_tags, { Name = "${local.name}-db-subnet-group" })
}

# ─── Security Group ───────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "Security group RDS PostgreSQL — accès depuis EKS nodes uniquement"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL depuis EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.eks_nodes_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-rds-sg" })
}

# ─── Parameter Group ──────────────────────────────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name        = "${local.name}-postgres-params"
  family      = "postgres15"
  description = "Paramètres PostgreSQL optimisés pour ${local.name}"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log les requêtes > 1s
  }

  tags = local.common_tags
}

# ─── Instance RDS ─────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier = "${local.name}-postgres"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.instance_class

  db_name  = var.database_name
  username = var.database_username
  password = var.database_password

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az               = var.multi_az
  publicly_accessible    = false
  deletion_protection    = var.deletion_protection
  skip_final_snapshot    = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name}-final-snapshot"

  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  auto_minor_version_upgrade  = true
  copy_tags_to_snapshot       = true
  performance_insights_enabled = var.performance_insights_enabled

  tags = merge(local.common_tags, { Name = "${local.name}-postgres" })
}
