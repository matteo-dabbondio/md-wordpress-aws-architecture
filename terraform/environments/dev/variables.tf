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