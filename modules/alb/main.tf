# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  MODULE : alb                                                               │
# │                                                                             │
# │  IRSA pour AWS Load Balancer Controller :                                   │
# │    Le controller Kubernetes crée/gère les ALB AWS automatiquement           │
# │    quand on crée un Ingress. Ce module crée le IAM Role IRSA               │
# │    et le Security Group du ALB.                                             │
# │                                                                             │
# │  Free Tier : 750h ALB/mois (12 premiers mois)                              │
# └─────────────────────────────────────────────────────────────────────────────┘

locals {
  name        = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Module = "alb" })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─── Security Group ALB ───────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Security group pour Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-alb-sg" })
}

# ─── IRSA — AWS Load Balancer Controller ──────────────────────────────────────
# Le LBC tourne comme pod Kubernetes et a besoin de permissions AWS
# pour créer/modifier les ALB, Target Groups, etc.
data "aws_iam_policy_document" "lbc_assume" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "${local.name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
  tags               = local.common_tags
}

# Policy officielle AWS pour le Load Balancer Controller
resource "aws_iam_role_policy" "lbc" {
  name = "${local.name}-lbc-policy"
  role = aws_iam_role.lbc.id

  policy = file("${path.module}/iam_policy.json")
}
