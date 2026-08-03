output "endpoint_address" {
  description = "Valkey Serverless primary endpoint hostname"
  value       = aws_elasticache_serverless_cache.this.endpoint[0].address
}

output "endpoint_port" {
  description = "Valkey Serverless endpoint port"
  value       = aws_elasticache_serverless_cache.this.endpoint[0].port
}

output "reader_endpoint_address" {
  description = "Valkey Serverless reader endpoint hostname"
  value       = try(aws_elasticache_serverless_cache.this.reader_endpoint[0].address, null)
}

output "auth_secret_arn" {
  description = "Secrets Manager ARN (JSON: username, password, host, port)"
  value       = aws_secretsmanager_secret.auth.arn
  sensitive   = true
}

output "serverless_cache_name" {
  description = "ElastiCache Serverless cache name"
  value       = aws_elasticache_serverless_cache.this.name
}

output "serverless_cache_arn" {
  description = "ElastiCache Serverless cache ARN"
  value       = aws_elasticache_serverless_cache.this.arn
}

output "security_group_id" {
  description = "ElastiCache security group ID"
  value       = aws_security_group.this.id
}