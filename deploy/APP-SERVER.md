# App 서버 구성 (T13)

App 서버에서 uvicorn을 systemd 서비스로 실행한다. DB는 T12에서 구성한 DB 서버를 사용한다.

- 설치 경로: /opt/task-flow
- 실행 계정: task-flow (로그인 불가)
- 대기 주소: 0.0.0.0:8000. 방화벽·보안그룹에서 8000은 Web 서버에만 연다(T14).
- 필요: Python 3.10 이상, python3-venv

## 1. 코드 묶기 (개발 PC, 저장소 루트)
.venv와 .env는 넣지 않는다. 필요한 경로만 지정해 묶는다. 화면 파일(frontend)은 Web 서버에 둔다(T14).

```bash
git archive -o task-flow.tar.gz HEAD backend requirements.txt .env.example deploy
scp task-flow.tar.gz <App서버계정>@<App서버주소>:/tmp/
```

## 2. 계정·코드·가상환경 (App 서버)
```bash
sudo apt install -y python3-venv          # 없을 때만
sudo useradd --system --no-create-home --shell /usr/sbin/nologin task-flow
sudo mkdir -p /opt/task-flow
sudo tar -xzf /tmp/task-flow.tar.gz -C /opt/task-flow
sudo python3 -m venv /opt/task-flow/.venv
sudo /opt/task-flow/.venv/bin/pip install -r /opt/task-flow/requirements.txt
```
코드와 가상환경은 root 소유로 두어 서비스 계정이 수정할 수 없게 한다.

## 3. 환경변수 (App 서버)
.env.example을 복사해 DB 서버 주소와 실제 비밀번호를 넣는다. 값은 Git·로그·메신저에 남기지 않는다.

```bash
sudo cp /opt/task-flow/.env.example /opt/task-flow/.env
sudo nano /opt/task-flow/.env             # DB_HOST=<DB서버주소>, DB_PASSWORD=<실제값>
sudo chown task-flow:task-flow /opt/task-flow/.env
sudo chmod 600 /opt/task-flow/.env
```

## 4. systemd 서비스 (App 서버)
```bash
sudo cp /opt/task-flow/deploy/task-flow-api.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now task-flow-api
systemctl status task-flow-api --no-pager
```

## 5. 확인 (App 서버)
```bash
curl -i http://127.0.0.1:8000/api/health      # 200, {"status":"ok"}
curl -i http://127.0.0.1:8000/api/tasks       # 200이면 DB 연결 정상, 503이면 DB 접속 문제
sudo systemctl restart task-flow-api && sleep 2 && curl -s http://127.0.0.1:8000/api/health
journalctl -u task-flow-api -n 50 --no-pager  # 오류 확인
```

## 코드 갱신
1의 묶음을 다시 만들어 2의 tar 명령으로 덮어쓴 뒤, requirements.txt가 바뀌었으면 pip install을 다시 실행하고
`sudo systemctl restart task-flow-api`로 재시작한다. .env는 묶음에 없으므로 유지된다.
