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

variable "posix_uid" {
  description = "POSIX UID for the access point (www-data on Debian/WordPress image)"
  type        = number
  default     = 33
}

variable "posix_gid" {
  description = "POSIX GID for the access point (www-data on Debian/WordPress image)"
  type        = number
  default     = 33
}

variable "access_point_path" {
  description = "Root directory path on the file system (mounted at /var/www/html)"
  type        = string
  default     = "/html"
}

variable "access_point_permissions" {
  description = "POSIX permissions for the access point root directory"
  type        = string
  default     = "775"
}
