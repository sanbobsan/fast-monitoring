# fast-monitoring

Docker-based server monitoring stack (Grafana + Prometheus + Node Exporter).
Single-command deploy — monitors CPU, RAM, disk, and network of any Linux server.

## Project Structure

```
.
├── AGENTS.md                       # AI assistant instructions (this file)
├── install.sh                      # Deploy: copies files, docker compose up -d
├── remove.sh                       # Teardown: docker compose down -v + rm -rf
├── .env.example                    # Configuration template
├── config/
│   ├── compose.yaml                # Docker Compose (prometheus, grafana, node-exporter)
│   ├── prometheus.template.yaml    # Prometheus config template (envsubst)
│   └── grafana/
│       └── datasources.yaml        # Provisioned Grafana datasource
├── docs/
│   ├── README.md                   # User-facing documentation (English)
│   └── note.md                     # Technical notes (Russian)
└── .gitignore
```

## How to Use

### Local install (from repo)

```bash
./install.sh                                    # defaults
./install.sh --app_dir /opt/mon --node_port 9200
./install.sh --dev                              # from dev branch (pre-release)
```

### Remote install (no local files needed)

```bash
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | bash
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/install.sh | bash -s -- --dev
curl -fSsL https://raw.githubusercontent.com/sanbobsan/fast-monitoring/main/remove.sh | bash -s -- --app_dir /opt/mon
```

### Custom fork / branch via env

```bash
REPO=myfork/fast-monitoring BRANCH=myfeature ./install.sh
```

## Configuration

All options are optional — defaults apply for any omitted value.

### Variable precedence (highest → lowest)

1. **CLI args** — `--app_dir`, `--grafana_port`, `--grafana_user`, `--grafana_password`, `--node_port`, `--dev`
2. **`.env` / environment variables**
3. **Built-in defaults**

### Available options

| CLI flag | Env var | Default | Description |
|---|---|---|---|
| `--app_dir` | `APP_DIR` | `/opt/fast-monitoring` | Deployment directory |
| `--grafana_port` | `GRAFANA_PORT` | `3000` | Grafana port on localhost |
| `--grafana_user` | `GRAFANA_USER` | `user` | Grafana admin login |
| `--grafana_password` | `GRAFANA_PASSWORD` | `password` | Grafana admin password |
| `--node_port` | `NODE_PORT` | `9100` | Node Exporter port on Docker bridge |
| `--dev` | `BRANCH` | `main` | Install from `dev` branch (pre-release) |
| _(no flag)_ | `REPO` | `sanbobsan/fast-monitoring` | Fork/repo URL for remote install |

`--dev` overrides `BRANCH` from `.env` (CLI > .env).

`VERSION` is hardcoded in `install.sh` and is not overridable.

## Architecture

### Network

- Isolated Docker bridge network `172.30.0.0/24`
- Compose project name: `fast-monitoring`

### Components

- **Node Exporter** — `network_mode: host`. Runs in the host network namespace to collect hardware metrics via `/proc` and `/sys`. Listens on `172.30.0.1:NODE_PORT` (Docker bridge gateway interface on the host). Not exposed outside the server.
- **Prometheus** — scrapes Node Exporter every 15s. Stores 30 days in a Docker volume. Internal — not exposed to the host. Accessible only within the Docker network.
- **Grafana** — visualizes metrics from Prometheus. Bound to `127.0.0.1:GRAFANA_PORT` only. Remote access via SSH tunnel: `ssh -N -L 8000:127.0.0.1:GRAFANA_PORT user@host`.

### Firewall consideration

Because Node Exporter uses `network_mode: host` and listens on the Docker bridge gateway IP, a host firewall (UFW, firewalld, iptables) may block traffic from the Docker bridge subnet (`172.30.0.0/24`) to `NODE_PORT`.

The install script checks connectivity after `docker compose up -d` and prints a warning with the appropriate fix command if the check fails.

**Fix commands:**

- **UFW**: `sudo ufw allow from 172.30.0.0/24 to any port 9100 proto tcp`
- **firewalld**: `sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=172.30.0.0/24 port port=9100 protocol=tcp accept' && sudo firewall-cmd --reload`
- **iptables** (DOCKER-USER chain, recommended for Docker): `sudo iptables -I DOCKER-USER -s 172.30.0.0/24 -p tcp --dport 9100 -j ACCEPT`

## Troubleshooting

### Node Exporter not scraped (N/A in dashboards)

**Symptom**: Grafana connects to Prometheus, but no Node Exporter metrics. Dashboard values show N/A. Prometheus target `node-local` has `health: "down"` with error `context deadline exceeded`.

**Diagnosis**:

```bash
# 1. Check if Node Exporter is running
docker compose ps

# 2. Check Prometheus targets
docker compose exec prometheus wget -qO- http://localhost:9090/api/v1/targets | python3 -m json.tool

# 3. Test connectivity from Prometheus to Node Exporter
docker compose exec prometheus wget -qO- -T 5 http://host.docker.internal:9100/metrics
```

If step 3 fails, it is most likely a **firewall blocking Docker bridge traffic** (see "Firewall consideration" above).

### Grafana 401 errors on /api/live/ws

Logs may show repeated `401` errors from `remote_addr=172.30.0.1` (Docker bridge gateway) to `GET /api/live/ws`. This is a non-issue — it is either a browser tab left open or Grafana Live heartbeat. It does not affect scraping or metric collection.

## Versioning & Release Workflow

### Branching model

- **`main`** — stable releases. History is clean (one squash commit per release).
- **`dev`** — active development. Recreated after each release (see below).

### Release cycle

1. **Development** in `dev`:
   ```bash
   git checkout dev
   # make changes, commit
   git add .
   git commit -m "feat: ..."
   git commit -m "fix: ..."
   ```

2. **Push and create PR**:
   ```bash
   git push origin dev
   gh pr create --base main --head dev \
     --title "feat: summary of changes (vX.Y.Z)" \
     --body "- summary of change one
   - summary of change two

   Closes #N"
   ```
   PR title follows **conventional commits** — it becomes the squash commit subject on `main`.
   PR body uses a bullet list with lowercase start, no trailing dot.
   `Closes #N` at the end — GitHub auto-closes the referenced issues on squash merge.

3. **Squash merge** (GitHub setting: "Pull request title and description"):
   ```bash
   gh pr merge --squash --delete-branch
   ```

4. **Tag**:
   ```bash
   git checkout main && git pull origin main
   git tag vX.Y.Z && git push origin vX.Y.Z
   ```

5. **Recreate dev** (clean sync):
   ```bash
   git checkout main
   git pull origin main
   git branch -D dev
   git checkout -b dev
   git push origin dev
   ```

#### Automation alias (optional)

```bash
git config --global alias.sync-dev "!git checkout main && git pull origin main && git branch -D dev && git checkout -b dev && git push origin dev"
```

After step 3, run: `git sync-dev`

### Hotfix

For urgent fixes that cannot wait for the next dev cycle:

1. Branch from `main`: `git checkout -b fix/xxx main`
2. Commit the fix
3. Push and PR to `main` (same squash + tag flow)
4. Recreate dev: `git sync-dev` (or the 5-step recreate above)
5. Patch version bump: `chore: bump version to v1.0.1`

## Conventions

### Commit messages

[Conventional Commits](https://www.conventionalcommits.org/):
`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`.

### Squash commit naming

Squash commits in `main` use the same conventional commit types, NOT "Release vX.Y.Z". The release version is captured by the git tag only.

If a release bundles multiple features, pick the dominant type:
```text
feat: add firewall detection and dev branch support
```
not:
```text
Release v1.1.0     ← avoid
```

### PR title and body

- **PR title** follows conventional commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`).
  It becomes the squash commit message on `main`.
- **PR body** uses a bullet list with `- ` prefix, lowercase start, no trailing dot.
  Ends with `Closes #N` lines to auto-close referenced issues.

### GitHub setting

Squash merge must use **"Pull request title and description"** as the default commit message.

### Code

- Bash scripts: no strict style rules, shellcheck welcome
- `VERSION` in `install.sh` is **hardcoded** — do not make it configurable
- All new config must follow the existing `CLI → .env → defaults` precedence

### Documentation

- `docs/README.md` — user-facing, **English**
- `docs/note.md` — internal technical notes, **Russian**
- `AGENTS.md` — AI assistant instructions, **English**

### Testing

No test framework. Validation is done by running scripts manually. Before committing changes to `install.sh` or `remove.sh`, verify they work in a test environment.
