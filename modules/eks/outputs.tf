output "cluster_name" {
  description = "Nom du cluster EKS"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "URL de l'API server EKS"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Certificat CA du cluster (base64)"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_version" {
  description = "Version Kubernetes du cluster"
  value       = aws_eks_cluster.this.version
}

output "oidc_provider_arn" {
  description = "ARN de l'OIDC provider (requis pour IRSA)"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL de l'OIDC provider (sans https://)"
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "node_role_arn" {
  description = "ARN du IAM Role des worker nodes"
  value       = aws_iam_role.nodes.arn
}

output "cluster_security_group_id" {
  description = "ID du Security Group du control plane"
  value       = aws_security_group.cluster.id
}

output "nodes_security_group_id" {
  description = "ID du Security Group des worker nodes"
  value       = aws_security_group.nodes.id
}
