terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.0"
    }
  }
}

provider "github" {
    token = var.github_token
  
}
# Configure the AWS Provider
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.aws_region
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "${var.namespace}_VPC"
  }
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.namespace}_IG"
  }
}


resource "aws_route_table" "route" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
  tags = {
    Name = "${var.namespace}_RT"
  }
}

resource "aws_route_table_association" "default" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route.id
}


data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "subnet" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = var.vpc_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  depends_on              = [aws_internet_gateway.gateway]
  tags = {
    Name = "${var.namespace}_Subnet"
  }
}


resource "aws_security_group" "default" {
  name        = "ssh-allow"
  description = "Allow SSH Connections"
  vpc_id      = aws_vpc.vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.namespace}-SG"
  }
}



resource "aws_network_acl" "acl" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "-1"
    rule_no    = 150
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }
  egress {
    protocol   = "-1"
    rule_no    = 150
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    Name = "${var.namespace}-NACL"
  }
}


resource "tls_private_key" "instancessh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "dot"
  public_key = tls_private_key.instancessh.public_key_openssh
}

# resource "local_file" "instancekey" {
#   filename = "${path.module}/dot.pem"
#   content  = tls_private_key.instancessh.private_key_pem
# }

# AWS Instance

resource "aws_instance" "instance" {
  ami                    = var.ec2_ami
  availability_zone      = data.aws_availability_zones.available.names[0]
  instance_type          = "t2.micro"
  monitoring             = true
  vpc_security_group_ids = [aws_security_group.default.id]
  subnet_id              = aws_subnet.subnet.id
  associate_public_ip_address = true
  key_name = aws_key_pair.deployer.key_name

#   user_data = <<EOF
#    #!/bin/bash
#    echo "dotadmin:@P@$$w0rd@dmin" | chpasswd
#   EOF

#   user_data = <<EOF
#   #!/bin/bash
#   sudo sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config
#   sudo systemctl restart sshd
#   EOF
#   useradd dotadmin
#   echo "**" | passwd --stdin dotadmin
  
  provisioner "remote-exec" {
   inline = [
    # "sed 's/PasswordAuthentication no/PasswordAuthentication yes/' -i /etc/ssh/sshd_config",
    # "systemctl restart sshd",

    #  "echo '***' | sudo passwd ec2-user --stdin",
    # "sudo apt-get update && sudo apt-get install -y make build-essential ruby-full rubygems && gem install jekyll --version="~> 4.2.0" ",
    # "sudo gem update --system",
    # "sudo gem install jekyll bundler",
   ] 
  }
  connection {
    user = var.user
    private_key = tls_private_key.instancessh.private_key_pem
    host = self.public_ip
  }
  
  
  tags = {
    name = "${var.namespace}-Instance"
  }
}


resource "aws_s3_bucket" "jekyll_bucket" {
  bucket = "dot-jekyll-bucket"
}

resource "aws_s3_bucket_policy" "jekyll_bucket_policy" {
  bucket = aws_s3_bucket.jekyll_bucket.id
  
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::dot-jekyll-bucket/*"
        }
    ]
}
EOF
}

resource "aws_s3_bucket_website" "jekyll_bucket_website" {
  bucket = aws_s3_bucket.jekyll_bucket.id
  index_document = "index.html"
  error_document = "error.html"
}



data "github_actions_public_key" "public_key" {
  repository = "dotai-assessment"
}

resource "github_actions_secret" "secret" {
  repository       = "dotai-assessment"
  secret_name      = "SSH_PRIVATE_KEY"
  plaintext_value  = tls_private_key.instancessh.private_key_pem
}