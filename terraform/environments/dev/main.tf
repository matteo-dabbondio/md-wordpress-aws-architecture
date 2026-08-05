# Main Terraform configuration for the development environment
# Terraform modules are orchestrated here to build the infrastructure

# Modules order (PLACEHOLDER): networking (ok), efs (ok), database (ok), cache (ok), ecr (ok), storage, alb, cdn, ecs 

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = var.repository
    Owner       = var.owner
  }

  # One AZ per public subnet CIDR (list length drives HA width).
  azs = slice(data.aws_availability_zones.available.names, 0, length(var.public_subnet_cidrs))

  # Full AZ name as key for subnets maps.
  public_subnets = {
    for i, cidr in var.public_subnet_cidrs :
    local.azs[i] => { cidr = cidr, az = local.azs[i] }
  }
  private_subnets = {
    for i, cidr in var.private_subnet_cidrs :
    local.azs[i] => { cidr = cidr, az = local.azs[i] }
  }
  isolated_subnets = {
    for i, cidr in var.isolated_subnet_cidrs :
    local.azs[i] => { cidr = cidr, az = local.azs[i] }
  }

  skip_final_snapshot         = var.ephemeral_environment
  secret_recovery_window_days = var.ephemeral_environment ? 0 : 7
  deletion_protection         = !var.ephemeral_environment
  force_delete                = var.ephemeral_environment
}

# Validation checks on AZ region availability and subnet variables list lengths
check "subnet_list_lengths_match" {
  assert {
    condition = (
      length(var.public_subnet_cidrs) > 0 &&
      length(var.public_subnet_cidrs) == length(var.private_subnet_cidrs) &&
      length(var.public_subnet_cidrs) == length(var.isolated_subnet_cidrs)
    )
    error_message = "public_subnet_cidrs, private_subnet_cidrs, and isolated_subnet_cidrs must all have the same non-zero length."
  }
}

check "enough_availability_zones" {
  assert {
    condition     = length(data.aws_availability_zones.available.names) >= length(var.public_subnet_cidrs)
    error_message = "The selected region does not expose enough available AZs for the configured subnet CIDR lists."
  }
}

module "networking" {
  source = "../../modules/networking"

  name_prefix = local.name_prefix
  common_tags = local.common_tags

  vpc_cidr         = var.vpc_cidr
  public_subnets   = local.public_subnets
  private_subnets  = local.private_subnets
  isolated_subnets = local.isolated_subnets
}

module "efs" {
  source = "../../modules/efs"

  name_prefix        = local.name_prefix
  common_tags        = local.common_tags
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
}

module "database" {
  source = "../../modules/database"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  vpc_id              = module.networking.vpc_id
  isolated_subnet_ids = module.networking.isolated_subnet_ids

  min_capacity                  = var.aurora_min_capacity
  max_capacity                  = var.aurora_max_capacity
  backup_retention_period       = var.aurora_backup_retention_period
  master_password_rotation_days = var.aurora_master_password_rotation_days
  apply_immediately             = var.aurora_apply_immediately
  deletion_protection           = local.deletion_protection
  skip_final_snapshot           = local.skip_final_snapshot
}

module "cache" {
  source = "../../modules/cache"

  name_prefix = local.name_prefix
  common_tags = local.common_tags

  vpc_id              = module.networking.vpc_id
  isolated_subnet_ids = module.networking.isolated_subnet_ids

  max_data_storage_gb         = var.valkey_max_data_storage_gb
  max_ecpu_per_second         = var.valkey_max_ecpu_per_second
  secret_recovery_window_days = local.secret_recovery_window_days
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix = local.name_prefix
  common_tags = local.common_tags

  image_retention_count = var.ecr_image_retention_count
  force_delete          = local.force_delete
}

module "storage" {
  source = "../../modules/storage"

  name_prefix = local.name_prefix
  common_tags = local.common_tags

  force_destroy = local.force_delete
}

module "alb" {
  source = "../../modules/alb"

  name_prefix = local.name_prefix
  common_tags = local.common_tags

  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids

  enable_deletion_protection = local.deletion_protection
}

module "cdn" {
  source = "../../modules/cdn"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix = local.name_prefix
  common_tags = local.common_tags

  alb_dns_name                      = module.alb.alb_dns_name
  media_bucket_regional_domain_name = module.storage.media_bucket_regional_domain_name
  media_bucket_id                   = module.storage.media_bucket_id
  media_bucket_arn                  = module.storage.media_bucket_arn

  price_class = var.cloudfront_price_class
}

module "ecs" {
  source = "../../modules/ecs"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  container_image_tag = var.container_image_tag
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids

  alb_security_group_id    = module.alb.security_group_id
  aurora_security_group_id = module.database.security_group_id
  cache_security_group_id  = module.cache.security_group_id
  efs_security_group_id    = module.efs.security_group_id

  ecr_repository_url = module.ecr.repository_url
  target_group_arn   = module.alb.target_group_arn

  wordpress_url = module.cdn.cloudfront_url

  db_host                     = module.database.cluster_endpoint
  db_port                     = module.database.cluster_port
  db_name                     = module.database.database_name
  db_master_user_secret_arn   = module.database.master_user_secret_arn
  cache_auth_secret_arn       = module.cache.auth_secret_arn
  media_bucket_arn            = module.storage.media_bucket_arn
  media_bucket_id             = module.storage.media_bucket_id
  efs_file_system_id          = module.efs.file_system_id
  efs_file_system_arn         = module.efs.file_system_arn
  efs_access_point_id         = module.efs.access_point_id
  efs_access_point_arn        = module.efs.access_point_arn
  alb_arn_suffix              = module.alb.alb_arn_suffix
  target_group_arn_suffix     = module.alb.target_group_arn_suffix
  secret_recovery_window_days = local.secret_recovery_window_days

  task_cpu            = var.ecs_task_cpu
  task_memory         = var.ecs_task_memory
  desired_count       = var.ecs_min_capacity
  min_capacity        = var.ecs_min_capacity
  max_capacity        = var.ecs_max_capacity
  fargate_base        = var.ecs_fargate_base
  fargate_spot_weight = var.ecs_fargate_spot_weight
}