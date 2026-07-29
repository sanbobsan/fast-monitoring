# fast-monitoring

Автоматическая настройка мониторинга сервера (Grafana + Prometheus + Node Exporter) в изолированной Docker-среде.

## Project Structure

```
.
├── AGENTS.md                       # Инструкции для AI-ассистента
├── install.sh                      # Деплой стека (docker compose up -d)
├── remove.sh                       # Снос стека (docker compose down -v + rm -rf)
├── .env.example                    # Шаблон конфигурации
├── data/
│   ├── compose.yaml                # Docker Compose (prometheus, grafana, node-exporter)
│   ├── prometheus.template.yaml    # Шаблон конфига Prometheus (envsubst)
│   └── grafana/
│       └── datasources.yaml        # Provisioning datasource для Grafana
├── docs/
│   └── README.md                   # Документация (на русском)
└── .gitignore
```

## How to Use

- `./install.sh` — установка: копирует файлы в `$APP_DIR`, запускает `docker compose up -d`
- `./remove.sh` — удаление: `docker compose down -v` + удаляет `$APP_DIR`
- Перед запуском создать `.env` по образцу `.env.example`

## Configuration (.env)

| Variable | Default | Description |
|---|---|---|
| `APP_DIR` | `/opt/fast-monitoring` | Директория развёртывания |
| `GRAFANA_PORT` | `3000` | Проброшенный порт Grafana (localhost) |
| `GRAFANA_USER` | `user` | Логин администратора Grafana |
| `GRAFANA_PASSWORD` | `password` | Пароль администратора Grafana |
| `NODE_PORT` | `9100` | Порт node-exporter на Docker bridge |

## Architecture

- Изолированная сеть `172.30.0.0/24`
- Grafana доступна только на `127.0.0.1:GRAFANA_PORT` (прокси через SSH: `ssh -N -L 8000:127.0.0.1:{port} {user}@{ip}`)
- Node Exporter — `network_mode: host`, слушает на `172.30.0.1:NODE_PORT`
- Переменные окружения подставляются через `envsubst`
- Docker Compose project name: `fast-monitoring`

## Conventions

- Коммиты — conventional commits (`feat:`, `fix:`, `docs:`, `chore:`)
- Bash-скрипты без строгих правил, shellcheck приветствуется
- Документация на русском языке (в `docs/`)
- Тестовый фреймворк отсутствует — проверка ручным запуском скриптов
