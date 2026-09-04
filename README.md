# Nuon Claude Code Plugin (last updated June 2026, new ways for agentic use of Nuon are under active development)

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that makes Claude an expert at creating [Nuon](https://nuon.co) BYOC app configurations. Describe your application and infrastructure, and the plugin generates production-ready Nuon config files with correct TOML structure, Go template wiring, and dependency ordering.

## What it does

- Scaffolds complete Nuon app configs from a description of your application
- Converts existing Helm charts into Nuon `helm_chart` components with properly templated values
- Validates configs against the Nuon schema, checks template syntax, and runs `nuon apps validate` if the CLI is installed
- Classifies Helm values into the right categories: customer input, infrastructure-derived, component-derived, or hardcoded default

## Requirements

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) v2.1+
- [Nuon CLI](https://docs.nuon.co) (strongly recommended, enables `nuon apps validate` feedback loop)

Install the Nuon CLI:
```bash
brew install nuonco/tap/nuon
```

## Usage

Load the plugin when starting Claude Code:

```bash
claude --plugin-dir /path/to/nuon-plugin
```

### Commands

| Command | Description |
|---------|-------------|
| `/nuon:init` | Interactive guided flow to scaffold a new Nuon app config |
| `/nuon:convert` | Convert existing Helm charts, Terraform, or Docker Compose to Nuon configs |
| `/nuon:validate` | Validate Nuon config files in the current directory |

### Skills (auto-invoked)

The plugin also includes skills that Claude invokes automatically when relevant:

- **create-app-config** - Triggers when you describe an app you want to deploy with Nuon, or provide a Helm chart for conversion
- **validate-config** - Triggers when you ask to check or validate Nuon configs

### Agents

- **nuon-config-architect** - Primary agent with deep knowledge of Nuon's config schema, templating system, and deployment patterns
- **helm-analyzer** - Specialized agent for analyzing Helm charts and converting them to Nuon components

## Plugin structure

```
nuon-plugin/
├── .claude-plugin/plugin.json    # Plugin manifest
├── agents/                       # Subagent prompts
│   ├── nuon-config-architect.md  # Primary Nuon config expert
│   └── helm-analyzer.md          # Helm conversion specialist
├── skills/                       # Auto-invoked skills
│   ├── create-app-config/        # Generate app configs / Helm conversion
│   └── validate-config/          # Config validation
├── commands/                     # User-invoked slash commands
│   ├── init.md                   # /nuon:init
│   ├── convert.md                # /nuon:convert
│   └── validate.md               # /nuon:validate
├── hooks/hooks.json              # PostToolUse TOML validation
├── .lsp.json                     # Nuon LSP integration
├── reference/                    # Knowledge base
│   ├── schema.md                 # Complete TOML config schema
│   ├── patterns.md               # Annotated architecture patterns
│   └── templating.md             # Go template variable reference
├── examples/                     # Bundled example app configs
│   ├── eks-simple/               # Simple K8s app (Helm + ALB + cert)
│   ├── grafana/                  # Multi-component (RDS + Helm + secrets)
│   └── aws-lambda/               # Serverless (Docker + Lambda + API GW)
└── scripts/
    └── check-nuon-cli.sh         # CLI installation check
```

## Example

```
$ claude --plugin-dir ~/nuon-plugin

> I have a Node.js app with PostgreSQL and Redis that I want to deploy
> with Nuon on AWS. The app uses a Helm chart.

Claude will:
1. Ask clarifying questions about your infrastructure
2. Plan the component architecture
3. Generate all config files (metadata, inputs, sandbox, runner, stack, components, permissions, actions)
4. Validate the output with nuon apps validate if the CLI is installed
```

## How it works

The plugin is agent-centric. Rather than code generation templates, it uses:

1. **Reference docs** (`reference/`) - Complete schema, patterns, and templating docs that agents read on-demand
2. **Bundled examples** (`examples/`) - Real working Nuon app configs that agents study before generating new ones
3. **Carefully crafted prompts** - Agent and skill prompts with explicit format examples and guardrails learned from testing

This approach means Claude generates configs that match the exact TOML format Nuon expects, with correct flat structure (no nested wrappers), proper field names, and valid Go template expressions.

## License

Apache-2.0
