
if [ -f .env ]; then
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ""|"#"*) continue ;;
            *) export "$line" ;;
        esac
    done < .env
fi

mkdir -p "${APP_DIR}"
mkdir -p "${APP_DIR}/prometheus"
mkdir -p "${APP_DIR}/grafana"

cp ./data/compose.yaml "${APP_DIR}"
envsubst < ./data/prometheus.template.yaml > "${APP_DIR}/prometheus/prometheus.yaml"
cp ./data/grafana/* "${APP_DIR}/grafana/"

cd "${APP_DIR}"
docker compose up -d
