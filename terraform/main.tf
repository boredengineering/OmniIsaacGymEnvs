locals {
  instance_name = var.instance_name
  region       = var.region
  instance_type = var.instance_type
  nvidia_ami = var.nvidia_ami
  # vpc_cidr
}

terraform {
  required_version = ">= 1.2.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.30.0"
    }
  }

}

provider "aws" {
  # profile = "default"
  region = local.region
}

#---------------------------------------------------------------
# Create the Instance
# NVIDIA Omniverse GPU-Optimized for running Isaac-Sim Container
resource "aws_instance" "isaac_sim_oige" {
  ami             = data.aws_ami.nvidia_omniverse_ami
  instance_type   = local.instance_type
  key_name        = "isaac-sim-oige-key"
  user_data	      = file("isaac-sim-oige.sh")
  security_groups = [ aws_security_group.sg_isaac_sim_oige.id ]
  subnet_id       = var.subnet_id

  Env = "Isaac-Sim"
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 200
  }

  tags = {
    Name = "isaac-sim-oige"
  }

  depends_on = [
    aws_security_group.sg_isaac_sim_oige, 
    aws_key_pair.isaac-sim-oige-public-key
  ]
}

#---------------------------------------------------------------
# Images - AMI
#---------------------------------------------------------------
data "aws_ami" "nvidia_omniverse_ami" {
  executable_users = ["self"]
  most_recent      = true
  owners           = ["aws-marketplace"]

  filter {
    name   = "name"
    values = ["NVIDIA Omniverse GPU-Optimized AMI"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#---------------------------------------------------------------
# Network & Security
#---------------------------------------------------------------
# Security Group
#---------------------------------------------------------------
resource "aws_security_group" "sg_isaac_sim_oige" {
  name        = "sg_isaac_sim_oige"
  description = "Allow all traffic in and out so we can talk to Omniverse Services"
  # vpc_id      = aws_vpc.main.id
  vpc_id      = aws_vpc.vpc.id
# protocol of -1 is equivalent to all
  ingress {
    description      = "Allows all Traffic Ingress"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description      = "Allows all Traffic Egress"    
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "sg_isaac_sim_oige"
  }
  depends_on = [ aws_vpc.vpc ]
}
#---------------------------------------------------------------
# Create a Key Pair
#---------------------------------------------------------------
resource "aws_key_pair" "isaac-sim-oige-public-key" {
  key_name   = "isaac-sim-oige-key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "isaac-sim-oige-private-key" {
  content = tls_private_key.rsa.private_key_pem
  filename = "isaac-sim-oige-private-key"
}
#---------------------------------------------------------------
# VPC
#---------------------------------------------------------------
resource "aws_vpc" "vpc" {
  cidr_block = var.cidr_block
  tags = {
    Name = "${var.env}_vpc"
    Env  = var.env
  }

}
#---------------------------------------------------------------
# Subnet
#---------------------------------------------------------------
resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.subnet
  map_public_ip_on_launch = "true"
  tags = {
      Name = "${var.env}_subnet"
      Env  = var.env
    }
  depends_on = [ aws_vpc.vpc ]
}
#---------------------------------------------------------------
# Internet Gateway
#---------------------------------------------------------------
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
      Name = "${var.env}_gw"
      Env  = var.env
    }
  depends_on = [ aws_vpc.vpc ]
}
#---------------------------------------------------------------
# Route Table
#---------------------------------------------------------------
resource "aws_default_route_table" "route_table" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "default route table"
    env  = var.env
  }
  depends_on = [ aws_vpc.vpc ]
}
#---------------------------------------------------------------
# Supporting Resources
#---------------------------------------------------------------

#---------------------------------------------------------------
# Output
#---------------------------------------------------------------
output "ami_id" {
  value = data.aws_ami.nvidia_omniverse_ami.id
}
output "ami_name" {
  value = data.aws_ami.nvidia_omniverse_ami.name
}