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