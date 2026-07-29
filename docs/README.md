# fast-monitoring

Fast server monitoring setup (Grafana + Prometheus + Node Exporter) in an isolated Docker environment. Single command to deploy — monitor CPU, RAM, disk, and network of any Linux server.

## Quick Start

```bash
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | sudo bash
```

That's it. The stack is deployed to `/opt/fast-monitoring/` (default) and starts automatically.

- **Grafana** — `http://localhost:3000` (user: `user`, password: `password`)
- **Prometheus** — internal, reachable via Docker network
- **Node Exporter** — collects host metrics

## Prerequisites

- Linux server with **Docker** and **Docker Compose** (plugin or standalone)
- `curl` — for downloading the script
- `envsubst` — for template processing (part of `gettext`, usually pre-installed)

## Configuration

All options are optional — defaults are used for any omitted value.

You can configure the stack in two ways.

### Available options

| Option | Env variable | Default | Description |
|---|---|---|---|
| `--app_dir` | `APP_DIR` | `/opt/fast-monitoring` | Deployment directory (must be writable) |
| `--grafana_port` | `GRAFANA_PORT` | `3000` | Grafana port on localhost |
| `--grafana_user` | `GRAFANA_USER` | `user` | Grafana admin login |
| `--grafana_password` | `GRAFANA_PASSWORD` | `password` | Grafana admin password |
| `--node_port` | `NODE_PORT` | `9100` | Node Exporter port on Docker bridge |

### 1. CLI arguments

```bash
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | sudo bash -s -- \
  --app_dir /opt/mon \
  --node_port 9200 \
  --grafana_port 4000 \
  --grafana_user admin \
  --grafana_password secret
```

### 2. .env file

Place a `.env` file in the current working directory before running the script. The script reads it automatically:

```bash
mkdir -p /tmp/fm-install && cd /tmp/fm-install
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/.env.example -o .env
# edit .env (APP_DIR, GRAFANA_PORT, etc.)
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | sudo bash
# script reads .env from the current directory automatically
rm -rf /tmp/fm-install  # temp directory can be cleaned up after install
```

### Precedence (highest → lowest)

```
CLI arguments → .env / environment variables → built-in defaults
```

## Post-install

The deployment directory (`/opt/fast-monitoring/` by default) contains everything needed to run the stack:

```
/opt/fast-monitoring/
├── .env                   # configuration (editable)
├── .fast-monitoring       # deployment marker with version and install date
├── compose.yaml
├── prometheus/
│   └── prometheus.yaml
└── grafana/
    └── datasources.yaml
```

### Changing settings

- **GRAFANA_PORT, GRAFANA_USER, GRAFANA_PASSWORD** — edit `$APP_DIR/.env`, then run `docker compose up -d` in the same directory
- **NODE_PORT** — baked into `prometheus/prometheus.yaml` at install time. To change, re-run `install.sh` or edit `prometheus/prometheus.yaml` manually

## Management

Run from the deployment directory:

```bash
cd /opt/fast-monitoring
docker compose ps       # check container status
docker compose logs -f  # view logs
docker compose up -d    # restart with updated .env
docker compose down     # stop without removing data
```

## Architecture

Three components connected in an isolated Docker bridge network (`172.30.0.0/24`):

- **Node Exporter** — `network_mode: host`. Runs directly on the host network namespace to access hardware metrics (/proc, /sys). Listens on `172.30.0.1:NODE_PORT` (Docker bridge interface). Not accessible from outside the server.

- **Prometheus** — scrapes Node Exporter every 15s. Stores 30 days of metrics in a Docker volume (`prometheus_data`). Internal — not exposed to the host.

- **Grafana** — visualizes metrics from Prometheus. Bound to `127.0.0.1:GRAFANA_PORT` only for security. Not accessible from the internet directly.

### Accessing Grafana remotely

Use an SSH tunnel to forward Grafana to your local machine:

```bash
ssh -N -L 8000:127.0.0.1:GRAFANA_PORT user@your-server
```

Then open `http://localhost:8000` in your browser.

### Docker Compose project name

The project name is `fast-monitoring`. Use `-p fast-monitoring` if running docker compose from outside the deployment directory:

```bash
docker compose -f /opt/fast-monitoring/compose.yaml -p fast-monitoring up -d
```

## Removal

```bash
# remove the default location (/opt/fast-monitoring)
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/remove.sh | sudo bash

# remove a custom location
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/remove.sh | sudo bash -s -- --app_dir /opt/mon
```

By default, `--app_dir` is `/opt/fast-monitoring`, so it can be omitted when removing the default location.

The script checks for the `.fast-monitoring` marker before deleting to prevent accidental data loss. It stops containers (`docker compose down -v`) and removes the entire deployment directory.
