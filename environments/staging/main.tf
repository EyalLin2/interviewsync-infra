terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "staging" {
  source = "../../modules/environment"

  environment        = "staging"
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  grafana_password   = var.grafana_password
  slack_webhook_url  = var.slack_webhook_url
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "cluster_name"       { value = module.staging.cluster_name }
output "cluster_endpoint"   { value = module.staging.cluster_endpoint }
output "ecr_backend_url"    { value = module.staging.ecr_backend_url }
output "ecr_frontend_url"   { value = module.staging.ecr_frontend_url }

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.staging.cluster_name}"
}

output "argocd_access" {
  value = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
}
