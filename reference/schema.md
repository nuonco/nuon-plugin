# Nuon TOML Configuration Schema Reference

Nuon apps are configured using TOML files. Each file type has a comment header (e.g., `# metadata`) that identifies it. Files live in a directory structure under the app root.

## Directory Structure

```
your-app/
  metadata.toml          # App metadata
  inputs.toml            # Customer inputs (or inputs/ directory)
  sandbox.toml           # Infrastructure sandbox
  runner.toml            # Runner configuration
  stack.toml             # CloudFormation stack
  secrets.toml           # Secrets (or secrets/ directory)
  permissions.toml       # IAM permissions (or permissions/ directory)
  policies.toml          # Compliance policies (or policies/ directory)
  break_glass.toml       # Break-glass IAM roles
  installer.toml         # Installer UI configuration
  components/            # Component TOML files
    <name>.toml          # One file per component
  actions/               # Action TOML files
    <name>.toml          # One file per action
  installs/              # Install override files
    <name>.toml          # One file per install
```

## Template Variables

All string fields support Go templating. Common variables:
- `{{.nuon.install.id}}` - Install ID
- `{{.nuon.install.name}}` - Install name
- `{{.nuon.inputs.inputs.<name>}}` - Customer input value
- `{{.nuon.secrets.<name>}}` - Secret metadata (not the value)
- `{{.nuon.sandbox.outputs.<path>}}` - Sandbox Terraform outputs
- `{{.nuon.install.sandbox.outputs.<path>}}` - Alias for sandbox outputs
- `{{.nuon.install_stack.outputs.<path>}}` - CloudFormation stack outputs
- `{{.nuon.components.<name>.outputs.<path>}}` - Component outputs
- `{{.nuon.app.name}}` - App name
- `{{.nuon.app.variables.<name>}}` - App variables

## Shared Types

### PublicRepoConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `repo` | string | Yes | GitHub repo in `org/repo` format |
| `branch` | string | Yes | Branch name |
| `directory` | string | No | Subdirectory within repo |

### ConnectedRepoConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `repo` | string | Yes | GitHub repo in `org/repo` format (must be connected to Nuon) |
| `branch` | string | Yes | Branch name |
| `directory` | string | No | Subdirectory within repo |

### HelmRepoConfig

Used for Helm charts from a Helm repository (not a git repo).

---

# App-Level Files

## metadata.toml

Purpose: App display name, description, and notification settings.

Header comment: `# metadata`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Config file format version (e.g., `"1.0.0"`, `"v2"`) |
| `description` | string | No | App description shown in installer UI |
| `display_name` | string | No | Human-readable app name |
| `slack_webhook_url` | string | No | Slack webhook for deployment notifications |
| `readme` | string | No | Markdown README content or file path (e.g., `"./README.md"`) |

```toml
# metadata
version      = "v2"
description  = "My SaaS Application"
display_name = "My SaaS App"
readme       = "./README.md"
```

## inputs.toml

Purpose: Define customer-configurable inputs shown during installation.

Header comment: `# inputs`

### Input Group (within inputs.toml as `[[group]]`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Group name referenced by inputs |
| `description` | string | Yes | Human-readable description for installer UI |
| `display_name` | string | No | Human-readable name for installer UI |

### Input (within inputs.toml as `[[input]]`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Identifier for template references (`{{.nuon.inputs.inputs.<name>}}`) |
| `display_name` | string | Yes | Human-readable name in installer UI |
| `description` | string | Yes | Explanation shown in installer |
| `group` | string | Yes | Must match a defined group name |
| `default` | any | No | Default value if customer skips |
| `required` | boolean | No | Whether customer must provide a value |
| `sensitive` | boolean | No | Mask value in UI/logs after install creation |
| `type` | string | No | Data type: `"string"`, `"number"`, `"list"`, `"json"`, `"bool"` |
| `internal` | boolean | No | Only settable via admin panel |
| `user_configurable` | boolean | No | Modifiable by end users after installation |

```toml
# inputs
[[group]]
name         = "database"
description  = "Database Configuration"
display_name = "Database Settings"

[[input]]
name         = "db_host"
display_name = "Database Host"
description  = "PostgreSQL hostname"
group        = "database"
default      = "localhost"
type         = "string"
required     = true

[[input]]
name         = "api_key"
display_name = "API Key"
description  = "API key for external service"
group        = "database"
sensitive    = true
type         = "string"
```

Directory-based alternative: Place individual input files in `inputs/` and group files in `input_groups/` (no `[[input]]`/`[[group]]` wrapper needed).

## sandbox.toml

Purpose: Define the infrastructure sandbox (Terraform module for base infra like VPC/EKS).

Header comment: `# sandbox`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `terraform_version` | string | Yes | Terraform version (e.g., `"1.5.0"`, `"latest"`) |
| `connected_repo` | ConnectedRepoConfig | No | Private repo with sandbox Terraform |
| `public_repo` | PublicRepoConfig | No | Public repo with sandbox Terraform |
| `drift_schedule` | string | No | Cron expression for drift detection |
| `env_vars` | object | No | Environment variables for Terraform (key-value map) |
| `vars` | object | No | Terraform input variables (key-value map, supports templating) |
| `var_file` | array | No | External `.tfvars` files to load |

`var_file` entries have a `contents` field pointing to a file path, URL, or git source.

```toml
# sandbox
terraform_version = "1.11.3"

[public_repo]
directory = "."
repo      = "nuonco/aws-eks-sandbox"
branch    = "main"

[vars]
cluster_name         = "n-{{.nuon.install.id}}"
enable_nuon_dns      = "true"
public_root_domain   = "{{.nuon.inputs.inputs.root_domain}}"
internal_root_domain = "internal.{{.nuon.inputs.inputs.root_domain}}"

[[var_file]]
contents = "./sandbox.tfvars"
```

## runner.toml

Purpose: Configure the deployment runner that executes in the customer's environment.

Header comment: `# runner`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `runner_type` | string | Yes | Runner type: `"kubernetes"`, `"docker"`, `"vm"`, `"aws"`, `"azure"` |
| `env_vars` | object | No | Environment variables for the runner |
| `helm_driver` | string | No | Helm storage driver: `"configmap"` or `"secret"` |
| `init_script_url` | string | No | URL to initialization script (HTTP(S), git, file, or `./` relative) |
| `env_var` | array | No | Alternative array format for env vars |

```toml
# runner
runner_type = "aws"
helm_driver = "configmap"
```

## stack.toml

Purpose: Configure the AWS CloudFormation stack for install infrastructure.

Header comment: `# stack`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | No | Stack type (only `"aws-cloudformation"` supported) |
| `name` | string | Yes | CloudFormation stack name (supports templating) |
| `description` | string | Yes | Stack description for CF console (supports templating) |
| `vpc_nested_template_url` | string | No | URL to VPC nested CF template |
| `runner_nested_template_url` | string | No | URL to runner nested CF template |

```toml
# stack
name        = "myapp-{{.nuon.install.id}}"
description = "Infrastructure for MyApp"
runner_nested_template_url = "https://nuon-artifacts.s3.us-west-2.amazonaws.com/aws-cloudformation-templates/v0.1.6/runner/asg/stack.yaml"
```

## secrets.toml

Purpose: Define secrets that customers provide or that are auto-generated.

Header comment: `# secrets`

### Secret (within secrets.toml as `[[secret]]`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Identifier for template references (`{{.nuon.secrets.<name>}}`) |
| `display_name` | string | No | Human-readable name in installer UI |
| `description` | string | Yes | Explanation of the secret |
| `required` | boolean | No | Customer must provide a value |
| `auto_generate` | boolean | No | Auto-generate random value (mutually exclusive with `required`/`default`) |
| `format` | string | No | `"base64"` for base64-encoded, or empty for plain text |
| `default` | string | No | Default value (mutually exclusive with `required`/`auto_generate`) |
| `kubernetes_sync` | boolean | No | Sync to a Kubernetes Secret resource |
| `kubernetes_secret_namespace` | string | No | K8s namespace for synced secret (required if `kubernetes_sync` is true) |
| `kubernetes_secret_name` | string | No | K8s Secret resource name (required if `kubernetes_sync` is true) |

```toml
# secrets
[[secret]]
name         = "github_app_key"
display_name = "GitHub App Key"
description  = "Base64 encoded Github App Key"
required     = true
format       = "base64"
kubernetes_sync             = true
kubernetes_secret_namespace = "control-plane"
kubernetes_secret_name      = "github-app-key"

[[secret]]
name          = "db_password"
display_name  = "Database Password"
description   = "Auto-generated database password"
auto_generate = true
kubernetes_sync             = true
kubernetes_secret_namespace = "app"
kubernetes_secret_name      = "db-password"
```

Directory-based alternative: Place individual secret files in `secrets/` (no `[[secret]]` wrapper needed).

## permissions.toml

Purpose: Define AWS IAM roles for provisioning, maintenance, and deprovisioning.

Header comment: `# permissions`

### File-based format (permissions.toml)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `provision_role` | AppAWSIAMRole | No | IAM role for initial provisioning |
| `deprovision_role` | AppAWSIAMRole | No | IAM role for teardown |
| `maintenance_role` | AppAWSIAMRole | No | IAM role for day-to-day operations |
| `roles` | array | No | Array of role definitions (directory-based format) |

### AppAWSIAMRole fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | IAM role name (supports templating) |
| `description` | string | Yes | Role description |
| `display_name` | string | No | Display name in installer UI |
| `policies` | array | Yes | List of IAM policies |
| `permissions_boundary` | string | No | ARN or file path to permissions boundary policy |

### Policy fields (within a role)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Policy name |
| `contents` | string | No | Inline IAM policy JSON or file reference |
| `managed_policy_name` | string | No | AWS managed policy name (e.g., `"AdministratorAccess"`) |

```toml
# permissions
[provision_role]
name         = "{{.nuon.install.id}}-provision"
description  = "Provisioning role"
display_name = "Provision Role"

[[provision_role.policies]]
managed_policy_name = "AdministratorAccess"

[maintenance_role]
name         = "{{.nuon.install.id}}-maintenance"
description  = "Maintenance role"
display_name = "Maintenance Role"

[[maintenance_role.policies]]
managed_policy_name = "AdministratorAccess"
```

Directory-based alternative: Place individual role files in `permissions/` with a `type` field (`"provision"`, `"maintenance"`, or `"deprovision"`) instead of using `[provision_role]` etc.

```toml
# In permissions/deprovision.toml (no wrapper needed)
type                 = "deprovision"
name                 = "{{.nuon.install.id}}-deprovision"
description          = "deprovision"
display_name         = "deprovision"
permissions_boundary = "./deprovision_boundary.json"

[[policies]]
managed_policy_name = "AdministratorAccess"
```

## policies.toml

Purpose: Define compliance and security policies enforced across infrastructure.

Header comment: `# policies`

### Policy (within policies.toml as `[[policy]]`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | No | Policy type: `"kubernetes_cluster"`, `"terraform_module"`, `"helm_chart"`, `"kubernetes_manifest"`, `"container_image"`, `"sandbox"` |
| `engine` | string | No | Policy engine: `"kyverno"` or `"opa"` |
| `name` | string | No | Policy name |
| `contents` | string | No | Policy document content, file path, or URL |
| `components` | array | No | Target components: `["*"]` for all, or list of component names. Ignored for `"sandbox"` type. |

```toml
# policies
[[policy]]
type       = "container_image"
engine     = "opa"
components = ["*"]
contents   = """
package nuon

default allow := false

allow if {
    input.metadata.signed == true
}
"""
```

Directory-based alternative: Place individual policy files in `policies/` (no `[[policy]]` wrapper needed).

## break_glass.toml

Purpose: Define break-glass IAM roles for emergency/elevated access during actions.

Header comment: varies

### Role (within break_glass.toml as `[[role]]`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | No | Role type for directory-based: `"provision"`, `"maintenance"`, `"deprovision"` |
| `name` | string | Yes | IAM role name (supports templating) |
| `description` | string | Yes | Role description |
| `display_name` | string | No | Display name in installer UI |
| `policies` | array | Yes | List of IAM policies with `name` and `contents` fields |
| `permissions_boundary` | string | No | ARN or file path to permissions boundary |

```toml
[[role]]
name                 = "bucket-operations-break-glass"
description          = "Grants access to the install bucket"
display_name         = "Bucket Operations Break Glass"
permissions_boundary = ""

[[role.policies]]
name = "bucket operations"
contents = """
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "S3Access",
            "Effect": "Allow",
            "Action": ["s3:ListBucket", "s3:GetObject"],
            "Resource": "arn:aws:s3:::{{.nuon.install.id}}-*"
        }
    ]
}
"""
```

## installer.toml

Purpose: Configure the customer-facing installer UI experience.

Header comment: `# installer`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | Installer name |
| `description` | string | No | Installer description |
| `slug` | string | No | URL-safe identifier |
| `apps` | array | No | List of app names to include |
| `documentation_url` | string | No | Link to app documentation |
| `community_url` | string | No | Link to community resources |
| `homepage_url` | string | No | Link to app homepage |
| `github_url` | string | No | Link to GitHub repo |
| `logo_url` | string | No | URL to app logo image |
| `favicon_url` | string | No | URL to favicon |
| `og_image_url` | string | No | OpenGraph image URL |
| `demo_url` | string | No | Link to live demo |
| `post_install_markdown` | string | No | Markdown shown after successful installation |
| `copyright_markdown` | string | No | Copyright markdown |
| `footer_markdown` | string | No | Footer markdown |

```toml
# installer
name              = "My SaaS Installer"
slug              = "my-saas"
apps              = ["api", "web-ui"]
documentation_url = "https://docs.example.com"
homepage_url      = "https://example.com"
logo_url          = "https://example.com/logo.png"
```

---

# Component Types

All components share these base fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Unique component name within the app |
| `type` | string | Yes | Component type: `"terraform_module"`, `"helm_chart"`, `"docker_build"`, `"container_image"`, `"kubernetes_manifest"`, `"job"` |
| `var_name` | string | No | Variable name for outputs (defaults to component name) |
| `dependencies` | array | No | Component names that must deploy first |
| `build_timeout` | string | No | Build timeout duration (e.g., `"30m"`, `"1h"`) |
| `deploy_timeout` | string | No | Deploy timeout duration (e.g., `"30m"`, `"1h"`) |

Component files live in `components/` directory. The first line comment identifies the type for the LSP.

## terraform_module

Purpose: Deploy Terraform modules.

Header comment: `# terraform`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `terraform_version` | string | Yes | Terraform version (e.g., `"1.5.0"`, `"latest"`) |
| `env_vars` | object | No | Environment variables for Terraform |
| `vars` | object | No | Terraform input variables (supports templating) |
| `var_file` | array | No | External `.tfvars` files (each with `contents` field) |
| `public_repo` | PublicRepoConfig | No | Public repo with Terraform code |
| `connected_repo` | ConnectedRepoConfig | No | Private repo with Terraform code |
| `drift_schedule` | string | No | Cron expression for drift detection |
| `var` | array | No | Alternative array format for vars |
| `env_var` | array | No | Alternative array format for env_vars |

```toml
# terraform
name              = "rds_cluster"
type              = "terraform_module"
terraform_version = "1.11.3"

[connected_repo]
directory = "infra/rds"
repo      = "org/repo"
branch    = "main"

[env_vars]
AWS_REGION = "{{.nuon.install_stack.outputs.region}}"

[vars]
install_id  = "{{.nuon.install.id}}"
vpc_id      = "{{.nuon.sandbox.outputs.vpc.id}}"
```

## helm_chart

Purpose: Deploy Helm charts to Kubernetes.

Header comment: `# helm`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `chart_name` | string | Yes | Helm chart name |
| `values` | object | No | Helm values as key-value map (dot-notation keys supported) |
| `values_file` | array | No | External values files (each with `contents` field) |
| `public_repo` | PublicRepoConfig | No | Public repo with chart |
| `connected_repo` | ConnectedRepoConfig | No | Private repo with chart |
| `helm_repo` | HelmRepoConfig | No | Helm repository config |
| `namespace` | string | No | K8s namespace (defaults to `{{.nuon.install.id}}`, supports templating) |
| `storage_driver` | string | No | Helm storage: `"configmap"` (default) or `"secret"` |
| `take_ownership` | boolean | No | Take ownership of existing resources |
| `drift_schedule` | string | No | Cron expression for drift detection |
| `value` | array | No | Alternative array format for values (not recommended) |

```toml
# helm
name           = "whoami"
type           = "helm_chart"
chart_name     = "whoami"
namespace      = "whoami"
storage_driver = "configmap"

[public_repo]
repo      = "nuonco/demo"
directory = "eks-simple/src/components/whoami"
branch    = "main"

[values]
"api.ingresses.public_domain" = "{{.nuon.sandbox.outputs.nuon_dns.public_domain.name}}"

[[values_file]]
contents = "./whoami-values.yaml"
```

## docker_build

Purpose: Build Docker images from a Dockerfile and push to registry.

Header comment: `# docker-build`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `dockerfile` | string | Yes | Path to Dockerfile (relative, URL, or git source) |
| `env_vars` | object | No | Build environment variables (supports templating) |
| `public_repo` | PublicRepoConfig | No | Public repo with Dockerfile |
| `connected_repo` | ConnectedRepoConfig | No | Private repo with Dockerfile |

Outputs available via `{{.nuon.components.<name>.outputs.image.repository}}` and `{{.nuon.components.<name>.outputs.image.tag}}`.

```toml
# docker-build
name       = "app_image"
type       = "docker_build"
dockerfile = "Dockerfile"

[connected_repo]
directory = "."
repo      = "org/repo"
branch    = "main"
```

## container_image

Purpose: Reference an existing container image from a public registry or ECR.

Header comment: `# container-image`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `aws_ecr` | AWSECRConfig | No | ECR image config |
| `public` | PublicImageConfig | No | Public registry image config |

### PublicImageConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image_url` | string | Yes | Image URL (e.g., `"kennethreitz/httpbin"`) |
| `tag` | string | Yes | Image tag |

### AWSECRConfig

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `iam_role_arn` | string | Yes | IAM role ARN for ECR access |
| `image_url` | string | Yes | ECR image URL |
| `tag` | string | Yes | Image tag |
| `region` | string | Yes | AWS region |

```toml
# container-image
name = "httpbin"
type = "container_image"

[public]
image_url = "kennethreitz/httpbin"
tag       = "latest"
```

```toml
# container-image
name = "app_image_ecr"
type = "container_image"

[aws_ecr]
iam_role_arn = "arn:aws:iam::123456789:role/ecr-access"
image_url    = "123456789.dkr.ecr.us-west-2.amazonaws.com/my-app"
tag          = "latest"
region       = "us-west-2"
```

## kubernetes_manifest

Purpose: Deploy raw Kubernetes YAML manifests or Kustomize overlays.

Header comment: `# kubernetes-manifest`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `manifest` | string | No | Inline YAML manifest (supports templating). Mutually exclusive with `kustomize`. |
| `kustomize` | KustomizeConfig | No | Kustomize overlay config. Mutually exclusive with `manifest`. |
| `public_repo` | PublicRepoConfig | No | Public repo with manifest/kustomize files |
| `connected_repo` | ConnectedRepoConfig | No | Private repo with manifest/kustomize files |
| `namespace` | string | Yes | K8s namespace (supports templating) |
| `drift_schedule` | string | No | Cron expression for drift detection |

```toml
# kubernetes-manifest
name      = "app_config"
type      = "kubernetes_manifest"
namespace = "{{.nuon.install.id}}"

manifest = """
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: {{.nuon.install.id}}
data:
  DATABASE_URL: "{{.nuon.components.rds_cluster.outputs.endpoint}}"
"""
```

## job

Purpose: Run batch/job components using Docker images.

Header comment: `# job` or within actions as `type = "job"`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `image_url` | string | Yes | Docker image URL (supports templating) |
| `tag` | string | Yes | Image tag (supports templating) |

```toml
# In actions/eks_job.toml
# action
name      = "eks_job"
type      = "job"
image_url = "{{.nuon.components.app_image.image.repository.uri}}"
tag       = "{{.nuon.components.app_image.image.tag}}"
```

---

# Advanced Features

## actions/<name>.toml

Purpose: Define custom workflows triggered manually, on schedule, or by lifecycle events.

Header comment: `# action`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Action name (shown in dashboard Actions tab) |
| `timeout` | string | Yes | Max execution time (Go duration, max 30m). E.g., `"15s"`, `"5m"`, `"30m"` |
| `triggers` | array | Yes | List of trigger definitions |
| `steps` | array | Yes | Ordered list of execution steps |
| `dependencies` | array | No | Component names referenced in this action |
| `break_glass_role` | string | No | Name of a break-glass role for elevated permissions |

### Trigger fields (within `[[triggers]]`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Trigger type: `"manual"`, `"cron"`, `"post-deploy-component"`, `"provision"`, `"deploy"`, `"teardown"`, etc. |
| `cron_schedule` | string | No | Cron expression (required for `"cron"` type) |
| `component_name` | string | No | Component name (required for `"post-deploy-component"` type) |
| `index` | number | No | Ordering index for actions with same trigger type |

### Step fields (within `[[steps]]`)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Step name |
| `command` | string | No | Command to execute (path to script) |
| `inline_contents` | string | No | Inline script content |
| `env_vars` | object | No | Environment variables for the step (as `[steps.env_vars]`) |
| `public_repo` | PublicRepoConfig | No | Public repo with scripts (as `[steps.public_repo]`) |
| `connected_repo` | ConnectedRepoConfig | No | Private repo with scripts (as `[steps.connected_repo]`) |

```toml
# action
name    = "http_healthcheck"
timeout = "5m"

[[triggers]]
type          = "cron"
cron_schedule = "*/5 * * * *"

[[triggers]]
type = "manual"

[[steps]]
name    = "healthcheck"
command = "./healthcheck"

[steps.public_repo]
repo      = "nuonco/actions"
branch    = "main"
directory = "common"

[steps.env_vars]
ENDPOINT             = "https://app.{{.nuon.sandbox.outputs.public_domain.name}}"
METHOD               = "HEAD"
EXPECTED_STATUS_CODE = "200"
```

```toml
# action
name    = "db_migration"
timeout = "10m"
break_glass_role = "db-migration-break-glass"

[[triggers]]
type           = "post-deploy-component"
component_name = "rds_cluster"

[[steps]]
name            = "run migration"
inline_contents = """
#!/usr/bin/env sh
echo "Running migration..."
"""

[steps.env_vars]
DB_URL = "{{.nuon.components.rds_cluster.outputs.endpoint}}"
```

## installs/<name>.toml

Purpose: Define install-specific configuration overrides (managed via `nuon installs sync`).

Header comment: `# install`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Unique install name |
| `approval_option` | string | No | `"approve-all"` (auto) or `"prompt"` (manual confirmation) |
| `aws_account` | object | No | AWS account settings (contains `region` field) |
| `inputs` | array | No | Input values as list of key-value group objects |

All input values must be strings. They are parsed to the correct type by Nuon. Sensitive inputs are excluded from config files and managed via dashboard.

```toml
# install
name            = "customer-prod"
approval_option = "approve-all"

[aws_account]
region = "us-east-1"

[[inputs]]
db_host = "prod-db.example.com"

[[inputs]]
api_key_enabled = "true"
max_connections = "100"
```

## Full Single-File Format (nuon.toml)

Purpose: Define the entire app in a single file instead of multiple files. Rarely used for complex apps.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | Yes | Config format version |
| `description` | string | No | App description |
| `display_name` | string | No | App display name |
| `slack_webhook_url` | string | No | Slack webhook URL |
| `readme` | string | No | README markdown |
| `branch` | AppBranchConfig | No | Default branch config |
| `inputs` | AppInputConfig | No | Input configuration |
| `sandbox` | AppSandboxConfig | Yes | Sandbox configuration |
| `runner` | AppRunnerConfig | Yes | Runner configuration |
| `permissions` | PermissionsConfig | No | Permissions configuration |
| `policies` | PoliciesConfig | No | Policies configuration |
| `secrets` | SecretsConfig | No | Secrets configuration |
| `break_glass` | BreakGlass | No | Break-glass configuration |
| `stack` | StackConfig | No | Stack configuration |
| `components` | ComponentList | No | Component configurations |
| `installs` | array | No | Install configurations |
| `actions` | array | No | Action configurations |
| `installer` | object | No | Installer UI configuration |

## Component Root (component-root.toml)

Purpose: Reference an external component definition via `source` field.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source` | string | No | Path/URL to component config (HTTP(S), git, file, `./` relative) |
| `name` | string | Yes | Component name |
| `type` | string | Yes | Component type |
| `var_name` | string | No | Variable name for outputs |
| `dependencies` | array | No | Component dependencies |
| `helm_chart` | object | No | Helm chart config (when type is `"helm_chart"`) |
| `terraform_module` | object | No | Terraform module config (when type is `"terraform_module"`) |
| `docker_build` | object | No | Docker build config (when type is `"docker_build"`) |
| `job` | object | No | Job config (when type is `"job"`) |
| `external_image` | object | No | Container image config (when type is `"container_image"`) |
| `kubernetes_manifest` | object | No | K8s manifest config (when type is `"kubernetes_manifest"`) |

---

# Valid LSP Header Comments

The first line of each TOML file must be one of these comments for the Nuon LSP:

| Comment | File Type |
|---------|-----------|
| `# metadata` | metadata.toml |
| `# inputs` | inputs.toml |
| `# sandbox` | sandbox.toml |
| `# runner` | runner.toml |
| `# stack` | stack.toml |
| `# secrets` | secrets.toml |
| `# permissions` | permissions.toml |
| `# policies` | policies.toml |
| `# installer` | installer.toml |
| `# install` | installs/*.toml |
| `# action` | actions/*.toml |
| `# terraform` | components/*.toml (terraform_module) |
| `# helm` | components/*.toml (helm_chart) |
| `# docker-build` | components/*.toml (docker_build) |
| `# container-image` | components/*.toml (container_image) |
| `# kubernetes-manifest` | components/*.toml (kubernetes_manifest) |
| `# job` | components/*.toml (job) |

---

# Valid Component Types

```
terraform_module
helm_chart
docker_build
container_image
kubernetes_manifest
job
```

# Sync Commands

```bash
nuon apps sync                              # Sync app config
nuon installs sync -a <app> -d <path>       # Sync install configs
```
