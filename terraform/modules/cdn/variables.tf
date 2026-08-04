variable "name_prefix" {
  type        = string
  description = "The prefix for the name of the resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The common tags for the resources"
}


variable "alb_dns_name" {
  description = "ALB DNS name — dynamic origin"
  type        = string
}

variable "media_bucket_regional_domain_name" {
  description = "Media bucket regional domain — S3 origin via OAC"
  type        = string
}

variable "media_bucket_id" {
  description = "Media bucket id/name — OAC bucket policy"
  type        = string
}

variable "media_bucket_arn" {
  description = "Media bucket ARN — OAC bucket policy"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class (100 = NA/EU; raise for broader edge coverage)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition = contains([
      "PriceClass_100",
      "PriceClass_200",
      "PriceClass_All",
    ], var.price_class)
    error_message = "price_class must be one of PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "wp_login_rate_limit" {
  description = "WAF rate limit (requests / 5 min / IP) for /wp-login.php"
  type        = number
  default     = 30

  validation {
    condition     = var.wp_login_rate_limit > 0
    error_message = "wp_login_rate_limit must be greater than 0."
  }
}
