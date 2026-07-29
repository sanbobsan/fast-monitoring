# fast-monitoring

Fast server monitoring setup (Grafana + Prometheus + Node Exporter)
in an isolated Docker environment.

## Quick Start

Single command — and the stack is running:

```bash
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | sudo bash
```

By default, Grafana will be available at `http://localhost:3000` (user: `user`, password: `password`).

## Configuration

You can configure the stack in two ways.

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

Download `.env.example`, fill it, and run the script alongside it:

```bash
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/.env.example -o /tmp/.env
# edit /tmp/.env (APP_DIR, GRAFANA_PORT, etc.)
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | sudo bash
# script reads /tmp/.env automatically
# /tmp/.env can be removed after install
```

### Available options

| Option | Env variable | Default | Description |
|---|---|---|---|
| `--app_dir` | `APP_DIR` | `/opt/fast-monitoring` | Deployment directory |
| `--grafana_port` | `GRAFANA_PORT` | `3000` | Grafana port (localhost) |
| `--grafana_user` | `GRAFANA_USER` | `user` | Grafana admin login |
| `--grafana_password` | `GRAFANA_PASSWORD` | `password` | Grafana admin password |
| `--node_port` | `NODE_PORT` | `9100` | Node exporter port on docker bridge |

### Precedence (highest → lowest)

```
CLI arguments → .env / environment variables → built-in defaults
```

## Post-install

After installation, `$APP_DIR/.env` is generated with the values used during setup.
Docker Compose reads this file automatically on every `up -d`.

- To change `GRAFANA_PORT`, `GRAFANA_USER`, or `GRAFANA_PASSWORD` — edit `.env`
  and run `docker compose up -d`.
- To change `NODE_PORT` — re-run install.sh or edit
  `$APP_DIR/prometheus/prometheus.yaml` manually (it is baked at install time).

The deployment directory is fully self-contained:

```
/opt/fast-monitoring/
├── .env                   # configuration (editable)
├── .fast-monitoring       # deployment marker with version info
├── compose.yaml
├── prometheus/
│   └── prometheus.yaml
└── grafana/
    └── datasources.yaml
```

## Architecture

- **Grafana** — accessible on `127.0.0.1:GRAFANA_PORT` only (use SSH tunnel:
  `ssh -N -L 8000:127.0.0.1:{port} {user}@{ip}`)
- **Prometheus** — internal, reachable only within the Docker network
- **Node Exporter** — `network_mode: host`, listens on `172.30.0.1:NODE_PORT`
- **Network** — isolated bridge `172.30.0.0/24`
- **Docker Compose project name** — `fast-monitoring`

## Removal

```bash
# via internet
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/remove.sh | sudo bash -s -- --app_dir /opt/fast-monitoring

# or locally if you have the repo
sudo bash remove.sh --app_dir /opt/fast-monitoring
```

The script checks for the `.fast-monitoring` marker before deletion to prevent
accidental data loss.
