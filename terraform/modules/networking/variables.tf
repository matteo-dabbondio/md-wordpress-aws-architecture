variable "name_prefix" {
  type        = string
  description = "The prefix for the name of the resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The common tags for the resources"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "public_subnets" {
  description = "Public subnets references (cidr and az, also used as key)"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "private_subnets" {
  description = "Private subnets references (cidr and az, also used as key)"
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "isolated_subnets" {
  description = "Isolated subnets references (cidr and az, also used as key)"
  type = map(object({
    cidr = string
    az   = string
  }))
}