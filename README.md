# Локальный стенд (ветка `macos`): Nginx (TLS) → backend → PostgreSQL 15 + Redis

> Ветка для **macOS** (Docker Desktop). Для Ubuntu 22.04 см. ветку `ubuntu`, обзор — в `main`.

```
клиент ──https:443──▶ nginx ──http──▶ backend:8080 ──▶ postgres:5432
                                           └────────▶ redis:6379
```

Наружу опубликован только nginx (`:443`). Backend, Postgres и Redis доступны только внутри docker-сети.

## Требования
macOS 12+ (Intel или Apple Silicon), **Docker Desktop** (уже включает Compose v2), `openssl` и `curl` (есть в системе; LibreSSL из macOS поддерживает `-addext`).
Порт 443 должен быть свободен (иначе поменяйте `HTTPS_PORT` в `.env`, напр. `8443`).

## Запуск

```bash
./gen-certs.sh                  # self-signed сертификат -> nginx/certs/
docker compose up -d --build    # старт; ждёт healthy у зависимостей
docker compose ps               # все 4 сервиса должны быть (healthy)
curl -k https://localhost/      # backend отвечает, видны X-Forwarded-* заголовки
```

Остановка: `docker compose down` (с `-v` — также удалить данные БД и Redis).

## Что внутри

| Сервис   | Образ                | Healthcheck                          |
|----------|----------------------|--------------------------------------|
| nginx    | nginx:1.27-alpine    | `wget https://127.0.0.1/healthz`     |
| backend  | python:3.12-alpine (Python http.server, `backend/app.py`) | `GET /health` (проверяет Postgres и Redis) |
| postgres | postgres:15-alpine   | `pg_isready`                         |
| redis    | redis:7-alpine       | `redis-cli ping` (с паролем)         |

- **Секреты** — в `.env` (тестовые значения для локального стенда, закоммичен намеренно), в compose нет хардкода. Сертификаты в `.gitignore`, генерируются `gen-certs.sh`.
- **Nginx** (`nginx/nginx.conf`): TLS 1.2/1.3, rate limit 10 req/s на IP (`burst=20`, при превышении — `429`), `client_max_body_size 10m` (больше — `413`), проксирование с `Host`, `X-Real-IP`, `X-Forwarded-For/Proto/Host`.
- **Backend endpoints**: `/` — эхо заголовков, `/hits` — счётчик в Redis + запись в Postgres, `/health`.

## Проверка требований

```bash
curl -sk https://localhost/ | grep -i x-forwarded                       # заголовки прокси
curl -sk https://localhost/hits                                         # Redis + Postgres работают
head -c 11000000 /dev/zero | curl -sk -o /dev/null -w '%{http_code}\n' \
     -X POST --data-binary @- https://localhost/                        # 413 (лимит 10MB)
seq 100 | xargs -P100 -I{} curl -sk -o /dev/null -w '%{http_code}\n' \
     https://localhost/ | sort | uniq -c                                # часть ответов 429 (rate limit)
```

## Особенности macOS
- Docker работает внутри виртуальной машины Docker Desktop, поэтому в логах и `X-Forwarded-For` клиент виден как адрес шлюза VM (например `192.168.65.1`), а не `127.0.0.1`. Это нормально.
- Порт 443 на macOS публикуется без `sudo` (Docker Desktop сам занимает привилегированные порты).
- Образы мультиархитектурные (`nginx`, `postgres`, `redis`, `python`), на Apple Silicon запускаются нативно.
- Если сертификат нужно доверить в браузере: `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain nginx/certs/server.crt`.
