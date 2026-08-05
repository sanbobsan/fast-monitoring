VERSION="1.3.0"
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
        --help|-h)
            echo "Usage: remove.sh [OPTIONS]"
            echo ""
            echo "Remove fast-monitoring stack (docker compose down -v + rm -rf)"
            echo ""
            echo "Options:"
            echo "  --app_dir DIR           Deployment directory (default: /opt/fast-monitoring)"
            echo "  --force                 Skip .fast-monitoring check and confirmation"
            echo "  --help, -h              Show this help"
            exit 0 ;;
        --app_dir)
            [ -z "$2" ] && die "--app_dir requires a non-empty value"
            [ "${2#-}" != "$2" ] && die "--app_dir expects a value, got '$2'"
            APP_DIR="$2"; shift 2 ;;
        --force)
            FORCE=1; shift ;;
        *) die "Unknown option: $1"
    esac
done

export APP_DIR="${APP_DIR:-/opt/fast-monitoring}"
export GRAFANA_PORT="${GRAFANA_PORT:-3000}"
export GRAFANA_USER="${GRAFANA_USER:-user}"
export GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-password}"
export NODE_PORT="${NODE_PORT:-9100}"

REPO="${REPO:-sanbobsan/fast-monitoring}"
BRANCH="${BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/$REPO/$BRANCH"

cd "${APP_DIR}" 2>/dev/null || die "Directory ${APP_DIR} does not exist"

[ "$FORCE" = "1" ] || [ -f "${APP_DIR}/.fast-monitoring" ] || die "${APP_DIR} is not a fast-monitoring project (missing .fast-monitoring)"

if [ "$FORCE" != "1" ]; then
    echo ""
    echo "This will remove the fast-monitoring stack from ${APP_DIR}:"
    echo "  - docker compose down -v (containers, volumes, network)"
    echo "  - rm -rf ${APP_DIR}"
    echo ""
    if [ -t 0 ] || (exec 3< /dev/tty) 2>/dev/null; then
        if [ -t 0 ]; then
            read -r -p "Are you sure? Type 'yes' to continue: " answer || true
        else
            read -r -p "Are you sure? Type 'yes' to continue: " answer < /dev/tty || true
        fi
        [ "$answer" = "yes" ] || { echo "Aborted." >&2; exit 1; }
    else
        echo "No interactive terminal detected. Re-run with --force to skip confirmation." >&2
        exit 1
    fi
fi

docker compose down -v 2>/dev/null || true

rm -rf "${APP_DIR}" 2>/dev/null || die "Failed to remove ${APP_DIR}. Re-run with: curl -fSsL ${RAW_BASE}/remove.sh | sudo bash"
