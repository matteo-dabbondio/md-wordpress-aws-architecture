variable "aws_region" {
  type        = string
  description = "The AWS region to deploy the infrastructure to"
  default     = "eu-central-1"
}

variable "project" {
  type        = string
  description = "The project name"
  default     = "wordpress"
}

variable "environment" {
  type        = string
  description = "The environment to deploy the infrastructure to"
  default     = "dev"
}

variable "owner" {
  type        = string
  description = "The owner of the project"
}

variable "repository" {
  type        = string
  description = "The repository of the project"
  default     = "https://github.com/matteo-dabbondio/md-wordpress-aws-architecture"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets - one per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets - one per AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "isolated_subnet_cidrs" {
  description = "CIDRs for isolated subnets - one per AZ"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "deletion_protection" {
  description = "Protect deletable resources if they contains data (es db). false in dev for easy destroy the environment; true in prod"
  type        = bool
  default     = true
}

variable "aurora_min_capacity" {
  description = "Aurora Serverless v2 minimum ACU"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Aurora Serverless v2 maximum ACU"
  type        = number
  default     = 4
}

variable "aurora_backup_retention_period" {
  description = "Aurora automated backup retention in days"
  type        = number
  default     = 7
}

variable "aurora_master_password_rotation_days" {
  description = "Rotate Aurora master password every N days"
  type        = number
  default     = 30
}

variable "aurora_apply_immediately" {
  description = "Apply Aurora modifications immediately or during maintenance windows"
  type        = bool
  default     = false
}

variable "valkey_max_data_storage_gb" {
  description = "Valkey Serverless max data storage (GB)"
  type        = number
  default     = 1
}

variable "valkey_max_ecpu_per_second" {
  description = "Valkey Serverless max ECPU per second"
  type        = number
  default     = 1000
}