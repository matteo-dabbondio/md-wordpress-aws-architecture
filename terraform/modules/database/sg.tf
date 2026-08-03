# Security group for Aurora

# Only setup. The security group rules need the security group of ECS 
# and it will be configured in the evironment

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-aurora-sg"
  description = "Aurora - ingress from ECS only"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-aurora-sg" })
}