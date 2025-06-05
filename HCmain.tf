
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

#Step 7. Making security group  for bastion & priv ec2. before we create/launch ec2's. #properly fixed.
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow SSH from my IP"
  vpc_id      = aws_vpc.vpcBP.id

  ingress = [{
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["51.19.34.122/32"] #public IP - kept to /32 to only use specific one not a whole ip range.
  }]

  egress = [{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]

  tags = {
    Name = "bastion_sg"
  }
}

resource "aws_security_group" "private_sg" {
  name        = "private_sg"
  description = "Allow SSH only from bastion security group"
  vpc_id      = aws_vpc.vpcBP.id

  ingress = [{
    from_port                = 22
    to_port                  = 22
    protocol                 = "tcp" 
    source_security_group_id = aws_security_group.bastion_sg.ID #THIS ISNT WORKINGGG AND ITS ONLY STEP7 IM STUCK ON AND DOCUMENTATION IS CONFUSING ME FOR ONCEEEE
  }]

  egress = [{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]

  tags = {
    Name = "private_sg"
  }
}
