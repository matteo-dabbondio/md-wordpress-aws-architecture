# AWS Security Group module for the Application Load Balancer 

# It is configured to allow traffic only from Cloudfront IPs
# The egress rule to ECS is composed in environments/dev/sg_rules_composer.tf because of requires ECS module.

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Internet-facing ALB; ingress from CloudFront only"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-alb-sg" })
}

# Viewer TLS terminates at CloudFront (*.cloudfront.net), so origin protocol is HTTP only
# To be evaluated for future improvements the introduction of custom domain and ACM certificate.

resource "aws_vpc_security_group_ingress_rule" "from_cloudfront" {
  security_group_id = aws_security_group.this.id
  description       = "HTTP from CloudFront managed prefix list (origin only)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}
