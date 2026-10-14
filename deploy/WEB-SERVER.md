# Web 서버 구성 (T14)

Web 서버의 Nginx가 화면 파일을 제공하고 `/api/` 요청을 App 서버(T13)로 전달한다.
화면은 `/api` 상대 경로로 호출하므로 CORS 설정과 프런트엔드 수정이 필요 없다.

- 화면 파일: /var/www/task-flow (frontend/의 index.html, styles.css, app.js)
- Nginx 설정: /etc/nginx/sites-available/task-flow (deploy/task-flow-web.conf)
- 대기 주소: 80. App 서버 8000은 Web 서버에서만 접속되도록 App 서버 방화벽·보안그룹을 제한한다.

## 1. 코드 묶기 (개발 PC, 저장소 루트)
```bash
git archive -o task-flow-web.tar.gz HEAD frontend deploy/task-flow-web.conf
scp task-flow-web.tar.gz <Web서버계정>@<Web서버주소>:/tmp/
```

## 2. Nginx와 화면 파일 (Web 서버)
```bash
sudo apt install -y nginx                 # 없을 때만
mkdir -p /tmp/task-flow-web && tar -xzf /tmp/task-flow-web.tar.gz -C /tmp/task-flow-web
sudo mkdir -p /var/www/task-flow
sudo install -m 644 /tmp/task-flow-web/frontend/* /var/www/task-flow/
```

## 3. Nginx 설정 (Web 서버)
`APP_SERVER_ADDR`를 App 서버 주소로 바꿔 설치한다. 기본 사이트는 링크만 해제한다(sites-available/default는 남는다).

```bash
sed 's/APP_SERVER_ADDR/<App서버주소>/' /tmp/task-flow-web/deploy/task-flow-web.conf \
  | sudo tee /etc/nginx/sites-available/task-flow >/dev/null
sudo ln -sf /etc/nginx/sites-available/task-flow /etc/nginx/sites-enabled/task-flow
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
```

## 4. 확인
```bash
# Web 서버
curl -i http://127.0.0.1/                 # 200, 화면 HTML
curl -i http://127.0.0.1/api/health       # 200, {"status":"ok"} (App 서버 응답)
curl -i http://127.0.0.1/api/tasks        # 200. 503은 App→DB 문제, 502·504는 Web→App 문제
```
브라우저에서 `http://<Web서버주소>/`로 접속해 할 일을 등록한다. 이어서 아래 순서로 확인한다.
1. DB 서버에서 `SELECT id, title FROM tasks ORDER BY id DESC LIMIT 5;`로 등록한 행이 보인다.
2. App 서버에서 `sudo systemctl restart task-flow-api`를 실행한다.
3. 브라우저를 새로고침하면 등록한 항목이 그대로 보인다.

## 오류 확인
```bash
sudo tail -n 50 /var/log/nginx/error.log  # connect() failed → App 서버 주소·8000 방화벽 확인
```

## 화면 갱신
1의 묶음을 다시 만들어 2의 install 명령으로 덮어쓴다. 정적 파일만 바뀐 경우 Nginx 재시작은 필요 없다.
