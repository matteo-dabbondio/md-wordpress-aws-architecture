variable "name_prefix" {
  type        = string
  description = "The prefix for the name of the resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The common tags for the resources"
}

variable "vpc_id" {
  description = "VPC ID (from networking)"
  type        = string
}

variable "isolated_subnet_ids" {
  description = "Isolated subnet IDs for Aurora (from networking module)"
  type        = map(string)
}

variable "database_name" {
  description = "Initial MySQL schema/database name used by WordPress"
  type        = string
  default     = "wordpress"
}

variable "master_username" {
  description = "Master DB login username (not the WordPress admin user)"
  type        = string
  default     = "wordpress"
}

variable "engine_version" {
  description = "Aurora MySQL engine version (Serverless v2 compatible)"
  type        = string
  default     = "8.0.mysql_aurora.3.08.2"
}

variable "min_capacity" {
  description = "Aurora Serverless v2 minimum ACU"
  type        = number
  default     = 0.5
}

variable "max_capacity" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 4
}

variable "backup_retention_period" {
  description = "Automated backup retention in days"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Protect cluster from deletion"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy"
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "Apply DB modifications immediately (true in dev; prefer false in prod)"
  type        = bool
  default     = false
}

variable "master_password_rotation_days" {
  description = "Rotate the RDS-managed master password every N days"
  type        = number
  default     = 30
}
