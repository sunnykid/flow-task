#!/usr/bin/env bash
# WSL의 Nginx에 Task Flow 화면과 /api 프록시를 WEB-SERVER.md와 같은 구성으로 설치·갱신한다.
# 실행: sudo bash deploy/install-wsl-web.sh [App서버주소]   (기본 127.0.0.1, install-wsl.sh로 설치한 API)
# 화면 파일은 커밋된 HEAD 기준, Nginx 설정은 작업 폴더의 deploy/task-flow-web.conf를 쓴다.
# 기본 사이트(sites-enabled/default)는 링크만 해제한다. sites-available/default는 남는다.
set -euo pipefail

if [ "$(id -u)" -ne 0 ] || [ -z "${SUDO_USER:-}" ]; then
  echo "sudo bash deploy/install-wsl-web.sh 로 실행하세요." >&2
  exit 1
fi

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP_ADDR="${1:-127.0.0.1}"
WEB=/var/www/task-flow
SITE=/etc/nginx/sites-available/task-flow
as_user() { sudo -u "$SUDO_USER" "$@"; }

step() { echo "==> $*"; }

command -v nginx >/dev/null || { echo "nginx가 없습니다. sudo apt install -y nginx 후 다시 실행하세요." >&2; exit 1; }

step "화면 파일 복사 (HEAD: $(as_user git -C "$REPO" log --oneline -1))"
mkdir -p "$WEB"
as_user git -C "$REPO" archive HEAD frontend | tar -xf - -C "$WEB" --strip-components=1
chmod 644 "$WEB"/*

step "Nginx 설정 (App: $APP_ADDR:8000)"
sed "s/APP_SERVER_ADDR/$APP_ADDR/" "$REPO/deploy/task-flow-web.conf" > "$SITE"
chmod 644 "$SITE"
ln -sf "$SITE" /etc/nginx/sites-enabled/task-flow
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

step "확인"
curl -s -o /dev/null -w "/            HTTP %{http_code}\n" http://127.0.0.1/ || true
curl -s -w "\n/api/health  HTTP %{http_code}\n" http://127.0.0.1/api/health || true
curl -s -o /dev/null -w "/api/tasks   HTTP %{http_code}\n" http://127.0.0.1/api/tasks || true
