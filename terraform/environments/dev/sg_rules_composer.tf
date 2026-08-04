# Configured security group rules for:
# - EFS Security Group (it needs ECS module) - ingress
# - Database (Aurora) Security Group (it needs ECS module) - ingress
# - Cache (Valkey Serverless) Security Group (it needs ECS module) - ingress
# - ALB Security Group (it needs ECs module) - egress

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  security_group_id            = module.alb.security_group_id
  description                  = "HTTP to ECS tasks"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.ecs.security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "aurora_from_ecs" {
  security_group_id            = module.database.security_group_id
  description                  = "MySQL from ECS"
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.ecs.security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "cache_from_ecs" {
  security_group_id            = module.cache.security_group_id
  description                  = "Valkey from ECS"
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.ecs.security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_ecs" {
  security_group_id            = module.efs.security_group_id
  description                  = "NFS from ECS"
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.ecs.security_group_id
}