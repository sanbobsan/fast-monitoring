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
        *) die "Unknown option: $1"
    esac
done

export APP_DIR="${APP_DIR:-/opt/fast-monitoring}"
export GRAFANA_PORT="${GRAFANA_PORT:-3000}"
export GRAFANA_USER="${GRAFANA_USER:-user}"
export GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-password}"
export NODE_PORT="${NODE_PORT:-9100}"

cd "${APP_DIR}" 2>/dev/null || die "Directory ${APP_DIR} does not exist"

docker compose down -v 2>/dev/null || true

rm -rf "${APP_DIR}" || die "Failed to remove ${APP_DIR}. Try: sudo rm -rf ${APP_DIR}"
