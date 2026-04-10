# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  MODULE : security                                                          │
# │                                                                             │
# │  Composants :                                                               │
# │    1. KMS Customer Managed Key (CMK) — chiffre RDS, EKS secrets, logs      │
# │    2. Secrets Manager — credentials DB, tokens applicatifs                 │
# │    3. IRSA Role — permet aux pods de lire Secrets Manager sans credentials  │
# │                                                                             │
# │  Coût :                                                                     │
# │    KMS CMK : $1/mois/clé (désactivable en dev via use_kms_cmk = false)     │
# │    Secrets Manager : $0.40/secret/mois                                     │
# └─────────────────────────────────────────────────────────────────────────────┘

locals {
  name        = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Module = "security" })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── 1. KMS CMK ───────────────────────────────────────────────────────────────
resource "aws_kms_key" "main" {
  count = var.use_kms_cmk ? 1 : 0

  description             = "CMK pour ${local.name} — RDS, EKS secrets, CloudWatch Logs"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true # Rotation annuelle automatique

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow EKS to use the key"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${data.aws_region.current.name}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, { Name = "${local.name}-cmk" })
}

resource "aws_kms_alias" "main" {
  count = var.use_kms_cmk ? 1 : 0

  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.main[0].key_id
}

# ─── 2. Secrets Manager — credentials DB ──────────────────────────────────────
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${local.name}/db/credentials"
  description = "Credentials PostgreSQL pour ${local.name}"
  kms_key_id  = var.use_kms_cmk ? aws_kms_key.main[0].arn : null

  recovery_window_in_days = var.secret_recovery_window_days

  tags = merge(local.common_tags, { Name = "${local.name}-db-credentials" })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = var.db_host
    port     = 5432
    dbname   = var.db_name
    url      = "postgresql://${var.db_username}:${var.db_password}@${var.db_host}:5432/${var.db_name}"
  })
}

# ─── 3. IRSA Role — lecture Secrets Manager depuis pods ──────────────────────
# Pattern IRSA : le pod Kubernetes assume ce rôle IAM via OIDC
# Sans IRSA, il faudrait donner les permissions à TOUS les nodes
data "aws_iam_policy_document" "secrets_reader_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.app_namespace}:${var.app_service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "secrets_reader" {
  name               = "${local.name}-secrets-reader"
  assume_role_policy = data.aws_iam_policy_document.secrets_reader_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "secrets_reader" {
  name = "${local.name}-secrets-reader-policy"
  role = aws_iam_role.secrets_reader.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          aws_secretsmanager_secret.db_credentials.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.use_kms_cmk ? [aws_kms_key.main[0].arn] : ["*"]
        Condition = var.use_kms_cmk ? {
          StringEquals = { "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com" }
        } : null
      }
    ]
  })
}
