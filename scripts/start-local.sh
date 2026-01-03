#!/bin/bash
set -e

echo "Starting Minikube..."
minikube start --memory=4096 --cpus=2
minikube addons enable ingress

echo "Creating namespace..."
kubectl create namespace social-media 2>/dev/null || true

echo "Deploying infrastructure..."
kubectl apply -f k8s/keycloak-postgres.yaml
kubectl apply -f k8s/keycloak.yaml
kubectl apply -f k8s/backend/infrastructure/

echo "Waiting for infrastructure..."
kubectl wait --for=condition=ready pod -l app=keycloak-postgres -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=keycloak -n social-media --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongodb -n social-media --timeout=120s

echo "Deploying services..."
kubectl apply -f k8s/backend/services/
kubectl apply -f k8s/frontend.yaml

echo "Waiting for services..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=user-service -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=core -n social-media --timeout=120s

echo "Starting port forwards..."
kubectl port-forward -n social-media svc/core 3000:3000 &
kubectl port-forward -n social-media svc/api-gateway 8080:8080 &
kubectl port-forward -n social-media svc/keycloak 8180:8080 &
kubectl port-forward -n social-media svc/mailhog 8025:8025 &

echo ""
echo "=========================================="
echo "Application is ready!"
echo "Frontend:       http://localhost:3000"
echo "Backend API:    http://localhost:8080"
echo "Keycloak Admin: http://localhost:8180"
echo "MailHog:        http://localhost:8025"
echo "=========================================="
echo ""
echo "Press Ctrl+C to stop port forwards"
wait
