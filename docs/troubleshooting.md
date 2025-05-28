## 트러블슈팅

### 일반적인 문제 해결

#### DevStack 설치 실패 시
```bash
# 로그 확인
tail -f /opt/stack/logs/stack.sh.log

# 환경 초기화 후 재설치
./unstack.sh
./clean.sh
./stack.sh
```

#### 메모리 부족 오류
```bash
# 스왑 파일 생성 (임시 해결책)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### 네트워크 연결 문제
```bash
# 네트워크 설정 확인
ip addr show
sudo netplan status
sudo systemctl restart systemd-networkd
```

### 로그 파일 위치
- DevStack 설치 로그: `/opt/stack/logs/stack.sh.log`
- OpenStack 서비스 로그: `/opt/stack/logs/`
- 시스템 로그: `/var/log/syslog`
