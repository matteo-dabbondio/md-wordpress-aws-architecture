variable "name_prefix" {
  type        = string
  description = "The prefix for the name of the resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The common tags for the resources"
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID"
}

variable "isolated_subnet_ids" {
  description = "Isolated subnet IDs for Valkey Serverless"
  type        = map(string)
}

variable "max_data_storage_gb" {
  description = "Max data storage (GB) — caps Serverless spend"
  type        = number
  default     = 1
}

variable "max_ecpu_per_second" {
  description = "Max ECPU/second — caps Serverless spend"
  type        = number
  default     = 1000
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window (0 = delete immediately on destroy)"
  type        = number
  default     = 0
}