# fast-monitoring

Fast server monitoring setup (Grafana + Prometheus + Node Exporter) in an isolated Docker environment. Single command to deploy — monitor CPU, RAM, disk, and network of any Linux server.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Firewall](#firewall)
- [Configuration](#configuration)
- [Post-install](#post-install)
- [Management](#management)
- [Architecture](#architecture)
- [Removal](#removal)

## Quick Start

```bash
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | sudo bash
```

That's it. The stack is deployed to `/opt/fast-monitoring/` (default) and starts automatically.

Removal is just as easy — see [Removal](#removal).

- **Grafana** — `http://localhost:3000` (user: `user`, password: `password`)
- **Prometheus** — internal, reachable via Docker network
- **Node Exporter** — collects host metrics

A **Node Exporter Full** dashboard is provisioned automatically — open it in
Grafana: Dashboards → **Node Exporter Full**.

## Prerequisites

- Linux server with **Docker** and **Docker Compose** (plugin or standalone)
- `curl` — for downloading the script
- `envsubst` — for template processing (part of `gettext`, usually pre-installed)

## Firewall

Node Exporter uses `network_mode: host` and listens on the Docker bridge interface
(`172.30.0.1:NODE_PORT`). Prometheus scrapes it through the Docker bridge network.
If a firewall (UFW, firewalld, iptables, nftables) blocks traffic from the Docker
bridge subnet (`172.30.0.0/24`) to `NODE_PORT`, Prometheus will not receive any
Node Exporter metrics.

**Symptom**: Grafana connects to Prometheus successfully, but Node Exporter metrics
are missing. Prometheus target `node-local` shows `health: "down"` with error
`context deadline exceeded`.

Check connectivity manually:
```bash
docker compose exec prometheus wget -qO- http://host.docker.internal:9100/metrics
```

If the command hangs or fails, apply the appropriate rule:

- **UFW**:
  ```bash
  sudo ufw allow from 172.30.0.0/24 to any port 9100 proto tcp
  ```
- **firewalld**:
  ```bash
  sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=172.30.0.0/24 port port=9100 protocol=tcp accept' && sudo firewall-cmd --reload
  ```
- **iptables** (DOCKER-USER chain, persists across Docker restarts):
  ```bash
  sudo iptables -I DOCKER-USER -s 172.30.0.0/24 -p tcp --dport 9100 -j ACCEPT
  ```

The install script attempts to detect active firewalls and prints a warning if
Prometheus cannot reach Node Exporter after deployment.

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
| `--dev` | `BRANCH` | `main` | Install from `dev` branch (pre-release testing) |
| `--force` | — | — | Skip `.fast-monitoring` check and confirmation (remove.sh only) |

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

1. Download the example config:
   ```bash
   mkdir -p /tmp/fm-install && cd /tmp/fm-install
   curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/.env.example -o .env
   ```
2. Edit `.env` (APP_DIR, GRAFANA_PORT, etc.)
3. Run the installer (reads `.env` from the current directory):
   ```bash
   curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | sudo bash
   ```
4. Clean up (optional):
   ```bash
   rm -rf /tmp/fm-install
   ```

`REPO` and `BRANCH` are not available as CLI flags but can be set via `.env` to install from a custom fork or branch:

```bash
REPO=myfork/fast-monitoring BRANCH=myfeature ./install.sh
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
    ├── datasources.yaml
    ├── dashboards.yaml
    └── dashboards/
        └── node-exporter-full.json
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
```

```bash
# remove a custom location
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/remove.sh | sudo bash -s -- --app_dir /opt/mon
```

```bash
# force removal (skips .fast-monitoring check and confirmation)
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/remove.sh | sudo bash -s -- --force
```

By default, `--app_dir` is `/opt/fast-monitoring`, so it can be omitted when removing the default location.

The script checks for the `.fast-monitoring` marker and asks for confirmation (`yes`) before deleting anything. Use `--force` to skip both. It stops containers (`docker compose down -v`) and removes the entire deployment directory.
