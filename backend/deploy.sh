#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")/backend/social-media-microservices"

echo "=== Social Media Backend Deployment Script ==="

# Check if minikube is running
if ! minikube status | grep -q "Running"; then
    echo "Starting Minikube..."
    minikube start --memory=8192 --cpus=4
fi

# Set up Docker environment for Minikube
echo "Setting up Docker environment for Minikube..."
eval $(minikube docker-env)

# Create namespace if not exists
echo "Creating namespace..."
kubectl create namespace social-media --dry-run=client -o yaml | kubectl apply -f -

# Build all services
echo "Building all services..."
cd "$BACKEND_DIR"
./mvnw clean package -DskipTests

# Build Docker images
echo "Building Docker images..."
docker build -t social-media/discovery-server:latest ./discovery-server
docker build -t social-media/api-gateway:latest ./api-gateway
docker build -t social-media/user-service:latest ./user-service
docker build -t social-media/social-service:latest ./social-service

# Deploy infrastructure
echo "Deploying infrastructure..."
kubectl apply -f "$SCRIPT_DIR/infrastructure/"

# Wait for infrastructure to be ready
echo "Waiting for infrastructure..."
kubectl wait --for=condition=available --timeout=120s deployment/mongodb -n social-media || true
kubectl wait --for=condition=available --timeout=120s deployment/redis -n social-media || true
kubectl wait --for=condition=available --timeout=120s deployment/zookeeper -n social-media || true
kubectl wait --for=condition=available --timeout=120s deployment/kafka -n social-media || true

# Deploy secrets
echo "Deploying secrets..."
kubectl apply -f "$SCRIPT_DIR/services/secrets.yaml"

# Deploy services
echo "Deploying services..."
kubectl apply -f "$SCRIPT_DIR/services/discovery-server.yaml"
kubectl wait --for=condition=available --timeout=120s deployment/discovery-server -n social-media || true

kubectl apply -f "$SCRIPT_DIR/services/user-service.yaml"
kubectl apply -f "$SCRIPT_DIR/services/social-service.yaml"
kubectl apply -f "$SCRIPT_DIR/services/api-gateway.yaml"

# Deploy observability
echo "Deploying observability stack..."
kubectl apply -f "$SCRIPT_DIR/observability/"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Wait for all pods to be ready:"
echo "  kubectl get pods -n social-media -w"
echo ""
echo "Access URLs:"
echo "  API Gateway: $(minikube service api-gateway -n social-media --url 2>/dev/null || echo 'pending')"
echo "  Prometheus: $(minikube service prometheus -n social-media --url 2>/dev/null || echo 'pending')"
echo "  Grafana: $(minikube service grafana -n social-media --url 2>/dev/null || echo 'pending')"
echo "  Jaeger: $(minikube service jaeger-query -n social-media --url 2>/dev/null || echo 'pending')"
echo "  OpenSearch Dashboards: $(minikube service opensearch-dashboards -n social-media --url 2>/dev/null || echo 'pending')"
