# Cluster add-ons installed via Helm — all driven by Terraform
# This means the entire cluster state (infra + software) is reproduced by one `terraform apply`

# ── 1. nginx Ingress Controller ───────────────────────────────────────────────
# Exposes an AWS NLB; the frontend Helm chart's Ingress routes through it

resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  version          = "4.10.0"

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  depends_on = [module.eks]
}

# ── 2. kube-prometheus-stack ──────────────────────────────────────────────────
# Installs: Prometheus + Alertmanager + Grafana + node-exporter + kube-state-metrics
# Out-of-the-box dashboards: Kubernetes / Nodes, Kubernetes / Pods, etc.
# Alertmanager is wired to Slack via the webhook variable

resource "helm_release" "prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  version          = "59.0.0"

  values = [
    yamlencode({
      grafana = {
        adminPassword = var.grafana_password
        service = {
          type = "ClusterIP"
        }
      }
      alertmanager = {
        config = {
          global = {
            slack_api_url = var.slack_webhook_url
          }
          receivers = [
            {
              name = "slack-alerts"
              slack_configs = [
                {
                  channel       = "#alerts"
                  send_resolved = true
                  title         = "{{ .GroupLabels.alertname }}"
                  text          = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
                }
              ]
            },
            {
              name = "null"
            }
          ]
          route = {
            receiver   = "slack-alerts"
            group_wait = "10s"
            routes = [
              {
                receiver = "null"
                matchers = ["alertname=Watchdog"]
              }
            ]
          }
        }
      }
    })
  ]

  depends_on = [module.eks]
}

# ── 3. ArgoCD ─────────────────────────────────────────────────────────────────
# GitOps controller — watches interviewsync-gitops repo and syncs desired state

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "6.9.0"

  values = [
    yamlencode({
      server = {
        extraArgs = ["--insecure"]
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  depends_on = [module.eks]
}

# ── 4. AWS for Fluent Bit (CloudWatch logs) ───────────────────────────────────
# DaemonSet that ships every pod's stdout/stderr to CloudWatch Logs
# Log group: /eks/<environment>-interviewsync
#
# Permissions: attach CloudWatchAgentServerPolicy directly to the EKS node
# group IAM role — Fluent Bit runs as a DaemonSet on each node and inherits
# the node's instance profile. No separate IRSA role needed.

resource "aws_iam_role_policy_attachment" "fluent_bit_cloudwatch" {
  role       = module.eks.eks_managed_node_groups["default"].iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "helm_release" "fluent_bit" {
  name             = "aws-for-fluent-bit"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-for-fluent-bit"
  namespace        = "logging"
  create_namespace = true
  version          = "0.1.32"

  set { name = "cloudWatch.enabled";      value = "true" }
  set { name = "cloudWatch.region";       value = var.aws_region }
  set { name = "cloudWatch.logGroupName"; value = "/eks/${var.environment}-interviewsync" }
  set { name = "cloudWatch.autoCreateGroup"; value = "true" }
  set { name = "firehose.enabled";        value = "false" }
  set { name = "kinesis.enabled";         value = "false" }
  set { name = "elasticsearch.enabled";   value = "false" }

  depends_on = [module.eks]
}
