terraform {
  backend "s3" {
    bucket         = "interviewsync-terraform-state-<YOUR_ACCOUNT_ID>"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "interviewsync-terraform-locks"
    encrypt        = true
  }
}
