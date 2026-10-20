#!/usr/bin/env sh
# Генерирует self-signed сертификат для localhost (macOS/Ubuntu, нужен openssl).
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)/nginx/certs"
DAYS="${DAYS:-365}"
mkdir -p "$DIR"

openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days "$DAYS" \
  -keyout "$DIR/server.key" -out "$DIR/server.crt" \
  -subj "/C=US/O=Local Dev/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

chmod 644 "$DIR/server.crt"
chmod 600 "$DIR/server.key"
echo "OK: $DIR/server.crt, $DIR/server.key (valid $DAYS days)"
