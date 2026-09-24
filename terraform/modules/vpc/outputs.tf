# =============================================================================
# VPC
# =============================================================================

output "vpc_id" {
  description = "ID of the VPC (pass to security-groups module's vpc_id)"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# =============================================================================
# Public subnets
# =============================================================================

output "public_subnet_ids" {
  description = "List of public subnet IDs (in AZ order)"
  value       = aws_subnet.public[*].id
}

output "public_subnet_id" {
  description = "First public subnet ID (convenience for single-subnet deployments)"
  value       = aws_subnet.public[0].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "public_subnet_azs" {
  description = "List of AZs where public subnets were created"
  value       = aws_subnet.public[*].availability_zone
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

# =============================================================================
# Internet Gateway
# =============================================================================

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# =============================================================================
# Private subnets (empty when create_private_subnets = false)
# =============================================================================

output "private_subnet_ids" {
  description = "List of private subnet IDs (empty if not created)"
  value       = var.create_private_subnets ? aws_subnet.private[*].id : []
}

output "private_route_table_id" {
  description = "ID of the private route table (empty string if not created)"
  value       = var.create_private_subnets ? aws_route_table.private[0].id : ""
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway (empty string if not created)"
  value       = var.enable_nat_gateway && var.create_private_subnets ? aws_nat_gateway.main[0].id : ""
}