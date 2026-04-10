output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "lbc_role_arn" {
  description = "IRSA Role ARN pour AWS Load Balancer Controller"
  value       = aws_iam_role.lbc.arn
}
