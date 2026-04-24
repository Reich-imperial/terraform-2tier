# =============================================================================
# vpc.tf — The Network Layer
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
# The VPC is your private, isolated network on AWS.
# Nothing outside can reach it unless you explicitly allow it.
# Nothing inside can reach outside unless you build the path.
#
# enable_dns_hostnames → EC2 instances get a public DNS name like:
# ec2-54-123-45-67.compute-1.amazonaws.com
# Required for some services to work correctly.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}


# -----------------------------------------------------------------------------
# SUBNETS
# -----------------------------------------------------------------------------
# Subnets are subdivisions of your VPC — think of them as floors in a building.
#
# PUBLIC SUBNET:
# Has a route to the internet gateway. EC2s here can receive public IPs.
# map_public_ip_on_launch = true → every EC2 launched here automatically
# gets a public IP address. This is how web01 becomes reachable from outside.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id   # Belongs to our VPC
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone_public
  map_public_ip_on_launch = true              # web01 gets a public IP automatically

  tags = {
    Name = "${var.project_name}-public-subnet"
    Tier = "public"
  }
}

# PRIVATE SUBNET:
# No route to the internet gateway. EC2s here get NO public IP.
# db01 lives here — it can only be reached from inside the VPC (i.e., from web01).
# This is the correct architecture: databases should never be publicly accessible.
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone_private
  # No map_public_ip_on_launch — private subnet instances get no public IP

  tags = {
    Name = "${var.project_name}-private-subnet"
    Tier = "private"
  }
}

# SECOND PUBLIC SUBNET (different AZ)
# AWS requires a load balancer to span at least two Availability Zones.
# This subnet exists solely to satisfy that requirement.
# AZ: us-east-1b (our first public subnet is in us-east-1a)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-2"
    Tier = "public"
  }
}


# -----------------------------------------------------------------------------
# INTERNET GATEWAY
# -----------------------------------------------------------------------------
# The IGW is the front door between your VPC and the public internet.
# One VPC can have at most one IGW.
#
# Creating an IGW alone doesn't open any doors — you also need a route table
# that points traffic toward it. The IGW + route table together = internet access.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}


# -----------------------------------------------------------------------------
# ROUTE TABLES
# -----------------------------------------------------------------------------
# A route table is a set of rules that tells network traffic where to go.
# Every subnet must be associated with exactly one route table.
#
# PUBLIC ROUTE TABLE:
# Rule: "Any traffic destined for the open internet (0.0.0.0/0)?
#        Send it through the internet gateway."
# The public subnet is associated with this table → its EC2s can reach the internet.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                  # All internet-bound traffic
    gateway_id = aws_internet_gateway.main.id  # Goes through the front door
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# PRIVATE ROUTE TABLE:
# No internet route is added here.
# The private subnet is associated with this table → its EC2s have no internet path.
# They can only communicate with other resources inside the VPC.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  # Intentionally empty — no internet route

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}


# -----------------------------------------------------------------------------
# ROUTE TABLE ASSOCIATIONS
# -----------------------------------------------------------------------------
# This is the wiring step — connecting each subnet to its route table.
# Without associations, subnets fall back to the VPC's default route table.
# Explicit associations make your intent clear and your infrastructure auditable.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id  # Same public route table
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
