nuon-plugin

Claude Code plugin for building and validating Nuon BYOC app configs. This is a plugin definition (markdown + shell), not a compiled project. Owned by nuonco.

Layout:
- skills/ — skill definitions (create-app-config, validate-config)
- commands/ — slash commands
- agents/ — agent definitions
- reference/ — reference docs the skills pull from
- examples/ — example configs
- scripts/ — helper scripts (e.g. check-nuon-cli.sh)

Conventions:
- edit skills/commands/agents as markdown with the expected frontmatter; keep names and descriptions accurate since they drive discovery
- bash scripts: set -euo pipefail; check with shellcheck; quote expansions
- keep reference/ and examples/ consistent with the current Nuon app-config schema
- this is a shared company repo — branch and open a PR; do not push to the default branch
