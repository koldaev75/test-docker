# Локальный стенд (ветка `ubuntu`): Nginx (TLS) → backend → PostgreSQL 15 + Redis

> Ветка для **Ubuntu 22.04 LTS**. Для macOS см. ветку `macos`, обзор — в `main`.

```
клиент ──https:443──▶ nginx ──http──▶ backend:8080 ──▶ postgres:5432
                                           └────────▶ redis:6379
```

Наружу опубликован только nginx (`:443`). Backend, Postgres и Redis доступны только внутри docker-сети.

## Требования
Ubuntu 22.04 (jammy), доступ к `sudo`, интернет. Docker Engine 24+ с Compose v2 ставится скриптом `setup-ubuntu.sh` (если уже стоит — пропустит). Пакет `docker.io` из apt не подходит — в нём нет `docker compose`.
Порт 443 должен быть свободен (иначе поменяйте `HTTPS_PORT` в `.env`, напр. `8443`).

## Запуск

```bash
./setup-ubuntu.sh               # Docker + Compose v2 (один раз), затем перелогиньтесь
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

## Особенности Ubuntu
- Docker работает нативно, без VM: в `X-Forwarded-For` виден реальный адрес клиента.
- Порт 443 публикует демон Docker (root), `sudo` для запуска `docker compose` не нужен после добавления в группу `docker` (`setup-ubuntu.sh` делает это сам; потребуется перелогин).
- Если включён `ufw`: `sudo ufw allow 443/tcp`. Docker вносит правила в iptables в обход ufw, поэтому порт 443 может быть открыт наружу и при включённом ufw — учитывайте это на машине с публичным IP.
- Для доступа не только с localhost добавьте имя/IP сервера в сертификат: `SAN_EXTRA="DNS:stand.example.com,IP:10.0.0.5" ./gen-certs.sh`.
- Если 443 занят (`sudo ss -ltnp | grep :443`), поменяйте `HTTPS_PORT` в `.env`.
- Сертификат можно доверить системе: `sudo cp nginx/certs/server.crt /usr/local/share/ca-certificates/stand.crt && sudo update-ca-certificates`.
