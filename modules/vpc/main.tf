# ┌─────────────────────────────────────────────────────────────────────────────┐
# │  MODULE : vpc                                                               │
# │                                                                             │
# │  Architecture 3-tier :                                                      │
# │    • public    : ALB, NAT Gateway, Bastion                                  │
# │    • private   : EKS nodes, app workloads                                   │
# │    • database  : RDS, ElastiCache (pas de route internet)                   │
# │                                                                             │
# │  Fonctionnalités :                                                          │
# │    - NAT Gateway (single en dev, 1/AZ en prod pour HA)                     │
# │    - VPC Flow Logs → CloudWatch                                             │
# │    - DNS resolution + hostnames activés (requis par EKS)                   │
# │    - Tags kubernetes.io/* requis par l'AWS Load Balancer Controller         │
# └─────────────────────────────────────────────────────────────────────────────┘

locals {
  name        = "${var.project}-${var.environment}"
  common_tags = merge(var.tags, { Module = "vpc" })

  # Nombre de NAT Gateways : 1 en dev (économique), 1/AZ en prod (HA)
  nat_gateway_count = var.single_nat_gateway ? 1 : length(var.availability_zones)
}

# ─── VPC ──────────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Requis par EKS pour la résolution DNS des endpoints AWS
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-vpc"
    # Tag requis par AWS Load Balancer Controller pour découvrir le VPC
    "kubernetes.io/cluster/${local.name}" = "shared"
  })
}

# ─── Internet Gateway ─────────────────────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-igw"
  })
}

# ─── Subnets publics ──────────────────────────────────────────────────────────
# ALB, NAT Gateway — doivent être publics (route vers IGW)
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-${var.availability_zones[count.index]}"
    # Tag requis par AWS Load Balancer Controller pour placer les ALB publics
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${local.name}"         = "shared"
  })
}

# ─── Subnets privés ───────────────────────────────────────────────────────────
# EKS nodes — accès internet via NAT, pas d'IP publique
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name}-private-${var.availability_zones[count.index]}"
    # Tag requis par AWS Load Balancer Controller pour placer les ALB internes
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${local.name}"         = "owned"
  })
}

# ─── Subnets database ─────────────────────────────────────────────────────────
# RDS, ElastiCache — aucune route internet, isolation maximale
resource "aws_subnet" "database" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 2 * length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name}-database-${var.availability_zones[count.index]}"
  })
}

# ─── Elastic IPs pour NAT Gateway ─────────────────────────────────────────────
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ─── NAT Gateway ──────────────────────────────────────────────────────────────
# Placés dans les subnets publics — permettent aux nodes privés d'accéder internet
resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = "${local.name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

# ─── Route table publique ─────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ─── Route tables privées ─────────────────────────────────────────────────────
# Une par AZ si multi-NAT, une seule si single_nat_gateway
resource "aws_route_table" "private" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ─── Route table database (pas de route internet) ────────────────────────────
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name}-database-rt"
  })
}

resource "aws_route_table_association" "database" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}

# ─── VPC Flow Logs ────────────────────────────────────────────────────────────
# Enregistre tout le trafic réseau — audit, sécurité, debugging
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${local.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days

  tags = local.common_tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${local.name}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${local.name}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = merge(local.common_tags, {
    Name = "${local.name}-flow-logs"
  })
}

# ─── Security Group de base ───────────────────────────────────────────────────
# SG par défaut du VPC — on révoque toutes les règles (bonne pratique)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  # Pas d'ingress ni egress → isolation totale par défaut
  tags = merge(local.common_tags, {
    Name = "${local.name}-default-sg-DO-NOT-USE"
  })
}
