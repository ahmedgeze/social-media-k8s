# Local Development Setup Guide

Bu döküman, Social Media Platform'u lokal ortamda çalıştırmak için gereken adımları içerir.

## Gereksinimler

### Tüm Platformlar

| Yazılım | Versiyon | İndirme Linki |
|---------|----------|---------------|
| Java | 21+ | https://adoptium.net/ |
| Node.js | 20+ | https://nodejs.org/ |
| Docker Desktop | Latest | https://docker.com/products/docker-desktop |
| kubectl | Latest | https://kubernetes.io/docs/tasks/tools/ |
| Minikube | Latest | https://minikube.sigs.k8s.io/docs/start/ |
| Git | Latest | https://git-scm.com/ |

---

## macOS Kurulum

### 1. Homebrew ile Gereksinimleri Yükle

```bash
# Homebrew yüklü değilse
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Gereksinimleri yükle
brew install openjdk@21
brew install node@20
brew install kubectl
brew install minikube
brew install git

# Java'yı PATH'e ekle
echo 'export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Docker Desktop'ı yükle (GUI uygulaması)
brew install --cask docker
```

### 2. Docker Desktop'ı Başlat

```bash
# Docker Desktop uygulamasını aç
open -a Docker

# Docker'ın çalıştığını kontrol et
docker info
```

### 3. Minikube'u Başlat

```bash
# Minikube'u başlat (4GB RAM, 2 CPU önerilir)
minikube start --memory=4096 --cpus=2

# Ingress addon'ını etkinleştir
minikube addons enable ingress

# Durumu kontrol et
minikube status
```

### 4. Projeyi Klonla ve Çalıştır

```bash
# Projeyi klonla
git clone <repo-url>
cd project

# Kubernetes namespace oluştur
kubectl create namespace social-media

# Infrastructure'ı deploy et
kubectl apply -f k8s/keycloak-postgres.yaml
kubectl apply -f k8s/keycloak.yaml
kubectl apply -f k8s/backend/infrastructure/

# Pod'ların hazır olmasını bekle
kubectl wait --for=condition=ready pod -l app=keycloak -n social-media --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongodb -n social-media --timeout=120s

# Backend servislerini deploy et
kubectl apply -f k8s/backend/services/

# Frontend'i deploy et
kubectl apply -f k8s/frontend.yaml
```

### 5. Port Forward'ları Başlat

```bash
# Terminal 1: Frontend
kubectl port-forward -n social-media svc/core 3000:3000

# Terminal 2: Backend API Gateway
kubectl port-forward -n social-media svc/api-gateway 8080:8080

# Terminal 3: Keycloak
kubectl port-forward -n social-media svc/keycloak 8180:8080

# Terminal 4: MailHog (Email test)
kubectl port-forward -n social-media svc/mailhog 8025:8025
```

### 6. Uygulamaya Eriş

| Servis | URL |
|--------|-----|
| Frontend | http://localhost:3000 |
| Backend API | http://localhost:8080 |
| Keycloak Admin | http://localhost:8180 (admin/admin-password) |
| MailHog | http://localhost:8025 |

---

## Windows Kurulum

### 1. Chocolatey ile Gereksinimleri Yükle

PowerShell'i **Administrator** olarak aç:

```powershell
# Chocolatey yüklü değilse
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Gereksinimleri yükle
choco install openjdk21 -y
choco install nodejs-lts -y
choco install kubernetes-cli -y
choco install minikube -y
choco install git -y

# Docker Desktop'ı yükle
choco install docker-desktop -y

# Terminal'i kapat ve yeniden aç
```

### 2. WSL2 ve Docker Desktop Kurulumu

```powershell
# WSL2'yi etkinleştir (Docker Desktop için gerekli)
wsl --install

# Bilgisayarı yeniden başlat
# Docker Desktop'ı aç ve WSL2 backend'ini kullan
```

### 3. Minikube'u Başlat

PowerShell'de:

```powershell
# Minikube'u Hyper-V veya Docker driver ile başlat
minikube start --driver=docker --memory=4096 --cpus=2

# Ingress addon'ını etkinleştir
minikube addons enable ingress

# Durumu kontrol et
minikube status
```

### 4. Projeyi Klonla ve Çalıştır

```powershell
# Projeyi klonla
git clone <repo-url>
cd project

# Kubernetes namespace oluştur
kubectl create namespace social-media

# Infrastructure'ı deploy et
kubectl apply -f k8s/keycloak-postgres.yaml
kubectl apply -f k8s/keycloak.yaml
kubectl apply -f k8s/backend/infrastructure/

# Pod'ların hazır olmasını bekle
kubectl wait --for=condition=ready pod -l app=keycloak -n social-media --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongodb -n social-media --timeout=120s

# Backend servislerini deploy et
kubectl apply -f k8s/backend/services/

# Frontend'i deploy et
kubectl apply -f k8s/frontend.yaml
```

### 5. Port Forward'ları Başlat

Her biri için ayrı PowerShell penceresi aç:

```powershell
# Pencere 1: Frontend
kubectl port-forward -n social-media svc/core 3000:3000

# Pencere 2: Backend API Gateway
kubectl port-forward -n social-media svc/api-gateway 8080:8080

# Pencere 3: Keycloak
kubectl port-forward -n social-media svc/keycloak 8180:8080

# Pencere 4: MailHog (Email test)
kubectl port-forward -n social-media svc/mailhog 8025:8025
```

### 6. Uygulamaya Eriş

| Servis | URL |
|--------|-----|
| Frontend | http://localhost:3000 |
| Backend API | http://localhost:8080 |
| Keycloak Admin | http://localhost:8180 (admin/admin-password) |
| MailHog | http://localhost:8025 |

---

## Hızlı Başlatma Script'leri

### macOS/Linux: start-local.sh

```bash
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
```

### Windows: start-local.ps1

```powershell
Write-Host "Starting Minikube..."
minikube start --driver=docker --memory=4096 --cpus=2
minikube addons enable ingress

Write-Host "Creating namespace..."
kubectl create namespace social-media 2>$null

Write-Host "Deploying infrastructure..."
kubectl apply -f k8s/keycloak-postgres.yaml
kubectl apply -f k8s/keycloak.yaml
kubectl apply -f k8s/backend/infrastructure/

Write-Host "Waiting for infrastructure..."
kubectl wait --for=condition=ready pod -l app=keycloak-postgres -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=keycloak -n social-media --timeout=300s
kubectl wait --for=condition=ready pod -l app=mongodb -n social-media --timeout=120s

Write-Host "Deploying services..."
kubectl apply -f k8s/backend/services/
kubectl apply -f k8s/frontend.yaml

Write-Host "Waiting for services..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=user-service -n social-media --timeout=120s
kubectl wait --for=condition=ready pod -l app=core -n social-media --timeout=120s

Write-Host "Starting port forwards in background..."
Start-Job { kubectl port-forward -n social-media svc/core 3000:3000 }
Start-Job { kubectl port-forward -n social-media svc/api-gateway 8080:8080 }
Start-Job { kubectl port-forward -n social-media svc/keycloak 8180:8080 }
Start-Job { kubectl port-forward -n social-media svc/mailhog 8025:8025 }

Write-Host ""
Write-Host "=========================================="
Write-Host "Application is ready!"
Write-Host "Frontend:       http://localhost:3000"
Write-Host "Backend API:    http://localhost:8080"
Write-Host "Keycloak Admin: http://localhost:8180"
Write-Host "MailHog:        http://localhost:8025"
Write-Host "=========================================="
```

---

## Sorun Giderme

### Pod'lar Başlamıyor

```bash
# Pod durumlarını kontrol et
kubectl get pods -n social-media

# Detaylı bilgi al
kubectl describe pod <pod-name> -n social-media

# Log'ları kontrol et
kubectl logs <pod-name> -n social-media
```

### Port Forward Çalışmıyor

```bash
# Mevcut port forward'ları sonlandır
pkill -f "port-forward"   # macOS/Linux
Get-Job | Stop-Job        # Windows PowerShell

# Yeniden başlat
kubectl port-forward -n social-media svc/core 3000:3000
```

### Minikube Sorunları

```bash
# Minikube'u sıfırla
minikube delete
minikube start --memory=4096 --cpus=2
```

### Docker Image Bulunamıyor

```bash
# Minikube Docker daemon'ına bağlan
eval $(minikube docker-env)   # macOS/Linux
& minikube -p minikube docker-env --shell powershell | Invoke-Expression   # Windows

# Image'ları yeniden build et
cd backend/social-media-microservices
./mvnw clean package -DskipTests
docker build -t user-service:latest -f user-service/Dockerfile user-service/
```

---

## Faydalı Komutlar

```bash
# Tüm pod'ları listele
kubectl get pods -n social-media

# Tüm servisleri listele
kubectl get svc -n social-media

# Pod loglarını izle
kubectl logs -f deployment/user-service -n social-media

# Pod'a shell bağlantısı
kubectl exec -it <pod-name> -n social-media -- /bin/sh

# Namespace'i sil (temizlik)
kubectl delete namespace social-media

# Minikube dashboard
minikube dashboard
```
