output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_gateway_public_ips" {
  description = "IPs publiques NAT (à whitelister si besoin)"
  value       = module.vpc.nat_gateway_public_ips
}

output "rds_endpoint" {
  value     = module.rds.db_instance_endpoint
  sensitive = true
}

output "redis_endpoint" {
  value     = module.elasticache.redis_endpoint
  sensitive = true
}

output "lbc_role_arn" {
  description = "ARN à annoter sur le ServiceAccount aws-load-balancer-controller"
  value       = module.alb.lbc_role_arn
}

output "secrets_reader_role_arn" {
  description = "ARN IRSA pour lire les secrets depuis les pods app"
  value       = module.security.secrets_reader_role_arn
}

output "kubeconfig_command" {
  description = "Commande pour configurer kubectl"
  value       = "aws eks update-kubeconfig --region ca-central-1 --name ${module.eks.cluster_name}"
}
