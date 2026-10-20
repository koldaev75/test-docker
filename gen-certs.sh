#!/usr/bin/env sh
# Генерирует self-signed сертификат (Ubuntu 22.04, OpenSSL 3.0).
# Доп. имена/IP сервера: SAN_EXTRA="DNS:stand.example.com,IP:10.0.0.5" ./gen-certs.sh
set -eu
DIR="$(cd "$(dirname "$0")" && pwd)/nginx/certs"
DAYS="${DAYS:-365}"
SAN="DNS:localhost,IP:127.0.0.1"
[ -n "${SAN_EXTRA:-}" ] && SAN="$SAN,$SAN_EXTRA"
mkdir -p "$DIR"

openssl req -x509 -nodes -newkey rsa:2048 -sha256 -days "$DAYS" \
  -keyout "$DIR/server.key" -out "$DIR/server.crt" \
  -subj "/C=US/O=Local Dev/CN=localhost" \
  -addext "subjectAltName=$SAN"

# nginx master читает ключ от root внутри контейнера, но 644 избавляет от проблем с правами bind-mount
chmod 644 "$DIR/server.crt" "$DIR/server.key"
echo "OK: $DIR/server.crt, $DIR/server.key (SAN: $SAN, $DAYS дней)"
