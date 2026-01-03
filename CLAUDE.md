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
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              social-media namespace                              │
│                                                                                  │
│  ┌─────────────┐     ┌─────────────────────────────────────────────────────┐    │
│  │   Ingress   │────▶│  core:3000  │  auth:3001  │  social:3002            │    │
│  │   (nginx)   │     │  (Shell)    │  (Auth UI)  │  (Social UI)            │    │
│  └─────────────┘     └─────────────────────────────────────────────────────┘    │
│         │                              │                                         │
│         ▼                              ▼                                         │
│  ┌─────────────┐     ┌─────────────────────────────────────────────────────┐    │
│  │ API Gateway │────▶│ user-service:8081 │ social-service:8082             │    │
│  │   :8080     │     │     (MongoDB)     │      (MongoDB)                  │    │
│  └─────────────┘     └─────────────────────────────────────────────────────┘    │
│         │                              │                                         │
│         ▼                              ▼                                         │
│  ┌─────────────┐     ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  Discovery  │     │ Keycloak │  │ Postgres │  │ MongoDB  │  │  Redis   │    │
│  │  (Eureka)   │     │  :8080   │  │  :5432   │  │  :27017  │  │  :6379   │    │
│  │   :8761     │     └────┬─────┘  └──────────┘  └──────────┘  └──────────┘    │
│  └─────────────┘          │                                                      │
│                           ▼                                                      │
│  ┌─────────────┐     ┌──────────┐  ┌──────────┐  ┌──────────┐                   │
│  │  Kafka UI   │────▶│  Kafka   │  │  Vault   │  │ Keycloak │                   │
│  │   :8080     │     │  :9092   │  │  :8200   │  │ Postgres │                   │
│  └─────────────┘     └──────────┘  └──────────┘  └──────────┘                   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Manifest Files

### Root Manifests
| File | Description |
|------|-------------|
| `postgres.yaml` | PostgreSQL database deployment (app data) |
| `backend.yaml` | Spring Boot backend deployment |
| `frontend.yaml` | Next.js micro-frontends (core, auth, social) |
| `ingress.yaml` | NGINX Ingress routing rules |
| `keycloak-postgres.yaml` | PostgreSQL for Keycloak (identity data) |
| `keycloak.yaml` | Keycloak identity server |

### Backend Infrastructure (`backend/infrastructure/`)
| File | Description |
|------|-------------|
| `mongodb.yaml` | MongoDB for microservices |
| `redis.yaml` | Redis cache |
| `kafka.yaml` | Apache Kafka message broker |
| `kafka-ui.yaml` | Kafka UI for monitoring topics/messages |
| `vault-values.yaml` | HashiCorp Vault Helm values |

### Backend Services (`backend/services/`)
| File | Description |
|------|-------------|
| `discovery-server.yaml` | Eureka service discovery |
| `api-gateway.yaml` | Spring Cloud Gateway |
| `user-service.yaml` | User microservice |
| `social-service.yaml` | Social features microservice |

### Documentation
| File | Description |
|------|-------------|
| `docs/KEYCLOAK_SETUP.md` | Keycloak kurulum ve konfigürasyon rehberi |
| `docs/KEYCLOAK_CONFIG.md` | Keycloak konfigürasyon referansı (clients, roles, users) |
| `scripts/configure-keycloak.sh` | Otomatik Keycloak konfigürasyon scripti |

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

## Keycloak (Identity & Access Management)

### Kubernetes Resources

**keycloak-postgres.yaml:**
- **Secret**: `keycloak-db-secret` - Database credentials
- **PersistentVolumeClaim**: `keycloak-postgres-pvc` - 5Gi persistent storage
- **Deployment**: `keycloak-postgres` - Dedicated PostgreSQL for Keycloak
- **Service**: `keycloak-postgres` - ClusterIP on port 5432

**keycloak.yaml:**
- **Secret**: `keycloak-secret` - Admin credentials
- **ConfigMap**: `keycloak-config` - Keycloak configuration
- **Deployment**: `keycloak` - Keycloak 24.0
- **Service**: `keycloak` - ClusterIP on port 8080

### Realm Configuration

**Realm**: `social-media`

| Client | Type | Flow | Kullanım |
|--------|------|------|----------|
| `social-media-frontend` | Public | Authorization Code + PKCE | UI Authentication |
| `social-media-backend` | Confidential | Direct Access, Service Account | API Resource Server |
| `social-media-service` | Confidential | Client Credentials | Service-to-Service |

**Roles:**
| Role | Description |
|------|-------------|
| `user` | Default - create/edit/delete own content |
| `moderator` | Delete any post/comment |
| `admin` | Full access |

**Test Users:**
| Username | Password | Role |
|----------|----------|------|
| testuser | test123 | user |
| moderator | mod123 | moderator |
| adminuser | admin123 | admin |

### Client Secrets

```bash
# Backend Client
social-media-backend: nQCIaPfA1xCdm6MKJ9FORh5KGC0nLrwa

# Service Client (machine-to-machine)
social-media-service: 1nzswpyIFadAKnlmAMPcMEtpGSKQxBNk
```

### Quick Start

```bash
# 1. Port forward Keycloak
kubectl port-forward svc/keycloak 8180:8080 -n social-media

# 2. Run configuration script
./scripts/configure-keycloak.sh

# 3. Test login
curl -X POST "http://localhost:8180/realms/social-media/protocol/openid-connect/token" \
  -d "username=testuser&password=test123&grant_type=password" \
  -d "client_id=social-media-backend&client_secret=nQCIaPfA1xCdm6MKJ9FORh5KGC0nLrwa"
```

### Endpoints

| Endpoint | URL |
|----------|-----|
| Admin Console | http://localhost:8180/admin/social-media/console/ |
| Token | http://localhost:8180/realms/social-media/protocol/openid-connect/token |
| JWKS | http://localhost:8180/realms/social-media/protocol/openid-connect/certs |

### Documentation

- `docs/KEYCLOAK_SETUP.md` - Detaylı kurulum rehberi
- `docs/KEYCLOAK_CONFIG.md` - Client, role, user konfigürasyonu

---

## Deployment Order

```bash
# 1. Create namespace
kubectl create namespace social-media

# 2. Deploy databases first (dependencies)
kubectl apply -f postgres.yaml
kubectl apply -f keycloak-postgres.yaml
kubectl wait --for=condition=ready pod -l app=postgres -n social-media
kubectl wait --for=condition=ready pod -l app=keycloak-postgres -n social-media

# 3. Deploy Keycloak
kubectl apply -f keycloak.yaml
kubectl wait --for=condition=ready pod -l app=keycloak -n social-media --timeout=300s

# 4. Configure Keycloak (realm, clients, roles, users)
kubectl port-forward svc/keycloak 8180:8080 -n social-media &
sleep 5
./scripts/configure-keycloak.sh
pkill -f "kubectl port-forward.*keycloak"

# 5. Deploy backend
kubectl apply -f backend.yaml
kubectl wait --for=condition=ready pod -l app=backend -n social-media

# 6. Deploy frontend apps
kubectl apply -f frontend.yaml
kubectl wait --for=condition=ready pod -l app=core -n social-media
kubectl wait --for=condition=ready pod -l app=auth -n social-media
kubectl wait --for=condition=ready pod -l app=social -n social-media

# 7. Deploy ingress
kubectl apply -f ingress.yaml
```

---

## Kafka & Kafka UI

### Kafka (Message Broker)
- **Deployment**: `kafka` - Apache Kafka 3.7.0 (KRaft mode, no Zookeeper)
- **Service**: `kafka` - ClusterIP on port 9092

### Kafka UI
- **Deployment**: `kafka-ui` - Provectus Kafka UI
- **Service**: `kafka-ui` - ClusterIP on port 8080

### Quick Start
```bash
# Access Kafka UI
kubectl port-forward svc/kafka-ui 9000:8080 -n social-media

# Open browser: http://localhost:9000
```

### Features
- Topic management (create, delete, view messages)
- Consumer group monitoring
- Broker metrics
- Message production/consumption

---

## HashiCorp Vault (Secret Management)

### Overview
HashiCorp Vault kullanarak tüm secret'lar merkezi olarak yönetilir. Vault, Helm ile kurulmuştur ve Kubernetes auth method'u yapılandırılmıştır.

### Components
- **vault-0**: Vault server (dev mode)
- **vault-agent-injector**: Sidecar injection for pods

### Stored Secrets
| Path | Description |
|------|-------------|
| `secret/social-media/postgres` | PostgreSQL credentials |
| `secret/social-media/keycloak-postgres` | Keycloak DB credentials |
| `secret/social-media/keycloak` | Keycloak admin credentials |
| `secret/social-media/oauth2-clients` | OAuth2 client secrets |
| `secret/social-media/mongodb` | MongoDB connection |
| `secret/social-media/redis` | Redis connection |

### Quick Start
```bash
# Access Vault UI
kubectl port-forward svc/vault 8200:8200 -n social-media

# Open browser: http://localhost:8200
# Token: root (dev mode)

# CLI access
kubectl exec -n social-media vault-0 -- vault kv get secret/social-media/postgres
```

### Reading Secrets from Pods
```yaml
# Pod annotation for Vault Agent injection
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "social-media-role"
  vault.hashicorp.com/agent-inject-secret-db: "secret/data/social-media/postgres"
```

### Vault Commands
```bash
# List all secrets
kubectl exec -n social-media vault-0 -- vault kv list secret/social-media/

# Get a secret
kubectl exec -n social-media vault-0 -- vault kv get secret/social-media/postgres

# Update a secret
kubectl exec -n social-media vault-0 -- vault kv put secret/social-media/postgres \
  username="postgres" password="new-password" database="socialmedia"
```

---

## Observability Stack

Full observability stack Helm ile kurulmuştur:

### Components

| Component | Purpose | Port | Helm Chart |
|-----------|---------|------|------------|
| **Prometheus** | Metrics collection | 9090 | prometheus-community/prometheus |
| **Grafana** | Visualization & Dashboards | 3000 | grafana/grafana |
| **Loki** | Log aggregation | 3100 | grafana/loki-stack |
| **Promtail** | Log shipping (DaemonSet) | - | grafana/loki-stack |
| **Tempo** | Distributed tracing | 3100 | grafana/tempo |

### Quick Start

```bash
# Grafana UI (Dashboards, Logs, Traces)
kubectl port-forward svc/grafana 3333:3000 -n social-media
# http://localhost:3333
# Username: admin / Password: admin123

# Prometheus UI (Metrics queries)
kubectl port-forward svc/prometheus-server 9090:80 -n social-media
# http://localhost:9090
```

### Grafana Datasources (Pre-configured)

| Datasource | Type | URL | Default |
|------------|------|-----|---------|
| Prometheus | prometheus | http://prometheus-server:80 | Yes |
| Loki | loki | http://loki:3100 | No |
| Tempo | tempo | http://tempo:3100 | No |

### Pre-installed Dashboards

- **Spring Boot 2.1 Statistics** (ID: 12900)
- **Kubernetes Cluster** (ID: 7249)
- **JVM Micrometer** (ID: 4701)

### Tracing Integration

Tempo, Loki ile entegre edilmiştir. Log'lardan trace'lere, trace'lerden log'lara geçiş yapılabilir:
- Log'larda `traceId` fieldı varsa Tempo'ya link oluşturulur
- Tempo'da trace detayından ilgili log'lara geçiş yapılabilir

### Spring Boot Metrics Configuration

Uygulamaların Prometheus metriklerini expose etmesi için:

```yaml
# application.yml
management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  metrics:
    export:
      prometheus:
        enabled: true
```

Pod annotation'ları (otomatik scraping için):
```yaml
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
```

### Helm Values Files

| File | Description |
|------|-------------|
| `backend/observability/prometheus-values.yaml` | Prometheus configuration |
| `backend/observability/grafana-values.yaml` | Grafana datasources & dashboards |
| `backend/observability/loki-values.yaml` | Loki log aggregation config |
| `backend/observability/tempo-values.yaml` | Tempo tracing config |

### Useful Queries

**Prometheus (Metrics):**
```promql
# HTTP request rate by service
rate(http_server_requests_seconds_count[5m])

# JVM memory usage
jvm_memory_used_bytes{area="heap"}

# Pod CPU usage
rate(container_cpu_usage_seconds_total{namespace="social-media"}[5m])
```

**Loki (Logs):**
```logql
# All logs from backend
{app="backend"}

# Error logs
{namespace="social-media"} |= "ERROR"

# Logs with specific traceId
{app="api-gateway"} | json | traceId="abc123"
```

---

## Port Forwarding (Local Access)

```bash
# Frontend
kubectl port-forward svc/core 3000:3000 -n social-media &
kubectl port-forward svc/auth 3001:3001 -n social-media &
kubectl port-forward svc/social 3002:3002 -n social-media &

# Backend Services
kubectl port-forward svc/backend 8080:8080 -n social-media &
kubectl port-forward svc/api-gateway 8888:8080 -n social-media &
kubectl port-forward svc/discovery-server 8761:8761 -n social-media &

# Infrastructure
kubectl port-forward svc/keycloak 8180:8080 -n social-media &
kubectl port-forward svc/kafka-ui 9000:8080 -n social-media &
kubectl port-forward svc/vault 8200:8200 -n social-media &

# Observability
kubectl port-forward svc/grafana 3333:3000 -n social-media &
kubectl port-forward svc/prometheus-server 9090:80 -n social-media &
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

- [x] Use HashiCorp Vault for secret management
- [x] Set up monitoring (Prometheus/Grafana)
- [x] Configure log aggregation (Loki/Promtail)
- [x] Set up distributed tracing (Tempo)
- [ ] Switch Vault from dev mode to HA mode with persistent storage
- [ ] Enable persistent storage for Prometheus, Loki, Tempo
- [ ] Add resource quotas and limit ranges
- [ ] Configure horizontal pod autoscaling (HPA)
- [ ] Use external PostgreSQL (RDS, Cloud SQL)
- [ ] Set up TLS certificates (cert-manager)
- [ ] Configure network policies
- [ ] Enable Vault audit logging
- [ ] Configure Vault policies per service
- [ ] Set up alerting rules in Prometheus/Alertmanager
