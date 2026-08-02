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