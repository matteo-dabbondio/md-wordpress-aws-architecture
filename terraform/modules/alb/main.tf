# AWS Application Load Balancer module

# It implements a public ALB with a single target group for the WordPress service
# The ALB is configured to accept traffic only from Cloudfront IPs

# No ALB Logs enabled, to be considered for future improvements

locals {
  # To be evaluated possible optimization of the health check path (es. custom endpoint lighter)
  health_check_path    = "/"
  health_check_matcher = "200,301,302"
}

resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.this.id]
  subnets            = values(var.public_subnet_ids)

  # Must be >= CloudFront origin_read_timeout (plugin/theme installs are slow on EFS).
  idle_timeout = 120

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-alb" })
}

resource "aws_lb_target_group" "wordpress" {
  name        = "${var.name_prefix}-wp-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    path                = local.health_check_path
    protocol            = "HTTP"
    matcher             = local.health_check_matcher
    interval            = 30
    timeout             = 5
    healthy_threshold   = 4
    unhealthy_threshold = 2
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-wp-tg" })
}

# CloudFront -> ALB is HTTP-only
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-alb-http" })
}