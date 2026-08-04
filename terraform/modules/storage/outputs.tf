output "media_bucket_id" {
  description = "Media bucket name/id"
  value       = aws_s3_bucket.media.id
}

output "media_bucket_arn" {
  description = "Media bucket ARN"
  value       = aws_s3_bucket.media.arn
}

output "media_bucket_regional_domain_name" {
  description = "Regional domain name for CloudFront S3 origin"
  value       = aws_s3_bucket.media.bucket_regional_domain_name
}