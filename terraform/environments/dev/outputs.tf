output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "isolated_subnet_ids" {
  value = module.networking.isolated_subnet_ids
}

output "nat_gateway_ids" {
  value = module.networking.nat_gateway_ids
}

output "efs_file_system_id" {
  value = module.efs.file_system_id
}

output "efs_access_point_id" {
  value = module.efs.access_point_id
}

output "valkey_endpoint" {
  value = module.cache.endpoint_address
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "media_bucket_id" {
  value = module.storage.media_bucket_id
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "alb_target_group_arn" {
  value = module.alb.target_group_arn
}

output "cloudfront_domain_name" {
  value = module.cdn.cloudfront_domain_name
}

output "cloudfront_url" {
  value = module.cdn.cloudfront_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "ecs_log_group_name" {
  value = module.ecs.log_group_name
}