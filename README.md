# interviewsync-infra

Terraform infrastructure for InterviewSync on AWS EKS.

## Architecture

```
AWS Account
└── VPC (10.0.0.0/16)
    ├── Private Subnets → EKS Node Groups (t3.medium)
    └── Public Subnets  → NAT Gateway, Load Balancers
        └── EKS Cluster
            ├── ingress-nginx          (exposes frontend)
            ├── kube-prometheus-stack  (Prometheus + Grafana + Alertmanager)
            ├── argocd                 (GitOps controller)
            └── aws-for-fluent-bit    (CloudWatch log shipping)
ECR
├── interviewsync-backend
└── interviewsync-frontend
```

## Prerequisites

- Terraform >= 1.6.0
- AWS CLI configured (`aws configure`)
- `kubectl` installed
- `helm` >= 3.14

## Step 1 — Bootstrap state backend (run once)

```bash
cd bootstrap/
terraform init
terraform apply \
  -var="aws_region=us-east-1" \
  -var="aws_account_id=<YOUR_12_DIGIT_ACCOUNT_ID>"
```

Copy the `state_bucket_name` output and update `bucket` in both:
- `environments/staging/backend.tf`
- `environments/production/backend.tf`

## Step 2 — Deploy staging

```bash
cd environments/staging/
terraform init
terraform apply \
  -var="grafana_password=<CHOOSE_A_PASSWORD>" \
  -var="slack_webhook_url=<YOUR_SLACK_WEBHOOK_URL>"
```

This creates (in ~15 minutes):
- VPC + subnets + NAT gateway
- EKS cluster (2 × t3.medium nodes)
- ECR repos for backend and frontend
- nginx ingress controller
- Prometheus + Grafana + Alertmanager (Slack wired in)
- ArgoCD
- Fluent Bit → CloudWatch

## Step 3 — Configure kubectl

```bash
# Command is also printed as a Terraform output:
aws eks update-kubeconfig --region us-east-1 --name staging-interviewsync

# Verify nodes are Ready:
kubectl get nodes
```

## Step 4 — Access ArgoCD

```bash
# Get the initial admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward the ArgoCD UI:
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open in browser: http://localhost:8080
# Username: admin
# Password: (from above)
```

## Step 5 — Deploy the application via ArgoCD

```bash
# Apply ArgoCD Application manifests from the gitops repo:
kubectl apply -f https://raw.githubusercontent.com/<YOUR_USERNAME>/interviewsync-gitops/main/argocd/staging/app-postgres.yaml
kubectl apply -f https://raw.githubusercontent.com/<YOUR_USERNAME>/interviewsync-gitops/main/argocd/staging/app-backend.yaml
kubectl apply -f https://raw.githubusercontent.com/<YOUR_USERNAME>/interviewsync-gitops/main/argocd/staging/app-frontend.yaml

# Watch ArgoCD sync:
kubectl get applications -n argocd
```

## Step 6 — Access Grafana

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Open: http://localhost:3000
# Username: admin
# Password: (the grafana_password you set in Step 2)
# Dashboard: Dashboards → Kubernetes → Nodes
```

## Step 7 — View logs in CloudWatch

AWS Console → CloudWatch → Log Groups → `/eks/staging-interviewsync`

---

## Deploy production

```bash
cd environments/production/
terraform init
terraform apply \
  -var="grafana_password=<PROD_PASSWORD>" \
  -var="slack_webhook_url=<SLACK_WEBHOOK>"
```

Then apply the production ArgoCD manifests and tag a release:

```bash
git tag v1.0.0 && git push --tags  # triggers deploy.yml production job
```

## Module reuse

To add a new environment (e.g. `qa`):

```bash
cp -r environments/staging environments/qa
# edit environments/qa/terraform.tfvars — change CIDRs to avoid overlap
# edit environments/qa/backend.tf — change key to "qa/terraform.tfstate"
terraform -chdir=environments/qa init && terraform -chdir=environments/qa apply
```
