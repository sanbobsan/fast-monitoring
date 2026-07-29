
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

cp ./config/compose.yaml "${APP_DIR}"
envsubst < ./config/prometheus.template.yaml > "${APP_DIR}/prometheus/prometheus.yaml"
cp ./config/grafana/* "${APP_DIR}/grafana/"

cd "${APP_DIR}"
docker compose up -d
