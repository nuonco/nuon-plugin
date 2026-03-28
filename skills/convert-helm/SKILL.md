---
name: convert-helm
description: Convert a Helm chart into Nuon helm_chart component configuration. Invoke when users mention Helm charts, values.yaml, ArtifactHub, or ask to convert existing Helm deployments to Nuon.
---

You are converting a Helm chart into a Nuon app component.

IMPORTANT: Before generating ANY TOML, read `examples/eks-simple/components/whoami.toml` and `examples/grafana/components/5-grafana.toml` from this plugin to see the exact Nuon TOML format. Your output MUST match that format exactly. Also read `examples/grafana/inputs.toml` for the correct inputs format.

## Step 1: Get the Chart

Obtain the Helm chart's configuration. The user may provide:
- A values.yaml file (pasted or file path)
- A Chart.yaml showing dependencies
- A Helm repo URL and chart name
- An ArtifactHub link
- A description of what chart they use

## Step 2: Analyze Values

Read `reference/templating.md` and `reference/schema.md` for Nuon specifics.

For every value in values.yaml, classify it:

| Category | Destination | When |
|----------|------------|------|
| **Customer Input** | `inputs.toml` → `{{ .nuon.inputs.inputs.X }}` | Differs per customer |
| **Infra-Derived** | `{{ .nuon.install.sandbox.outputs.X }}` | From cloud infrastructure |
| **Component-Derived** | `{{ .nuon.components.X.outputs.Y }}` | From another Nuon component |
| **Hardcoded Default** | Static in values file | Vendor default, rarely changes |

Present the classification to the user as a table before generating files.

## Step 3: Detect Dependencies

Check Chart.yaml for dependencies (postgresql, redis, mysql, elasticsearch, etc.). For each dependency:
- Suggest creating a separate Nuon component (Terraform RDS or Helm subchart)
- Show how to wire the connection via `{{ .nuon.components.X.outputs.Y }}`
- Reference `examples/grafana/` for the RDS + Helm pattern

## Step 4: Generate Nuon Configuration

CRITICAL: Nuon TOML uses a **flat structure** - NO nested `[component]` wrappers. The first line MUST be a type comment. Use `dependencies` NOT `depends_on`. Use `[values]` for inline values and `[[values_file]]` for YAML files. NEVER use the deprecated `value` array — always use the `[values]` map. Helm components may include `take_ownership`, `build_timeout`, and `deploy_timeout` fields.

Create three files:

**1. Component TOML** (`components/N-chart-name.toml`):
```toml
# helm
name           = "grafana"
type           = "helm_chart"
chart_name     = "grafana"
namespace      = "grafana"
storage_driver = "configmap"
dependencies   = ["rds_cluster", "redis"]

[helm_repo]
repo_url = "https://grafana.github.io/helm-charts"
chart    = "grafana"

[[values_file]]
contents = "./values/grafana/values.yaml"
```

For inline values (simple wiring without a separate YAML file):
```toml
# helm
name         = "alb"
type         = "helm_chart"
chart_name   = "application-load-balancer"
dependencies = ["webapp"]

[public_repo]
repo      = "org/repo"
directory = "src/components/alb"
branch    = "main"

[values]
domain             = "{{.nuon.inputs.inputs.sub_domain}}.{{.nuon.install.sandbox.outputs.nuon_dns.public_domain.name}}"
domain_certificate = "{{.nuon.components.certificate.outputs.public_domain_certificate_arn}}"
service_name       = "webapp"
service_port       = "80"
```

**2. Templated values file** (`components/values/chart-name/values.yaml`):
Only values that differ from defaults, using Nuon template variables:
```yaml
replicaCount: {{ .nuon.inputs.inputs.replica_count }}

image:
  repository: vendor/app
  tag: "{{ .nuon.inputs.inputs.app_version }}"

persistence:
  size: {{ .nuon.inputs.inputs.storage_size }}Gi

env:
  DATABASE_HOST: "{{ .nuon.components.rds_cluster.outputs.address }}"
  REDIS_HOST: "{{ .nuon.components.redis.outputs.host }}"
  LOG_LEVEL: "{{ .nuon.inputs.inputs.log_level }}"
```

**3. Input entries** for `inputs.toml`:
```toml
[[group]]
name         = "scaling"
description  = "Application scaling configuration"
display_name = "Scaling"

[[input]]
name              = "replica_count"
description       = "Number of application pod replicas"
default           = "3"
display_name      = "Replica Count"
group             = "scaling"
type              = "number"
user_configurable = true
```

Note: `display_name` and `group` are required on every `[[input]]`. Use `type` and `user_configurable` where appropriate. Do NOT use the deprecated `internal` field.

## Reference

- `reference/schema.md` - TOML field reference for helm_chart components
- `reference/patterns.md` - Common patterns and decision framework
- `examples/eks-simple/components/whoami.toml` - Simple Helm component (flat TOML format)
- `examples/grafana/components/5-grafana.toml` - Complex Helm with dependencies
- `examples/eks-simple/components/alb.toml` - Inline [values] example

$ARGUMENTS
