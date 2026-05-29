# Upstream-to-Plugin Change Map

This document maps upstream source files to the plugin files that need updating when they change.
The upgrade agent reads this to know which plugin docs/prompts to update for a given upstream diff.

## nuonco/nuon (public)

### Config Schema (`pkg/config/*.go`)

These Go structs define the TOML config schema. Field names come from `mapstructure`/`toml` tags.
Required fields are marked with `jsonschema:"required"`. Descriptions come from `JSONSchemaExtend` methods.

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `pkg/config/component.go` | `reference/schema.md`, `agents/nuon-config-architect.md`, `agents/helm-analyzer.md` | Base component fields (name, type, var_name, dependencies, build_timeout, deploy_timeout), ComponentType enum values |
| `pkg/config/helm_chart_component.go` | `reference/schema.md`, `agents/helm-analyzer.md`, `skills/create-app-config/SKILL.md` | Helm fields (chart_name, values, values_file, namespace, storage_driver, helm_repo, drift_schedule) |
| `pkg/config/terraform_module_component.go` | `reference/schema.md`, `agents/nuon-config-architect.md` | Terraform fields (terraform_version, vars, var_file, env_vars, drift_schedule) |
| `pkg/config/docker_build_component.go` | `reference/schema.md` | Docker build fields |
| `pkg/config/external_image_component.go` | `reference/schema.md` | External/container image fields |
| `pkg/config/kubernetes_manifest_component.go` | `reference/schema.md` | K8s manifest fields |
| `pkg/config/job_component.go` | `reference/schema.md` | Job component fields |
| `pkg/config/config.go` | `reference/schema.md` | Top-level AppConfig fields (version, description, display_name) |
| `pkg/config/app_sandbox.go` | `reference/schema.md` | Sandbox fields (terraform_version, source, drift_schedule) |
| `pkg/config/app_runner.go` | `reference/schema.md` | Runner fields (runner_type, env_vars, helm_driver) |
| `pkg/config/app_stack.go` | `reference/schema.md` | Stack/CloudFormation fields |
| `pkg/config/app_input.go` | `reference/schema.md`, `skills/create-app-config/SKILL.md` | Input/group fields (name, description, default, sensitive, group) |
| `pkg/config/app_secrets.go` | `reference/schema.md` | Secret config fields |
| `pkg/config/app_permissions.go` | `reference/schema.md` | Permission/role fields |
| `pkg/config/app_policies.go` | `reference/schema.md` | Policy fields |
| `pkg/config/app_break_glass.go` | `reference/schema.md` | Break glass fields |
| `pkg/config/installer.go` | `reference/schema.md` | Installer fields |
| `pkg/config/metadata.go` | `reference/schema.md` | Metadata fields (name, description, display_name) |
| `pkg/config/action_config.go` | `reference/schema.md`, `agents/nuon-config-architect.md` | Action trigger types, step configs, timeouts |
| `pkg/config/vcs.go` | `reference/schema.md`, `agents/helm-analyzer.md`, `agents/nuon-config-architect.md` | PublicRepoConfig, ConnectedRepoConfig, HelmRepoConfig source block fields |
| `pkg/config/operation_roles.go` | `reference/schema.md` | Operation role fields (provision, maintenance, deprovision) |
| `pkg/config/shared.go` | `reference/schema.md` | Shared types used across configs |
| `pkg/config/shared_aws_iam_policy.go` | `reference/schema.md` | AWS IAM policy config |
| `pkg/config/shared_aws_iam_role.go` | `reference/schema.md` | AWS IAM role config |
| `pkg/config/install.go` | `reference/schema.md` | Install config fields |

### Template Variables (`pkg/config/vars/`)

These define the Go template variables available in Nuon configs (e.g., `{{ .nuon.install.id }}`).

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `pkg/config/vars/types.go` | `reference/templating.md`, `reference/system-prompt.md` | Root template struct, variable hierarchy |
| `pkg/config/vars/components.go` | `reference/templating.md` | `.nuon.components.<name>.outputs.*` variables |
| `pkg/config/vars/inputs.go` | `reference/templating.md` | `.nuon.inputs.inputs.*` variables |
| `pkg/config/vars/install_stack.go` | `reference/templating.md` | `.nuon.install_stack.outputs.*` variables |
| `pkg/config/vars/sandbox_outputs.go` | `reference/templating.md` | `.nuon.install.sandbox.outputs.*` variables |
| `pkg/config/vars/var.go` | `reference/templating.md` | Variable resolution logic |
| `pkg/config/vars/validate_var.go` | `skills/validate-config/SKILL.md` | Template variable validation rules |

### Validation (`pkg/config/validate/`)

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `pkg/config/validate/validate.go` | `skills/validate-config/SKILL.md`, `hooks/hooks.json` | Main validation orchestration |
| `pkg/config/validate/validate_dependencies.go` | `skills/validate-config/SKILL.md` | Dependency cycle detection rules |
| `pkg/config/validate/validate_duplicate_component_names.go` | `skills/validate-config/SKILL.md` | Uniqueness rules |
| `pkg/config/validate/validate_action_workflow_triggers.go` | `skills/validate-config/SKILL.md` | Action trigger validation |
| `pkg/config/validate/validate_vars.go` | `skills/validate-config/SKILL.md` | Variable validation rules |
| `pkg/config/validate/validate_version.go` | `skills/validate-config/SKILL.md` | Version constraint validation |
| `pkg/config/validate/validate_policies.go` | `skills/validate-config/SKILL.md` | Policy validation |
| `pkg/config/validate/validate_custom_nested_stacks.go` | `skills/validate-config/SKILL.md` | Stack validation |

### Config Generation (`pkg/config/generator/`)

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `pkg/config/generator/config_structure.go` | `skills/create-app-config/SKILL.md`, `reference/patterns.md` | Prebuilt templates (EKS, ECS), default config structure |
| `pkg/config/generator/gen.go` | `skills/create-app-config/SKILL.md` | Generation logic, default values |

### Schema (`pkg/config/schema/`)

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `pkg/config/schema/schema.go` | `reference/schema.md` | JSON schema generation, field constraints |
| `pkg/config/schema/validate.go` | `skills/validate-config/SKILL.md` | Schema validation logic |
| `pkg/config/schema/validators.go` | `skills/validate-config/SKILL.md` | Custom validators |

### CLI Commands (`bins/cli/cmd/`)

These are Cobra command definitions. Look for `cobra.Command` structs, `Flags()` calls, and `RunE` functions.

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `bins/cli/cmd/apps.go` | `agents/nuon-config-architect.md` | `nuon apps` subcommands and flags |
| `bins/cli/cmd/sync.go` | `agents/nuon-config-architect.md`, `commands/validate.md` | `nuon apps sync` behavior and flags |
| `bins/cli/cmd/generate.go` | `commands/init.md`, `agents/nuon-config-architect.md` | `nuon apps init` / config generation flags |
| `bins/cli/cmd/init.go` | `commands/init.md` | `nuon init` subcommands (sandbox, runner, stack, component, action) |
| `bins/cli/cmd/components.go` | `agents/nuon-config-architect.md` | Component management commands |
| `bins/cli/cmd/installs.go` | `agents/nuon-config-architect.md` | Install management commands |
| `bins/cli/cmd/actions.go` | `agents/nuon-config-architect.md` | Action workflow commands |
| `bins/cli/cmd/builds.go` | `agents/nuon-config-architect.md` | Build management commands |
| `bins/cli/cmd/secrets.go` | `agents/nuon-config-architect.md` | Secret management commands |
| `bins/cli/cmd/login.go` | `agents/nuon-config-architect.md` | Authentication commands |
| `bins/cli/cmd/root.go` | `agents/nuon-config-architect.md` | Global flags, base URL config |
| `bins/cli/cmd/extensions.go` | `agents/nuon-config-architect.md` | CLI extension system |

### CLI Internal Services (`bins/cli/internal/services/`)

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `bins/cli/internal/services/apps/init.go` | `skills/create-app-config/SKILL.md`, `commands/init.md` | Config initialization logic |
| `bins/cli/internal/services/apps/sync_dir.go` | `agents/nuon-config-architect.md` | How sync reads config directories |
| `bins/cli/internal/services/apps/validate_dir.go` | `skills/validate-config/SKILL.md` | CLI validation behavior |
| `bins/cli/internal/services/apps/service.go` | `agents/nuon-config-architect.md` | App service methods |

### API Models (`sdks/nuon-go/models/`)

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `sdks/nuon-go/models/app_component_type.go` | `reference/schema.md` | Component type enum values |
| `sdks/nuon-go/models/app_app_runner_type.go` | `reference/schema.md` | Runner type enum values |
| `sdks/nuon-go/models/app_action_workflow_trigger_type.go` | `reference/schema.md` | Action trigger type enum values |
| `sdks/nuon-go/models/app_app_config.go` | `reference/schema.md` | App config API model |

### LSP (`bins/lsp/`)

| Upstream File | Plugin Files to Update | What to Look For |
|---|---|---|
| `bins/lsp/handlers/completion.go` | `hooks/hooks.json` | Completion items, valid type comments |
| `bins/lsp/handlers/diagnostics.go` | `hooks/hooks.json`, `skills/validate-config/SKILL.md` | Diagnostic rules |
| `bins/lsp/handlers/hover.go` | Reference only | Field descriptions on hover |
| `bins/lsp/mappers/schema.go` | `reference/schema.md` | Schema mapping for LSP |

> **Note:** `nuonco/mono` (nuonctl, ctl-api) is intentionally NOT tracked. It is internal
> tooling/infrastructure and has no bearing on how a customer authors a config or uses the
> `nuon` CLI — the only surfaces this plugin documents. Only `nuonco/nuon` is synced.

## How to Read Go Struct Tags

When analyzing upstream Go files, extract schema information from struct tags:

```go
ChartName string `mapstructure:"chart_name,omitempty" toml:"chart_name,omitempty" jsonschema:"required"`
```

- `mapstructure:"chart_name"` → TOML field name is `chart_name`
- `jsonschema:"required"` → field is required
- Go type `string` → schema type is string
- Go type `[]HelmValuesFile` → array, look up HelmValuesFile struct
- Go type `*PublicRepoConfig` → optional object, look up PublicRepoConfig struct
- Go type `map[string]string` → key-value map
- `features:"template"` tag → field supports Go template variables

Also check `JSONSchemaExtend` methods for descriptions and examples.
