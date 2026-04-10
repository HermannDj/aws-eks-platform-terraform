output "cluster_name" { value = module.eks.cluster_name }

output "cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ca-central-1 --name ${module.eks.cluster_name}"
}
