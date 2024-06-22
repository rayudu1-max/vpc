resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(
    var.common_tags,
    var.vpc_tags,
     {
    Name = local.resource_name
    }
  )
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.igw_tags, {
    Name = local.resource_name
  }
  )
}

## public subnet
resource "aws_subnet" "public" { # creates resources as public[0] and public[1]
  count = length(var.public_subnet_cidrs)
  availability_zone = local.azs_name[count.index]
  map_public_ip_on_launch = true
  vpc_id     = aws_vpc.main.id
  cidr_block = var.public_subnet_cidrs[count.index]

  tags = merge(
    var.common_tags,
    var.public_subnet_cidrs_tags,
  {
    Name = "${local.resource_name}-public-${local.azs_name[count.index]}"
    }
  )
}


## private subnet
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  availability_zone = local.azs_name[count.index]
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]

  tags = merge(
    var.common_tags,
    var.private_subnet_cidrs_tags,
  {
    Name = "${local.resource_name}-private-${local.azs_name[count.index]}"
    }
  )
}


## database subnet
resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidrs)
  availability_zone = local.azs_name[count.index]
  vpc_id     = aws_vpc.main.id
  cidr_block = var.database_subnet_cidrs[count.index]

  tags = merge(
    var.common_tags,
    var.database_subnet_cidrs_tags,
  {
    Name = "${local.resource_name}-database-${local.azs_name[count.index]}"
    }
  )
}

## elastic IP
resource "aws_eip" "elastic" {
  domain   = "vpc"
}

## nat gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.elastic.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.common_tags,
    var.nat_gateway_tags,
  {
    Name = "${local.resource_name}"
    }
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

## public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.public_route_table_tags,
  {
    Name = "${local.resource_name}-public"
    }
  )
}

## private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.private_route_table_tags,
  {
    Name = "${local.resource_name}-private"
    }
  )
}

## database route table
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.database_route_table_tags,
  {
    Name = "${local.resource_name}-database"
    }
  )
}

### public route
resource "aws_route" "public_route" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}

### private route
resource "aws_route" "private_route" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.nat.id
}

### database route
resource "aws_route" "database_route" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_nat_gateway.nat.id
}


### public route table and subnet association 
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

### private route table and subnet association 
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

### database route table and subnet association 
resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidrs)
  subnet_id      = element(aws_subnet.database[*].id, count.index)
  route_table_id = aws_route_table.database.id
}