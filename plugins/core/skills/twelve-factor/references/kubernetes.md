# Kubernetes Deployment Patterns for 12-Factor Apps

Kubernetes manifests implementing the twelve factors, plus Kubernetes-specific best practices.

## Table of Contents

- [Config: ConfigMaps and Secrets (Factor III)](#config-configmaps-and-secrets-factor-iii)
- [Backing Services: Service Discovery (Factor IV)](#backing-services-service-discovery-factor-iv)
- [Processes: Stateless Deployments (Factor VI)](#processes-stateless-deployments-factor-vi)
- [Port Binding: Services (Factor VII)](#port-binding-services-factor-vii)
- [Concurrency: Horizontal Pod Autoscaler (Factor VIII)](#concurrency-horizontal-pod-autoscaler-factor-viii)
- [Disposability: Lifecycle Hooks (Factor IX)](#disposability-lifecycle-hooks-factor-ix)
- [Admin Processes: Jobs and CronJobs (Factor XII)](#admin-processes-jobs-and-cronjobs-factor-xii)
- [Kubernetes-Specific Best Practices](#kubernetes-specific-best-practices)

## Config: ConfigMaps and Secrets (Factor III)

**Kubernetes ConfigMaps:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DATABASE_HOST: "postgres-service"
  CACHE_TTL: "3600"
  LOG_LEVEL: "info"
```

**Kubernetes Secrets:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  DATABASE_PASSWORD: <base64-encoded>
  JWT_SECRET: <base64-encoded>
  API_KEY: <base64-encoded>
```

## Backing Services: Service Discovery (Factor IV)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-service
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
```

## Processes: Stateless Deployments (Factor VI)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3  # Can scale horizontally
  selector:
    matchLabels:
      app: myapp
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
```

## Port Binding: Services (Factor VII)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
```

## Concurrency: Horizontal Pod Autoscaler (Factor VIII)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## Disposability: Lifecycle Hooks (Factor IX)

```yaml
spec:
  containers:
  - name: myapp
    image: myapp:latest
    lifecycle:
      preStop:
        exec:
          command: ["/bin/sh", "-c", "sleep 15"]
    terminationGracePeriodSeconds: 30
```

## Admin Processes: Jobs and CronJobs (Factor XII)

```yaml
# Kubernetes Job for database migration
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: myapp:latest
        command: ["npm", "run", "migrate"]
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: app-secrets
              key: DATABASE_URL
      restartPolicy: OnFailure
```

```yaml
# CronJob for scheduled cleanup
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-cleanup
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: cleanup
            image: myapp:latest
            command: ["npm", "run", "cleanup"]
          restartPolicy: OnFailure
```

## Kubernetes-Specific Best Practices

### Resource Limits

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### Init Containers

```yaml
initContainers:
- name: wait-for-db
  image: busybox
  command: ['sh', '-c', 'until nc -z postgres-service 5432; do sleep 1; done']
```

### Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: myapp
```

### Liveness and Readiness Probes

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 3000
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 3000
  initialDelaySeconds: 5
  periodSeconds: 5
```

Endpoint implementations backing these probes are in `operations.md`.
