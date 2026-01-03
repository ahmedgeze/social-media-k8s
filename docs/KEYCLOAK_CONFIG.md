# Keycloak Configuration Summary

## Quick Reference

### Endpoints

| Endpoint | URL |
|----------|-----|
| Admin Console | http://localhost:8180/admin/social-media/console/ |
| Token Endpoint | http://localhost:8180/realms/social-media/protocol/openid-connect/token |
| JWKS Endpoint | http://localhost:8180/realms/social-media/protocol/openid-connect/certs |
| OIDC Discovery | http://localhost:8180/realms/social-media/.well-known/openid-configuration |
| Issuer URI | http://localhost:8180/realms/social-media |

### Kubernetes Internal URLs

| Service | URL |
|---------|-----|
| Keycloak | http://keycloak:8080 |
| Token Endpoint | http://keycloak:8080/realms/social-media/protocol/openid-connect/token |
| JWKS Endpoint | http://keycloak:8080/realms/social-media/protocol/openid-connect/certs |
| Issuer URI | http://keycloak:8080/realms/social-media |

---

## Clients

### 1. Frontend Client (Public)

```
Client ID: social-media-frontend
Type: Public (no secret)
Flow: Authorization Code + PKCE
```

**Usage (Frontend):**
```typescript
const keycloakConfig = {
  url: 'http://localhost:8180',  // or http://keycloak:8080 in K8s
  realm: 'social-media',
  clientId: 'social-media-frontend',
};
```

### 2. Backend Client (Confidential)

```
Client ID: social-media-backend
Type: Confidential
Secret: nQCIaPfA1xCdm6MKJ9FORh5KGC0nLrwa
Flow: Direct Access Grants, Service Accounts
```

**Usage (Spring Boot application.yml):**
```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://keycloak:8080/realms/social-media
          jwk-set-uri: http://keycloak:8080/realms/social-media/protocol/openid-connect/certs
```

### 3. Service Client (Machine-to-Machine)

```
Client ID: social-media-service
Type: Confidential
Secret: 1nzswpyIFadAKnlmAMPcMEtpGSKQxBNk
Flow: Client Credentials
Role: admin (assigned to service account)
```

**Usage (Service-to-Service):**
```bash
curl -X POST "http://keycloak:8080/realms/social-media/protocol/openid-connect/token" \
  -d "grant_type=client_credentials" \
  -d "client_id=social-media-service" \
  -d "client_secret=1nzswpyIFadAKnlmAMPcMEtpGSKQxBNk"
```

---

## Roles

| Role | Description | Permissions |
|------|-------------|-------------|
| `user` | Default role for all users | Create/edit/delete own posts, comments, likes |
| `moderator` | Content moderator | Delete any post/comment |
| `admin` | Administrator | Full access to all operations |

### Role Hierarchy

```
admin
  └── moderator
        └── user
```

---

## Test Users

| Username | Password | Email | Role |
|----------|----------|-------|------|
| testuser | test123 | testuser@example.com | user |
| moderator | mod123 | moderator@example.com | moderator |
| adminuser | admin123 | adminuser@example.com | admin |

---

## Token Structure

### Access Token Claims

```json
{
  "sub": "user-uuid",
  "preferred_username": "testuser",
  "email": "testuser@example.com",
  "realm_access": {
    "roles": ["user", "default-roles-social-media"]
  },
  "resource_access": {
    "social-media-backend": {
      "roles": []
    }
  }
}
```

### Extracting Roles in Backend

```java
// Spring Security - JWT Authentication Converter
@Bean
public JwtAuthenticationConverter jwtAuthConverter() {
    JwtGrantedAuthoritiesConverter converter = new JwtGrantedAuthoritiesConverter();
    converter.setAuthoritiesClaimName("realm_access.roles");
    converter.setAuthorityPrefix("ROLE_");

    JwtAuthenticationConverter jwtConverter = new JwtAuthenticationConverter();
    jwtConverter.setJwtGrantedAuthoritiesConverter(jwt -> {
        Collection<GrantedAuthority> authorities = new ArrayList<>();

        // Extract realm roles
        Map<String, Object> realmAccess = jwt.getClaim("realm_access");
        if (realmAccess != null) {
            List<String> roles = (List<String>) realmAccess.get("roles");
            if (roles != null) {
                roles.forEach(role ->
                    authorities.add(new SimpleGrantedAuthority("ROLE_" + role)));
            }
        }
        return authorities;
    });
    return jwtConverter;
}
```

---

## Authorization Examples

### Backend API Security

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                // Public endpoints
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/actuator/health/**").permitAll()

                // User endpoints - authenticated users
                .requestMatchers(HttpMethod.GET, "/api/posts/**").authenticated()
                .requestMatchers(HttpMethod.GET, "/api/users/**").authenticated()

                // Create/Update/Delete - requires user role
                .requestMatchers(HttpMethod.POST, "/api/posts").hasRole("user")
                .requestMatchers(HttpMethod.PUT, "/api/posts/**").hasRole("user")
                .requestMatchers(HttpMethod.DELETE, "/api/posts/**").hasAnyRole("user", "moderator", "admin")

                // Admin only
                .requestMatchers("/api/admin/**").hasRole("admin")

                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt());

        return http.build();
    }
}
```

### Ownership Check

```java
@Service
public class PostService {

    public void deletePost(Long postId, Jwt jwt) {
        Post post = postRepository.findById(postId)
            .orElseThrow(() -> new ResourceNotFoundException("Post not found"));

        String userId = jwt.getSubject();
        List<String> roles = jwt.getClaimAsStringList("realm_access.roles");

        // Owner can delete their own post
        boolean isOwner = post.getUser().getKeycloakId().equals(userId);

        // Moderator and admin can delete any post
        boolean isModerator = roles.contains("moderator") || roles.contains("admin");

        if (!isOwner && !isModerator) {
            throw new ForbiddenException("Not authorized to delete this post");
        }

        postRepository.delete(post);
    }
}
```

---

## Environment Variables

### Backend (Kubernetes ConfigMap)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
data:
  SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_ISSUER_URI: "http://keycloak:8080/realms/social-media"
  SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_JWK_SET_URI: "http://keycloak:8080/realms/social-media/protocol/openid-connect/certs"
```

### Backend (Kubernetes Secret)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
type: Opaque
stringData:
  KEYCLOAK_CLIENT_SECRET: "nQCIaPfA1xCdm6MKJ9FORh5KGC0nLrwa"
  SERVICE_CLIENT_SECRET: "1nzswpyIFadAKnlmAMPcMEtpGSKQxBNk"
```

### Frontend (Environment)

```env
NEXT_PUBLIC_KEYCLOAK_URL=http://localhost:8180
NEXT_PUBLIC_KEYCLOAK_REALM=social-media
NEXT_PUBLIC_KEYCLOAK_CLIENT_ID=social-media-frontend
```

---

## Scripts

### Configure Keycloak

```bash
# Run after Keycloak is deployed
./scripts/configure-keycloak.sh
```

### Test Authentication

```bash
# User login
curl -X POST "http://localhost:8180/realms/social-media/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=testuser" \
  -d "password=test123" \
  -d "grant_type=password" \
  -d "client_id=social-media-backend" \
  -d "client_secret=nQCIaPfA1xCdm6MKJ9FORh5KGC0nLrwa"

# Service token
curl -X POST "http://localhost:8180/realms/social-media/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=social-media-service" \
  -d "client_secret=1nzswpyIFadAKnlmAMPcMEtpGSKQxBNk"
```
