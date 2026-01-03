#!/bin/bash

# Keycloak Configuration Script
# This script configures Keycloak for the Social Media application
# Run this after Keycloak is deployed and accessible

set -e

KEYCLOAK_URL="${KEYCLOAK_URL:-http://localhost:8180}"
ADMIN_USER="${KEYCLOAK_ADMIN:-admin}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD:-admin-password}"

echo "=================================================="
echo "  Keycloak Configuration Script"
echo "  URL: $KEYCLOAK_URL"
echo "=================================================="
echo ""

# Get admin token
echo "[1/8] Getting admin token..."
ADMIN_TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
  echo "✗ Failed to get admin token"
  exit 1
fi
echo "✓ Admin token acquired"

# Create realm
echo ""
echo "[2/8] Creating social-media realm..."
curl -s -X POST "${KEYCLOAK_URL}/admin/realms" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "social-media",
    "enabled": true,
    "displayName": "Social Media Platform",
    "registrationAllowed": true,
    "registrationEmailAsUsername": false,
    "editUsernameAllowed": true,
    "resetPasswordAllowed": true,
    "rememberMe": true,
    "verifyEmail": false,
    "loginWithEmailAllowed": true,
    "duplicateEmailsAllowed": false,
    "sslRequired": "none",
    "accessTokenLifespan": 300,
    "ssoSessionIdleTimeout": 1800,
    "ssoSessionMaxLifespan": 36000,
    "passwordPolicy": "length(6)",
    "bruteForceProtected": true,
    "failureFactor": 5
  }' 2>/dev/null || true
echo "✓ Realm created/exists"

# Create roles
echo ""
echo "[3/8] Creating realm roles..."
for role in "user:Standard user - can create posts, comments, likes" \
            "moderator:Moderator - can delete any post/comment" \
            "admin:Admin - full access to all operations"; do
  role_name=$(echo $role | cut -d: -f1)
  role_desc=$(echo $role | cut -d: -f2)

  curl -s -X POST "${KEYCLOAK_URL}/admin/realms/social-media/roles" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"${role_name}\", \"description\": \"${role_desc}\"}" 2>/dev/null || true
done
echo "✓ Roles created: user, moderator, admin"

# Set user as default role
echo ""
echo "[4/8] Setting default role..."
DEFAULT_ROLES_ID=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/roles/default-roles-social-media" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.id')
USER_ROLE=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/roles/user" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/social-media/roles-by-id/${DEFAULT_ROLES_ID}/composites" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "[${USER_ROLE}]" 2>/dev/null || true
echo "✓ 'user' set as default role"

# Create frontend client
echo ""
echo "[5/8] Creating frontend client..."
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/social-media/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "social-media-frontend",
    "name": "Social Media Frontend",
    "enabled": true,
    "publicClient": true,
    "directAccessGrantsEnabled": false,
    "standardFlowEnabled": true,
    "protocol": "openid-connect",
    "rootUrl": "http://localhost:3000",
    "baseUrl": "http://localhost:3000",
    "redirectUris": ["http://localhost:3000/*", "http://localhost:3001/*", "http://localhost:3002/*"],
    "webOrigins": ["http://localhost:3000", "http://localhost:3001", "http://localhost:3002"],
    "attributes": {"pkce.code.challenge.method": "S256"}
  }' 2>/dev/null || true
echo "✓ Frontend client created"

# Create backend client
echo ""
echo "[6/8] Creating backend client..."
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/social-media/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "social-media-backend",
    "name": "Social Media Backend API",
    "enabled": true,
    "publicClient": false,
    "directAccessGrantsEnabled": true,
    "standardFlowEnabled": true,
    "serviceAccountsEnabled": true,
    "protocol": "openid-connect",
    "rootUrl": "http://localhost:8080",
    "redirectUris": ["http://localhost:8080/*"]
  }' 2>/dev/null || true

BACKEND_CLIENT_ID=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/clients?clientId=social-media-backend" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')
BACKEND_SECRET=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/clients/${BACKEND_CLIENT_ID}/client-secret" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')
echo "✓ Backend client created"
echo "  Client Secret: ${BACKEND_SECRET}"

# Create service client
echo ""
echo "[7/8] Creating service client..."
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/social-media/clients" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "social-media-service",
    "name": "Social Media Service Account",
    "enabled": true,
    "publicClient": false,
    "directAccessGrantsEnabled": false,
    "standardFlowEnabled": false,
    "serviceAccountsEnabled": true,
    "protocol": "openid-connect"
  }' 2>/dev/null || true

SERVICE_CLIENT_ID=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/clients?clientId=social-media-service" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')
SERVICE_SECRET=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/clients/${SERVICE_CLIENT_ID}/client-secret" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.value')

# Assign admin role to service account
SERVICE_ACCOUNT_USER_ID=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/clients/${SERVICE_CLIENT_ID}/service-account-user" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.id')
ADMIN_ROLE=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/roles/admin" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")
curl -s -X POST "${KEYCLOAK_URL}/admin/realms/social-media/users/${SERVICE_ACCOUNT_USER_ID}/role-mappings/realm" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "[${ADMIN_ROLE}]" 2>/dev/null || true

echo "✓ Service client created"
echo "  Client Secret: ${SERVICE_SECRET}"

# Create test users
echo ""
echo "[8/8] Creating test users..."
for user_data in "testuser:testuser@example.com:test123:user" \
                 "moderator:moderator@example.com:mod123:moderator" \
                 "adminuser:adminuser@example.com:admin123:admin"; do
  username=$(echo $user_data | cut -d: -f1)
  email=$(echo $user_data | cut -d: -f2)
  password=$(echo $user_data | cut -d: -f3)
  role=$(echo $user_data | cut -d: -f4)

  # Create user
  curl -s -X POST "${KEYCLOAK_URL}/admin/realms/social-media/users" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"${username}\",
      \"email\": \"${email}\",
      \"enabled\": true,
      \"emailVerified\": true
    }" 2>/dev/null || true

  # Get user ID and set password
  USER_ID=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/users?username=${username}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" | jq -r '.[0].id')

  if [ "$USER_ID" != "null" ] && [ -n "$USER_ID" ]; then
    curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/social-media/users/${USER_ID}/reset-password" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "{\"type\": \"password\", \"value\": \"${password}\", \"temporary\": false}" 2>/dev/null || true

    # Assign role
    ROLE_DATA=$(curl -s "${KEYCLOAK_URL}/admin/realms/social-media/roles/${role}" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}")
    curl -s -X POST "${KEYCLOAK_URL}/admin/realms/social-media/users/${USER_ID}/role-mappings/realm" \
      -H "Authorization: Bearer ${ADMIN_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "[${ROLE_DATA}]" 2>/dev/null || true
  fi
done
echo "✓ Test users created"

echo ""
echo "=================================================="
echo "  Configuration Complete!"
echo "=================================================="
echo ""
echo "Realm: social-media"
echo "Admin Console: ${KEYCLOAK_URL}/admin/social-media/console/"
echo ""
echo "Clients:"
echo "  - social-media-frontend (public, PKCE)"
echo "  - social-media-backend  (confidential)"
echo "    Secret: ${BACKEND_SECRET}"
echo "  - social-media-service  (client credentials)"
echo "    Secret: ${SERVICE_SECRET}"
echo ""
echo "Test Users:"
echo "  - testuser / test123 (role: user)"
echo "  - moderator / mod123 (role: moderator)"
echo "  - adminuser / admin123 (role: admin)"
echo ""
echo "Endpoints:"
echo "  - Token: ${KEYCLOAK_URL}/realms/social-media/protocol/openid-connect/token"
echo "  - JWKS:  ${KEYCLOAK_URL}/realms/social-media/protocol/openid-connect/certs"
echo "  - OIDC:  ${KEYCLOAK_URL}/realms/social-media/.well-known/openid-configuration"
