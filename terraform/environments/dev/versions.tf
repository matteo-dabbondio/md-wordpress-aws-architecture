terraform {
  required_version = ">= 1.10.0" # for S3 native locking 

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}