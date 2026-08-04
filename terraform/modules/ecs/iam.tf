# Task execution role (pull ECR, awslogs, inject secrets) and task role (S3 + EFS).
# Least privilege principle

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    sid     = "ECSTasksAssume"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-ecs-execution" })
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    sid    = "GetTaskSecrets"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = [
      var.db_master_user_secret_arn,
      var.cache_auth_secret_arn,
      aws_secretsmanager_secret.wp_salts.arn,
    ]
  }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${var.name_prefix}-ecs-execution-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-ecs-task" })
}

data "aws_iam_policy_document" "task_media" {
  # WP Offload Media Lite requires bucket metadata reads and object reads/writes/deletes
  statement {
    sid    = "MediaBucketMeta"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketOwnershipControls",
    ]
    resources = [var.media_bucket_arn]
  }

  statement {
    sid    = "MediaObjectRW"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${var.media_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "task_media" {
  name   = "${var.name_prefix}-ecs-task-media"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_media.json
}

data "aws_iam_policy_document" "task_efs" {
  statement {
    sid    = "EfsClientMountWrite"
    effect = "Allow"
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
    ]
    resources = [var.efs_file_system_arn]

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [var.efs_access_point_arn]
    }
  }
}

resource "aws_iam_role_policy" "task_efs" {
  name   = "${var.name_prefix}-ecs-task-efs"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_efs.json
}