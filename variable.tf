# =============================================================================
# variables.tf — All Input Variables
# =============================================================================
# Variables are Terraform's way of avoiding hardcoded values.
#
# The problem with hardcoding:
#   If you write "us-east-1" in five different files and later need to
#   deploy to "eu-west-1", you have to find and replace it everywhere.
#   You'll miss one. Things will break in confusing ways.
#
# The solution — variables:
#   Define the variable once here. Reference it as var.aws_region everywhere.
#   To change the region, you change one value in terraform.tfvars.
#
# Think of variables.tf as a form with blank fields.
# terraform.tfvars is you filling in the form.
# The "default" value is the pre-filled answer if you leave it blank.
#
# HOW TERRAFORM RESOLVES VARIABLE VALUES (priority order, highest first):
#   1. -var flag on the CLI:      terraform apply -var="environment=prod"
#   2. terraform.tfvars file:     environment = "prod"
#   3. Default in variables.tf:   default = "dev"
# =============================================================================


# --- GENERAL -----------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy all resources into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment label used in resource names and tags (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Short prefix applied to every resource name for easy identification"
  type        = string
  default     = "tf2tier"
}


# --- NETWORKING --------------------------------------------------------------
# These CIDRs define the IP address ranges for your network.
# A /16 gives you 65,536 addresses. A /24 gives you 256.
# We use 10.1.x.x here to avoid clashing with your existing VPC (10.0.x.x).

variable "vpc_cidr" {
  description = "IP range for the entire VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IP range for the public subnet — web server lives here"
  type        = string
  default     = "10.1.1.0/24"
}

variable "private_subnet_cidr" {
  description = "IP range for the private subnet — DB server lives here, no internet access"
  type        = string
  default     = "10.1.2.0/24"
}

variable "availability_zone_public" {
  description = "AZ for the public subnet"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_private" {
  description = "AZ for the private subnet"
  type        = string
  default     = "us-east-1b"
}


# --- COMPUTE -----------------------------------------------------------------

variable "instance_type" {
  description = "EC2 instance type — t2.micro is free tier eligible"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Name of your existing AWS key pair (the name in the console, not the .pem path)"
  type        = string
  default     = "samson-key"
}
