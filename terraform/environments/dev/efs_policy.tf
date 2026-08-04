# EFS resource policy
# policy composed at the environment root (module composition between EFS and ECS).

data "aws_iam_policy_document" "efs_file_system" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["*"]

    resources = [module.efs.file_system_arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowEcsTaskRoleViaMountTarget"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [module.ecs.task_role_arn]
    }

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
    ]

    resources = [module.efs.file_system_arn]

    condition {
      test     = "Bool"
      variable = "elasticfilesystem:AccessedViaMountTarget"
      values   = ["true"]
    }

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [module.efs.access_point_arn]
    }
  }
}

resource "aws_efs_file_system_policy" "this" {
  file_system_id = module.efs.file_system_id
  policy         = data.aws_iam_policy_document.efs_file_system.json
}