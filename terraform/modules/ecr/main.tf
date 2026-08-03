# This module creates an ECR repository for the WordPress Apache image

locals {
    # retantion policy for untagged images
    non_tagged_image_retention_days = 7
}

resource "aws_ecr_repository" "wordpress_apache" {
  name = "${var.name_prefix}-wordpress-apache"
  # MUTABLE: can be used a fixed deploy alias tag (e.g. "app") for non-prod env.
  image_tag_mutability = "MUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-wordpress-apache"
  })
}

resource "aws_ecr_lifecycle_policy" "wordpress_apache" {
  repository = aws_ecr_repository.wordpress_apache.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${local.non_tagged_image_retention_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = local.non_tagged_image_retention_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the last ${var.image_retention_count} tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.image_retention_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}