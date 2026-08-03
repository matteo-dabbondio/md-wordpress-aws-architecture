output "security_group_id" {
  description = "EFS security group ID"
  value       = aws_security_group.this.id
}

output "file_system_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.this.id
  # Mount targets must exist before ECS tasks can attach.
  depends_on = [aws_efs_mount_target.this]
}

output "file_system_arn" {
  description = "EFS file system ARN"
  value       = aws_efs_file_system.this.arn
  depends_on  = [aws_efs_mount_target.this]
}

output "access_point_id" {
  description = "EFS access point ID for document root"
  value       = aws_efs_access_point.html.id
}

output "access_point_arn" {
  description = "EFS access point ARN for document root"
  value       = aws_efs_access_point.html.arn
}