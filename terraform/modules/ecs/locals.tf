# Container image / env / secrets wiring for the WordPress Hub task.
# WORDPRESS_CONFIG_EXTRA sources: Hub docs + plugin constants (see comments below).

data "aws_region" "current" {}

locals {
  image = "${var.ecr_repository_url}:${var.container_image_tag}"

  container_name = "wordpress-apache"
  container_port = 80

  # RDS-managed secret JSON keys: username, password (+ host/port/dbname etc.).
  db_username_secret = "${var.db_master_user_secret_arn}:username::"
  db_password_secret = "${var.db_master_user_secret_arn}:password::"

  # Official Hub env → wp-config.php.
  # https://hub.docker.com/_/wordpress/  (WORDPRESS_CONFIG_EXTRA → eval in wp-config)
  
  # HTTPS behind CloudFront + URL; Valkey/S3 targets for plugins installed from wp-admin
  # (Redis Object Cache + WP Offload Media Lite). No plugin files in the image.
  wordpress_config_extra = <<-PHP
  // Public URL is HTTPS via CloudFront; origin is HTTP-only so force is_ssl().
  if (($wp_url = getenv('WORDPRESS_URL')) && $wp_url !== '') {
      define('WP_HOME', $wp_url);
      define('WP_SITEURL', $wp_url);
      if (stripos($wp_url, 'https://') === 0) {
          $_SERVER['HTTPS'] = 'on';
          $_SERVER['HTTP_X_FORWARDED_PROTO'] = 'https';
      }
  }
  // https://wordpress.org/plugins/redis-cache/
  // https://github.com/rhubarbgroup/redis-cache#configuration
  // Predis: Hub image has no phpredis; Valkey Serverless requires TLS.
  // ACL auth: WP_REDIS_PASSWORD as [user, password] (no WP_REDIS_USERNAME in OSS plugin).
  //
  // Serverless is Cluster Mode: multi-key ops CROSSSLOT unless keys share a hash slot.
  // Do NOT use WP_REDIS_CLUSTER with Predis+TLS here — Predis fails with
  // "Cannot find a connection by id matching tls://…". Instead keep WP_REDIS_HOST
  // (single-key + TLS works) and force one slot via hashtag prefix `{wp}`.
  if (($redis_host = getenv('REDIS_HOST')) && $redis_host !== '') {
      define('WP_REDIS_CLIENT', 'predis');
      define('WP_REDIS_HOST', $redis_host);
      define('WP_REDIS_PORT', intval(getenv('REDIS_PORT') ?: 6379));
      define('WP_REDIS_SCHEME', 'tls');
      define('WP_REDIS_PASSWORD', [
          getenv('REDIS_USERNAME') ?: '',
          getenv('REDIS_PASSWORD') ?: '',
      ]);
      define('WP_REDIS_PREFIX', '{wp}');
      define('WP_REDIS_DISABLE_GROUP_FLUSH', true);
      // Never white-screen the site if Redis blips (drop-in otherwise dies hard).
      define('WP_REDIS_GRACEFUL', true);
  }
  // https://wordpress.org/plugins/amazon-s3-and-cloudfront/
  // https://deliciousbrains.com/wp-offload-media/doc/settings-constants/
  // IAM task role, no access keys. Private bucket + OAC: deliver via CloudFront
  // (same *.cloudfront.net as WP_HOME), not regional S3 URLs (would 403).
  // Object prefix matches CF path_pattern /wp-content/uploads/*.
  // use-bucket-acls MUST be false: media bucket is BlockPublicAccess + BucketOwnerEnforced.
  // If left unset, Lite may persist use-bucket-acls=true after a failed BAPA probe and
  // PutObject-with-ACL then fails silently (files stay on EFS only).
  if (($bucket = getenv('WORDPRESS_MEDIA_BUCKET')) && $bucket !== '') {
      $cf_host = parse_url(getenv('WORDPRESS_URL') ?: '', PHP_URL_HOST) ?: '';
      define('AS3CF_SETTINGS', serialize([
          'provider'               => 'aws',
          'use-server-roles'       => true,
          'bucket'                 => $bucket,
          'region'                 => getenv('AWS_REGION') ?: 'eu-central-1',
          'copy-to-s3'             => true,
          'serve-from-s3'          => true,
          'enable-object-prefix'   => true,
          'object-prefix'          => 'wp-content/uploads/',
          'use-yearmonth-folders'  => true,
          'use-bucket-acls'        => false,
          'delivery-provider'      => 'aws',
          'enable-delivery-domain' => ($cf_host !== ''),
          'delivery-domain'        => $cf_host,
          'force-https'            => true,
      ]));
  }
  PHP

  container_secrets = [
    { name = "WORDPRESS_DB_USER", valueFrom = local.db_username_secret },
    { name = "WORDPRESS_DB_PASSWORD", valueFrom = local.db_password_secret },
    { name = "WORDPRESS_AUTH_KEY", valueFrom = "${aws_secretsmanager_secret.wp_salts.arn}:AUTH_KEY::" },
    { name = "WORDPRESS_SECURE_AUTH_KEY", valueFrom = "${aws_secretsmanager_secret.wp_salts.arn}:SECURE_AUTH_KEY::" },
    { name = "WORDPRESS_LOGGED_IN_KEY", valueFrom = "${aws_secretsmanager_secret.wp_salts.arn}:LOGGED_IN_KEY::" },
    { name = "WORDPRESS_NONCE_KEY", valueFrom = "${aws_secretsmanager_secret.wp_salts.arn}:NONCE_KEY::" },
    { name = "WORDPRESS_AUTH_SALT", valueFrom = "${aws_secretsmanager_secret.wp_salts.arn}:AUTH_SALT::" },
    { name = "WORDPRESS_SECURE_AUTH_SALT", valueFrom = "${aws_secretsmanager_secret.wp_salts.arn}:SECURE_AUTH_SALT::" },
    { name = "WORDPRESS_LOGGED_IN_SALT", valueFrom = "${aws_secretsmanager_secret.wp_salts.arn}:LOGGED_IN_SALT::" },
    { name = "WORDPRESS_NONCE_SALT", valueFrom = "${aws_secretsmanager_secret.wp_salts.arn}:NONCE_SALT::" },
    { name = "REDIS_USERNAME", valueFrom = "${var.cache_auth_secret_arn}:username::" },
    { name = "REDIS_PASSWORD", valueFrom = "${var.cache_auth_secret_arn}:password::" },
    { name = "REDIS_HOST", valueFrom = "${var.cache_auth_secret_arn}:host::" },
    { name = "REDIS_PORT", valueFrom = "${var.cache_auth_secret_arn}:port::" },
  ]

  container_environment = [
    { name = "WORDPRESS_DB_HOST", value = "${var.db_host}:${var.db_port}" },
    { name = "WORDPRESS_DB_NAME", value = var.db_name },
    { name = "WORDPRESS_URL", value = var.wordpress_url },
    { name = "WORDPRESS_CONFIG_EXTRA", value = local.wordpress_config_extra },
    { name = "WORDPRESS_MEDIA_BUCKET", value = var.media_bucket_id },
    { name = "AWS_REGION", value = data.aws_region.current.region },
    { name = "AWS_DEFAULT_REGION", value = data.aws_region.current.region },
  ]
}