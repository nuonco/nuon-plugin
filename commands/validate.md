Validate the Nuon app configuration in the current directory.

Find and read all Nuon config files (.toml, values/*.yaml) in the current directory. Check for:

**Errors** (must fix):
- Missing required files (metadata.toml, inputs.toml, sandbox.toml, runner.toml, stack.toml)
- Missing required fields in each config file
- Invalid component types (must be: helm_chart, terraform_module, docker_build, container_image, kubernetes_manifest, job, pulumi)
- Broken template syntax (unbalanced `{{ }}`, invalid variable paths)
- References to undefined inputs or components
- Circular component dependencies
- Use of deprecated `var` array or `env_var` array (must use `[vars]` map / `[env_vars]` map)
- Missing `display_name` or `group` on inputs
- GCP install missing `project_id` or `region` in `[gcp_account]`

**Warnings** (should fix):
- Component files not numbered (should be 0-name.toml, 1-name.toml)
- Sensitive inputs without `sensitive = true`
- Missing permissions (provision, maintenance, deprovision)
- Missing break_glass.toml
- Resources without `{{ .nuon.install.id }}` in names
- Use of deprecated `internal` field on inputs

**New fields to be aware of**:
- runner.toml: `role`, `enable_kube_config`, `cloud_platform`, `gcp_permissions`, `gcp_predefined_role`
- GCP installs: `[gcp_account]` with `project_id` and `region`
- Components: `take_ownership`, `build_timeout`, `deploy_timeout`
- kubernetes_manifest components: kustomize fields `path`, `patches`, `enable_helm`, `load_restrictor`
- Inputs: `type`, `user_configurable` (the `internal` field is deprecated)

**Best practices**:
- Inputs grouped by concern
- Components ordered by dependency
- Minimal comments in config files

Read `reference/schema.md` for the complete field reference.

If the Nuon CLI is available, also run `nuon apps validate` for local directory validation. If not installed, suggest:
```
brew install nuonco/tap/nuon
```
