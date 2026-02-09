---
name: validate-config
description: Validate a Nuon app configuration for correctness and best practices. Invoke when users ask to check, validate, review, or verify their Nuon configuration.
---

You are validating a Nuon app configuration. Follow these steps:

## Step 1: Discover Config Files

Look for Nuon app configuration files in the current directory or the path the user specifies. Expected files:
- `metadata.toml`, `inputs.toml`, `sandbox.toml`, `runner.toml`, `stack.toml`
- `components/*.toml`, `components/values/*.yaml`
- `actions/*.toml`, `secrets.toml`, `permissions/*.toml`, `break_glass.toml`, `policies.toml`

Read all discovered files.

## Step 2: Schema Validation

Read `reference/schema.md` and check each file against its schema:

- **metadata.toml**: Must have `version` (should be "v2"), `display_name`, `description`
- **inputs.toml**: Each `[[input]]` needs `name`, `display_name`, `description`, `group`. Groups need `name`, `display_name`, `description`
- **sandbox.toml**: Needs `terraform_version`, repo config (`[public_repo]` or `[connected_repo]`), `[vars]`
- **runner.toml**: Needs `runner_type` (aws/azure)
- **stack.toml**: Needs `type` (aws-cloudformation/azure-bicep/nested), `name`
- **Components**: Each needs `name`, `type`, type-specific fields. Check `type` is one of: helm_chart, terraform_module, docker_build, container_image, kubernetes_manifest, job

## Step 3: Template Validation

Read `reference/templating.md` and check all `{{ }}` expressions:

- Valid prefixes: `.nuon.install.id`, `.nuon.inputs.inputs.`, `.nuon.install.sandbox.outputs.`, `.nuon.install_stack.outputs.`, `.nuon.components.`, `.nuon.org.id`, `.nuon.app.id`
- Balanced braces: every `{{` has matching `}}`
- No typos in common paths (e.g., `.nuon.input.inputs` should be `.nuon.inputs.inputs`)
- Input references match defined inputs in inputs.toml
- Component references match defined component names

## Step 4: Dependency Validation

- Check for circular dependencies in component `dependencies` arrays
- Verify that referenced components exist
- Check that components using `{{ .nuon.components.X.outputs.Y }}` have X in their dependencies (or X is defined)

## Step 5: Best Practices

- Component files should be numbered (0-name.toml, 1-name.toml)
- Sensitive inputs should have `sensitive = true`
- Required inputs should have `required = true`
- Resources should include `{{ .nuon.install.id }}` in names for uniqueness
- Permissions should define all three roles (provision, maintenance, deprovision)
- Break glass config should exist

## Step 6: CLI Validation

Run the Nuon CLI check script to see if nuon is installed:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-nuon-cli.sh
```

If installed, run validation in the app config directory:
```bash
nuon apps validate
```

- If validation passes, note "CLI validation passed" in your report.
- If validation returns errors, add them to the **Errors** section of your report, attempt to fix the issues, and re-run `nuon apps validate` until it passes or you cannot resolve the remaining errors.
- If validation returns "app not found": this means the app has not been created in the Nuon control plane yet. This is NOT a config error — report it in the **Info** section and offer to create the app by asking the user if they'd like to run `nuon apps create --name=<dir-name>` (where dir-name is the current directory name, since app name must match directory name). If they accept, create the app and re-run `nuon apps validate`.
- If the CLI is not installed, skip this step and add an info note: "Install Nuon CLI for authoritative validation: brew install nuonco/tap/nuon"

## Report Format

Present findings as:

**Errors** (must fix):
- Missing required fields
- Invalid component types
- Broken template references
- Circular dependencies

**Warnings** (should fix):
- Missing best practice fields
- Unnumbered component files
- Sensitive inputs without `sensitive = true`

**Info**:
- Total files found
- Component count and types
- Input count and groups

$ARGUMENTS
