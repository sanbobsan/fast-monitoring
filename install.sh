
if [ -f .env ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ""|"#"*) continue ;;
            *) export "$line" ;;
        esac
    done < .env
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --app_dir) APP_DIR="$2"; shift 2 ;;
        --grafana_port) GRAFANA_PORT="$2"; shift 2 ;;
        --grafana_user) GRAFANA_USER="$2"; shift 2 ;;
        --grafana_password) GRAFANA_PASSWORD="$2"; shift 2 ;;
        --node_port) NODE_PORT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

export APP_DIR="${APP_DIR:-/opt/fast-monitoring}"
export GRAFANA_PORT="${GRAFANA_PORT:-3000}"
export GRAFANA_USER="${GRAFANA_USER:-user}"
export GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-password}"
export NODE_PORT="${NODE_PORT:-9100}"

mkdir -p "${APP_DIR}"
mkdir -p "${APP_DIR}/prometheus"
mkdir -p "${APP_DIR}/grafana"

cp ./config/compose.yaml "${APP_DIR}"
envsubst < ./config/prometheus.template.yaml > "${APP_DIR}/prometheus/prometheus.yaml"
cp ./config/grafana/* "${APP_DIR}/grafana/"

cd "${APP_DIR}"
docker compose up -d
