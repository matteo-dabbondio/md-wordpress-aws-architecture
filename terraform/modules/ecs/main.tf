# ECS module to deploy the WordPress application

# ECS Fargate cluster, task definition (wordpress-apache), service.

# Admin user: WordPress first-run wizard only (not managed by Terraform).
# Container env/secrets locals: locals.tf

resource "aws_cloudwatch_log_group" "apache" {
  name              = "/ecs/${var.name_prefix}/apache"
  retention_in_days = var.log_retention_days

  tags = merge(var.common_tags, { Name = "/ecs/${var.name_prefix}/apache" })
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-cluster" })
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = var.fargate_base
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.fargate_spot_weight
    base              = 0
  }
}

resource "aws_ecs_task_definition" "wordpress" {
  family                   = "${var.name_prefix}-wordpress"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = local.image
      essential = true

      portMappings = [
        {
          containerPort = local.container_port
          hostPort      = local.container_port
          protocol      = "tcp"
        }
      ]

      environment = local.container_environment
      secrets     = local.container_secrets

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.apache.name
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "apache"
        }
      }

      # Official image entrypoint; document root on EFS (Hub volume pattern).
      readonlyRootFilesystem = false

      mountPoints = [
        {
          sourceVolume  = "wordpress"
          containerPath = "/var/www/html"
          readOnly      = false
        }
      ]
    }
  ])

  volume {
    name = "wordpress"

    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = var.efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-wordpress-task" })
}

resource "aws_ecs_service" "wordpress" {
  name            = "${var.name_prefix}-wordpress"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = var.desired_count

  platform_version = "LATEST"

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = var.fargate_base
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.fargate_spot_weight
    base              = 0
  }

  network_configuration {
    subnets          = values(var.private_subnet_ids)
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 50
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds

  enable_execute_command = false

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-wordpress-svc" })

  depends_on = [
    aws_ecs_cluster_capacity_providers.this,
    aws_iam_role_policy.execution_secrets,
  ]

  lifecycle {
    # Autoscaling owns desired_count; CI owns which image revision is live.
    ignore_changes = [desired_count, task_definition]
  }
}