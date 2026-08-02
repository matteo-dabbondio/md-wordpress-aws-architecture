output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Map of AZ  -> public subnet ID"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  description = "Map of AZ -> private subnet ID"
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "isolated_subnet_ids" {
  description = "Map of AZ -> isolated subnet ID"
  value       = { for k, s in aws_subnet.isolated : k => s.id }
}

output "nat_gateway_ids" {
  description = "Map of AZ -> NAT Gateway ID"
  value       = { for k, n in aws_nat_gateway.main : k => n.id }
}