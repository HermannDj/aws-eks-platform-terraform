output "vpc_id" {
  description = "ID du VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block du VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs des subnets publics (ALB, NAT)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs des subnets privés (EKS nodes)"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs des subnets database (RDS, ElastiCache)"
  value       = aws_subnet.database[*].id
}

output "nat_gateway_ids" {
  description = "IDs des NAT Gateways"
  value       = aws_nat_gateway.this[*].id
}

output "nat_gateway_public_ips" {
  description = "IPs publiques des NAT Gateways (whitelist firewall)"
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "ID de l'Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "flow_logs_log_group" {
  description = "Nom du CloudWatch Log Group des VPC Flow Logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}
