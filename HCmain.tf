#Step 1. Add AWS provider.
terraform {
    required_version = ">= 1.0"
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
}

provider "aws" {
    region = "eu-west-2"
}

#Step 2. Make VPC after setitng up provider.tf w/ AWS provider.
resource "aws_vpc" "vpcBP" { #This changes resource name in local file to vpcBP
  cidr_block       = "10.0.0.0/16" #Open access to internet and wide range.
  instance_tenancy = "default"

  tags = {
    Name = "vpcBP" #This makes it appear as vpcBP in just awsconfig. good to make both match (local file and the aws config as its easier)
  }
}

#3. Make IGW (Internet gateway).

resource "aws_internet_gateway" "vpcBP-igw" { #made into igw over gw as its local file name.
  vpc_id = aws_vpc.vpcBP.id #This tells us which VPC ID to attach to.

  tags = {
    Name = "vpcBP-igw"
  }
}

#4. Making Subnets.
#Public Subnet(sn) #1
resource "aws_subnet" "publicBPsn" {
  vpc_id     = aws_vpc.vpcBP.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a" #adds resillience w/ AZ's

  tags = {
    Name = "publicBPsn"
  }
}

#Private subnet(sn) #2
resource "aws_subnet" "privateBPsn" {
  vpc_id     = aws_vpc.vpcBP.id
  cidr_block = "10.0.2.0/24" #changed this to 10.0.2.0/24 over 10.0.1.0/24 (increased by 1)
  availability_zone = "eu-west-2b" #adds resillience w/ AZ's.

  tags = {
    Name = "privateBPsn"
  }
}

#Step 5. Make route tables (public & private)

#public-routetable(RT)
resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.vpcBP.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpcBP-igw.id
  }

  tags = {
    Name = "publicRT"
  }
}

#private-routetale(RT)
resource "aws_route_table" "privateRT" {
  vpc_id = aws_vpc.vpcBP.id

  tags = {
    Name = "privateRT"
  }
}

#Step 6. Associate route tables with subnets

resource "aws_route_table_association" "public-rt-assoc" {
  subnet_id      = aws_subnet.publicBPsn.id
  route_table_id = aws_route_table.publicRT.id
}

resource "aws_route_table_association" "private-rt-assoc" {
  subnet_id      = aws_subnet.privateBPsn.id
  route_table_id = aws_route_table.privateRT.id
}

#Step 7. Making security group  for bastion & priv ec2. before we create/launch ec2's.
#Public bastion Security group.
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.vpcBP.id

  tags = {
    Name = "bastion_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_ingress" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "51.19.34.122/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "bastion_egress" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0" #Allows all outbound traffic
  ip_protocol       = "-1" # semantically equivalent to all ports aka all protocols?
}

#Private security group now.
resource "aws_security_group" "private_sg" {
  name        = "private_sg"
  description = "Only allows bastion host to SSH in."
  vpc_id      = aws_vpc.vpcBP.id

  tags = {
    Name = "private_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "private_ssh_ingress" {
  security_group_id = aws_security_group.private_sg.id
  referenced_security_group_id        = aws_security_group.bastion_sg.id
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "private_egress" {
  security_group_id = aws_security_group.private_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#step 8. Make key-pair value. Did this on AWS Config over terraform. security over complexity. 

#Step 9. Launch Ec2 instances - Bastion host & private host.

#Bastion Host Instance.
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Canonical
}

resource "aws_instance" "bastion_ec2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.publicBPsn.id
  vpc_security_group_ids      = [aws_security_group_bastion_sg.id]
  associate_public_ip_address = true
  key_name                    = "bastion key"

  tags = {
    Name = "Bastion_ec2"
  }
}

#Private Instance. 
resource "aws_instance" "private_ec2" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.privateBPsn.id
  vpc_security_group_ids      = [aws_security_group_private_sg.id]
  associate_public_ip_address = false
  key_name                    = "bastion key"

  tags = {
    Name = "private_ec2"
  }
}



