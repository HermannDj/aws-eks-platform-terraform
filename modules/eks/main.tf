# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  MODULE : eks                                                               │
# │                                                                             │
# │  Composants :                                                               │
# │    1. IAM Role cluster EKS                                                  │
# │    2. Cluster EKS (control plane)                                           │
# │    3. IAM Role nodes (worker nodes)                                         │
# │    4. Managed Node Group                                                    │
# │    5. IRSA (IAM Roles for Service Accounts) — OIDC provider                │
# │    6. aws-auth ConfigMap (accès kubectl)                                    │
# │                                                                             │
# │  IRSA : pattern clé pour un profil Architect                               │
# │    Au lieu de donner des permissions AWS aux nodes entiers,                 │
# │    chaque pod reçoit exactement les permissions dont il a besoin            │
# │    via un ServiceAccount Kubernetes lié à un IAM Role AWS.                 │
# └─────────────────────────────────────────────────────────────────────────────┘

locals {
  name        = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Module = "eks" })
}

# ─── 1. IAM Role — Control Plane EKS ─────────────────────────────────────────
data "aws_iam_policy_document" "eks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${local.name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ─── 2. Cluster EKS ───────────────────────────────────────────────────────────
resource "aws_eks_cluster" "this" {
  name     = local.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # Logs du control plane → CloudWatch
  enabled_cluster_log_types = var.cluster_log_types

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  tags = local.common_tags
}

# ─── Security Group — Cluster ─────────────────────────────────────────────────
resource "aws_security_group" "cluster" {
  name        = "${local.name}-eks-cluster-sg"
  description = "Security group pour le control plane EKS"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name}-eks-cluster-sg" })
}

resource "aws_security_group_rule" "cluster_egress" {
  security_group_id = aws_security_group.cluster.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

resource "aws_security_group_rule" "cluster_nodes_ingress" {
  security_group_id        = aws_security_group.cluster.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow nodes to reach API server"
}

# ─── 3. IAM Role — Worker Nodes ───────────────────────────────────────────────
data "aws_iam_policy_document" "nodes_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${local.name}-eks-nodes-role"
  assume_role_policy = data.aws_iam_policy_document.nodes_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "nodes_worker" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_cni" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "nodes_ecr" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ─── Security Group — Nodes ───────────────────────────────────────────────────
resource "aws_security_group" "nodes" {
  name        = "${local.name}-eks-nodes-sg"
  description = "Security group pour les worker nodes EKS"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name}-eks-nodes-sg" })
}

resource "aws_security_group_rule" "nodes_egress" {
  security_group_id = aws_security_group.nodes.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound"
}

resource "aws_security_group_rule" "nodes_self" {
  security_group_id = aws_security_group.nodes.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  self              = true
  description       = "Allow nodes to communicate with each other"
}

resource "aws_security_group_rule" "nodes_cluster_ingress" {
  security_group_id        = aws_security_group.nodes.id
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow control plane to reach nodes"
}

# ─── 4. Managed Node Group ────────────────────────────────────────────────────
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${local.name}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.node_instance_types
  disk_size       = var.node_disk_size

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role        = "worker"
    environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
  ]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# ─── 5. IRSA — OIDC Provider ──────────────────────────────────────────────────
# IRSA = IAM Roles for Service Accounts
# Permet à un pod Kubernetes d'assumer un IAM Role AWS précis
# sans donner de permissions à tous les nodes.
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = local.common_tags
}

# ─── CloudWatch Log Group pour cluster logs ───────────────────────────────────
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.name}/cluster"
  retention_in_days = 7

  tags = local.common_tags
}
