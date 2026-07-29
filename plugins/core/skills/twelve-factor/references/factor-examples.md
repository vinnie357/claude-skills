# Per-Factor Worked Examples

Language-level code examples for the twelve factors. Kubernetes manifests live in `kubernetes.md`.

## Table of Contents

- [I. Codebase — repository layout](#i-codebase--repository-layout)
- [II. Dependencies — multi-stage Dockerfile](#ii-dependencies--multi-stage-dockerfile)
- [III. Config — environment-driven configuration](#iii-config--environment-driven-configuration)
- [IV. Backing Services — uniform attachment](#iv-backing-services--uniform-attachment)
- [V. Build, Release, Run — CI/CD pipeline](#v-build-release-run--cicd-pipeline)
- [VI. Processes — stateless session storage](#vi-processes--stateless-session-storage)
- [VII. Port Binding — self-contained servers](#vii-port-binding--self-contained-servers)
- [VIII. Concurrency — process types](#viii-concurrency--process-types)
- [IX. Disposability — graceful shutdown](#ix-disposability--graceful-shutdown)
- [X. Dev/Prod Parity — Docker Compose](#x-devprod-parity--docker-compose)
- [XI. Logs — structured logging to stdout](#xi-logs--structured-logging-to-stdout)

## I. Codebase — repository layout

```
myapp-repo/
├── src/
├── config/
├── deploy/
│   ├── staging/
│   ├── production/
│   └── development/
└── Dockerfile
```

## II. Dependencies — multi-stage Dockerfile

```dockerfile
# Multi-stage build for dependency isolation
FROM node:18-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:18-alpine AS runtime
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
CMD ["node", "index.js"]
```

**Language-specific dependency manifests:**
- Node.js: `package.json` and `package-lock.json`
- Python: `requirements.txt` or `Pipfile.lock`
- Java: `pom.xml` or `build.gradle`
- Go: `go.mod` and `go.sum`
- Elixir: `mix.exs` and `mix.lock`
- Rust: `Cargo.toml` and `Cargo.lock`

## III. Config — environment-driven configuration

```elixir
# Elixir - config/runtime.exs
import Config

config :my_app, MyApp.Repo,
  database: System.get_env("DATABASE_NAME") || "my_app_dev",
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.fetch_env!("DATABASE_PASSWORD"),
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
```

```javascript
// Node.js
const config = {
  database: {
    url: process.env.DATABASE_URL,
    pool: {
      min: parseInt(process.env.DB_POOL_MIN || '2'),
      max: parseInt(process.env.DB_POOL_MAX || '10')
    }
  },
  cache: {
    ttl: parseInt(process.env.CACHE_TTL || '3600')
  }
};
```

## IV. Backing Services — uniform attachment

```javascript
// Treat all backing services uniformly
const services = {
  database: createConnection(process.env.DATABASE_URL),
  cache: createRedisClient(process.env.REDIS_URL),
  queue: createQueueClient(process.env.RABBITMQ_URL),
  storage: createS3Client(process.env.S3_ENDPOINT)
};
```

## V. Build, Release, Run — CI/CD pipeline

```yaml
# GitHub Actions CI/CD Pipeline
name: Build and Deploy
on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7.0.1
      - name: Build Docker image
        run: docker build -t myapp:${{ github.sha }} .
      - name: Push to registry
        run: docker push myapp:${{ github.sha }}

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Kubernetes
        run: kubectl set image deployment/myapp myapp=myapp:${{ github.sha }}
```

## VI. Processes — stateless session storage

```javascript
// ❌ Bad: In-memory session store
app.use(session({
  secret: process.env.SESSION_SECRET,
  resave: false
  // Uses memory store by default
}));

// ✓ Good: Store session in Redis
app.use(session({
  store: new RedisStore({
    client: redisClient,
    prefix: 'sess:'
  }),
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false
}));
```

## VII. Port Binding — self-contained servers

```javascript
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});
```

```elixir
# Phoenix endpoint config
config :my_app, MyAppWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT") || "4000")],
  server: true
```

## VIII. Concurrency — process types

```
web: node server.js
worker: node worker.js
scheduler: node scheduler.js
```

Procfile-style process types: different process types for different workloads, each scalable independently.

## IX. Disposability — graceful shutdown

```javascript
const server = app.listen(port, () => {
  console.log('Server started');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');

  server.close(() => {
    // Close database connections
    db.close();

    // Close other connections
    redis.quit();

    console.log('Process terminated');
    process.exit(0);
  });
});
```

## X. Dev/Prod Parity — Docker Compose

```yaml
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
      - REDIS_URL=redis://redis:6379
    depends_on:
      - db
      - redis

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass

  redis:
    image: redis:7-alpine
```

## XI. Logs — structured logging to stdout

```javascript
// Structured logging to stdout
const winston = require('winston');

const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

logger.info('User logged in', {
  userId: 123,
  ip: '192.0.2.1',
  userAgent: 'Mozilla/5.0...'
});
```

```elixir
# Elixir structured logging
require Logger

Logger.info("User logged in",
  user_id: 123,
  ip: "192.0.2.1"
)
```
