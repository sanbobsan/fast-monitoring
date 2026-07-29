
APP_DIR="${APP_DIR:-/opt/fast-monitoring}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"
GRAFANA_USER="${GRAFANA_USER:-user}"
GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-password}"
NODE_PORT="${NODE_PORT:-9100}"

if [ -f .env ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ""|"#"*) continue ;;
            *) export "$line" ;;
        esac
    done < .env
fi

cd "${APP_DIR}"

docker compose down -v

rm -rf "${APP_DIR}"
