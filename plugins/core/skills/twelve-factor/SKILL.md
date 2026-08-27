---
name: twelve-factor
description: Guide for 12-Factor cloud-native applications. Use when designing microservices, configuring containers, deploying to Kubernetes, or following cloud-native patterns.
license: MIT
---

# 12-Factor App Methodology

Guide for building scalable, maintainable, and portable cloud-native applications following the 12-Factor App principles and modern extensions.

## Anti-fabrication

This skill follows `core:anti-fabrication`. The 12 factors themselves are the
methodology cited in `sources.md` (12factor.net) — a stable, versionless reference, so
naming a factor correctly is low-risk. The risk sits in the worked examples: the
Kubernetes manifests, `runtime.exs` snippets, and Docker Compose configs in
`references/kubernetes.md` and `references/factor-examples.md` assert real API fields
(e.g. `livenessProbe`, `ConfigMap` keys) that do change across Kubernetes versions —
verify a manifest field against current API docs before asserting it applies, rather
than assuming an older example still matches the current API.

## The 12 Factors

### I. Codebase

**One codebase tracked in revision control, many deploys**

- Single Git repository for the application; every environment deploys from it
- Environment-specific config lives outside the code
- Use GitOps (ArgoCD, Flux) for deployment automation

Violations: multiple repositories for one application, per-environment codebases, copying code between repositories. Fix: consolidate to one repository and move the differences into environment config.

### II. Dependencies

**Explicitly declare and isolate dependencies**

- Declare every dependency in the package manager manifest; never rely on system-wide packages
- Commit lock files for reproducible builds (`package-lock.json`, `mix.lock`, `Cargo.lock`, `go.sum`)
- Multi-stage container builds isolate build-time dependencies from the runtime image

Worked Dockerfile and per-language manifest list: `references/factor-examples.md`.

### III. Config

**Store config in the environment**

All configuration comes from environment variables — anything that varies between deploys: credentials, hostnames, ports, pool sizes, backing service URLs, model names.

```elixir
# Elixir - config/runtime.exs
config :my_app, MyApp.Repo,
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  password: System.fetch_env!("DATABASE_PASSWORD"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

What makes a violation, and the smallest correct fix:

- Hardcoded value that differs (or could differ) between deploys → read it from an environment variable, with a default only when a safe dev default exists
- Hardcoded model name, API endpoint, or service hostname → environment variable; model names are config, not code
- Config file with real values committed to version control → environment variables plus a committed `.example` template
- Environment-specific code path (`if env == "production"`) → one code path driven by a config value

Litmus test from 12factor.net: the codebase could be made open source at any moment without compromising any credentials.

Kubernetes ConfigMap/Secret wiring: `references/kubernetes.md`.

### IV. Backing Services

**Treat backing services as attached resources**

- Databases, queues, caches, and third-party APIs all attach via URLs in environment variables
- No distinction between local and third-party services
- Swapping a backing service is a configuration change only — never a code change

### V. Build, Release, Run

**Strictly separate build and run stages**

1. **Build**: convert code to executable bundle
2. **Release**: combine build with config
3. **Run**: execute in target environment

- Releases are immutable and uniquely identified (git SHA, semver)
- Roll back by redeploying a previous release, never by modifying one
- Build artifacts stay separate from runtime config

CI/CD pipeline example: `references/factor-examples.md`.

### VI. Processes

**Execute the app as one or more stateless processes**

- Processes are stateless and share-nothing; persistent state lives in backing services
- No sticky sessions, no local filesystem for persistent data
- Violation: in-memory session or state store → move it to Redis or the database

Session-store example: `references/factor-examples.md`. Deployment manifest: `references/kubernetes.md`.

### VII. Port Binding

**Export services via port binding**

- Bind to `0.0.0.0`, never `localhost`; take the port number from the environment
- HTTP server library embedded in the app — no reliance on runtime injection (Apache, Nginx)

### VIII. Concurrency

**Scale out via the process model**

- Scale horizontally by adding processes, not vertically by enlarging them
- Distinct process types (web, worker, scheduler) scale independently
- The OS or platform process manager owns processes — never daemonize or write PID files

### IX. Disposability

**Maximize robustness with fast startup and graceful shutdown**

- Minimize startup time (under 10 seconds ideal) — fast startup enables rapid scaling
- Handle SIGTERM: finish in-flight requests, close connections, then exit
<!-- vale Flavored.Superlatives = NO -->
- Stay robust against sudden death
<!-- vale Flavored.Superlatives = YES -->

Graceful-shutdown example: `references/factor-examples.md`.

### X. Dev/Prod Parity

**Keep development, staging, and production as similar as possible**

- Same backing service types in dev and prod (not SQLite in dev, Postgres in prod)
- Containers ensure environment consistency; infrastructure as code for reproducibility
- Same deployment process for all environments; minimize the time gap between dev and production

Docker Compose dev-environment example: `references/factor-examples.md`.

### XI. Logs

**Treat logs as event streams**

- Write unbuffered to stdout/stderr; never manage or rotate log files in the app
- Use structured logging (JSON) with correlation IDs for tracing
- The platform routes logs (Fluentd, Logstash) — never send directly to an aggregation service from app code

### XII. Admin Processes

**Run admin/management tasks as one-off processes**

- Migrations, consoles, and one-time scripts use the same codebase, config, and environment as regular processes
- Run against a release, not development code
- Use the platform scheduler for recurring tasks; ship admin code with application code

Kubernetes Job/CronJob examples: `references/kubernetes.md`.

## Modern Extensions (Beyond 12)

Three extensions round out contemporary cloud-native practice — full detail and examples in `references/modern-extensions.md`:

- **XIII. API First** — design and document APIs (OpenAPI) before implementation; contract-first development
- **XIV. Telemetry** — `/metrics` endpoint, distributed tracing (OpenTelemetry), health check endpoints
- **XV. Security** — OAuth 2.0/OIDC, RBAC, secrets in environment never in code, TLS everywhere, security scanning in CI/CD

## Common Patterns

### Configuration Validation

Validate required configuration at startup — fail fast, naming the missing variables:

```javascript
function validateConfig() {
  const required = ['DATABASE_URL', 'JWT_SECRET', 'REDIS_URL'];
  const missing = required.filter(key => !process.env[key]);

  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
}

// Call before starting server
validateConfig();
```

Health checks, graceful degradation, and the troubleshooting guide: `references/operations.md`.

## Anti-Patterns to Avoid

### ❌ Environment-Specific Code Paths

```javascript
// DON'T: branch on environment
if (process.env.NODE_ENV === 'production') { /* different behavior */ }

// DO: one code path, configured value
const timeout = parseInt(process.env.TIMEOUT || '5000');
```

### ❌ Local File Storage

```javascript
// DON'T: write persistent data to local filesystem
fs.writeFile('/tmp/uploads/' + filename, data);

// DO: use object storage
await s3.putObject({ Bucket: process.env.S3_BUCKET, Key: filename, Body: data });
```

### ❌ In-Memory State

```javascript
// DON'T: store state in memory
const sessions = new Map();

// DO: use external store
const session = await redis.get(`session:${sessionId}`);
```

### ❌ Hardcoded Dependencies

```javascript
// DON'T: hardcode service locations
const db = connect('localhost:5432');

// DO: use environment variables
const db = connect(process.env.DATABASE_URL);
```

## Best Practices Summary

1. **Environment variables for all configuration**
2. **Stateless processes that can scale horizontally**
3. **Structured logging to stdout**
4. **Containers for development parity**
5. **Automated CI/CD pipelines**
6. **Health checks for orchestration**
7. **Graceful shutdown handling**
8. **Fast startup times (< 10s)**
9. **Immutable releases with unique IDs**
10. **Monitoring and telemetry via metrics and tracing**

## Resources

- **12factor.net**: Original methodology
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **Docker Best Practices**: https://docs.docker.com/develop/dev-best-practices/
- **OpenTelemetry**: https://opentelemetry.io/
- **Prometheus**: https://prometheus.io/

## Key Insights

> "The twelve-factor methodology can be applied to apps written in any programming language, and which use any combination of backing services (database, queue, memory cache, etc)."

> "The twelve-factor app never assumes that anything cached in memory or on disk will be available on a future request or job – with many processes of each type running, chances are high that a future request will be served by a different process." — [Factor VI, Processes](https://12factor.net/processes)

Design applications from day one to be cloud-native, scalable, and maintainable.

## References

- `references/factor-examples.md` — per-factor worked code examples (Dockerfile, runtime config, session storage, graceful shutdown, Docker Compose, structured logging, CI/CD pipeline)
- `references/kubernetes.md` — Kubernetes manifests per factor (ConfigMaps, Secrets, Deployments, HPA, Jobs, probes) and Kubernetes-specific best practices
- `references/modern-extensions.md` — API First, Telemetry, and Security extensions with examples
- `references/operations.md` — health check endpoints, graceful degradation, troubleshooting guide
- `references/infrastructure-conventions.md` — NGINX upstream over community ingress; Kustomize + Helm layout; single universal secret store; IaC over manual UI; bind all interfaces in prod
