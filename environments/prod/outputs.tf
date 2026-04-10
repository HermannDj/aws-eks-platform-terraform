output "cluster_name" { value = module.eks.cluster_name }
output "kms_key_arn" { value = module.security.kms_key_arn }
output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ca-central-1 --name ${module.eks.cluster_name}"
}
