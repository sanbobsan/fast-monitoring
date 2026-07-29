
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
        --app_dir)
            [ -z "$2" ] && { echo "Error: --app_dir requires a non-empty value" >&2; exit 1; }
            [ "${2#-}" != "$2" ] && { echo "Error: --app_dir expects a value, got '$2'" >&2; exit 1; }
            APP_DIR="$2"; shift 2 ;;
        --grafana_port)
            [ -z "$2" ] && { echo "Error: --grafana_port requires a non-empty value" >&2; exit 1; }
            [ "${2#-}" != "$2" ] && { echo "Error: --grafana_port expects a value, got '$2'" >&2; exit 1; }
            GRAFANA_PORT="$2"; shift 2 ;;
        --grafana_user)
            [ -z "$2" ] && { echo "Error: --grafana_user requires a non-empty value" >&2; exit 1; }
            [ "${2#-}" != "$2" ] && { echo "Error: --grafana_user expects a value, got '$2'" >&2; exit 1; }
            GRAFANA_USER="$2"; shift 2 ;;
        --grafana_password)
            [ -z "$2" ] && { echo "Error: --grafana_password requires a non-empty value" >&2; exit 1; }
            [ "${2#-}" != "$2" ] && { echo "Error: --grafana_password expects a value, got '$2'" >&2; exit 1; }
            GRAFANA_PASSWORD="$2"; shift 2 ;;
        --node_port)
            [ -z "$2" ] && { echo "Error: --node_port requires a non-empty value" >&2; exit 1; }
            [ "${2#-}" != "$2" ] && { echo "Error: --node_port expects a value, got '$2'" >&2; exit 1; }
            NODE_PORT="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
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
