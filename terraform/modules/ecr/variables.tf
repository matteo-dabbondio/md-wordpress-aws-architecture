variable "name_prefix" {
  type        = string
  description = "The prefix for the name of the resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The common tags for the resources"
}


variable "image_retention_count" {
  description = "Number of tagged images to retain (lifecycle policy)"
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Allow terraform destroy to delete the repository even if it contains images"
  type        = bool
  default     = false
}