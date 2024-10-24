# Variables
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {}

# Provider
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "K3s VPC"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true

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

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  
  tags = {
    Name = "NAT Gateway EIP"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "K3s NAT Gateway"
  }

  depends_on = [aws_internet_gateway.gw]
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

# Route Table (Private)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "Private Route Table"
  }
}

# Route Table Association (Public)
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Route Table Association (Private)
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
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
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "NGINX Security Group"
  }
}

# Security Group (K3s Cluster)
resource "aws_security_group" "k3s" {
  name        = "K3s Security Group"
  description = "Allow inbound traffic for K3s cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "K3s Security Group"
  }
}

# Key Pair
resource "aws_key_pair" "k3s_key" {
  key_name   = "k3s-key"
  public_key = file("~/.ssh/id_rsa.pub")  #Have to use the public key and change key directory to your own directory.
}

# NGINX Load Balancer Instance
resource "aws_instance" "nginx" {
  ami           = "ami-047126e50991d067b"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.k3s_key.key_name

  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.nginx.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx

              # Create a simple HTML page
              cat > /var/www/html/index.html <<'EOL'
              <!DOCTYPE html>
              <html>
              <head>
                  <title>Welcome to K3s Cluster Orchestration</title>
                  <style>
                      body {
                          font-family: Arial, sans-serif;
                          margin: 40px auto;
                          max-width: 650px;
                          line-height: 1.6;
                          padding: 0 10px;
                      }
                  </style>
              </head>
              <body>
                  <h1>Welcome to K3s Cluster Orchestration</h1>
                  <h1>AWS Infrastructure Automation with Terraform Blueprint</h1>
              </body>
              </html>
              EOL

              # Configure NGINX
              cat > /etc/nginx/sites-available/default <<'EOL'
              server {
                  listen 80 default_server;
                  listen [::]:80 default_server;
                  
                  root /var/www/html;
                  index index.html index.htm;

                  server_name _;

                  location / {
                      try_files $uri $uri/ =404;
                  }
              }
              EOL

              systemctl restart nginx
              EOF

  tags = {
    Name = "NGINX Load Balancer"
  }

  depends_on = [aws_internet_gateway.gw]
}

# K3s Master Node
resource "aws_instance" "k3s_master" {
  ami           = "ami-047126e50991d067b"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  key_name      = aws_key_pair.k3s_key.key_name

  vpc_security_group_ids = [aws_security_group.k3s.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y curl
              curl -sfL https://get.k3s.io | sh -
              EOF

  tags = {
    Name = "K3s Master Node"
  }

  depends_on = [aws_nat_gateway.main]
}

# K3s Worker Nodes
resource "aws_instance" "k3s_workers" {
  count         = 2
  ami           = "ami-047126e50991d067b"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.private.id
  key_name      = aws_key_pair.k3s_key.key_name

  vpc_security_group_ids = [aws_security_group.k3s.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y curl
              EOF

  tags = {
    Name = "K3s Worker Node ${count.index + 1}"
  }

  depends_on = [aws_nat_gateway.main]
}

# Outputs
output "nginx_public_ip" {
  value = aws_instance.nginx.public_ip
}

output "nginx_private_ip" {
  value = aws_instance.nginx.private_ip
}

output "k3s_master_private_ip" {
  value = aws_instance.k3s_master.private_ip
}

output "k3s_worker_private_ips" {
  value = aws_instance.k3s_workers[*].private_ip
}