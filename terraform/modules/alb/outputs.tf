output "security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.this.id
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch / autoscaling ResourceLabel"
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "ALB DNS name (CloudFront origin)"
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "Target group ARN for the ECS service"
  value       = aws_lb_target_group.wordpress.arn
}