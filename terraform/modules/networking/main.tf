
# ---------------------------------------------------------------------------
# VPC and IGW
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-igw" })
}

# ---------------------------------------------------------------------------
# Subnets (three tiers: public, private, isolated)
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_subnet" "isolated" {
  for_each = var.isolated_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-isolated-${each.key}"
    Tier = "isolated"
  })
}

# ---------------------------------------------------------------------------
# NAT Gateway — one per AZ
# ---------------------------------------------------------------------------

resource "aws_eip" "nat" {
  for_each = var.public_subnets

  domain = "vpc"

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "main" {
  for_each = var.public_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------------
# Public route table (default route to IGW)
# ---------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  for_each = var.public_subnets

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Private route tables (one per AZ, each to its own NAT)
# ---------------------------------------------------------------------------

resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-private-${each.key}-rt" })
}

resource "aws_route" "private_nat" {
  for_each = var.private_subnets

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = var.private_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}

# ---------------------------------------------------------------------------
# Isolated route table (VPC-local only)
# ---------------------------------------------------------------------------

resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-isolated-rt" })
}

resource "aws_route_table_association" "isolated" {
  for_each = var.isolated_subnets

  subnet_id      = aws_subnet.isolated[each.key].id
  route_table_id = aws_route_table.isolated.id
}
