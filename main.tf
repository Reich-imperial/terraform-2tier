
terraform {

  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-samson-2tier"
    key    = "terraform-2tier/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "terraform-2tier"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Samson"
    }
  }
}
