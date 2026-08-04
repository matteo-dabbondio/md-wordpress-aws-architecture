variable "name_prefix" {
  type        = string
  description = "The prefix for the name of the resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The common tags for the resources"
}

variable "container_image_tag" {
  description = "ECR image tag referenced by the bootstrap task definition (deploy alias, not WordPress version). App version is a Docker build-arg / CI concern."
  type        = string
  default     = "app"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Map of AZ -> private subnet ID"
  type        = map(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "aurora_security_group_id" {
  description = "Aurora security group ID"
  type        = string
}

variable "cache_security_group_id" {
  description = "ElastiCache security group ID"
  type        = string
}

variable "efs_security_group_id" {
  description = "EFS security group ID "
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "wordpress_url" {
  description = "Public site URL (https://<cloudfront_domain>) for WP install / WP_HOME"
  type        = string
}

variable "db_host" {
  description = "Aurora writer endpoint hostname"
  type        = string
}

variable "db_port" {
  description = "Aurora port (from database)"
  type        = number
}

variable "db_name" {
  description = "MySQL schema name for WordPress"
  type        = string
}

variable "db_master_user_secret_arn" {
  description = "ARN of RDS-managed Secrets Manager secret (username/password)"
  type        = string
}

variable "cache_auth_secret_arn" {
  description = "ARN of Valkey auth secret (username/password/host/port JSON)"
  type        = string
}

variable "media_bucket_arn" {
  description = "S3 media bucket ARN for task role (uploads offload)"
  type        = string
}

variable "media_bucket_id" {
  description = "S3 media bucket id/name"
  type        = string
}

variable "efs_file_system_id" {
  description = "EFS file system ID for shared /var/www/html"
  type        = string
}

variable "efs_file_system_arn" {
  description = "EFS file system ARN for task role IAM"
  type        = string
}

variable "efs_access_point_id" {
  description = "EFS access point ID for document root"
  type        = string
}

variable "efs_access_point_arn" {
  description = "EFS access point ARN for task role IAM"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for autoscaling ResourceLabel (app/name/id)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for autoscaling ResourceLabel (targetgroup/name/id)"
  type        = string
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Desired number of tasks (HA baseline: 2)"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Autoscaling minimum task count"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Autoscaling maximum task count"
  type        = number
  default     = 6
}

variable "fargate_base" {
  description = "Capacity provider base on FARGATE (on-demand)"
  type        = number
  default     = 2
}

variable "fargate_spot_weight" {
  description = "Capacity provider weight for FARGATE_SPOT"
  type        = number
  default     = 4
}

variable "cpu_target_value" {
  description = "Target tracking CPU utilization percent"
  type        = number
  default     = 70
}

variable "request_count_target_value" {
  description = "ALBRequestCountPerTarget target (req/task/min)"
  type        = number
  default     = 1000
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to ignore ELB health checks after task start (WP bootstrap)"
  type        = number
  default     = 180
}

variable "log_retention_days" {
  description = "CloudWatch log group retention for the Apache container"
  type        = number
  default     = 14
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window (0 = immediate delete on destroy; raise in prod)"
  type        = number
  default     = 0
}