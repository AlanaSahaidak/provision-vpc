resource "aws_vpc" "vnet_nebo" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vnet-nebo"
  }
}

resource "aws_subnet" "snet_public" {
  vpc_id                  = aws_vpc.vnet_nebo.id
  cidr_block              = var.subnet_public_cidr
  map_public_ip_on_launch = true

  tags = {
    Name = "snet-public"
  }
}

resource "aws_subnet" "snet_private" {
  vpc_id     = aws_vpc.vnet_nebo.id
  cidr_block = var.subnet_private_cidr

  tags = {
    Name = "snet-private"
  }
}

resource "aws_internet_gateway" "vnet_igw" {
  vpc_id = aws_vpc.vnet_nebo.id

  tags = {
    Name = "vnet-igw"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vnet_nebo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vnet_igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.snet_public.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "sg_private" {
  vpc_id = aws_vpc.vnet_nebo.id
  name   = "vm1-sg"

  ingress {
    description = "Allow traffic from VM2"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_subnet.snet_public.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_private"
  }
}

resource "aws_security_group" "sg_public" {
  vpc_id = aws_vpc.vnet_nebo.id
  name   = "vm2-sg"

  ingress {
    description = "Allow SSH from any IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP from any IP"
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

  tags = {
    Name = "sg_public"
  }
}

resource "aws_key_pair" "main" {
  key_name   = "nebo_key"
  public_key = file("${var.ssh_key_path}.pub")
}

resource "aws_instance" "vm_private" {
  ami           = var.linux_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.snet_private.id
  vpc_security_group_ids = [aws_security_group.sg_private.id]
  key_name      = aws_key_pair.main.key_name
  tags = {
    Name = "vm1-private"
  }
}

resource "aws_instance" "vm_public" {
  ami           = var.linux_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.snet_public.id
  vpc_security_group_ids = [aws_security_group.sg_public.id]
  key_name      = aws_key_pair.main.key_name
  tags = {
    Name = "vm2-public"
  }
}

resource "aws_network_acl" "public_acl" {
  vpc_id = aws_vpc.vnet_nebo.id


  ingress {
    protocol   = "icmp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

 
  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 400
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
  protocol   = "-1"
  rule_no    = 500
  action     = "allow"
  cidr_block = "10.0.0.0/16"
  from_port  = 0
  to_port    = 0
 }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  
  tags = {
    Name = "main-nacl"
  }
}

resource "aws_network_acl_association" "public_association" {
  network_acl_id = aws_network_acl.public_acl.id
  subnet_id      = aws_subnet.snet_public.id
}

resource "aws_network_acl" "private_acl" {
  vpc_id = aws_vpc.vnet_nebo.id

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.subnet_public_cidr
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "-1"
    rule_no    = 200
    action     = "deny"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "private-nacl-nebo"
  }
}

resource "aws_network_acl_association" "private_association" {
  network_acl_id = aws_network_acl.private_acl.id
  subnet_id      = aws_subnet.snet_private.id
}