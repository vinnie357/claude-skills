# Modern Extensions (Beyond 12)

Three extensions to the original twelve factors for contemporary cloud-native practice.

## XIII. API First

Design and document APIs before implementation:

```yaml
# OpenAPI specification
openapi: 3.0.0
info:
  title: My API
  version: v1
paths:
  /users:
    get:
      summary: List users
      responses:
        '200':
          description: Success
```

**Key principles:**
- OpenAPI/Swagger specifications
- API versioning (URL or header)
- API gateway pattern
- Contract-first development

## XIV. Telemetry

Observability via metrics, tracing, and monitoring:

```yaml
# Prometheus ServiceMonitor
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
spec:
  selector:
    matchLabels:
      app: myapp
  endpoints:
  - port: metrics
    path: /metrics
```

**Key principles:**
- Expose /metrics endpoint (Prometheus format)
- Distributed tracing (OpenTelemetry)
- Application Performance Monitoring (APM)
- Custom business metrics
- Health check endpoints

## XV. Security

Authentication, authorization, and security by design:

```javascript
// JWT authentication middleware
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) return res.sendStatus(401);

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) return res.sendStatus(403);
    req.user = user;
    next();
  });
}
```

**Key principles:**
- OAuth 2.0 / OpenID Connect
- RBAC (Role-Based Access Control)
- Secrets in environment, never in code
- TLS everywhere
- Security scanning in CI/CD
