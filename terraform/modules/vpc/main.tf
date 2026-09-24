# =============================================================================
# VPC Module — free-tier friendly
# =============================================================================
# Design:
#   - 1 VPC with DNS hostnames + DNS support enabled
#   - 1 Internet Gateway
#   - N public subnets (default: 1) — app + AI EC2s live here
#   - Route table for public subnets → IGW
#   - NO NAT Gateway by default (costs ~$32/month — not free tier)
#
# Free-tier notes:
#   - VPC, subnets, IGW, route tables: all FREE
#   - NAT Gateway: ~$32/month + data processing — NOT created unless you opt in
#   - Elastic IP: free while attached to a running instance
# =============================================================================

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # required for RDS, EIP DNS, SSM, etc.

  tags = merge(var.tags, {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-igw"
  })
}

# -----------------------------------------------------------------------------
# Public subnets — one per AZ in `availability_zones`
# -----------------------------------------------------------------------------

resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
    # "kubernetes.io/role/elb" = "1"  # uncomment if you add an ALB later
  })
}

# -----------------------------------------------------------------------------
# Public route table → IGW
# -----------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# OPTIONAL: Private subnets (disabled by default)
# =============================================================================
# Only created if create_private_subnets = true.
#
# ⚠️ If you enable these, instances in private subnets have NO internet access
#    unless you also create a NAT Gateway (~$32/month) or VPC endpoints.
#    For a free-tier learning project, leave this OFF.

resource "aws_subnet" "private" {
  count = var.create_private_subnets ? length(var.availability_zones) : 0

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 100) # offset to avoid overlap
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  })
}

resource "aws_route_table" "private" {
  count = var.create_private_subnets ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.project_name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count = var.create_private_subnets ? length(aws_subnet.private) : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# -----------------------------------------------------------------------------
# OPTIONAL: NAT Gateway (only if explicitly enabled — costs money!)
# -----------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway && var.create_private_subnets ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway && var.create_private_subnets ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name = "${var.project_name}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway && var.create_private_subnets ? 1 : 0

  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}