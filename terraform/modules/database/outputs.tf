output "cluster_id" {
  description = "Aurora cluster identifier"
  value       = aws_rds_cluster.this.id
}

output "cluster_endpoint" {
  description = "Writer endpoint (hostname)"
  value       = aws_rds_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint (hostname)"
  value       = aws_rds_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "Database port"
  value       = aws_rds_cluster.this.port
}

output "database_name" {
  description = "MySQL schema/database name"
  value       = aws_rds_cluster.this.database_name
}

output "master_username" {
  description = "Master DB username"
  value       = aws_rds_cluster.this.master_username
}

output "master_user_secret_arn" {
  description = "ARN of the RDS-managed Secrets Manager secret for the master password"
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
  sensitive   = true
}

output "security_group_id" {
  description = "Aurora security group ID"
  value       = aws_security_group.this.id
}
