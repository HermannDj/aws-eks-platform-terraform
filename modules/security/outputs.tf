output "kms_key_arn" {
  description = "ARN de la CMK KMS (null si use_kms_cmk = false)"
  value       = var.use_kms_cmk ? aws_kms_key.main[0].arn : null
}

output "kms_key_alias" {
  value = var.use_kms_cmk ? aws_kms_alias.main[0].name : null
}

output "db_secret_arn" {
  description = "ARN du secret Secrets Manager contenant les credentials DB"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secrets_reader_role_arn" {
  description = "ARN du IAM Role IRSA pour lire les secrets depuis les pods"
  value       = aws_iam_role.secrets_reader.arn
}
