variable "name_prefix" {
  type        = string
  description = "The prefix for the name of the resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The common tags for the resources"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Map of AZ -> private subnet ID"
  type        = map(string)
}

variable "throughput_mode" {
  description = "EFS throughput mode (bursting)"
  type        = string
  default     = "bursting"
}
