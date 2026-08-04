# AUTH_KEY for wp-config — shared across all tasks (HA).
# These keys are created here and not automatically by WP in order to avoid conflicts among tasks.
# Admin user/password are NOT managed here: classic WordPress first-run wizard
# stores credentials only in Aurora (wp_users).

resource "random_password" "auth_key" {
  length  = 64
  special = false
}

resource "random_password" "secure_auth_key" {
  length  = 64
  special = false
}

resource "random_password" "logged_in_key" {
  length  = 64
  special = false
}

resource "random_password" "nonce_key" {
  length  = 64
  special = false
}

resource "random_password" "auth_salt" {
  length  = 64
  special = false
}

resource "random_password" "secure_auth_salt" {
  length  = 64
  special = false
}

resource "random_password" "logged_in_salt" {
  length  = 64
  special = false
}

resource "random_password" "nonce_salt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "wp_salts" {
  name                    = "${var.name_prefix}-wp-salts"
  description             = "WordPress AUTH_KEY / salts for wp-config (shared by all ECS tasks)"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-wp-salts" })
}

resource "aws_secretsmanager_secret_version" "wp_salts" {
  secret_id = aws_secretsmanager_secret.wp_salts.id
  secret_string = jsonencode({
    AUTH_KEY         = random_password.auth_key.result
    SECURE_AUTH_KEY  = random_password.secure_auth_key.result
    LOGGED_IN_KEY    = random_password.logged_in_key.result
    NONCE_KEY        = random_password.nonce_key.result
    AUTH_SALT        = random_password.auth_salt.result
    SECURE_AUTH_SALT = random_password.secure_auth_salt.result
    LOGGED_IN_SALT   = random_password.logged_in_salt.result
    NONCE_SALT       = random_password.nonce_salt.result
  })
}
