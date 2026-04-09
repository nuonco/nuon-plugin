---
name: create-app-config
description: Generate a Nuon BYOC app configuration from a description of the user's application. Invoke when users describe an app they want to deploy with Nuon, ask about BYOC deployment, mention creating Nuon configs, or want to convert Helm charts (values.yaml, Chart.yaml, ArtifactHub) to Nuon components.
---

You are creating a Nuon app configuration.

IMPORTANT: Before generating ANY TOML files, read example files from the `examples/` directory in this plugin to confirm the exact format. Start with `examples/eks-simple/` for a simple pattern or `examples/grafana/` for a complex one. Your generated TOML MUST match the format in those examples exactly.

## Step 1: Gather Information

Ask the user (if not already provided):
- What does their app do? What components does it have?
- What cloud provider? (AWS is most common, Azure and GCP also supported)
- What infrastructure dependencies? (PostgreSQL, Redis, S3, etc.)
- How is the app currently deployed? (Helm charts, Terraform, Docker, serverless?)
- What should customers be able to configure? (domain, sizing, credentials?)

## Step 2: Read References

Read these files from the plugin for accurate schema and pattern information:
- `reference/schema.md` for valid TOML fields
- `reference/patterns.md` for architecture patterns matching their use case
- `reference/templating.md` for template variable syntax
- Browse `examples/` to find the closest matching pattern

## Step 2b: Helm Chart Value Classification

When converting Helm charts (user provides values.yaml, Chart.yaml, a Helm repo URL, an ArtifactHub link, or describes a chart they use), classify every value before generating files:

| Category | Destination | When |
|----------|------------|------|
| **Customer Input** | `inputs.toml` → `{{ .nuon.inputs.inputs.X }}` | Differs per customer |
| **Infra-Derived** | `{{ .nuon.install.sandbox.outputs.X }}` | From cloud infrastructure |
| **Component-Derived** | `{{ .nuon.components.X.outputs.Y }}` | From another Nuon component |
| **Hardcoded Default** | Static in values file | Vendor default, rarely changes |

Present the classification to the user as a table before generating files.

Also check Chart.yaml for dependencies (postgresql, redis, mysql, elasticsearch, etc.). For each dependency:
- Suggest creating a separate Nuon component (Terraform RDS or Helm subchart)
- Show how to wire the connection via `{{ .nuon.components.X.outputs.Y }}`
- Reference `examples/grafana/` for the RDS + Helm pattern

## Step 3: Plan the Configuration

Present a plan showing:
- File structure with every file that will be created
- Component list with types and dependency order
- Input groups and what customers will configure
- Which example pattern this most closely matches

## Step 4: Generate Files

IMPORTANT: Never fabricate repository paths. Only reference repos/directories from the bundled examples (nuonco/example-app-configs) or repos the user explicitly provides. If a Terraform module doesn't exist in the examples (e.g., S3 bucket, ElastiCache), generate the Terraform source code in src/components/<name>/ with main.tf, variables.tf, outputs.tf, providers.tf, versions.tf.

IMPORTANT: The directory name MUST match the app name. `nuon apps sync` uses the directory name to find the app. If you create a directory called `my-app/`, the `nuon apps create` command must use `--name=my-app`. Always ensure these match in your output and "next steps" instructions.

After user approves the plan, generate all configuration files:

1. `metadata.toml` - version, display_name, description. May also include `readme` (path to a README file) and `branch` (default branch for the app config)
2. `inputs.toml` - grouped customer inputs. Every `[[input]]` MUST have `display_name` and `group`. Use `type` (e.g. `"string"`, `"number"`, `"boolean"`) and `user_configurable` where appropriate. Do NOT use the deprecated `internal` field
3. `sandbox.toml` - base infrastructure (typically `nuonco/aws-eks-sandbox`)
4. `runner.toml` - runner type and config
5. `stack.toml` - CloudFormation/Bicep template config
6. `components/*.toml` - numbered, dash-separated names (0-name.toml, 1-name.toml)
7. `components/values/*.yaml` - templated Helm values if using helm_chart components
8. `permissions/*.toml` - provision, maintenance, deprovision roles
9. `break_glass.toml` - emergency access
10. `actions/*.toml` - healthchecks and operational actions

## CRITICAL: TOML Format

Nuon TOML uses a **flat structure** - NO nested wrappers like `[component]`. First line is a type comment.

```toml
# helm
name           = "webapp"
type           = "helm_chart"
chart_name     = "webapp"
namespace      = "webapp"
storage_driver = "configmap"
dependencies   = ["postgres"]

[helm_repo]
repo_url = "https://charts.example.com"
chart    = "webapp"

[[values_file]]
contents = "./values/webapp/values.yaml"
```

```toml
# terraform
name              = "rds_cluster"
type              = "terraform_module"
terraform_version = "1.11.3"

[public_repo]
repo      = "org/repo"
directory = "src/components/rds"
branch    = "main"

[vars]
identifier = "db-{{ .nuon.install.id }}"
region     = "{{ .nuon.install_stack.outputs.region }}"
```

Key rules:
- Use `dependencies` NOT `depends_on`
- Use `[values]` or `[[values_file]]` for Helm, `[vars]` or `[[var_file]]` for Terraform
- NEVER use deprecated `var` arrays or `env_var` arrays — always use `[vars]` and `[env_vars]` maps
- `chart_name` required for helm_chart, `terraform_version` required for terraform_module
- Components may include `take_ownership`, `build_timeout`, and `deploy_timeout` fields
- kubernetes_manifest components support kustomize fields: `path`, `patches`, `enable_helm`, `load_restrictor`
- File naming: `0-docker-image.toml` (dashes), field naming: `name = "docker_image"` (underscores)

## Style

- Number component files by dependency order
- Use dash-separated names for files: `0-docker-image.toml`, `1-rds-cluster.toml`
- Minimal or no comments in TOML/Helm/Terraform files
- Use `{{ .nuon.install.id }}` in resource names for uniqueness
- Default to `nuonco/aws-eks-sandbox` for AWS, `nuonco/azure-aks-sandbox` for Azure, `nuonco/gcp-gke-sandbox` for GCP

$ARGUMENTS
