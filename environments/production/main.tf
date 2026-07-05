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

module "production" {
  source = "../../modules/environment"

  environment        = "production"
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  grafana_password   = var.grafana_password
  slack_webhook_url  = var.slack_webhook_url
}

output "cluster_name"     { value = module.production.cluster_name }
output "cluster_endpoint" { value = module.production.cluster_endpoint }
output "ecr_backend_url"  { value = module.production.ecr_backend_url }
output "ecr_frontend_url" { value = module.production.ecr_frontend_url }

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.production.cluster_name}"
}
