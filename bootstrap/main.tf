terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 bucket for Terraform state — versioned so you can roll back
resource "aws_s3_bucket" "tfstate" {
  bucket        = "interviewsync-terraform-state-${var.aws_account_id}"
  force_destroy = false

  tags = {
    Project   = "interviewsync"
    ManagedBy = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for state locking — prevents concurrent applies
resource "aws_dynamodb_table" "tflock" {
  name         = "interviewsync-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Project   = "interviewsync"
    ManagedBy = "terraform-bootstrap"
  }
}

output "state_bucket_name" {
  value       = aws_s3_bucket.tfstate.bucket
  description = "Use this as the bucket name in environments/*/backend.tf"
}

output "lock_table_name" {
  value       = aws_dynamodb_table.tflock.name
  description = "Use this as the dynamodb_table name in environments/*/backend.tf"
}
