output "security_group_id" {
  description = "ECS tasks security group ID"
  value       = aws_security_group.this.id
}

output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.wordpress.name
}

output "log_group_name" {
  description = "CloudWatch log group for the Apache container"
  value       = aws_cloudwatch_log_group.apache.name
}

output "task_role_arn" {
  description = "ECS task role ARN"
  value       = aws_iam_role.task.arn
}