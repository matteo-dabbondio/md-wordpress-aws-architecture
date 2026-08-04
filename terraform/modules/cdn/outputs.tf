output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (*.cloudfront.net)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_url" {
  description = "HTTPS URL for the WordPress site"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}