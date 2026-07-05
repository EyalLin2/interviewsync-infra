terraform {
  backend "s3" {
    # Replace with the bucket name output from bootstrap/
    bucket         = "interviewsync-terraform-state-<YOUR_ACCOUNT_ID>"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "interviewsync-terraform-locks"
    encrypt        = true
  }
}
