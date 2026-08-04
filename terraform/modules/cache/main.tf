# This module creates an ElastiCache Serverless cache

locals {
  # ElastiCache user_id: alphanumeric only, 1-40 chars.
  user_id_prefix = replace(var.name_prefix, "-", "")

  # Auth: RBAC is mandatory on Serverless (no classic AUTH token).
  app_username = "wordpress"

  major_engine_version     = "9"
  snapshot_retention_limit = 0

  # WP Plugin: https://wordpress.org/plugins/redis-cache/
  # +@all then strip @dangerous (includes INFO/FLUSH*/KEYS/…).
  # Re-allow flushdb (plugin/admin) and info (plugin diagnostics / connection check).

  app_access_string = "on ~* +@all -@dangerous +flushdb +info"
}

# random password for the application user
resource "random_password" "app" {
  length  = 32
  special = true
  # ElastiCache user passwords cannot contain '/', '"', or '@'.
  override_special = "!&#$%^*()-_=+[]{}"
}

resource "aws_elasticache_user" "app" {
  user_id       = "${local.user_id_prefix}app"
  user_name     = local.app_username
  engine        = "valkey"
  access_string = local.app_access_string
  passwords     = [random_password.app.result]
}

resource "aws_elasticache_user_group" "this" {
  user_group_id = "${var.name_prefix}-valkey"
  engine        = "valkey"
  user_ids      = [aws_elasticache_user.app.user_id]
}

resource "aws_elasticache_serverless_cache" "this" {
  name        = "${var.name_prefix}-valkey"
  description = "WordPress object/session cache (Valkey Serverless)"
  engine      = "valkey"

  major_engine_version = local.major_engine_version

  cache_usage_limits {
    data_storage {
      maximum = var.max_data_storage_gb
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = var.max_ecpu_per_second
    }
  }

  subnet_ids         = values(var.isolated_subnet_ids)
  security_group_ids = [aws_security_group.this.id]
  user_group_id      = aws_elasticache_user_group.this.user_group_id

  snapshot_retention_limit = local.snapshot_retention_limit

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-valkey" })

  depends_on = [aws_elasticache_user_group.this]
}

resource "aws_secretsmanager_secret" "auth" {
  name                    = "${var.name_prefix}-valkey-auth"
  description             = "ElastiCache Valkey Serverless credentials (app RBAC user)"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-valkey-auth" })
}

resource "aws_secretsmanager_secret_version" "auth" {
  secret_id = aws_secretsmanager_secret.auth.id
  secret_string = jsonencode({
    username = local.app_username
    password = random_password.app.result
    host     = aws_elasticache_serverless_cache.this.endpoint[0].address
    port     = aws_elasticache_serverless_cache.this.endpoint[0].port
  })
}