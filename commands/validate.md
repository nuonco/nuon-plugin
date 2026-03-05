Validate the Nuon app configuration in the current directory.

Find and read all Nuon config files (.toml, values/*.yaml) in the current directory. Check for:

**Errors** (must fix):
- Missing required files (metadata.toml, inputs.toml, sandbox.toml, runner.toml, stack.toml)
- Missing required fields in each config file
- Invalid component types (must be: helm_chart, terraform_module, docker_build, container_image, kubernetes_manifest, job)
- Broken template syntax (unbalanced `{{ }}`, invalid variable paths)
- References to undefined inputs or components
- Circular component dependencies

**Warnings** (should fix):
- Component files not numbered (should be 0-name.toml, 1-name.toml)
- Sensitive inputs without `sensitive = true`
- Missing permissions (provision, maintenance, deprovision)
- Missing break_glass.toml
- Resources without `{{ .nuon.install.id }}` in names

**Best practices**:
- Inputs grouped by concern
- Components ordered by dependency
- Minimal comments in config files

Read `reference/schema.md` for the complete field reference.

If the Nuon CLI is available, also run `nuon apps validate` for local directory validation. If not installed, suggest:
```
brew install nuonco/tap/nuon
```
