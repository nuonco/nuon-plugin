# Nuon App Configuration Patterns Reference

This document catalogs the proven patterns from canonical Nuon app configs. Use it to generate valid configurations for any common application deployment pattern.

---

## Table of Contents

1. [Pattern: EKS Simple (Single Helm Chart on Kubernetes)](#pattern-eks-simple)
2. [Pattern: Grafana (Multi-Tier Observability Stack)](#pattern-grafana)
3. [Pattern: AWS Lambda (Serverless with Docker Build)](#pattern-aws-lambda)
4. [Common Patterns](#common-patterns)
5. [Decision Framework](#decision-framework)

---

## Pattern: EKS Simple

**When to use:** Deploying a single containerized application on EKS with an ALB and TLS certificate. This is the simplest Kubernetes-based pattern and serves as the starting template for most EKS apps.

### Architecture Diagram

```
                        Customer's AWS Account
                        +-------------------------------------------+
                        |                                           |
  CloudFormation Stack  |  Runner (EC2 ASG)                         |
  (VPC + Runner)        |    |                                      |
                        |    v                                      |
                        |  EKS Sandbox (nuonco/aws-eks-sandbox)     |
                        |    |                                      |
                        |    +-- certificate (terraform_module)     |
                        |    |     ACM wildcard cert for DNS        |
                        |    |                                      |
                        |    +-- whoami (helm_chart)                |
                        |    |     Deploys app into "whoami" ns     |
                        |    |                                      |
                        |    +-- alb (helm_chart)                   |
                        |          Wires cert + service + domain    |
                        |          depends on: whoami, certificate  |
                        +-------------------------------------------+
```

### Complete File Listing

| File | Purpose |
|------|---------|
| `metadata.toml` | App identity: name, description, readme path |
| `inputs.toml` | Customer-facing inputs: domain, sub_domain (grouped under "dns") |
| `sandbox.toml` | EKS sandbox config pointing to `nuonco/aws-eks-sandbox` |
| `sandbox.tfvars` | Terraform variable overrides for sandbox (namespaces, node sizing, RBAC) |
| `stack.toml` | AWS CloudFormation stack for VPC + runner (type = "aws-cloudformation") |
| `runner.toml` | Runner type (aws), helm driver, init script URL |
| `secrets.toml` | Empty -- placeholder for app secrets |
| `policies.toml` | Kubernetes cluster policies (e.g., disallow nginx custom snippets) |
| `break_glass.toml` | Emergency access roles with AdministratorAccess minus SecretsManager |
| `permissions/provision.toml` | IAM role for provisioning sandbox + components |
| `permissions/maintenance.toml` | IAM role for day-2 operations (scoped SecretsManager, S3) |
| `permissions/deprovision.toml` | IAM role for teardown |
| `permissions/*_boundary.json` | Permissions boundaries for each role |
| `components/certificate.toml` | Terraform module: ACM wildcard certificate |
| `components/whoami.toml` | Helm chart: the application deployment |
| `components/alb.toml` | Helm chart: ALB ingress wiring cert to service |
| `components/values/whoami.yaml` | Helm values for whoami (image, ports) |
| `actions/healthcheck.toml` | Manual action: ALB health check |
| `actions/simple_action.toml` | Post-provision action: create k8s secrets |
| `actions/deployment_status.toml` | Manual action: get deployment status |
| `actions/deployment_restart.toml` | Manual action: rolling restart |
| `actions/certificate_status.toml` | Manual action: describe ACM certificate |
| `actions/alb.toml` | Manual action: multi-step ALB diagnostics |

### Key Config Snippets

**metadata.toml** -- Every app config starts with version and identity:
```toml
version = "v2"

display_name = "EKS Simple"
description  = "Whoami on AWS EKS"
readme       = "./README.md"
```

**inputs.toml** -- Inputs are grouped by concern. Each group gets a `[[group]]` entry, then inputs reference it via `group`:
```toml
[[group]]
name         = "dns"
description  = "DNS Configrations"
display_name = "Configurations for the root domain for Route53"

[[input]]
name         = "domain"
description  = "domain for the whoami endpoint e.g., nuon.run"
default      = "nuon.run"
display_name = "Domain"
group        = "dns"

[[input]]
name         = "sub_domain"
description  = "The sub domain for the Whoami service"
default      = "whoami"
display_name = "Sub Domain"
group        = "dns"
```

**sandbox.toml** -- Standard EKS sandbox with template variables:
```toml
terraform_version = "1.11.3"

[public_repo]
directory = "."
repo      = "nuonco/aws-eks-sandbox"
branch    = "main"

[vars]
cluster_name         = "n-{{.nuon.install.id}}"
enable_nuon_dns      = "true"
public_root_domain   = "{{ .nuon.install.id }}.{{.nuon.inputs.inputs.domain}}"
internal_root_domain = "internal.{{ .nuon.install.id }}.{{.nuon.inputs.inputs.domain}}"

[[var_file]]
contents = "./sandbox.tfvars"
```

**sandbox.tfvars** -- Hardcoded sandbox tuning (not templated in the simple case):
```hcl
maintenance_role_eks_access_entry_policy_associations = {
  eks_admin = {
    policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
    access_scope = {
      type = "cluster"
    }
  }
  eks_view = {
    policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
    access_scope = {
      type = "cluster"
    }
  }
}

additional_namespaces = ["whoami"]

min_size = 2
max_size = 3
desired_size = 2
```

**component: certificate (terraform_module)** -- References sandbox outputs for DNS zone:
```toml
name              = "certificate"
type              = "terraform_module"
terraform_version = "1.11.3"

[public_repo]
repo      = "nuonco/example-app-configs"
directory = "eks-simple/src/components/certificate"
branch    = "main"

[vars]
install_id  = "{{ .nuon.install.id }}"
region      = "{{ .nuon.install_stack.outputs.region }}"
zone_id     = "{{ .nuon.install.sandbox.outputs.nuon_dns.public_domain.zone_id }}"
domain_name = "*.{{ .nuon.install.sandbox.outputs.nuon_dns.public_domain.name }}"
```

**component: whoami (helm_chart)** -- Uses `[[values_file]]` for external YAML:
```toml
name           = "whoami"
type           = "helm_chart"
chart_name     = "whoami"
namespace      = "whoami"
storage_driver = "configmap"

[public_repo]
repo      = "nuonco/example-app-configs"
directory = "eks-simple/src/components/whoami"
branch    = "main"

[[values_file]]
contents = "./values/whoami.yaml"
```

**component: alb (helm_chart)** -- Dependency wiring and inline `[values]`:
```toml
name         = "application_load_balancer"
type         = "helm_chart"
chart_name   = "application-load-balancer"
dependencies = ["whoami"]

[public_repo]
repo      = "nuonco/example-app-configs"
directory = "eks-simple/src/components/alb"
branch    = "main"

[values]
domain_certificate = "{{.nuon.components.certificate.outputs.public_domain_certificate_arn}}"
domain             = "{{.nuon.inputs.inputs.sub_domain}}.{{.nuon.install.sandbox.outputs.nuon_dns.public_domain.name}}"
https_port         = "443"
service_name       = "whoami"
service_port       = "80"
install_name       = "{{.nuon.install.id}}"
namespace          = "whoami"
healthcheck_path   = "/health"
```

**action: post-provision with inline script**:
```toml
name    = "simple_demonstration"
timeout = "1m"

[[triggers]]
type = "post-provision"

[[triggers]]
type = "manual"

[[steps]]
name    = "create secrets in cluster"
inline_contents = """
#!/usr/bin/env sh
password=`openssl rand -hex 12`
kubectl create -n whoami secret generic whoami \
  --save-config    \
  --dry-run=client \
  --from-literal=value="$password" \
  -o yaml | kubectl apply -f -
"""
```

### What Makes This Pattern Different

- **Minimal complexity.** Only 3 components with a flat dependency chain.
- **No databases or stateful infrastructure** beyond what the sandbox provides.
- **No numbered component files.** Components do not use numeric prefixes because the dependency graph is trivial.
- **Hardcoded sandbox.tfvars.** Node sizing is not exposed as customer inputs.
- **Good starter template.** Copy this pattern when deploying any single-service web app on EKS.

---

## Pattern: Grafana

**When to use:** Deploying a multi-tier application stack with databases, monitoring, and multiple Helm charts. Use this pattern when your app requires RDS databases, cross-component secret sharing, and a layered deployment order.

### Architecture Diagram

```
                        Customer's AWS Account
                        +-----------------------------------------------------------+
                        |                                                           |
  CloudFormation Stack  |  Runner (EC2 ASG)                                         |
  (VPC + Runner)        |    |                                                      |
                        |    v                                                      |
                        |  EKS Sandbox (nuonco/aws-eks-sandbox)                     |
                        |    |                                                      |
                        |    +-- 0-rds_subnet (terraform_module)                    |
                        |    |     Creates DB subnet group from VPC private subnets |
                        |    |                                                      |
                        |    +-- 1-rds_cluster_grafana (terraform_module)            |
                        |    |     RDS PostgreSQL for Grafana metadata               |
                        |    |                                                      |
                        |    +-- 1-rds_cluster_exampledb (terraform_module)          |
                        |    |     RDS PostgreSQL for application data               |
                        |    |     depends on: rds_cluster_grafana                   |
                        |    |                                                      |
                        |    +-- 2-grafana-secrets (kubernetes_manifest)             |
                        |    |     Namespace + placeholder for DB creds              |
                        |    |     depends on: rds_cluster_grafana                   |
                        |    |                                                      |
                        |    +-- 2-exampledb-secrets (kubernetes_manifest)           |
                        |    |     Namespace + placeholder for DB creds              |
                        |    |     depends on: rds_cluster_exampledb                 |
                        |    |                                                      |
                        |    +-- 3-postgres-exporter (helm_chart)                    |
                        |    |     Exports DB metrics to Prometheus                  |
                        |    |     depends on: rds_cluster_exampledb                 |
                        |    |                                                      |
                        |    +-- 4-prometheus (helm_chart)                           |
                        |    |     Scrapes postgres-exporter metrics                 |
                        |    |     depends on: postgres_exporter                     |
                        |    |                                                      |
                        |    +-- 5-grafana (helm_chart)                              |
                        |    |     Dashboards + datasources                          |
                        |    |     depends on: prometheus, grafana_secrets,           |
                        |    |       exampledb_secrets, both RDS clusters             |
                        |    |                                                      |
                        |    +-- 6-certificate (terraform_module)                    |
                        |    |     ACM wildcard cert                                 |
                        |    |                                                      |
                        |    +-- 7-alb (helm_chart)                                  |
                        |          Wires cert + Grafana service + domain             |
                        |          depends on: certificate, grafana                  |
                        +-----------------------------------------------------------+

  Actions (post-deploy):
    grafana_rds_creds     --> triggered after rds_cluster_grafana deploy
    exampledb_rds_creds   --> triggered after rds_cluster_exampledb deploy
    default_storage_class --> triggered before rds_subnet deploy
    simulate_db_activity  --> manual
    stop_db_activity      --> manual
    alb_healthcheck       --> manual
```

### Complete File Listing

| File | Purpose |
|------|---------|
| `metadata.toml` | App identity |
| `inputs.toml` | Customer inputs in 3 groups: grafana, database, compute |
| `sandbox.toml` | EKS sandbox with templated cluster_version and instance_type from inputs |
| `sandbox.tfvars` | Namespaces, node sizing from inputs (templated), maintenance RBAC |
| `stack.toml` | AWS CloudFormation nested stack |
| `runner.toml` | Standard AWS runner config |
| `secrets.toml` | Empty placeholder |
| `policies.toml` | Kubernetes cluster policies |
| `break_glass.toml` | Emergency access role |
| `permissions/provision.toml` | Provision IAM role |
| `permissions/maintenance.toml` | Maintenance role with scoped SecretsManager + S3 policies |
| `permissions/deprovision.toml` | Deprovision IAM role |
| `components/0-rds_subnet.toml` | Shared RDS subnet group from VPC private subnets |
| `components/1-rds_cluster_grafana.toml` | RDS PostgreSQL for Grafana's internal DB |
| `components/1-rds_cluster_exampledb.toml` | RDS PostgreSQL for application data |
| `components/2-grafana-secrets.toml` | Kubernetes namespace manifest for Grafana |
| `components/2-exampledb-secrets.toml` | Kubernetes namespace manifest for ExampleDB |
| `components/3-postgres-exporter.toml` | Helm chart: PostgreSQL metrics exporter |
| `components/4-prometheus.toml` | Helm chart: Prometheus server |
| `components/5-grafana.toml` | Helm chart: Grafana with datasources + dashboards |
| `components/6-certificate.toml` | Terraform module: ACM certificate |
| `components/7-alb.toml` | Helm chart: ALB ingress |
| `components/values/grafana/values.yaml` | Grafana helm values (DB, auth, dashboards, datasources) |
| `components/values/postgres-exporter/values.yaml` | Postgres exporter helm values |
| `components/values/prometheus/values.yaml` | Prometheus helm values |
| `actions/grafana_rds_creds.toml` | Post-deploy: copy RDS secret to k8s secret |
| `actions/exampledb_rds_creds.toml` | Post-deploy: copy RDS secret to k8s (2 namespaces) |
| `actions/gp2-default-storage-class.toml` | Pre-deploy: set gp2 as default storage class |
| `actions/simulate-db-activity.toml` | Manual: generate sample DB load |
| `actions/stop-db-activity.toml` | Manual: stop DB load simulation |
| `actions/healthcheck.toml` | Manual: ALB health check |

### Key Config Snippets

**inputs.toml** -- Multiple input groups for different concerns:
```toml
[[group]]
name         = "grafana"
description  = "Env vars https://github.com/grafana/grafana/releases"
display_name = "Grafana Configuration"

[[input]]
name         = "grafana_release"
description  = "The version of Grafana to deploy"
default      = "12.1.0"
display_name = "Grafana Release Version"
group        = "grafana"

[[input]]
name         = "admin_password"
description  = "Grafana admin password for login"
default      = "admin"
display_name = "Admin Password"
required     = true
sensitive    = true
group        = "grafana"

[[group]]
name         = "database"
description  = "RDS PostgreSQL database configuration"
display_name = "Database Configuration"

[[input]]
name         = "grafana_db_instance_type"
description  = "RDS instance type for Grafana database"
default      = "db.t4g.micro"
display_name = "Grafana DB Instance Type"
group        = "database"

[[group]]
name         = "compute"
description  = "Kubernetes node configuration for the EKS cluster."
display_name = "Kubernetes Nodes"

[[input]]
name         = "min_size"
description  = "Minimum number of nodes to provision in the EKS cluster"
default      = "3"
display_name = "Minimum Node Count"
group        = "compute"
```

**sandbox.tfvars** -- Templated values from inputs (note: no quotes around template expressions in .tfvars):
```hcl
additional_namespaces = ["grafana", "exampledb"]

min_size             = {{ .nuon.inputs.inputs.min_size }}
max_size             = {{ .nuon.inputs.inputs.max_size }}
desired_size         = {{ .nuon.inputs.inputs.desired_size }}

maintenance_role_eks_access_entry_policy_associations = {
  eks_admin = {
    policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
    access_scope = {
      type = "cluster"
    }
  }
}
```

**component: rds_subnet (terraform_module)** -- Extracting sandbox VPC outputs with index:
```toml
name              = "rds_subnet"
type              = "terraform_module"
terraform_version = "1.11.3"

[public_repo]
repo      = "nuonco/components"
directory = "aws/rds-subnet"
branch    = "main"

[vars]
install_id              = "{{ .nuon.install.id }}"
rds_subnet_name         = "rds-subnet-grafana-{{ .nuon.install.id }}"
rds_subnet_display_name = "Grafana RDS Subnet {{ .nuon.install.id }}"
region             = "{{ .nuon.sandbox.outputs.account.region }}"
private_subnet_ids = "{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 0}},{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 1 }},{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 2 }}"
```

**component: rds_cluster (terraform_module)** -- Wiring component output as input to another component, with drift detection:
```toml
name              = "rds_cluster_grafana"
type              = "terraform_module"
terraform_version = "1.11.3"

drift_schedule = "0 0 * * *"

[public_repo]
repo      = "nuonco/example-app-configs"
directory = "grafana/src/components/rds_cluster"
branch    = "main"

[vars]
identifier      = "grafana-{{ .nuon.install.id }}"
port            = "5432"
db_name         = "grafana"
db_user         = "grafana"
instance_class  = "{{ .nuon.install.inputs.grafana_db_instance_type }}"
subnet_group_id = "{{ .nuon.components.rds_subnet.outputs.id }}"
region          = "{{ .nuon.install_stack.outputs.region }}"
vpc_id          = "{{ .nuon.install_stack.outputs.vpc_id }}"
subnet_ids      = "{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 0}},{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 1 }},{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 2 }}"
nuon_id         = "{{ .nuon.install.id }}"
```

**component: kubernetes_manifest** -- Creating namespaces that depend on infrastructure being ready:
```toml
name         = "grafana_secrets"
type         = "kubernetes_manifest"
dependencies = ["rds_cluster_grafana"]

namespace = "grafana"
manifest  = """
apiVersion: v1
kind: Namespace
metadata:
  name: grafana
"""
```

**component: grafana (helm_chart via helm_repo)** -- Using a public Helm repository instead of a Git repo:
```toml
name           = "grafana"
type           = "helm_chart"
chart_name     = "grafana"
namespace      = "grafana"
storage_driver = "configmap"
dependencies   = ["prometheus", "grafana_secrets", "exampledb_secrets", "rds_cluster_grafana", "rds_cluster_exampledb"]

[helm_repo]
repo_url = "https://grafana.github.io/helm-charts"
chart    = "grafana"

[[values_file]]
contents = "./values/grafana/values.yaml"
```

**values/grafana/values.yaml** -- Template expressions inside Helm values files. References component outputs and inputs:
```yaml
env:
  GF_SECURITY_ADMIN_USER: "{{ .nuon.inputs.inputs.admin_user }}"
  GF_SECURITY_ADMIN_PASSWORD: "{{ .nuon.inputs.inputs.admin_password }}"
  GF_ENTERPRISE_LICENSE_TEXT: "{{ .nuon.inputs.inputs.enterprise_license_key }}"

image:
  repository: grafana/grafana
  tag: "{{ .nuon.inputs.inputs.grafana_release }}"

datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: ExampleDB PostgreSQL
      type: postgres
      url: "{{ .nuon.components.rds_cluster_exampledb.outputs.address }}:5432"
      database: exampledb
      user: exampledb
```

**action: post-deploy-component trigger** -- Runs automatically after a specific component deploys:
```toml
name    = "grafana_rds_creds"
timeout = "1m"

[[triggers]]
type           = "post-deploy-component"
component_name = "rds_cluster_grafana"

[[triggers]]
type = "manual"

[[steps]]
name    = "Copy RDS Secret for Grafana"
command = "./rds_secrets/import.sh"

[steps.public_repo]
repo      = "nuonco/example-app-configs"
directory = "grafana/src/actions"
branch    = "main"

[steps.env_vars]
SECRET_ARN       = "{{ .nuon.components.rds_cluster_grafana.outputs.db_instance_master_user_secret_arn }}"
REGION           = "{{ .nuon.install_stack.outputs.region }}"
TARGET_NAME      = "grafana-db-secret"
TARGET_NAMESPACE = "grafana"
DB_ADDRESS       = "{{ .nuon.components.rds_cluster_grafana.outputs.address }}"
DB_PORT          = "{{ .nuon.components.rds_cluster_grafana.outputs.db_instance_port }}"
DB_NAME          = "{{ .nuon.components.rds_cluster_grafana.outputs.db_instance_name }}"
```

**action: pre-deploy-component trigger** -- Runs before a component deploys:
```toml
name    = "default_storage_class"
timeout = "1m"

[[triggers]]
type           = "pre-deploy-component"
component_name = "rds_subnet"

[[triggers]]
type = "manual"

[[steps]]
name    = "make_gp2_default_storage_class"
inline_contents = """
#!/usr/bin/env sh
kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
"""
```

### What Makes This Pattern Different

- **Numbered component files** (0-, 1-, 2-, ...) indicating deployment order and logical tiers.
- **Same Terraform module reused** for multiple RDS instances (both `1-rds_cluster_grafana.toml` and `1-rds_cluster_exampledb.toml` point to the same `grafana/src/components/rds_cluster` directory).
- **kubernetes_manifest type** used to create namespaces as dependency gates.
- **helm_repo block** (for Grafana chart) vs `public_repo` (for community charts). Two ways to source Helm charts.
- **Post-deploy-component actions** that bridge infrastructure outputs to Kubernetes secrets.
- **Templated values in .yaml files.** Nuon renders Go templates inside Helm values files too.
- **drift_schedule** on database components for daily drift detection.
- **Multiple input groups** (grafana, database, compute) giving the customer fine-grained control.
- **Templated sandbox.tfvars** where node sizing comes from customer inputs.

---

## Pattern: AWS Lambda

**When to use:** Deploying serverless applications that do not require Kubernetes. Uses Docker build for the Lambda container image, DynamoDB for storage, and API Gateway for HTTPS access. This pattern demonstrates the non-EKS sandbox (`aws-min-sandbox`).

### Architecture Diagram

```
                        Customer's AWS Account
                        +----------------------------------------------------+
                        |                                                    |
  CloudFormation Stack  |  Runner (EC2 ASG)                                  |
  (VPC + Runner)        |    |                                               |
                        |    v                                               |
                        |  Minimal Sandbox (nuonco/aws-min-sandbox)          |
                        |    |                                               |
                        |    +-- 0-docker-image (docker_build)               |
                        |    |     Builds container from Dockerfile          |
                        |    |                                               |
                        |    +-- 1-dynamodb-table (terraform_module)         |
                        |    |     Creates DynamoDB table for app data       |
                        |    |                                               |
                        |    +-- 2-lambda-function (terraform_module)        |
                        |    |     Lambda using docker image + DynamoDB ARN  |
                        |    |     depends on: dynamodb_table                |
                        |    |                                               |
                        |    +-- 3-certificate (terraform_module)            |
                        |    |     ACM certificate for custom domain         |
                        |    |                                               |
                        |    +-- 4-api-gateway (terraform_module)            |
                        |          HTTP API Gateway with custom domain       |
                        |          wires: certificate + lambda function      |
                        +----------------------------------------------------+
```

### Complete File Listing

| File | Purpose |
|------|---------|
| `metadata.toml` | App identity |
| `inputs.toml` | Customer inputs: domain, sub_domain (grouped under "dns") |
| `sandbox.toml` | Minimal sandbox (`nuonco/aws-min-sandbox`) -- no EKS |
| `sandbox.tfvars` | Empty (no extra sandbox vars needed) |
| `stack.toml` | AWS CloudFormation nested stack |
| `runner.toml` | Standard AWS runner config |
| `break_glass.toml` | Emergency access role |
| `policies.toml` | Kubernetes cluster policies (present even without EKS) |
| `permissions/provision.toml` | Provision IAM role |
| `permissions/maintenance.toml` | Maintenance IAM role |
| `permissions/deprovision.toml` | Deprovision IAM role |
| `components/0-docker-image.toml` | Docker build: builds Lambda container image |
| `components/1-dynamodb-table.toml` | Terraform module: DynamoDB table |
| `components/2-lambda-function.toml` | Terraform module: Lambda function |
| `components/3-certificate.toml` | Terraform module: ACM certificate |
| `components/4-api-gateway.toml` | Terraform module: API Gateway + custom domain |

### Key Config Snippets

**sandbox.toml** -- Minimal sandbox (no EKS):
```toml
terraform_version = "1.11.4"

[public_repo]
directory = "."
repo      = "nuonco/aws-min-sandbox"
branch    = "main"

[vars]
enable_nuon_dns      = "true"
public_root_domain   = "{{ .nuon.install.id }}.{{.nuon.inputs.inputs.domain}}"
internal_root_domain = "internal.{{ .nuon.install.id }}.{{.nuon.inputs.inputs.domain}}"

[[var_file]]
contents = "./sandbox.tfvars"
```

**component: docker_build** -- Builds a Docker image from a Dockerfile in the repo:
```toml
name   = "docker_image"
type = "docker_build"

dockerfile = "Dockerfile"

[public_repo]
repo      = "nuonco/example-app-configs"
directory = "aws-lambda/src/components/api"
branch    = "main"
```

**component: lambda_function** -- Wiring docker_build output and dynamodb_table output:
```toml
name              = "lambda_function"
type              = "terraform_module"
terraform_version = "1.11.4"
dependencies      = ["dynamodb_table"]

[public_repo]
repo      = "nuonco/example-app-configs"
directory = "aws-lambda/src/components/lambda-function"
branch    = "main"

[vars]
install_id         = "{{.nuon.install.id}}"
region             = "{{.nuon.sandbox.outputs.account.region}}"
function_name      = "widgets-{{.nuon.install.id}}"
image_uri          = "{{.nuon.components.docker_image.outputs.image.repository}}:{{.nuon.components.docker_image.outputs.image.tag}}"
dynamodb_table_arn = "{{.nuon.components.dynamodb_table.outputs.dynamodb_table_arn}}"
```

**component: api_gateway** -- Wiring certificate and lambda outputs:
```toml
name              = "api_gateway"
type              = "terraform_module"
terraform_version = "1.11.4"

[public_repo]
repo      = "nuonco/example-app-configs"
directory = "aws-lambda/src/components/api-gateway"
branch    = "main"

[vars]
install_id                  = "{{.nuon.install.id}}"
region                      = "{{.nuon.install_stack.outputs.region}}"
name                        = "{{.nuon.inputs.inputs.sub_domain}}"
domain_name                 = "{{.nuon.install.sandbox.outputs.nuon_dns.public_domain.name }}"
domain_name_certificate_arn = "{{.nuon.components.certificate.outputs.public_domain_certificate_arn}}"
lambda_function_arn         = "{{.nuon.components.lambda_function.outputs.lambda_function.lambda_function_arn}}"
zone_id                     = "{{.nuon.install.sandbox.outputs.nuon_dns.public_domain.zone_id}}"
```

### What Makes This Pattern Different

- **No Kubernetes.** Uses `nuonco/aws-min-sandbox` instead of `nuonco/aws-eks-sandbox`.
- **docker_build component type.** Nuon builds the container image; the output provides `image.repository` and `image.tag`.
- **All terraform_module components** (besides the docker build). No helm_chart or kubernetes_manifest.
- **No actions.** Simple enough that post-provision automation is unnecessary.
- **No values files.** All configuration is done through `[vars]` in the component TOML.
- **Linear dependency chain.** Each component only depends on the one before it or has no dependencies.

---

## Common Patterns

### File Naming Convention

Components use numbered prefixes with dash-separated names to indicate deployment order:

```
components/
  0-rds_subnet.toml              # Tier 0: shared infrastructure
  1-rds_cluster_grafana.toml     # Tier 1: databases
  1-rds_cluster_exampledb.toml   # Tier 1: databases (same tier = parallel eligible)
  2-grafana-secrets.toml         # Tier 2: namespace/secret setup
  2-exampledb-secrets.toml       # Tier 2: namespace/secret setup
  3-postgres-exporter.toml       # Tier 3: monitoring agents
  4-prometheus.toml              # Tier 4: monitoring aggregation
  5-grafana.toml                 # Tier 5: application
  6-certificate.toml             # Tier 6: TLS
  7-alb.toml                     # Tier 7: ingress
```

Rules:
- The number prefix indicates the logical deployment tier, not strict ordering.
- Components at the same number can potentially deploy in parallel (if dependencies allow).
- Use underscores in the component `name` field (e.g., `rds_cluster_grafana`).
- Use dashes in the file name (e.g., `1-rds_cluster_exampledb.toml`). The file name is for human readability; the `name` field is what matters for dependency references.
- Simple apps (like eks-simple) may skip numbering entirely.

### Dependency Wiring

Components reference each other's outputs using Go template expressions. The key patterns:

**Component outputs:**
```
{{.nuon.components.<component_name>.outputs.<output_key>}}
```

**Nested component outputs:**
```
{{.nuon.components.<component_name>.outputs.<parent>.<child>}}
```

**Sandbox outputs:**
```
{{.nuon.install.sandbox.outputs.<output_path>}}
{{.nuon.sandbox.outputs.<output_path>}}
```

**Stack outputs:**
```
{{.nuon.install_stack.outputs.<output_key>}}
```

**Customer inputs:**
```
{{.nuon.inputs.inputs.<input_name>}}
{{.nuon.install.inputs.<input_name>}}
```

**Install metadata:**
```
{{.nuon.install.id}}
```

**Cloud account info:**
```
{{.nuon.cloud_account.aws.region}}
```

**Indexing arrays:**
```
{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 0 }}
```

Common wiring examples from the canonical configs:

| Source | Template Expression | Used In |
|--------|-------------------|---------|
| Certificate ARN | `{{.nuon.components.certificate.outputs.public_domain_certificate_arn}}` | ALB component |
| RDS endpoint | `{{.nuon.components.rds_cluster_grafana.outputs.address}}` | Helm values, actions |
| RDS secret ARN | `{{.nuon.components.rds_cluster_grafana.outputs.db_instance_master_user_secret_arn}}` | Actions |
| Docker image URI | `{{.nuon.components.docker_image.outputs.image.repository}}:{{.nuon.components.docker_image.outputs.image.tag}}` | Lambda function |
| DynamoDB table ARN | `{{.nuon.components.dynamodb_table.outputs.dynamodb_table_arn}}` | Lambda function |
| DNS zone ID | `{{.nuon.install.sandbox.outputs.nuon_dns.public_domain.zone_id}}` | Certificate, API GW |
| DNS domain name | `{{.nuon.install.sandbox.outputs.nuon_dns.public_domain.name}}` | Certificate, ALB |
| VPC private subnets | `{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 0 }}` | RDS subnet |
| AWS region | `{{.nuon.install_stack.outputs.region}}` | Most terraform components |
| VPC ID | `{{.nuon.install_stack.outputs.vpc_id}}` | RDS cluster |
| Component subnet output | `{{.nuon.components.rds_subnet.outputs.id}}` | RDS cluster |
| Lambda function ARN | `{{.nuon.components.lambda_function.outputs.lambda_function.lambda_function_arn}}` | API Gateway |

### Input Organization

Inputs are organized into groups by concern. Each group gets a `[[group]]` declaration, then each `[[input]]` references the group name.

**Standard input groups by app type:**

| Group | When to Use | Example Inputs |
|-------|-------------|----------------|
| `dns` | Any app with a public endpoint | domain, sub_domain |
| `compute` | Apps on EKS | kubernetes_version, instance_type, min_size, max_size, desired_size |
| `database` | Apps with RDS or other managed DB | db_instance_type, allocated_storage |
| App-specific (e.g., `grafana`) | App configuration | release version, admin credentials, license keys |

**Input field reference:**

```toml
[[input]]
name         = "admin_password"      # Snake_case name, referenced in templates
description  = "Grafana admin..."    # Shown in UI
default      = "admin"               # Default value (string)
display_name = "Admin Password"      # Human-readable label
required     = true                  # Whether customer must provide a value
sensitive    = true                  # Masks the value in UI
group        = "grafana"             # Which group this belongs to
```

### Sandbox Configuration

The sandbox is the foundational infrastructure (VPC, EKS cluster, DNS, etc.) provisioned in the customer's account.

**EKS sandbox (most common):**
```toml
terraform_version = "1.11.3"

[public_repo]
directory = "."
repo      = "nuonco/aws-eks-sandbox"
branch    = "main"

[vars]
cluster_name         = "n-{{.nuon.install.id}}"
enable_nuon_dns      = "true"
public_root_domain   = "{{ .nuon.install.id }}.{{.nuon.inputs.inputs.domain}}"
internal_root_domain = "internal.{{ .nuon.install.id }}.{{.nuon.inputs.inputs.domain}}"

[[var_file]]
contents = "./sandbox.tfvars"
```

**Minimal sandbox (serverless / non-EKS):**
```toml
terraform_version = "1.11.4"

[public_repo]
directory = "."
repo      = "nuonco/aws-min-sandbox"
branch    = "main"

[vars]
enable_nuon_dns      = "true"
public_root_domain   = "{{ .nuon.install.id }}.{{.nuon.inputs.inputs.domain}}"
internal_root_domain = "internal.{{ .nuon.install.id }}.{{.nuon.inputs.inputs.domain}}"

[[var_file]]
contents = "./sandbox.tfvars"
```

**Standard sandbox.tfvars entries:**

| Variable | Purpose | Example |
|----------|---------|---------|
| `additional_namespaces` | K8s namespaces to pre-create | `["grafana", "exampledb"]` |
| `min_size` / `max_size` / `desired_size` | Node group sizing | `2` / `3` / `2` |
| `maintenance_role_eks_access_entry_policy_associations` | RBAC for maintenance role | EKSAdminPolicy, EKSClusterAdminPolicy |
| `maintenance_cluster_role_rules_override` | K8s ClusterRole rules for maintenance | `[{"apiGroups": ["*"], ...}]` |

### Stack Configuration

The stack creates the VPC and runner in the customer's account. Currently only AWS CloudFormation is supported.

```toml
type        = "aws-cloudformation"
name        = "nuon-<appname>-{{.nuon.install.id}}"
description = "QuickLink to install runner for <app>: Install {{.nuon.install.id}}"

vpc_nested_template_url    = "https://nuon-artifacts.s3.us-west-2.amazonaws.com/aws-cloudformation-templates/v0.1.12/vpc/eks/default/stack.yaml"
runner_nested_template_url = "https://nuon-artifacts.s3.us-west-2.amazonaws.com/aws-cloudformation-templates/v0.1.12/runner/asg/stack.yaml"
```

The template URLs are versioned Nuon-maintained CloudFormation templates. Use the latest version from the examples.

### Permissions: The 3-Role Model

Every app config defines three IAM roles in the `permissions/` directory:

**1. Provision role** (`permissions/provision.toml`):
- Used during initial infrastructure and component deployment.
- Typically grants broad access (AdministratorAccess with boundary).
- Permissions boundary can be permissive for initial setup.

```toml
type = "provision"
name = "{{.nuon.install.id}}-provision"
description = "provision the sandbox and components; trigger actions."
display_name = "provision role"
permissions_boundary = "./provision_boundary.json"

[[policies]]
managed_policy_name = "AdministratorAccess"
```

**2. Maintenance role** (`permissions/maintenance.toml`):
- Used for day-2 operations: actions, component updates, drift remediation.
- Should be the most tightly scoped role.
- Add inline policies for specific needs (e.g., scoped SecretsManager access).

```toml
type = "maintenance"
name = "{{ .nuon.install.id }}-maintenance"
description = "operate and remediate the app's components and use actions."
display_name = "maintenance role"
permissions_boundary = "./maintenance_boundary.json"

[[policies]]
managed_policy_name = "AdministratorAccess"

[[policies]]
name = "{{ .nuon.install.id }}-limited-secrets-manage-rds"
contents = """
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSecretsManagerReadScoped",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:CreateSecret",
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:{{ .nuon.cloud_account.aws.region }}::secret:rds!*",
            "Condition": {
                "StringEquals": {
                    "aws:ResourceTag/install.nuon.co/id": "{{ .nuon.install.id }}"
                }
            }
        }
    ]
}
"""
```

**3. Deprovision role** (`permissions/deprovision.toml`):
- Used during teardown of components and sandbox.
- Typically mirrors provision permissions.

```toml
type = "deprovision"
name = "{{.nuon.install.id}}-deprovision"
description = "deprovision sandbox and components."
display_name = "deprovision role"
permissions_boundary = "./deprovision_boundary.json"

[[policies]]
managed_policy_name = "AdministratorAccess"
```

**Permissions boundaries** are JSON files that set the maximum possible permissions for each role. The maintenance boundary is typically the most restrictive (e.g., denying S3 object access):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCommonActions",
      "Effect": "Allow",
      "Action": ["cloudwatch:*", "ec2:*", "eks:*", "iam:*", "rds:*", "s3:*",
                 "ecr:*", "acm:*", "Route53:*", "kms:*", "elasticloadbalancing:*"],
      "Resource": "*"
    },
    {
      "Sid": "DenyS3ObjectActions",
      "Effect": "Deny",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "*"
    }
  ]
}
```

**Break glass roles** (`break_glass.toml`) provide emergency access with broad permissions minus sensitive operations:

```toml
[[role]]
name                 = "{{.nuon.install.id}}-<app>-sandbox-break-glass"
description          = "grants access to the sandbox for install {{.nuon.install.id}}."
display_name         = "break glass role"
permissions_boundary = ""

[[role.policies]]
managed_policy_name = "AdministratorAccess"

[[role.policies]]
name = "remove-secrets-manager"
contents = """
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenySecretsManagerAccess",
            "Effect": "Deny",
            "Action": ["secretsmanager:*"],
            "Resource": "*"
        }
    ]
}
"""
```

### Actions

Actions are shell scripts that run on the runner. They have three trigger types and can have multiple steps.

**Trigger types:**

| Trigger | When it Runs | Use Case |
|---------|-------------|----------|
| `manual` | On-demand via UI or API | Diagnostics, restarts |
| `post-provision` | After all components deploy | Initial secrets, data seeding |
| `post-deploy-component` | After a specific component deploys | Bridge infra outputs to k8s secrets |
| `pre-deploy-component` | Before a specific component deploys | Prerequisite setup |

**Step types:**

1. **Inline script** -- Shell script embedded in TOML:
```toml
[[steps]]
name    = "status"
inline_contents = """
#!/usr/bin/env sh
set -e
kubectl get -n whoami deployments
response=`kubectl get -n whoami deployments -o json | jq -c`
echo $response >> $NUON_ACTIONS_OUTPUT_FILEPATH
"""
```

2. **Script from repo** -- References a script in a Git repository:
```toml
[[steps]]
name    = "Copy RDS Secret"
command = "./rds_secrets/import.sh"

[steps.public_repo]
repo      = "nuonco/example-app-configs"
directory = "grafana/src/actions"
branch    = "main"

[steps.env_vars]
SECRET_ARN = "{{ .nuon.components.rds_cluster_grafana.outputs.db_instance_master_user_secret_arn }}"
REGION     = "{{ .nuon.install_stack.outputs.region }}"
```

3. **Script file reference** -- References a local file for the inline_contents:
```toml
[[steps]]
name = "elbv2"
inline_contents = "./src/alb/elbv2.sh"

[steps.env_vars]
INGRESS_NAME      = "{{.nuon.install.id}}-public"
INGRESS_NAMESPACE = "whoami"
```

**Action outputs:** Steps can write JSON to `$NUON_ACTIONS_OUTPUT_FILEPATH` to make structured data available after execution.

**Multi-step actions** run steps sequentially. Each step can have its own env_vars and repo:
```toml
name    = "deployment_restart"
timeout = "45s"

[[triggers]]
type = "manual"

[[steps]]
name    = "restart"
inline_contents = """..."""

[[steps]]
name    = "status"
inline_contents = """..."""
```

---

## Decision Framework

### When to Use helm_chart vs terraform_module

| Use `helm_chart` when... | Use `terraform_module` when... |
|---------------------------|--------------------------------|
| Deploying to Kubernetes (EKS) | Provisioning AWS/cloud infrastructure |
| The app has an existing Helm chart | Managing RDS, DynamoDB, Lambda, ACM, etc. |
| You need Helm values templating | You need Terraform state management |
| Deploying sidecars, exporters, agents | Creating IAM roles, security groups, subnets |
| The app runs as pods/services | The resource is a cloud-provider managed service |

**Helm chart source options:**

1. `[public_repo]` -- A Git repository containing the chart:
```toml
[public_repo]
repo      = "nuonco/example-app-configs"
directory = "eks-simple/src/components/whoami"
branch    = "main"
```

2. `[helm_repo]` -- A Helm registry URL:
```toml
[helm_repo]
repo_url = "https://grafana.github.io/helm-charts"
chart    = "grafana"
```

Use `[public_repo]` when you maintain the chart or need to pin to a Git commit. Use `[helm_repo]` when consuming a well-known public chart.

**Helm values options:**

1. `[values]` -- Inline key-value pairs (good for small configs, dependency wiring):
```toml
[values]
domain_certificate = "{{.nuon.components.certificate.outputs.public_domain_certificate_arn}}"
service_port       = "80"
```

2. `[[values_file]]` -- External YAML file (good for complex configs):
```toml
[[values_file]]
contents = "./values/grafana/values.yaml"
```

You can use both in the same component. Template expressions work in both.

### When to Use docker_build vs container_image

| Use `docker_build` when... | Use `container_image` when... |
|-----------------------------|-------------------------------|
| You have a Dockerfile in a repo | The image is already published to a registry |
| The image needs to be built per-install | You just need to reference an existing tag |
| Deploying to Lambda (container-based) | Deploying a public Docker Hub image to K8s |
| You need the build output (repo + tag) wired to other components | The image tag is static or controlled by an input |

`docker_build` outputs are accessed via:
```
{{.nuon.components.<name>.outputs.image.repository}}
{{.nuon.components.<name>.outputs.image.tag}}
```

For Kubernetes deployments using a public image, just set the image in Helm values:
```yaml
image:
  repository: traefik/whoami
  tag: "latest"
```

### How to Decide What Becomes a Customer Input vs Hardcoded Default

**Make it a customer input when:**
- The customer has a legitimate reason to customize it (instance size, version, domain).
- Different installs will have different values.
- It affects cost or compliance (node count, DB instance type).
- It is a credential or secret (`sensitive = true`).

**Hardcode it when:**
- It is an implementation detail the customer should not change (port numbers, chart names).
- It is a Nuon convention (install ID in resource names, DNS patterns).
- Changing it would break the deployment.
- It is an internal wiring value (subnet IDs, certificate ARNs from other components).

**Examples from canonical configs:**

| Input (customer-facing) | Hardcoded |
|--------------------------|-----------|
| `domain` (nuon.run) | `cluster_name = "n-{{.nuon.install.id}}"` |
| `grafana_release` (12.1.0) | `port = "5432"` |
| `instance_type` (t3a.medium) | `storage_driver = "configmap"` |
| `admin_password` (sensitive) | `healthcheck_path = "/health"` |
| `min_size` / `max_size` | `enable_nuon_dns = "true"` |
| `grafana_db_instance_type` | `db_name = "grafana"` |

### How to Structure Dependencies Between Components

**Rule 1: Only declare dependencies when a component needs another's outputs.**
If component B references `{{.nuon.components.A.outputs.x}}`, then B must list A in its `dependencies` array.

**Rule 2: Dependencies are by component name, not file name.**
```toml
# In 2-lambda-function.toml
dependencies = ["dynamodb_table"]  # References the name field, not the file name
```

**Rule 3: Components without dependencies deploy in parallel (within the same tier).**
The `1-rds_cluster_grafana.toml` and `1-rds_cluster_exampledb.toml` are at the same tier but `exampledb` has `dependencies = ["rds_cluster_grafana"]` to serialize them (sharing the same Terraform module can cause conflicts).

**Rule 4: Fan-in dependencies are allowed.**
A single component can depend on many:
```toml
dependencies = ["prometheus", "grafana_secrets", "exampledb_secrets", "rds_cluster_grafana", "rds_cluster_exampledb"]
```

**Rule 5: The dependency graph must be a DAG (no cycles).**

**Common dependency patterns:**

```
Pattern: Linear Chain (Lambda)
  docker_image --> dynamodb_table --> lambda_function --> certificate --> api_gateway

Pattern: Fan-out/Fan-in (Grafana)
  rds_subnet --> rds_cluster_grafana  --> grafana_secrets --+
             \-> rds_cluster_exampledb -> exampledb_secrets -+--> grafana --> alb
                                      \-> postgres_exporter --> prometheus -/

Pattern: Flat (EKS Simple)
  certificate (no deps)
  whoami      (no deps)
  alb         (depends on whoami)
```

### Choosing the Right Sandbox

| Sandbox | Repo | When to Use |
|---------|------|-------------|
| EKS Sandbox | `nuonco/aws-eks-sandbox` | Apps that deploy Helm charts or Kubernetes manifests |
| Minimal Sandbox | `nuonco/aws-min-sandbox` | Serverless apps (Lambda, Fargate), pure Terraform infrastructure |

Both sandboxes provide:
- VPC networking
- DNS (Route53 zones) when `enable_nuon_dns = "true"`

The EKS sandbox additionally provides:
- EKS cluster with managed node groups
- Karpenter for autoscaling
- Pre-created namespaces
- RBAC roles for maintenance

### Component Type Quick Reference

| Type | Source Block | Outputs | Use Case |
|------|------------|---------|----------|
| `terraform_module` | `[public_repo]` with `[vars]` | Terraform outputs | Cloud infra (RDS, Lambda, DynamoDB, ACM, API GW) |
| `helm_chart` | `[public_repo]` or `[helm_repo]` with `[values]` or `[[values_file]]` | Helm release status | K8s apps (web services, monitoring, databases) |
| `docker_build` | `[public_repo]` with `dockerfile` | `image.repository`, `image.tag` | Building container images |
| `kubernetes_manifest` | Inline `manifest` field | K8s resource status | Namespaces, CRDs, one-off resources |

### Template Expression Quick Reference

| Expression | Returns | Example Value |
|------------|---------|---------------|
| `{{.nuon.install.id}}` | Unique install identifier | `abc123` |
| `{{.nuon.inputs.inputs.<name>}}` | Customer input value | `nuon.run` |
| `{{.nuon.install.inputs.<name>}}` | Customer input value (alternate path) | `db.t4g.micro` |
| `{{.nuon.install_stack.outputs.region}}` | AWS region from CF stack | `us-west-2` |
| `{{.nuon.install_stack.outputs.vpc_id}}` | VPC ID from CF stack | `vpc-0abc123` |
| `{{.nuon.sandbox.outputs.account.region}}` | Region from sandbox outputs | `us-west-2` |
| `{{.nuon.install.sandbox.outputs.nuon_dns.public_domain.zone_id}}` | Route53 zone ID | `Z0123456` |
| `{{.nuon.install.sandbox.outputs.nuon_dns.public_domain.name}}` | Public domain name | `abc123.nuon.run` |
| `{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 0 }}` | First private subnet | `subnet-0abc` |
| `{{.nuon.components.<name>.outputs.<key>}}` | Component output | (varies) |
| `{{.nuon.cloud_account.aws.region}}` | Cloud account region | `us-west-2` |

### Generating a New App Config: Checklist

1. Create `metadata.toml` with version, display_name, description, readme.
2. Identify customer inputs. Group them by concern. Write `inputs.toml`.
3. Choose sandbox type (EKS or minimal). Write `sandbox.toml` and `sandbox.tfvars`.
4. Write `stack.toml` with the CloudFormation template URLs.
5. Write `runner.toml` with standard AWS runner config.
6. Map your application to components:
   - Infrastructure (DB, storage, networking) -> `terraform_module`
   - Kubernetes apps -> `helm_chart`
   - Container images to build -> `docker_build`
   - K8s namespaces/resources -> `kubernetes_manifest`
7. Number component files by deployment tier. Wire dependencies.
8. Create `values/` directory for complex Helm values files.
9. Write permissions (provision, maintenance, deprovision) with boundaries.
10. Write `break_glass.toml` for emergency access.
11. Write `policies.toml` for cluster policies.
12. Add actions for post-provision setup, health checks, and operational tasks.
13. Create `secrets.toml` (can be empty placeholder).
