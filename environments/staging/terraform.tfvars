# Non-sensitive staging values
# Sensitive values (grafana_password, slack_webhook_url) are passed via:
#   TF_VAR_grafana_password=... terraform apply
# or stored in AWS Secrets Manager / GitHub Actions secrets

aws_region         = "us-east-1"
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]
private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnets     = ["10.0.101.0/24", "10.0.102.0/24"]
