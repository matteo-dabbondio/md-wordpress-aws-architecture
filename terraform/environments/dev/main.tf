# Main Terraform configuration for the development environment
# Terraform modules are orchestrated here to build the infrastructure

# Modules order (PLACEHOLDER): networking (ok), efs (ok), database (ok), storage, cache, ecr, alb, cdn, ecs 

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
  deletion_protection           = var.deletion_protection
  skip_final_snapshot           = !var.deletion_protection
}