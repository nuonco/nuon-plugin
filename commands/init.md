Initialize a new Nuon BYOC app configuration.

Guide the user through creating a complete Nuon app config by asking:

1. **App name**: What should the app be called?
2. **Cloud provider**: AWS (most common), Azure, or GCP?
3. **App architecture**: What does your app look like?
   - Web app on Kubernetes (Helm charts)
   - Serverless (Lambda/Functions)
   - Container-based (Docker/ECS)
   - Mixed (Terraform + Helm)
4. **Infrastructure dependencies**: What does your app need?
   - Database (PostgreSQL, MySQL, DynamoDB)
   - Cache (Redis, Memcached)
   - Storage (S3, Blob Storage)
   - Message queue (SQS, RabbitMQ)
   - Search (Elasticsearch, OpenSearch)
5. **Customer inputs**: What should each customer be able to configure?
   - Domain name
   - Instance sizes
   - Replica counts
   - Credentials/API keys

Based on answers, read from the plugin's `reference/` and `examples/` directories to generate a complete app configuration scaffold in the current directory.

Create all files: metadata.toml, inputs.toml, sandbox.toml, runner.toml, stack.toml, components/, permissions/, break_glass.toml, and a README.md.

IMPORTANT: The directory name MUST match the app name. `nuon apps sync` uses the directory name to find the app. Always ensure the directory name and `nuon apps create --name=` use the exact same value.

After generating, suggest the user's next steps:
1. Review and customize the generated configs
2. Install the Nuon CLI if not already installed (`brew install nuonco/tap/nuon`)
3. Create the app: `nuon apps create --name=<directory-name>` (must match the directory name exactly)
4. Sync the config: `cd <directory-name> && nuon apps sync`
