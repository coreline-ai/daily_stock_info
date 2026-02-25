#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

resolve_lan_ip() {
  if [[ -n "${LAN_IP:-}" ]]; then
    echo "$LAN_IP"
    return 0
  fi

  if command -v route >/dev/null 2>&1 && command -v ipconfig >/dev/null 2>&1; then
    local iface
    iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2}' | head -n1)"
    if [[ -n "$iface" ]]; then
      local ip
      ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
      if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
      fi
    fi
  fi

  if command -v ip >/dev/null 2>&1; then
    local ip_addr
    ip_addr="$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="src"){print $(i+1); exit}}}')"
    if [[ -n "$ip_addr" ]]; then
      echo "$ip_addr"
      return 0
    fi
  fi

  return 1
}

LAN_IP="$(resolve_lan_ip || true)"
if [[ -z "$LAN_IP" ]]; then
  echo "[ERROR] LAN IP 자동 감지 실패. 수동으로 실행하세요:"
  echo "  LAN_IP=192.168.x.x scripts/run-lan-dev.sh"
  exit 1
fi

API_URL="http://${LAN_IP}:8000"
WEB_URL="http://${LAN_IP}:3000"

export FRONTEND_ALLOWED_ORIGINS="http://localhost:3000,http://127.0.0.1:3000,${WEB_URL}"
export FRONTEND_ALLOWED_ORIGIN_REGEX=""

echo "[LAN DEV] IP: ${LAN_IP}"
echo "[LAN DEV] Backend: ${API_URL}"
echo "[LAN DEV] Frontend: ${WEB_URL}"
echo "[LAN DEV] Mobile run command:"
echo "  cd mobile_flutter && flutter run --dart-define=API_BASE_URL=${API_URL}"
echo

start_backend() {
  cd "${ROOT_DIR}/backend"
  if [[ -f ".venv311/bin/activate" ]]; then
    # shellcheck disable=SC1091
    source .venv311/bin/activate
  fi
  exec python -m uvicorn main:app --host 0.0.0.0 --port 8000
}

start_frontend() {
  cd "${ROOT_DIR}/frontend"
  export NEXT_PUBLIC_API_BASE_URL="${API_URL}"
  export NEXT_PUBLIC_SITE_URL="${WEB_URL}"
  exec npm run dev -- --hostname 0.0.0.0 --port 3000
}

start_backend &
BACKEND_PID=$!
start_frontend &
FRONTEND_PID=$!

cleanup() {
  echo
  echo "[LAN DEV] stopping..."
  kill "${BACKEND_PID}" "${FRONTEND_PID}" >/dev/null 2>&1 || true
}

trap cleanup INT TERM EXIT

wait -n "${BACKEND_PID}" "${FRONTEND_PID}"
