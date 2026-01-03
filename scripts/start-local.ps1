Write-Host "Starting Minikube..." -ForegroundColor Green
minikube start --driver=docker --memory=4096 --cpus=2
minikube addons enable ingress

Write-Host "Creating namespace..." -ForegroundColor Green
kubectl create namespace social-media 2>$null

Write-Host "Deploying infrastructure..." -ForegroundColor Green
kubectl apply -f k8s/keycloak-postgres.yaml
kubectl apply -f k8s/keycloak.yaml
kubectl apply -f k8s/backend/infrastructure/

Write-Host "Waiting for infrastructure..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=keycloak-postgres -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=keycloak -n social-media --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongodb -n social-media --timeout=120s

Write-Host "Deploying services..." -ForegroundColor Green
kubectl apply -f k8s/backend/services/
kubectl apply -f k8s/frontend.yaml

Write-Host "Waiting for services..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=api-gateway -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=user-service -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=core -n social-media --timeout=120s

Write-Host "Starting port forwards in background..." -ForegroundColor Green
$job1 = Start-Job { kubectl port-forward -n social-media svc/core 3000:3000 }
$job2 = Start-Job { kubectl port-forward -n social-media svc/api-gateway 8080:8080 }
$job3 = Start-Job { kubectl port-forward -n social-media svc/keycloak 8180:8080 }
$job4 = Start-Job { kubectl port-forward -n social-media svc/mailhog 8025:8025 }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Application is ready!" -ForegroundColor Cyan
Write-Host "Frontend:       http://localhost:3000" -ForegroundColor White
Write-Host "Backend API:    http://localhost:8080" -ForegroundColor White
Write-Host "Keycloak Admin: http://localhost:8180" -ForegroundColor White
Write-Host "MailHog:        http://localhost:8025" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Port forward jobs running. Use 'Get-Job' to see status."
Write-Host "Use 'Get-Job | Stop-Job' to stop all port forwards."
