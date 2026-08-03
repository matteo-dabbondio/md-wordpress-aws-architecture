output "repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.wordpress_apache.repository_url
}

output "repository_arn" {
  description = "ECR repository ARN"
  value       = aws_ecr_repository.wordpress_apache.arn
}

output "repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.wordpress_apache.name
}

output "registry_id" {
  description = "Registry ID (AWS account ID hosting the repository)"
  value       = aws_ecr_repository.wordpress_apache.registry_id
}
