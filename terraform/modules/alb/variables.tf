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

variable "public_subnet_ids" {
  description = "Map of AZ -> public subnet ID (from networking)"
  type        = map(string)
}

variable "enable_deletion_protection" {
  description = "Protect ALB from deletion"
  type        = bool
  default     = false
}

variable "deregistration_delay" {
  description = "Target deregistration delay in seconds (drain time)"
  type        = number
  default     = 30
}
