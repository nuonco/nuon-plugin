Convert existing infrastructure into a Nuon app configuration.

Ask the user what they're converting:

1. **Helm chart** - Provide values.yaml content, chart repo URL, or file path
2. **Existing Terraform** - Point to Terraform modules/configs
3. **Docker Compose** - Provide docker-compose.yml
4. **Kubernetes manifests** - Provide YAML manifests

For Helm charts:
- Analyze the values.yaml to classify every value (customer input, infra-derived, component-derived, hardcoded default)
- Present the classification as a table for user review
- Detect dependencies (PostgreSQL, Redis, etc.) from Chart.yaml
- Generate Nuon component TOML, templated values file, and input definitions
- Read `reference/schema.md` and `reference/patterns.md` for correct syntax

For Terraform:
- Analyze variables.tf to identify what becomes Nuon inputs vs hardcoded
- Generate a terraform_module component TOML
- Map variable values to Nuon template references

For Docker Compose:
- Map services to Nuon components (helm_chart or terraform_module)
- Identify databases, caches, and other dependencies
- Generate component TOMLs for each service

For Kubernetes manifests:
- Convert to kubernetes_manifest component type
- Or suggest wrapping in a Helm chart for more flexibility

After conversion, validate the generated config and suggest next steps.
