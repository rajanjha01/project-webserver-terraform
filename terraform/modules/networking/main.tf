
################################################
## CUSTOM VPC CONFIGURATION 
################################################

resource "random_integer" "random" {
  min = 1
  max = 100
}

resource "aws_vpc" "web_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "web_vpc-${random_integer.random.id}"
  }
  lifecycle {
    create_before_destroy = true
  }
}
## FETCH THE AZ'S
data "aws_availability_zones" "available" {
}

## INTERNET GATEWAY

resource "aws_internet_gateway" "web_internet_gateway" {
  vpc_id = aws_vpc.web_vpc.id

  tags = {
    Name = "web_igw"
  }
  lifecycle {
    create_before_destroy = true
  }
}


## PUBLIC SUBNETS 

resource "aws_subnet" "web_public_subnets" {
  count                   = var.public_sn_count
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.${10 + count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "web_public_${count.index + 1}"
  }
}
## ROUTE TABLE 
resource "aws_route_table" "web_public_rt" {
  vpc_id = aws_vpc.web_vpc.id

  tags = {
    Name = "web_public"
  }
}
## ROUTE WITH IG ATTACHED FOR PUBLIC SUBNET 

resource "aws_route" "default_public_route" {
  route_table_id         = aws_route_table.web_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.web_internet_gateway.id
}

## ASSOCIATING SUBNETS TO ROUTE TABLE

resource "aws_route_table_association" "web_public_assoc" {
  count          = var.public_sn_count
  subnet_id      = aws_subnet.web_public_subnets.*.id[count.index]
  route_table_id = aws_route_table.web_public_rt.id
}


## EIP AND NAT GATEWAY

resource "aws_eip" "web_nat_eip" {
  vpc = true
}

resource "aws_nat_gateway" "web_ngw" {
  depends_on = [
    aws_eip.web_nat_eip
  ]
  allocation_id     = aws_eip.web_nat_eip.id
  subnet_id         = aws_subnet.web_public_subnets[1].id
}


### PRIVATE SUBNETS 

resource "aws_subnet" "web_private_subnets" {
  count                   = var.private_sn_count
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.${20 + count.index}.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "web_private_${count.index + 1}"
  }
}
## ROUTE TABLE

resource "aws_route_table" "web_private_rt" {
  vpc_id = aws_vpc.web_vpc.id
  
  tags = {
    Name = "web_private"
  }
}
## CREATING ROUTE FOR PRIVATE SUBNET

resource "aws_route" "default_private_route" {
  route_table_id         = aws_route_table.web_private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.web_ngw.id
}

## ASSOCIATING PRIVATE SUBNET TO THE ROUTE TABLE

resource "aws_route_table_association" "web_private_assoc" {
  count          = var.private_sn_count
  route_table_id = aws_route_table.web_private_rt.id
  subnet_id      = aws_subnet.web_private_subnets.*.id[count.index]
}

## PRIVATE SUBNET FOR THE BACKEND DB

resource "aws_subnet" "web_private_subnets_db" {
  count                   = var.private_sn_count
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.${40 + count.index}.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "web_private_db${count.index + 1}"
  }
}
##############################################################
### CREATING SECURITY GROUPS FOR BATION HOST, FRONTEND AND BACKEND
##############################################################

## CREATE BASTION SECURITY GROUP

resource "aws_security_group" "web_bastion_sg" {
  name        = "web_bastion_sg"
  description = "Allow SSH Inbound Traffic From Set IP"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.access_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
## CREATE ELB SECURITY GROUP

resource "aws_security_group" "web_lb_sg" {
  name        = "web_lb_sg"
  description = "Allow Inbound HTTP Traffic"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    description = "HTTP Access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "webserver-elb-SG"
  }
}
## FRONEND SECURITY GROUP 

resource "aws_security_group" "web_frontend_app_sg" {
  name        = "web_frontend_app_sg"
  description = "Allow SSH inbound traffic from HTTP inbound traffic from loadbalancer"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_lb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## BACKEND SECURITY GROUP 

resource "aws_security_group" "web_backend_app_sg" {
  name        = "web_backend_app_sg"
  vpc_id      = aws_vpc.web_vpc.id
  description = "Allow Inbound HTTP from FRONTEND APP "

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web_frontend_app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## SECURITY GROUP FOR THE DATABASE

resource "aws_security_group" "web_rds_sg" {
  name        = "web_rds_sg"
  description = "Allow PostgreSQL Port Inbound Traffic from Backend App Security Group"
  vpc_id      = aws_vpc.web_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_backend_app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


### DATABASE SUBNET GROUP

resource "aws_db_subnet_group" "web_rds_subnetgroup" {
  count      = var.db_subnet_group == true ? 1 : 0
  name       = "web_rds_subnetgroup"
  subnet_ids = [aws_subnet.web_private_subnets_db[0].id, aws_subnet.web_private_subnets_db[1].id]

  tags = {
    Name = "web_rds_sng"
  }
}
###################################################################