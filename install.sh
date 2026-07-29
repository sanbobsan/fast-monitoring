die() { echo "Error: $1" >&2; exit 1; }

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
        *) die "Unknown option: $1"
    esac
done

export APP_DIR="${APP_DIR:-/opt/fast-monitoring}"
export GRAFANA_PORT="${GRAFANA_PORT:-3000}"
export GRAFANA_USER="${GRAFANA_USER:-user}"
export GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-password}"
export NODE_PORT="${NODE_PORT:-9100}"

REPO="sanbobsan/fast-monitoring"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

if [ -f "./config/compose.yaml" ]; then
    MODE="local"
else
    MODE="remote"
fi

mkdir -p "${APP_DIR}" 2>/dev/null || die "Cannot create ${APP_DIR}. Re-run with: curl -fSsL ${RAW_BASE}/install.sh | sudo bash"
mkdir -p "${APP_DIR}/prometheus" "${APP_DIR}/grafana" 2>/dev/null || die "Cannot create subdirectories in ${APP_DIR}. Re-run with: curl -fSsL ${RAW_BASE}/install.sh | sudo bash"

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
    ls ./config/grafana/*.yaml >/dev/null 2>&1 || die "No grafana datasource files in ./config/grafana/"
    cp ./config/grafana/* "${APP_DIR}/grafana/" || die "Failed to copy grafana datasource"
else
    curl -fSsL "$RAW_BASE/config/grafana/datasources.yaml" -o "${APP_DIR}/grafana/datasources.yaml" || die "Failed to download datasources.yaml"
fi

cd "${APP_DIR}" || die "Cannot access ${APP_DIR}"

docker compose up -d
