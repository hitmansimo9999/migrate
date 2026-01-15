# Kubernetes Deployment for migrate

This directory contains Kubernetes manifests for deploying the `migrate` CLI tool as Jobs in your cluster.

## Overview

Two deployment options are provided:

1. **Helm Chart** (`helm/migrate/`) - Full-featured, configurable deployment
2. **Plain Manifests** (`k8s-job.yaml`) - Simple, standalone deployment

## Use Cases

- **Schema Analysis**: Extract and document database schemas as part of CI/CD
- **Migration Generation**: Automatically generate migration SQL when schemas change
- **Drift Detection**: Scheduled jobs to detect schema drift in production
- **Multi-Database Comparison**: Compare schemas across different environments

## Quick Start

### Option 1: Plain Kubernetes Manifests

```bash
# Deploy all resources
kubectl apply -f k8s-job.yaml

# Check job status
kubectl -n migrate get jobs

# View analysis output
kubectl -n migrate logs job/migrate-analyze

# View diff output (migration SQL)
kubectl -n migrate logs job/migrate-diff
```

### Option 2: Helm Chart

```bash
# Add your values
cat > my-values.yaml <<EOF
migration:
  command: analyze
  source:
    connectionString: "postgres://user:pass@mydb:5432/production"
  output:
    format: json
EOF

# Install
helm install migrate ./helm/migrate -f my-values.yaml

# Or with inline values
helm install migrate ./helm/migrate \
  --set migration.command=analyze \
  --set migration.source.connectionString="postgres://user:pass@mydb:5432/prod"
```

## Examples

### Analyze a Live Database

```yaml
# values-analyze.yaml
migration:
  command: analyze
  source:
    connectionString: "postgres://readonly:${PASSWORD}@prod-db:5432/myapp"
  output:
    format: json

secrets:
  sourcePassword: "your-password-here"
```

```bash
helm install analyze-prod ./helm/migrate -f values-analyze.yaml
```

### Generate Migration SQL (Diff Two Schemas)

```yaml
# values-diff.yaml
migration:
  command: diff
  source:
    sqlFile: source.sql
    dialect: postgres
  target:
    sqlFile: target.sql
    dialect: postgres
  output:
    format: sql

sqlFiles:
  source.sql: |
    CREATE TABLE users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255)
    );
  target.sql: |
    CREATE TABLE users (
      id SERIAL PRIMARY KEY,
      email VARCHAR(255),
      name VARCHAR(100)
    );
```

```bash
helm install migration-gen ./helm/migrate -f values-diff.yaml
kubectl logs job/migration-gen-migrate-<timestamp>
# Output: ALTER TABLE users ADD COLUMN name VARCHAR(100);
```

### Transform Schema Between Dialects

```yaml
# values-transform.yaml
migration:
  command: transform
  transform:
    fromDialect: postgres
    toDialect: mysql
    inputFile: schema.sql

sqlFiles:
  schema.sql: |
    CREATE TABLE users (
      id SERIAL PRIMARY KEY,
      data JSONB
    );
```

```bash
helm install pg-to-mysql ./helm/migrate -f values-transform.yaml
# Output: MySQL-compatible schema
```

### Scheduled Drift Detection (CronJob)

```yaml
# values-cronjob.yaml
migration:
  command: analyze
  source:
    connectionString: "postgres://monitor:${PASSWORD}@prod:5432/app"
  output:
    format: json

cronJob:
  enabled: true
  schedule: "0 */6 * * *"  # Every 6 hours

secrets:
  sourcePassword: "monitoring-password"
```

```bash
helm install drift-monitor ./helm/migrate -f values-cronjob.yaml
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/schema-check.yml
name: Schema Drift Check

on:
  schedule:
    - cron: '0 6 * * *'
  workflow_dispatch:

jobs:
  check-drift:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/k8s-set-context@v3
        with:
          kubeconfig: ${{ secrets.KUBECONFIG }}

      - name: Run schema analysis
        run: |
          kubectl create job --from=cronjob/migrate-drift-check drift-check-manual
          kubectl wait --for=condition=complete job/drift-check-manual --timeout=300s
          kubectl logs job/drift-check-manual
```

### GitLab CI Example

```yaml
# .gitlab-ci.yml
schema-analysis:
  stage: validate
  script:
    - helm upgrade --install schema-check ./deploy/migrate
        --set migration.command=analyze
        --set migration.source.connectionString="${DB_CONNECTION}"
        --wait
    - kubectl logs job/schema-check-migrate-$(date +%Y%m%d)
```

## Configuration Reference

### Helm Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `migration.command` | Command: analyze, diff, transform | `analyze` |
| `migration.source.connectionString` | Database connection string | `""` |
| `migration.source.sqlFile` | SQL file path (in ConfigMap) | `""` |
| `migration.source.dialect` | SQL dialect | `postgres` |
| `migration.output.format` | Output: text, json, yaml, sql | `json` |
| `cronJob.enabled` | Enable CronJob instead of Job | `false` |
| `cronJob.schedule` | Cron schedule | `0 2 * * *` |

See `helm/migrate/values.yaml` for full configuration options.

## Security Considerations

1. **Use Secrets**: Never put credentials in ConfigMaps or command args
2. **Read-Only Access**: Use read-only database credentials for analysis
3. **Network Policies**: Restrict pod network access to only required databases
4. **RBAC**: The included ServiceAccount has minimal permissions

### Example Network Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: migrate-egress
  namespace: migrate
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: migrate
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8  # Internal database network
      ports:
        - protocol: TCP
          port: 5432  # PostgreSQL
        - protocol: TCP
          port: 3306  # MySQL
        - protocol: TCP
          port: 1433  # SQL Server
```

## Troubleshooting

### Job Failed

```bash
# Check pod status
kubectl -n migrate describe job/migrate-analyze

# Check pod logs
kubectl -n migrate logs -l app.kubernetes.io/name=migrate

# Check events
kubectl -n migrate get events --sort-by='.lastTimestamp'
```

### Connection Issues

```bash
# Test connectivity from within cluster
kubectl run -n migrate test-conn --rm -it --image=postgres:15 -- \
  psql "postgres://user:pass@your-db:5432/dbname" -c "SELECT 1"
```

## Building the Container Image

If you need to build your own image:

```dockerfile
# Dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o migrate ./cmd/migrate

FROM alpine:3.19
RUN apk add --no-cache ca-certificates
COPY --from=builder /app/migrate /usr/local/bin/
ENTRYPOINT ["migrate"]
```

```bash
docker build -t ghcr.io/egoughnour/migrate:latest .
docker push ghcr.io/egoughnour/migrate:latest
```

## License

MIT License - see [LICENSE](../LICENSE) for details.
