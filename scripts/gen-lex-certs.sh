#!/usr/bin/env bash
# gen-lex-certs.sh — generate fleet CA and per-service TLS certs
# Usage: LEX_CERTS_DIR=/path/to/store ./scripts/gen-lex-certs.sh [--force]
# Use --force to overwrite existing certificates
set -euo pipefail

CERTS_DIR="${LEX_CERTS_DIR:-$(dirname "$0")/../certs}"
DAYS=3650  # 10 years
FORCE=false

# Parse --force flag
for arg in "$@"; do
  if [[ "$arg" == "--force" ]]; then
    FORCE=true
  fi
done

# Check if certs already exist
if [[ -f "$CERTS_DIR/ca/ca.key" ]]; then
  if [[ "$FORCE" != "true" ]]; then
    echo "Certs already exist at $CERTS_DIR. Use --force to regenerate." >&2
    exit 1
  fi
  echo "Regenerating certs (--force flag set)..."
fi

mkdir -p "$CERTS_DIR/ca" "$CERTS_DIR/synapse"

echo "Generating fleet CA..."
# CA key + self-signed cert
openssl genrsa -out "$CERTS_DIR/ca/ca.key" 4096
openssl req -new -x509 -days "$DAYS" -key "$CERTS_DIR/ca/ca.key" \
  -out "$CERTS_DIR/ca/ca.crt" \
  -subj "/CN=Lex Fleet CA/O=Meridian Lex/C=AU"

echo "Generating Synapse broker cert..."
# Synapse server key + CSR
openssl genrsa -out "$CERTS_DIR/synapse/broker.key" 2048
openssl req -new -key "$CERTS_DIR/synapse/broker.key" \
  -out "$CERTS_DIR/synapse/broker.csr" \
  -subj "/CN=synapse-broker/O=Meridian Lex/C=AU"

# Sign with fleet CA, include SANs for Docker service name, container name, and localhost
cat > "$CERTS_DIR/synapse/broker.ext" <<EXTEOF
[v3_req]
subjectAltName = DNS:synapse-broker,DNS:stratavore-synapse,DNS:localhost,IP:127.0.0.1
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
EXTEOF

openssl x509 -req -days "$DAYS" \
  -in "$CERTS_DIR/synapse/broker.csr" \
  -CA "$CERTS_DIR/ca/ca.crt" \
  -CAkey "$CERTS_DIR/ca/ca.key" \
  -CAcreateserial \
  -out "$CERTS_DIR/synapse/broker.crt" \
  -extfile "$CERTS_DIR/synapse/broker.ext" \
  -extensions v3_req

rm "$CERTS_DIR/synapse/broker.csr" "$CERTS_DIR/synapse/broker.ext"
chmod 600 "$CERTS_DIR/ca/ca.key" "$CERTS_DIR/synapse/broker.key"

echo "Certs written to $CERTS_DIR"
echo "  CA:     $CERTS_DIR/ca/ca.crt"
echo "  Broker: $CERTS_DIR/synapse/broker.crt + broker.key"
