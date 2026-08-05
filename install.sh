VERSION="1.4.1"
die() { echo "Error: $1" >&2; exit 1; }

if [ -f .env ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ""|"#"*) continue ;;
            *) export "$line" ;;
        esac
    done < .env
fi

ORIG_ARGS=("$@")

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            echo "Usage: install.sh [OPTIONS]"
            echo ""
            echo "Deploy fast-monitoring stack (Grafana + Prometheus + Node Exporter)"
            echo ""
            echo "Options:"
            echo "  --app_dir DIR           Deployment directory (default: /opt/fast-monitoring)"
            echo "  --grafana_port PORT     Grafana port (default: 3000)"
            echo "  --grafana_user USER     Grafana admin user (default: user)"
            echo "  --grafana_password PASS Grafana admin password (default: password)"
            echo "  --node_port PORT        Node exporter port (default: 9100)"
            echo "  --project_name NAME     Docker compose project name (default: fast-monitoring)"
            echo "  --dev                   Install from dev branch (pre-release)"
            echo "  --help, -h              Show this help"
            exit 0 ;;
        --app_dir)
            [ -z "$2" ] && die "--app_dir requires a non-empty value"
            [ "${2#-}" != "$2" ] && die "--app_dir expects a value, got '$2'"
            APP_DIR="$2"; shift 2 ;;
        --grafana_port)
            [ -z "$2" ] && die "--grafana_port requires a non-empty value"
            [ "${2#-}" != "$2" ] && die "--grafana_port expects a value, got '$2'"
            GRAFANA_PORT="$2"; shift 2 ;;
        --grafana_user)
            [ -z "$2" ] && die "--grafana_user requires a non-empty value"
            [ "${2#-}" != "$2" ] && die "--grafana_user expects a value, got '$2'"
            GRAFANA_USER="$2"; shift 2 ;;
        --grafana_password)
            [ -z "$2" ] && die "--grafana_password requires a non-empty value"
            [ "${2#-}" != "$2" ] && die "--grafana_password expects a value, got '$2'"
            GRAFANA_PASSWORD="$2"; shift 2 ;;
        --node_port)
            [ -z "$2" ] && die "--node_port requires a non-empty value"
            [ "${2#-}" != "$2" ] && die "--node_port expects a value, got '$2'"
            NODE_PORT="$2"; shift 2 ;;
        --project_name)
            [ -z "$2" ] && die "--project_name requires a non-empty value"
            [ "${2#-}" != "$2" ] && die "--project_name expects a value, got '$2'"
            PROJECT_NAME="$2"; shift 2 ;;
        --dev)
            BRANCH="dev"; shift ;;
        *) die "Unknown option: $1"
    esac
done

export APP_DIR="${APP_DIR:-/opt/fast-monitoring}"
export GRAFANA_PORT="${GRAFANA_PORT:-3000}"
export GRAFANA_USER="${GRAFANA_USER:-user}"
export GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-password}"
export NODE_PORT="${NODE_PORT:-9100}"
export PROJECT_NAME="${PROJECT_NAME:-fast-monitoring}"

REPO="${REPO:-sanbobsan/fast-monitoring}"
BRANCH="${BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

if [ "$BRANCH" = "dev" ] && [ "${FM_REDIRECTED:-0}" != "1" ]; then
    echo "Fetching install.sh from $REPO/dev (--dev)..."
    tmp=$(mktemp) || die "Cannot create temporary file"
    DEV_URL="https://raw.githubusercontent.com/${REPO}/dev/install.sh"
    curl -fSsL "$DEV_URL" -o "$tmp" || { rm -f "$tmp"; die "Failed to download $DEV_URL"; }
    export FM_REDIRECTED=1
    bash "$tmp" "${ORIG_ARGS[@]}"
    status=$?
    rm -f "$tmp"
    exit $status
fi

if [ -d "${APP_DIR}" ] && [ -n "$(ls -A "${APP_DIR}" 2>/dev/null)" ]; then
    echo "Error: ${APP_DIR} already exists and is not empty." >&2
    echo "  Choose a different directory or remove it first:" >&2
    echo "    rm -rf ${APP_DIR}" >&2
    echo "  If it is a fast-monitoring deployment, use remove.sh:" >&2
    echo "    curl -fSsL ${RAW_BASE}/remove.sh | sudo bash -s -- --app_dir ${APP_DIR}" >&2
    exit 1
fi

if [ -f "./config/compose.yaml" ]; then
    MODE="local"
else
    MODE="remote"
fi

mkdir -p "${APP_DIR}" 2>/dev/null || die "Cannot create ${APP_DIR}. Re-run with: curl -fSsL ${RAW_BASE}/install.sh | sudo bash"
mkdir -p "${APP_DIR}/prometheus" "${APP_DIR}/grafana" "${APP_DIR}/grafana/dashboards" 2>/dev/null || die "Cannot create subdirectories in ${APP_DIR}. Re-run with: curl -fSsL ${RAW_BASE}/install.sh | sudo bash"

if [ "$MODE" = "local" ]; then
    [ -f ./config/compose.yaml ] || die "Missing ./config/compose.yaml"
    cp ./config/compose.yaml "${APP_DIR}" || die "Failed to copy compose.yaml"
else
    curl -fSsL "$RAW_BASE/config/compose.yaml" -o "${APP_DIR}/compose.yaml" || die "Failed to download compose.yaml"
fi

if [ "$MODE" = "local" ]; then
    [ -f ./config/prometheus.template.yaml ] || die "Missing ./config/prometheus.template.yaml"
    envsubst < ./config/prometheus.template.yaml > "${APP_DIR}/prometheus/prometheus.yaml" || die "Failed to process prometheus template"
else
    curl -fSsL "$RAW_BASE/config/prometheus.template.yaml" | envsubst > "${APP_DIR}/prometheus/prometheus.yaml" || die "Failed to download or process prometheus template"
fi

if [ "$MODE" = "local" ]; then
    [ -f ./config/grafana/datasources.yaml ] || die "Missing ./config/grafana/datasources.yaml"
    [ -f ./config/grafana/dashboards.yaml ] || die "Missing ./config/grafana/dashboards.yaml"
    ls ./config/grafana/dashboards/*.json >/dev/null 2>&1 || die "No dashboard files in ./config/grafana/dashboards/"
    cp ./config/grafana/datasources.yaml ./config/grafana/dashboards.yaml "${APP_DIR}/grafana/" || die "Failed to copy grafana provisioning files"
    cp -r ./config/grafana/dashboards "${APP_DIR}/grafana/" || die "Failed to copy grafana dashboards"
else
    curl -fSsL "$RAW_BASE/config/grafana/datasources.yaml" -o "${APP_DIR}/grafana/datasources.yaml" || die "Failed to download datasources.yaml"
    curl -fSsL "$RAW_BASE/config/grafana/dashboards.yaml" -o "${APP_DIR}/grafana/dashboards.yaml" || die "Failed to download dashboards.yaml"
    curl -fSsL "$RAW_BASE/config/grafana/dashboards/node-exporter-full.json" -o "${APP_DIR}/grafana/dashboards/node-exporter-full.json" || die "Failed to download dashboard"
fi

cat > "${APP_DIR}/.env" << EOF
# fast-monitoring configuration
APP_DIR=${APP_DIR}
GRAFANA_PORT=${GRAFANA_PORT}
GRAFANA_USER=${GRAFANA_USER}
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}
NODE_PORT=${NODE_PORT}
PROJECT_NAME=${PROJECT_NAME}

# NODE_PORT is baked into prometheus/prometheus.yaml at install time.
# To change NODE_PORT, edit prometheus/prometheus.yaml directly or re-deploy.
EOF

cat > "${APP_DIR}/.fast-monitoring" << EOF
# fast-monitoring deployment marker
VERSION=${VERSION}
INSTALL_DATE=$(date +%Y-%m-%d)
NODE_PORT=${NODE_PORT}
PROJECT_NAME=${PROJECT_NAME}
EOF

cd "${APP_DIR}" || die "Cannot access ${APP_DIR}"

docker compose --project-name "${PROJECT_NAME}" up -d

echo "Checking Node Exporter connectivity..."
sleep 5
if ! docker compose --project-name "${PROJECT_NAME}" exec -T prometheus wget -qO- -T 5 "http://host.docker.internal:${NODE_PORT}/metrics" >/dev/null 2>&1; then
    echo ""
    echo "⚠ Prometheus cannot reach Node Exporter at host.docker.internal:${NODE_PORT}"
    echo "  This is usually caused by a firewall blocking traffic from the Docker"
    echo "  bridge network (172.30.0.0/24) to port ${NODE_PORT} on the host."
    echo ""
    detected=false
    if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi active; then
        detected=true
        echo "  Detected: UFW is active."
        echo "  Fix it with:"
        echo "    sudo ufw allow from 172.30.0.0/24 to any port ${NODE_PORT} proto tcp"
        echo ""
    fi
    if command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state 2>/dev/null | grep -q running; then
        detected=true
        echo "  Detected: firewalld is active."
        echo "  Fix it with:"
        echo "    sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=172.30.0.0/24 port port=${NODE_PORT} protocol=tcp accept'"
        echo "    sudo firewall-cmd --reload"
        echo ""
    fi
    if [ "$detected" = false ]; then
        echo "  No recognized firewall detected, but the connection failed."
        echo "  Check your iptables/nftables rules for the Docker bridge."
        echo ""
    fi
    echo "  After applying the fix, run: docker compose --project-name \"${PROJECT_NAME}\" restart prometheus"
    echo ""
fi
