output "db_instance_endpoint" {
  description = "Endpoint de connexion RDS (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "db_instance_address" {
  description = "Hostname RDS"
  value       = aws_db_instance.this.address
}

output "db_instance_port" {
  description = "Port PostgreSQL"
  value       = aws_db_instance.this.port
}

output "db_instance_name" {
  description = "Nom de la base de données"
  value       = aws_db_instance.this.db_name
}

output "db_instance_username" {
  description = "Username administrateur"
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "db_security_group_id" {
  description = "ID du Security Group RDS"
  value       = aws_security_group.rds.id
}
