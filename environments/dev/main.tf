terraform {
  required_version = ">= 1.5"

  backend "s3" {
    bucket         = "eks-platform-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "eks-platform-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = var.owner
      Repository  = "aws-eks-platform-terraform"
    }
  }
}

# ─── Module VPC ───────────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  project     = var.project
  environment = "dev"

  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["ca-central-1a", "ca-central-1b"]

  # Dev : 1 seul NAT Gateway (économique — évite ~$32/mois supplémentaire)
  single_nat_gateway       = true
  flow_logs_retention_days = 7

  tags = local.common_tags
}

# ─── Module EKS ───────────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  project     = var.project
  environment = "dev"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  kubernetes_version = "1.29"

  # Dev : accès public à l'API server (pas de bastion nécessaire)
  endpoint_public_access = true
  public_access_cidrs    = ["0.0.0.0/0"]

  # t3.micro = Free Tier (750h/mois 12 premiers mois)
  node_instance_types = ["t3.micro"]
  node_disk_size      = 20
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3

  tags = local.common_tags
}

# ─── Module Security ──────────────────────────────────────────────────────────
module "security" {
  source = "../../modules/security"

  project     = var.project
  environment = "dev"

  # Dev : pas de KMS CMK ($1/mois) — AWS managed key
  use_kms_cmk                 = false
  secret_recovery_window_days = 0

  db_username = var.db_username
  db_password = var.db_password
  db_host     = module.rds.db_instance_address
  db_name     = var.db_name

  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  app_namespace       = "app"
  app_service_account = "app-sa"

  tags = local.common_tags
}

# ─── Module RDS ───────────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = "dev"

  vpc_id                      = module.vpc.vpc_id
  database_subnet_ids         = module.vpc.database_subnet_ids
  eks_nodes_security_group_id = module.eks.nodes_security_group_id

  # Dev : db.t3.micro = Free Tier, single-AZ
  instance_class  = "db.t3.micro"
  multi_az        = false
  allocated_storage = 20

  database_name     = var.db_name
  database_username = var.db_username
  database_password = var.db_password

  deletion_protection = false
  skip_final_snapshot = true
  backup_retention_days = 1

  tags = local.common_tags
}

# ─── Module ElastiCache ───────────────────────────────────────────────────────
module "elasticache" {
  source = "../../modules/elasticache"

  project     = var.project
  environment = "dev"

  vpc_id                      = module.vpc.vpc_id
  database_subnet_ids         = module.vpc.database_subnet_ids
  eks_nodes_security_group_id = module.eks.nodes_security_group_id

  # Dev : cache.t3.micro single node = Free Tier
  node_type          = "cache.t3.micro"
  num_cache_clusters = 1

  tags = local.common_tags
}

# ─── Module ALB ───────────────────────────────────────────────────────────────
module "alb" {
  source = "../../modules/alb"

  project     = var.project
  environment = "dev"

  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  tags = local.common_tags
}

# ─── Module Monitoring ────────────────────────────────────────────────────────
module "monitoring" {
  source = "../../modules/monitoring"

  project      = var.project
  environment  = "dev"
  cluster_name = module.eks.cluster_name

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  alarm_email        = var.alarm_email
  log_retention_days = 7

  tags = local.common_tags
}

locals {
  common_tags = {
    Project     = var.project
    Environment = "dev"
  }
}
