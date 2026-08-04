variable "name_prefix" {
  type        = string
  description = "The prefix for the name of the resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The common tags for the resources"
}

variable "force_destroy" {
  description = "Allow terraform destroy to delete non-empty buckets"
  type        = bool
  default     = false
}
