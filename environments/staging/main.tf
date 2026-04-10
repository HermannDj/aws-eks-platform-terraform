terraform {
  required_version = ">= 1.5"
  backend "s3" {
    bucket         = "eks-platform-tfstate-619071315221"
    key            = "staging/terraform.tfstate"
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
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source             = "../../modules/vpc"
  project            = var.project
  environment        = "staging"
  vpc_cidr           = "10.1.0.0/16"
  availability_zones = ["ca-central-1a", "ca-central-1b"]
  single_nat_gateway = true
  tags               = {}
}

module "eks" {
  source             = "../../modules/eks"
  project            = var.project
  environment        = "staging"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  kubernetes_version = "1.29"
  node_instance_types = ["t3.small"]
  node_desired_size  = 2
  node_min_size      = 1
  node_max_size      = 4
  tags               = {}
}

module "rds" {
  source                      = "../../modules/rds"
  project                     = var.project
  environment                 = "staging"
  vpc_id                      = module.vpc.vpc_id
  database_subnet_ids         = module.vpc.database_subnet_ids
  eks_nodes_security_group_id = module.eks.nodes_security_group_id
  instance_class              = "db.t3.small"
  multi_az                    = false
  database_password           = var.db_password
  tags                        = {}
}

module "alb" {
  source            = "../../modules/alb"
  project           = var.project
  environment       = "staging"
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  tags              = {}
}
