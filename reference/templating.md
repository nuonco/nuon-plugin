# Nuon Template Variables Reference

Nuon uses Go template syntax (`{{ }}`) in TOML config files and Helm values files. All templates are rendered at deploy time with the install's context.

## Variable Hierarchy

### Install Context

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{{ .nuon.install.id }}` | Unique install identifier | `ins2kLm0ZQ` |
| `{{ .nuon.org.id }}` | Organization ID | `org2kLm0ZQ` |
| `{{ .nuon.app.id }}` | App ID | `app2kLm0ZQ` |

### Customer Inputs

Defined in `inputs.toml`, referenced as:

```
{{ .nuon.inputs.inputs.<input_name> }}
```

Examples:
```
{{ .nuon.inputs.inputs.root_domain }}
{{ .nuon.inputs.inputs.db_instance_type }}
{{ .nuon.inputs.inputs.admin_password }}
{{ .nuon.inputs.inputs.replica_count }}
```

In Helm values files, use the alternate form:
```
{{ .nuon.install.inputs.<input_name> }}
```

### Install Stack Outputs

Values from the CloudFormation/Bicep stack deployed in the customer's account:

| Variable | Description |
|----------|-------------|
| `{{ .nuon.install_stack.outputs.region }}` | AWS region of the install |
| `{{ .nuon.install_stack.outputs.account_id }}` | AWS account ID |
| `{{ .nuon.install_stack.outputs.vpc_id }}` | VPC ID (if stack creates one) |
| `{{ .nuon.install_stack.outputs.resource_group_name }}` | Azure resource group (Azure only) |

### Sandbox Outputs

Values from the sandbox Terraform module (base infrastructure):

| Variable | Description |
|----------|-------------|
| `{{ .nuon.install.sandbox.outputs.account.id }}` | AWS account ID |
| `{{ .nuon.install.sandbox.outputs.account.region }}` | AWS region |
| `{{ .nuon.install.sandbox.outputs.vpc.id }}` | VPC ID |
| `{{ .nuon.install.sandbox.outputs.vpc.private_subnet_ids }}` | Private subnet IDs (array) |
| `{{ .nuon.install.sandbox.outputs.vpc.public_subnet_ids }}` | Public subnet IDs (array) |
| `{{ .nuon.install.sandbox.outputs.cluster.cluster_name }}` | EKS cluster name |
| `{{ .nuon.install.sandbox.outputs.cluster.cluster_endpoint }}` | EKS API endpoint |
| `{{ .nuon.install.sandbox.outputs.ecr.repository_url }}` | ECR repo URL |
| `{{ .nuon.install.sandbox.outputs.ecr.registry_url }}` | ECR registry URL |
| `{{ .nuon.install.sandbox.outputs.nuon_dns.public_domain.name }}` | Public DNS domain |
| `{{ .nuon.install.sandbox.outputs.nuon_dns.public_domain.zone_id }}` | Route53 zone ID |
| `{{ .nuon.install.sandbox.outputs.nuon_dns.internal_domain.name }}` | Internal DNS domain |
| `{{ .nuon.install.sandbox.outputs.namespaces }}` | Created K8s namespaces |

Short form (used in some contexts):
```
{{ .nuon.sandbox.outputs.account.region }}
{{ .nuon.sandbox.outputs.vpc.id }}
```

Array indexing for subnets:
```
{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 0 }}
{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 1 }}
{{ index .nuon.sandbox.outputs.vpc.private_subnet_ids 2 }}
```

### Component Outputs

Reference outputs from other components:

```
{{ .nuon.components.<component_name>.outputs.<output_field> }}
```

Common patterns:

**Docker image references:**
```
{{ .nuon.components.docker_image.outputs.image.repository }}
{{ .nuon.components.docker_image.outputs.image.tag }}

# Combined URI:
{{ .nuon.components.docker_image.outputs.image.repository }}:{{ .nuon.components.docker_image.outputs.image.tag }}
```

**Terraform module outputs:**
```
{{ .nuon.components.rds_cluster.outputs.address }}
{{ .nuon.components.rds_cluster.outputs.port }}
{{ .nuon.components.dynamodb_table.outputs.dynamodb_table_arn }}
{{ .nuon.components.certificate.outputs.public_domain_certificate_arn }}
```

**Helm chart outputs:**
```
{{ .nuon.components.whoami.outputs.<field> }}
```

### App Variables

Set at the app level, available to all components:

```
{{ .nuon.app.variables.<variable_name> }}
```

## Template Functions

Nuon supports Sprig template functions in README templates:

```
{{ "text" | upper }}
{{ "text" | repeat 3 }}
{{ toPrettyJson .nuon }}
{{ dig "account" "region" "default" .nuon.sandbox.outputs }}
{{ if eq .nuon.install_stack.status "active" }}Active{{ end }}
```

## Usage by File Type

### In TOML config files (sandbox.toml, components/*.toml)

Templates go in string values:
```toml
[vars]
cluster_name = "n-{{ .nuon.install.id }}"
region = "{{ .nuon.install_stack.outputs.region }}"
domain = "{{ .nuon.inputs.inputs.root_domain }}"
```

### In Helm values files (components/values/*.yaml)

Templates go directly in YAML values:
```yaml
image:
  tag: "{{ .nuon.components.docker_image.outputs.image.tag }}"
env:
  DATABASE_HOST: "{{ .nuon.components.postgres.outputs.address }}"
  DOMAIN: "{{ .nuon.inputs.inputs.domain }}"
```

### In stack.toml

```toml
name = "my-app-{{ .nuon.install.id }}"
description = "Install {{ .nuon.install.id }}"
```

### In permissions and break-glass

```toml
name = "{{ .nuon.install.id }}-provision-role"
```

## Common Patterns

**Namespace-scoped install IDs:**
```
n-{{ .nuon.install.id }}
```

**Domain construction:**
```
{{ .nuon.install.id }}.{{ .nuon.inputs.inputs.domain }}
internal.{{ .nuon.install.id }}.{{ .nuon.inputs.inputs.domain }}
{{ .nuon.inputs.inputs.sub_domain }}.{{ .nuon.install.sandbox.outputs.nuon_dns.public_domain.name }}
```

**Resource naming:**
```
widgets-{{ .nuon.install.id }}
grafana-{{ .nuon.install.id }}
```
