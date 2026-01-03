# Social Media K8s - Kubernetes Manifests

## Overview

Social Media uygulamasının Kubernetes deployment manifests'leri. PostgreSQL, Backend ve Frontend servislerinin tüm konfigürasyonlarını içerir.

## Namespace

Tüm kaynaklar `social-media` namespace'inde çalışır:
```bash
kubectl create namespace social-media
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     social-media namespace                   │
│                                                             │
│  ┌─────────┐     ┌─────────┐     ┌─────────────────────┐   │
│  │ Ingress │────▶│  core   │────▶│ auth    │  social   │   │
│  │ (nginx) │     │  :3000  │     │ :3001   │  :3002    │   │
│  └─────────┘     └─────────┘     └─────────────────────┘   │
│                        │                    │               │
│                        ▼                    ▼               │
│                  ┌──────────┐         ┌──────────┐         │
│                  │ backend  │────────▶│ postgres │         │
│                  │  :8080   │         │  :5432   │         │
│                  └──────────┘         └──────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## Manifest Files

| File | Description |
|------|-------------|
| `postgres.yaml` | PostgreSQL database deployment |
| `backend.yaml` | Spring Boot backend deployment |
| `frontend.yaml` | Next.js micro-frontends (core, auth, social) |
| `ingress.yaml` | NGINX Ingress routing rules |

## postgres.yaml

### Resources
- **ConfigMap**: `postgres-config` - Database credentials
- **PersistentVolumeClaim**: `postgres-pvc` - Data persistence
- **Deployment**: `postgres` - PostgreSQL 16 Alpine
- **Service**: `postgres` - ClusterIP on port 5432

### Configuration
```yaml
POSTGRES_DB: socialmedia
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres
```

## backend.yaml

### Resources
- **ConfigMap**: `backend-config` - Spring configuration
- **Deployment**: `backend` - Java 21 Spring Boot app
- **Service**: `backend` - ClusterIP on port 8080

### Configuration
```yaml
SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/socialmedia
SPRING_DATASOURCE_USERNAME: postgres
SPRING_DATASOURCE_PASSWORD: postgres
SPRING_JPA_HIBERNATE_DDL_AUTO: update
```

### Health Checks
- Liveness: `/actuator/health`
- Readiness: `/actuator/health`

## frontend.yaml

### Core App
- **ConfigMap**: `core-config`
  - `AUTH_SERVICE_URL`: http://auth:3001
  - `SOCIAL_SERVICE_URL`: http://social:3002
- **Deployment**: `core` - Shell application
- **Service**: `core` - ClusterIP on port 3000

### Auth App
- **ConfigMap**: `auth-config`
  - `NEXT_PUBLIC_API_URL`: http://backend:8080
- **Deployment**: `auth` - Authentication module
- **Service**: `auth` - ClusterIP on port 3001

### Social App
- **ConfigMap**: `social-config`
  - `NEXT_PUBLIC_API_URL`: http://backend:8080
- **Deployment**: `social` - Social features module
- **Service**: `social` - ClusterIP on port 3002

## ingress.yaml

### Routing Rules
```yaml
Host: social-media.local

/api/*     → backend:8080    # API requests
/login     → auth:3001       # Auth pages
/register  → auth:3001
/profile   → auth:3001
/feed      → social:3002     # Social pages
/users     → social:3002
/          → core:3000       # Default to shell
```

## Deployment Order

```bash
# 1. Create namespace
kubectl create namespace social-media

# 2. Deploy database first (dependencies)
kubectl apply -f postgres.yaml
kubectl wait --for=condition=ready pod -l app=postgres -n social-media

# 3. Deploy backend
kubectl apply -f backend.yaml
kubectl wait --for=condition=ready pod -l app=backend -n social-media

# 4. Deploy frontend apps
kubectl apply -f frontend.yaml
kubectl wait --for=condition=ready pod -l app=core -n social-media
kubectl wait --for=condition=ready pod -l app=auth -n social-media
kubectl wait --for=condition=ready pod -l app=social -n social-media

# 5. Deploy ingress
kubectl apply -f ingress.yaml
```

## Port Forwarding (Local Access)

```bash
# All services
kubectl port-forward svc/core 3000:3000 -n social-media &
kubectl port-forward svc/auth 3001:3001 -n social-media &
kubectl port-forward svc/social 3002:3002 -n social-media &
kubectl port-forward svc/backend 8080:8080 -n social-media &
```

## Minikube Setup

```bash
# Start Minikube
minikube start

# Enable ingress addon
minikube addons enable ingress

# Use Minikube's Docker daemon
eval $(minikube docker-env)

# Build images (from project directories)
docker build -t social-media-backend:latest .
docker build -t social-media-core:latest -f apps/core/Dockerfile .
docker build -t social-media-auth:latest -f apps/auth/Dockerfile .
docker build -t social-media-social:latest -f apps/social/Dockerfile .
```

## Common Commands

```bash
# Check all pods
kubectl get pods -n social-media

# Check services
kubectl get svc -n social-media

# View logs
kubectl logs -f deployment/backend -n social-media
kubectl logs -f deployment/core -n social-media

# Restart deployment
kubectl rollout restart deployment/core -n social-media

# Scale deployment
kubectl scale deployment/backend --replicas=3 -n social-media

# Delete all resources
kubectl delete namespace social-media
```

## Resource Limits

All deployments have resource limits:
```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "50m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

Backend (Java) has higher limits:
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod <pod-name> -n social-media
kubectl logs <pod-name> -n social-media
```

### Service not reachable
```bash
kubectl get endpoints -n social-media
kubectl exec -it <pod> -- curl http://service:port
```

### Image not found
```bash
# Ensure using Minikube Docker
eval $(minikube docker-env)
docker images | grep social-media
```

## Production Considerations

- [ ] Use Secrets instead of ConfigMaps for passwords
- [ ] Add resource quotas and limit ranges
- [ ] Configure horizontal pod autoscaling (HPA)
- [ ] Set up monitoring (Prometheus/Grafana)
- [ ] Configure log aggregation (ELK/Loki)
- [ ] Use external PostgreSQL (RDS, Cloud SQL)
- [ ] Set up TLS certificates (cert-manager)
- [ ] Configure network policies
