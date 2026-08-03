# Aurora MySQL 8.0 Serverless v2 — writer + reader (Multi-AZ).
# Password managed by AWS Secrets Manager with rotation.

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-aurora"
  subnet_ids = values(var.isolated_subnet_ids)

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-aurora-subnet-group" })
}

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-mysql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version

  database_name   = var.database_name
  master_username = var.master_username

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  backup_retention_period = var.backup_retention_period
  copy_tags_to_snapshot   = true

  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-aurora-final"
  apply_immediately         = var.apply_immediately

  # Basic error logging (advanced monitoring off to save costs)
  enabled_cloudwatch_logs_exports = ["error"]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-aurora" })
}

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.name_prefix}-aurora-writer"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  publicly_accessible = false
  promotion_tier      = 0

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-aurora-writer" })
}

resource "aws_rds_cluster_instance" "reader" {
  identifier         = "${var.name_prefix}-aurora-reader"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  publicly_accessible = false
  promotion_tier      = 1

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-aurora-reader" })
}

# Manage secret rotation. The secret is created at the creation of db 
# (with optional parametermanage_master_user_password = true)
resource "aws_secretsmanager_secret_rotation" "master" {
  secret_id          = aws_rds_cluster.this.master_user_secret[0].secret_arn
  rotate_immediately = false

  rotation_rules {
    automatically_after_days = var.master_password_rotation_days
  }

  depends_on = [
    aws_rds_cluster_instance.writer,
    aws_rds_cluster_instance.reader,
  ]
}