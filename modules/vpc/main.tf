
resource "aws_vpc" "default" {
  cidr_block           = local.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name        = var.name,
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id

  tags = merge(
    {
      Name        = "gwInternet",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}



# private subnet
resource "aws_subnet" "private" {
  count = length(local.private_subnet_cidr_blocks)

  vpc_id            = aws_vpc.default.id
  cidr_block        = local.private_subnet_cidr_blocks[count.index]
  availability_zone = local.availability_zones[count.index]

  tags = merge(
    {
      Name        = "PrivateSubnet",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

# public subnet
resource "aws_subnet" "public" {
  count = length(local.public_subnet_cidr_blocks)

  vpc_id                  = aws_vpc.default.id
  cidr_block              = local.public_subnet_cidr_blocks[count.index]
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name        = "PublicSubnet",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

#
# NAT resources
#
# resource "aws_eip" "nat" {
#   count = length(local.public_subnet_cidr_blocks)
#   vpc = true
# }

# resource "aws_nat_gateway" "default" {
#   depends_on = [aws_internet_gateway.default]

#   count = length(local.public_subnet_cidr_blocks)

#   allocation_id = aws_eip.nat[count.index].id
#   subnet_id     = aws_subnet.public[count.index].id

#   tags = merge(
#     {
#       Name        = "gwNAT",
#       Project     = var.project,
#       Environment = var.environment
#     },
#     var.tags
#   )
# }


# ルートテーブル＋関連付け
resource "aws_route_table" "private" {
  count = length(local.private_subnet_cidr_blocks)

  vpc_id = aws_vpc.default.id

  tags = merge(
    {
      Name        = "PrivateRouteTable",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  tags = merge(
    {
      Name        = "PublicRouteTable",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}


# resource "aws_route" "private" {
#   count = length(local.private_subnet_cidr_blocks)

#   route_table_id         = aws_route_table.private[count.index].id
#   destination_cidr_block = "0.0.0.0/0"
#   # nat_gateway_id         = aws_nat_gateway.default[count.index].id
# }


resource "aws_route_table_association" "private" {
  count = length(local.private_subnet_cidr_blocks)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "public" {
  count = length(local.public_subnet_cidr_blocks)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.default.id
  service_name = "com.amazonaws.ap-northeast-1.s3"

  tags = merge(
    {
      Name        = "s3-endpoint",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

module "https_sg" {
  source      = "../security_group"
  name        = "https-sg"
  vpc_id      = aws_vpc.default.id
  port        = 443
  cidr_blocks = ["0.0.0.0/0"]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id       = aws_vpc.default.id
  service_name = "com.amazonaws.ap-northeast-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  security_group_ids = [module.https_sg.security_group_id]
  private_dns_enabled = true

  tags = merge(
    {
      Name        = "ssm",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_vpc_endpoint" "ec2message" {
  vpc_id       = aws_vpc.default.id
  service_name = "com.amazonaws.ap-northeast-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  security_group_ids = [module.https_sg.security_group_id]
  private_dns_enabled = true

  tags = merge(
    {
      Name        = "ec2message",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_vpc_endpoint" "ssm_core" {
  vpc_id       = aws_vpc.default.id
  service_name = "com.amazonaws.ap-northeast-1.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids = [module.https_sg.security_group_id]
  private_dns_enabled = true

  tags = merge(
    {
      Name        = "ssm_core",
      Project     = var.project,
      Environment = var.environment
    },
    var.tags
  )
}


resource "aws_vpc_endpoint_route_table_association" "s3rt" {
  count = length(local.private_subnet_cidr_blocks)

  route_table_id = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_subnet_association" "ssm_ass" {
  count = length(local.private_subnet_cidr_blocks)

  vpc_endpoint_id = aws_vpc_endpoint.ssm.id
  subnet_id       = aws_subnet.private[count.index].id
}

resource "aws_vpc_endpoint_subnet_association" "ec2message" {
  count = length(local.private_subnet_cidr_blocks)

  vpc_endpoint_id = aws_vpc_endpoint.ec2message.id
  subnet_id       = aws_subnet.private[count.index].id
}

resource "aws_vpc_endpoint_subnet_association" "message" {
  count = length(local.private_subnet_cidr_blocks)

  vpc_endpoint_id = aws_vpc_endpoint.ssm_core.id
  subnet_id       = aws_subnet.private[count.index].id
}


