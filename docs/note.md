# fast-monitoring — устройство сети

Grafana доступна только на localhost:3000 (прокси через SSH):
`ssh -N -L 8000:127.0.0.1:{port grafana} {user}@{ip}`

Compose создает виртуальную сеть 172.30.0.0/24, через которую все контейнеры общаются.

Порт node-exporter открывается на хосте на интерфейсе сетевого моста docker,
потому что `network_mode: host` и `--web.listen-address=172.30.0.1:${NODE_PORT}`
