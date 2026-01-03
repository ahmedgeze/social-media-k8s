# Keycloak Kurulum ve Konfigürasyon Rehberi

## İçindekiler

1. [Genel Bakış](#genel-bakış)
2. [Kubernetes Kurulumu](#kubernetes-kurulumu)
3. [Keycloak Admin Konsolu](#keycloak-admin-konsolu)
4. [Realm Oluşturma](#realm-oluşturma)
5. [Client Konfigürasyonu](#client-konfigürasyonu)
6. [Kullanıcı Yönetimi](#kullanıcı-yönetimi)
7. [Backend Entegrasyonu](#backend-entegrasyonu)
8. [Frontend Entegrasyonu](#frontend-entegrasyonu)
9. [Service-to-Service Auth](#service-to-service-auth)
10. [Troubleshooting](#troubleshooting)

---

## Genel Bakış

### Mimari

```
┌─────────────────────────────────────────────────────────────────┐
│                     social-media namespace                       │
│                                                                 │
│  ┌──────────┐     ┌──────────┐     ┌───────────────────────┐   │
│  │ Frontend │────▶│ Keycloak │◀────│      Backend          │   │
│  │  Apps    │     │  :8080   │     │       :8080           │   │
│  └──────────┘     └────┬─────┘     └───────────────────────┘   │
│                        │                                        │
│                        ▼                                        │
│                  ┌──────────────┐                               │
│                  │  Keycloak    │                               │
│                  │  PostgreSQL  │                               │
│                  │    :5432     │                               │
│                  └──────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

### Auth Flows

| Flow | Kullanım | Protokol |
|------|----------|----------|
| Authorization Code + PKCE | Frontend user login | OIDC |
| Client Credentials | Service-to-service | OAuth2 |
| Resource Owner Password | Mobile apps (legacy) | OAuth2 |

---

## Kubernetes Kurulumu

### Önkoşullar

- Minikube çalışıyor olmalı
- `kubectl` kurulu olmalı
- `social-media` namespace oluşturulmuş olmalı

### Adım 1: Keycloak PostgreSQL Deploy

```bash
# Keycloak için dedicated PostgreSQL
kubectl apply -f keycloak-postgres.yaml

# Pod'un hazır olmasını bekle
kubectl wait --for=condition=ready pod -l app=keycloak-postgres -n social-media --timeout=120s

# Doğrulama
kubectl get pvc -n social-media
# keycloak-postgres-pvc   Bound    ...   5Gi
```

### Adım 2: Keycloak Deploy

```bash
# Keycloak deployment
kubectl apply -f keycloak.yaml

# Pod'un hazır olmasını bekle (ilk başlatma 2-3 dakika sürebilir)
kubectl wait --for=condition=ready pod -l app=keycloak -n social-media --timeout=300s

# Logları kontrol et
kubectl logs -f deployment/keycloak -n social-media
```

### Adım 3: Port Forward

```bash
# Keycloak Admin Console erişimi
kubectl port-forward svc/keycloak 8180:8080 -n social-media

# Tarayıcıda aç
open http://localhost:8180
```

### Doğrulama

```bash
# Tüm pod'ları kontrol et
kubectl get pods -n social-media | grep keycloak

# Beklenen çıktı:
# keycloak-postgres-xxx   1/1     Running
# keycloak-xxx            1/1     Running

# PVC durumu
kubectl get pvc -n social-media | grep keycloak
# keycloak-postgres-pvc   Bound
```

---

## Keycloak Admin Konsolu

### İlk Giriş

1. http://localhost:8180 adresine git
2. "Administration Console" tıkla
3. Giriş bilgileri:
   - Username: `admin`
   - Password: `admin-password`

### Admin Şifresini Değiştirme (Önerilen)

1. Sağ üst köşede "admin" → "Manage account"
2. "Signing In" → "Update Password"

---

## Realm Oluşturma

### Realm Nedir?

Realm, Keycloak'ta izole bir kullanıcı ve uygulama alanıdır. Her realm kendi kullanıcıları, rolleri ve client'larına sahiptir.

### Social Media Realm Oluşturma

1. Sol üst "Master" dropdown → "Create Realm"
2. Realm adı: `social-media`
3. "Create" tıkla

### Realm Ayarları

**Login Tab:**
- User registration: ON (kullanıcılar kayıt olabilsin)
- Edit username: ON
- Forgot password: ON
- Remember me: ON

**Tokens Tab:**
- Access Token Lifespan: 5 minutes
- Refresh Token Lifespan: 30 minutes

---

## Client Konfigürasyonu

### 1. Frontend Client (Public)

Frontend uygulaması için PKCE ile Authorization Code flow.

**Oluşturma:**
1. Clients → "Create client"
2. Client ID: `social-media-frontend`
3. Client type: `OpenID Connect`
4. Next

**Capability Config:**
- Client authentication: OFF (public client)
- Authorization: OFF
- Standard flow: ON
- Direct access grants: OFF

**Access Settings:**
```
Root URL: http://localhost:3000
Home URL: http://localhost:3000
Valid redirect URIs:
  - http://localhost:3000/*
  - http://localhost:3001/*
  - http://localhost:3002/*
Valid post logout redirect URIs:
  - http://localhost:3000/*
Web origins:
  - http://localhost:3000
  - http://localhost:3001
  - http://localhost:3002
```

### 2. Backend Client (Confidential)

Backend API için service authentication.

**Oluşturma:**
1. Clients → "Create client"
2. Client ID: `social-media-backend`
3. Client type: `OpenID Connect`
4. Next

**Capability Config:**
- Client authentication: ON (confidential client)
- Service accounts roles: ON (for service-to-service)
- Standard flow: ON
- Direct access grants: ON (for testing)

**Access Settings:**
```
Root URL: http://localhost:8080
Valid redirect URIs: http://localhost:8080/*
```

**Credentials Tab:**
- Client secret'ı kopyala (backend config için gerekli)

### 3. Service Client (Machine-to-Machine)

Backend'ler arası iletişim için.

**Oluşturma:**
1. Clients → "Create client"
2. Client ID: `social-media-service`
3. Client type: `OpenID Connect`

**Capability Config:**
- Client authentication: ON
- Service accounts roles: ON
- Standard flow: OFF
- Direct access grants: OFF

---

## Kullanıcı Yönetimi

### Rol Oluşturma

1. Realm roles → "Create role"
2. Roller:
   - `user` - Normal kullanıcı
   - `admin` - Admin yetkisi
   - `moderator` - Moderatör yetkisi

### Kullanıcı Oluşturma

1. Users → "Add user"
2. Bilgileri doldur:
   - Username: `testuser`
   - Email: `test@example.com`
   - First name: `Test`
   - Last name: `User`
   - Email verified: ON
3. "Create"

**Şifre Belirleme:**
1. Credentials tab
2. "Set password"
3. Password: `test123`
4. Temporary: OFF

**Rol Atama:**
1. Role mapping tab
2. "Assign role"
3. `user` rolünü seç

---

## Backend Entegrasyonu

### Spring Boot Dependencies

```xml
<!-- pom.xml -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

### Application Properties

```yaml
# application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://keycloak:8080/realms/social-media
          jwk-set-uri: http://keycloak:8080/realms/social-media/protocol/openid-connect/certs

# Local development
---
spring:
  config:
    activate:
      on-profile: local
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://localhost:8180/realms/social-media
```

### Security Configuration

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .cors(Customizer.withDefaults())
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/actuator/health/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("admin")
                .requestMatchers("/api/**").authenticated()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthConverter()))
            );
        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthConverter() {
        JwtGrantedAuthoritiesConverter converter = new JwtGrantedAuthoritiesConverter();
        converter.setAuthoritiesClaimName("realm_access.roles");
        converter.setAuthorityPrefix("ROLE_");

        JwtAuthenticationConverter jwtConverter = new JwtAuthenticationConverter();
        jwtConverter.setJwtGrantedAuthoritiesConverter(converter);
        return jwtConverter;
    }
}
```

### JWT'den Kullanıcı Bilgisi Alma

```java
@RestController
@RequestMapping("/api")
public class UserController {

    @GetMapping("/me")
    public Map<String, Object> getCurrentUser(@AuthenticationPrincipal Jwt jwt) {
        return Map.of(
            "sub", jwt.getSubject(),
            "username", jwt.getClaimAsString("preferred_username"),
            "email", jwt.getClaimAsString("email"),
            "roles", jwt.getClaimAsStringList("realm_access.roles")
        );
    }
}
```

---

## Frontend Entegrasyonu

### Keycloak JS Adapter

```bash
npm install keycloak-js
```

### Keycloak Config

```typescript
// packages/auth-lib/src/keycloak.ts
import Keycloak from 'keycloak-js';

const keycloakConfig = {
  url: process.env.NEXT_PUBLIC_KEYCLOAK_URL || 'http://localhost:8180',
  realm: 'social-media',
  clientId: 'social-media-frontend',
};

export const keycloak = new Keycloak(keycloakConfig);

export const initKeycloak = async () => {
  try {
    const authenticated = await keycloak.init({
      onLoad: 'check-sso',
      pkceMethod: 'S256',
      checkLoginIframe: false,
    });
    return authenticated;
  } catch (error) {
    console.error('Keycloak init failed:', error);
    return false;
  }
};
```

### Auth Context Update

```typescript
// packages/auth-lib/src/context/AuthContext.tsx
import { keycloak, initKeycloak } from '../keycloak';

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    initKeycloak().then((authenticated) => {
      if (authenticated && keycloak.tokenParsed) {
        setUser({
          id: keycloak.tokenParsed.sub!,
          username: keycloak.tokenParsed.preferred_username,
          email: keycloak.tokenParsed.email,
        });
      }
      setIsLoading(false);
    });
  }, []);

  const login = () => keycloak.login();
  const logout = () => keycloak.logout({ redirectUri: window.location.origin });
  const getToken = () => keycloak.token;

  return (
    <AuthContext.Provider value={{ user, isLoading, login, logout, getToken }}>
      {children}
    </AuthContext.Provider>
  );
}
```

### API Client Token Injection

```typescript
// packages/api-client/src/client.ts
import { keycloak } from '@repo/auth-lib';

async function request<T>(endpoint: string, options?: RequestInit): Promise<T> {
  // Refresh token if needed
  await keycloak.updateToken(30);

  const response = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${keycloak.token}`,
      ...options?.headers,
    },
  });

  if (response.status === 401) {
    keycloak.login();
    throw new Error('Unauthorized');
  }

  return response.json();
}
```

---

## Service-to-Service Auth

### Client Credentials Flow

Backend servisler arası güvenli iletişim için.

```java
@Service
public class ServiceAuthClient {

    private final WebClient webClient;
    private String accessToken;
    private Instant tokenExpiry;

    public ServiceAuthClient(WebClient.Builder builder) {
        this.webClient = builder.baseUrl("http://keycloak:8080").build();
    }

    public String getServiceToken() {
        if (accessToken == null || Instant.now().isAfter(tokenExpiry)) {
            refreshToken();
        }
        return accessToken;
    }

    private void refreshToken() {
        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("grant_type", "client_credentials");
        body.add("client_id", "social-media-service");
        body.add("client_secret", "${CLIENT_SECRET}");

        Map<String, Object> response = webClient.post()
            .uri("/realms/social-media/protocol/openid-connect/token")
            .contentType(MediaType.APPLICATION_FORM_URLENCODED)
            .body(BodyInserters.fromFormData(body))
            .retrieve()
            .bodyToMono(new ParameterizedTypeReference<Map<String, Object>>() {})
            .block();

        this.accessToken = (String) response.get("access_token");
        int expiresIn = (Integer) response.get("expires_in");
        this.tokenExpiry = Instant.now().plusSeconds(expiresIn - 30);
    }
}
```

---

## Troubleshooting

### Keycloak Başlamıyor

```bash
# Logları kontrol et
kubectl logs deployment/keycloak -n social-media

# Yaygın sorunlar:
# 1. PostgreSQL bağlantı hatası
kubectl logs deployment/keycloak-postgres -n social-media

# 2. Memory yetersiz
kubectl describe pod -l app=keycloak -n social-media | grep -A5 "Events"
```

### Token Doğrulama Hatası

```bash
# JWKS endpoint'i kontrol et
curl http://localhost:8180/realms/social-media/protocol/openid-connect/certs

# Issuer URI kontrol et
curl http://localhost:8180/realms/social-media/.well-known/openid-configuration
```

### CORS Hatası

Frontend client'ta Web Origins ayarlarını kontrol et.

### Data Persistence Kontrolü

```bash
# Pod restart sonrası veri kontrolü
kubectl delete pod -l app=keycloak -n social-media
kubectl wait --for=condition=ready pod -l app=keycloak -n social-media

# Admin console'a giriş yap - veriler durmalı
```

---

## Faydalı Linkler

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Spring Security OAuth2](https://docs.spring.io/spring-security/reference/servlet/oauth2/index.html)
- [Keycloak JS Adapter](https://www.keycloak.org/docs/latest/securing_apps/#_javascript_adapter)

---

## Sonraki Adımlar

1. [ ] Backend Spring Security entegrasyonu
2. [ ] Frontend Keycloak adapter entegrasyonu
3. [ ] Role-based access control (RBAC) implementasyonu
4. [ ] Social login (Google, GitHub) ekleme
5. [ ] MFA aktivasyonu
