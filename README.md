# Локальный стенд веб-приложения (Docker Compose)

Nginx (TLS, self-signed) → backend :8080 → PostgreSQL 15 + Redis. Healthcheck у всех сервисов, пароли в `.env`, rate limit 10 req/s на IP и лимит тела запроса 10 МБ.

```
клиент ──https:443──▶ nginx ──http──▶ backend:8080 ──▶ postgres:5432
                                           └────────▶ redis:6379
```

## Ветки: выберите свою ОС

В репозитории две ветки, каждая — под свою операционную систему. В каждой есть собственный `README.md` с пошаговой инструкцией и особенностями платформы.

| Ветка | Система | Отличия |
|-------|---------|---------|
| [`macos`](../../tree/macos) | macOS 12+ (Intel / Apple Silicon), Docker Desktop | Docker Desktop уже содержит Compose v2; клиент в логах виден как адрес шлюза VM (`192.168.65.1`); доверие сертификату через `security add-trusted-cert`. |
| [`ubuntu`](../../tree/ubuntu) | Ubuntu 22.04 LTS, Docker Engine | Дополнительно `setup-ubuntu.sh` (установка Docker CE + Compose v2 из официального репозитория; `docker.io` из apt не подходит), `gen-certs.sh` с `SAN_EXTRA` для доступа не только с localhost, заметки про `ufw`/группу `docker`/занятый порт 443. |
| `main` | — | Общая база и этот обзор. Код стенда идентичен ветке `macos`. |

```bash
git clone https://github.com/koldaev75/test-docker.git && cd test-docker
git checkout macos     # или: git checkout ubuntu
```

## Общее для обеих веток

Состав и поведение одинаковы: те же `docker-compose.yml`, `nginx/nginx.conf`, `backend/` (Python-сервер с `/`, `/hits`, `/health`). Различаются только `gen-certs.sh` (в `ubuntu` — SAN_EXTRA), наличие `setup-ubuntu.sh` и README.

Быстрый старт (после установки Docker):

```bash
./gen-certs.sh && docker compose up -d --build
docker compose ps            # 4 сервиса (healthy)
curl -k https://localhost/
```

`.env` с тестовыми паролями лежит в репозитории намеренно (стенд локальный); для реальных окружений замените значения. Сертификаты в git не хранятся — создаются `gen-certs.sh`.

## Статус проверки
- `macos` — полностью запущен и проверен на macOS (healthchecks, заголовки X-Forwarded-*, rate limit → 429, тело >10 МБ → 413, Postgres/Redis).
- `ubuntu` — `gen-certs.sh` и установка Docker из репозитория проверены в контейнере `ubuntu:22.04`; сам стек использует те же образы и compose-файл, что и `macos`. Полный прогон на живой Ubuntu-машине не выполнялся.
