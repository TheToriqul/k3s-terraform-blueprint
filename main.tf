variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "K3s VPC"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "Public Subnet"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "Private Subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "K3s Internet Gateway"
  }
}

# Route Table (Public)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

# Route Table Association (Public)
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group (NGINX)
resource "aws_security_group" "nginx" {
  name        = "NGINX Security Group"
  description = "Allow inbound HTTP/HTTPS traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

# NGINX Load Balancer
resource "aws_instance" "nginx" {
  ami           = "ami-047126e50991d067b"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id

  # Associate a public IP automatically
  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.nginx.id
  ]

  tags = {
    Name = "NGINX Load Balancer"
  }
}


# Security Group (K3s Cluster)
resource "aws_security_group" "k3s" {
  name        = "K3s Security Group"
  description = "Allow inbound traffic for K3s cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["10.0.0.0/16"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

# K3s Master Node
resource "aws_instance" "k3s_master" {
  ami           = "ami-047126e50991d067b"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id

  vpc_security_group_ids = [
    aws_security_group.k3s.id
  ]

  tags = {
    Name = "K3s Master Node"
  }
}

# K3s Worker Nodes
resource "aws_instance" "k3s_workers" {
  count         = 2
  ami           = "ami-047126e50991d067b"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id

  vpc_security_group_ids = [
    aws_security_group.k3s.id
  ]

  tags = {
    Name = "K3s Worker Node ${count.index + 1}"
  }
}