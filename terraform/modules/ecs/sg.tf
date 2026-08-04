# ECS owns only its own SG and rules on that SG.
# Peer allow rules (ALB→ECS, Aurora/cache/EFS←ECS) are composed in
# environments/dev/sg_rules_composer.tf so reusable modules stay ignorant of each other.

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-ecs-sg"
  description = "ECS Fargate tasks (wordpress-apache)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-ecs-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "from_alb" {
  security_group_id            = aws_security_group.this.id
  description                  = "HTTP from ALB"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.alb_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "to_aurora" {
  security_group_id            = aws_security_group.this.id
  description                  = "MySQL to Aurora"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.aurora_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "to_cache" {
  security_group_id            = aws_security_group.this.id
  description                  = "Valkey/Redis protocol to ElastiCache"
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.cache_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "to_efs" {
  security_group_id            = aws_security_group.this.id
  description                  = "NFS to EFS (WordPress document root)"
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.efs_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "to_aws_services" {
  security_group_id = aws_security_group.this.id
  description       = "HTTPS to ECR/Secrets Manager/SSM/CloudWatch Logs via NAT"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}