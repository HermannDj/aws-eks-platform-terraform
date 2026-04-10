# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  MODULE : monitoring                                                        │
# │                                                                             │
# │  CloudWatch Container Insights pour EKS :                                  │
# │    - Métriques CPU/Mémoire/Réseau des pods et nodes                        │
# │    - Logs des conteneurs centralisés                                        │
# │    - IRSA pour le CloudWatch Agent (accès sans credentials node)            │
# │                                                                             │
# │  Alarmes :                                                                  │
# │    1. CPU nodes élevé                                                       │
# │    2. Mémoire nodes élevée                                                  │
# │    3. Pods en état Failed                                                   │
# └─────────────────────────────────────────────────────────────────────────────┘

locals {
  name        = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Module = "monitoring" })
}

# ─── IRSA — CloudWatch Agent ──────────────────────────────────────────────────
data "aws_iam_policy_document" "cw_agent_assume" {
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
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cw_agent" {
  name               = "${local.name}-cloudwatch-agent"
  assume_role_policy = data.aws_iam_policy_document.cw_agent_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.cw_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ─── Log Groups ───────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/eks/${local.name}/application"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "dataplane" {
  name              = "/aws/eks/${local.name}/dataplane"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# ─── SNS Topic pour alertes ───────────────────────────────────────────────────
resource "aws_sns_topic" "alarms" {
  count = var.alarm_email != "" ? 1 : 0
  name  = "${local.name}-eks-alarms"
  tags  = local.common_tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

locals {
  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
}

# ─── Alarme 1 : CPU nodes ─────────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "node_cpu" {
  alarm_name          = "${local.name}-eks-node-cpu-high"
  alarm_description   = "CPU nodes EKS > ${var.cpu_threshold_percent}%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.cpu_threshold_percent
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"
  namespace           = "ContainerInsights"
  metric_name         = "node_cpu_utilization"

  dimensions = {
    ClusterName = var.cluster_name
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.alarm_actions
  ok_actions         = local.alarm_actions
  tags               = local.common_tags
}

# ─── Alarme 2 : Mémoire nodes ─────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "node_memory" {
  alarm_name          = "${local.name}-eks-node-memory-high"
  alarm_description   = "Mémoire nodes EKS > ${var.memory_threshold_percent}%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = var.memory_threshold_percent
  evaluation_periods  = 2
  period              = 300
  statistic           = "Average"
  namespace           = "ContainerInsights"
  metric_name         = "node_memory_utilization"

  dimensions = {
    ClusterName = var.cluster_name
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.alarm_actions
  ok_actions         = local.alarm_actions
  tags               = local.common_tags
}

# ─── Alarme 3 : Pods Failed ───────────────────────────────────────────────────
resource "aws_cloudwatch_metric_alarm" "pod_failed" {
  alarm_name          = "${local.name}-eks-pods-failed"
  alarm_description   = "Pods en état Failed détectés dans le cluster"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  evaluation_periods  = 1
  period              = 60
  statistic           = "Sum"
  namespace           = "ContainerInsights"
  metric_name         = "pod_number_of_container_restarts"

  dimensions = {
    ClusterName = var.cluster_name
  }

  treat_missing_data = "notBreaching"
  alarm_actions      = local.alarm_actions
  tags               = local.common_tags
}
