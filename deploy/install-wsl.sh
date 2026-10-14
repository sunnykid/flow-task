#!/usr/bin/env bash
# WSL에 task-flow-api 서비스를 APP-SERVER.md와 같은 구성(/opt/task-flow, task-flow 계정)으로 설치·갱신한다.
# 실행: sudo bash deploy/install-wsl.sh
# 코드는 커밋된 HEAD 기준, 서비스 파일은 작업 폴더의 deploy/task-flow-api.service를 쓴다.
# 다시 실행하면 코드와 패키지를 갱신하고 서비스를 재시작한다. 기존 /opt/task-flow/.env는 덮어쓰지 않는다.
set -euo pipefail

if [ "$(id -u)" -ne 0 ] || [ -z "${SUDO_USER:-}" ]; then
  echo "sudo bash deploy/install-wsl.sh 로 실행하세요." >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP=/opt/task-flow
SERVICE=task-flow-api
as_user() { sudo -u "$SUDO_USER" "$@"; }

step() { echo "==> $*"; }

if ! systemctl is-active --quiet "$SERVICE" && ss -ltn | grep -q ':8000 '; then
  echo "8000 포트를 다른 프로세스가 사용 중입니다. 개발용 uvicorn을 먼저 중지하세요." >&2
  exit 1
fi

step "서비스 계정 확인"
id task-flow >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin task-flow

step "코드 복사 (HEAD: $(as_user git -C "$REPO" log --oneline -1))"
mkdir -p "$APP/deploy"
as_user git -C "$REPO" archive HEAD backend frontend requirements.txt .env.example | tar -xf - -C "$APP"
install -m 644 "$REPO/deploy/task-flow-api.service" "$APP/deploy/"

step "패키지 내려받기 ($SUDO_USER 권한)"
WHEELS="$(as_user mktemp -d)"
trap 'rm -rf "$WHEELS"' EXIT
as_user python3 -m pip download --disable-pip-version-check -r "$APP/requirements.txt" -d "$WHEELS"

step "가상환경 설치"
[ -x "$APP/.venv/bin/python" ] || python3 -m venv "$APP/.venv"
"$APP/.venv/bin/pip" install --disable-pip-version-check --no-index --find-links "$WHEELS" -r "$APP/requirements.txt"

step ".env 확인"
if [ ! -f "$APP/.env" ]; then
  install -o task-flow -g task-flow -m 600 "$REPO/.env" "$APP/.env"
  echo "저장소 .env를 복사했습니다(600)."
else
  echo "기존 .env를 유지합니다."
fi

step "systemd 등록"
install -m 644 "$APP/deploy/task-flow-api.service" "/etc/systemd/system/$SERVICE.service"
systemctl daemon-reload
systemctl enable "$SERVICE"
systemctl restart "$SERVICE"

step "확인"
for _ in $(seq 20); do
  curl -s -o /dev/null http://127.0.0.1:8000/api/health && break
  sleep 0.5
done
systemctl --no-pager --lines=0 status "$SERVICE" || true
curl -s -w "\nhealth HTTP %{http_code}\n" http://127.0.0.1:8000/api/health || true
curl -s -o /dev/null -w "tasks  HTTP %{http_code}\n" http://127.0.0.1:8000/api/tasks || true
