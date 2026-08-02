# Gateway endpoint (free) to S3 (used for media uploads and later any ECS object access)

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [for rt in aws_route_table.private : rt.id]

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-s3-endpoint" })
}