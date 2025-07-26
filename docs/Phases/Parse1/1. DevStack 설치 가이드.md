# DevStack 설치 가이드

Ubuntu 22.04.5 LTS에서 VMware Bridged Network 환경을 이용한 OpenStack DevStack 설치 가이드

## 환경 개요

- **운영체제**: Ubuntu Server 22.04.5 LTS (64-bit)
- **가상화**: VMware Workstation Pro/Player
- **DevStack 버전**: master 브랜치 (최신 개발 버전)
- **네트워크 모드**: Bridged (VMnet0)
- **목표**: 외부에서 접근 가능한 OpenStack 환경 구축

## 시스템 요구사항

### VM 권장(본인기준) 사양

| 항목 | 권장 사양 |
|------|-----------|
| CPU | 8 vCPU 이상 |
| RAM | 16GB 이상 |
| 디스크 | 120GB 이상 (SSD 권장) |
| 네트워크 | VMware Bridged 모드 |

### VMware 네트워크 설정

1. VMware 가상 네트워크 에디터에서 VMnet0이 Bridged 타입으로 설정 확인
2. 호스트 PC의 실제 LAN 카드에 연결되어 있는지 확인
3. "Replicate physical network connection state" 옵션 체크

## 설치 과정

### 1. Ubuntu Server 기본 설정

Ubuntu Server 설치 시 사용자 계정을 `stack`으로 생성해야 함.

**중요**: DevStack은 반드시 `stack` 사용자 계정으로 설치하고 실행해야 함. root 계정이나 다른 사용자 계정으로는 설치할 수 없음.

```bash
# 시스템 업데이트
sudo apt update
sudo apt upgrade -y
sudo apt dist-upgrade -y

# 재부팅 (필요 시)
sudo reboot

# 기본 유틸리티 설치 (선택사항)
sudo apt install -y vim screen curl wget git nmap
```

### 2. stack 사용자 권한 설정

```bash
# sudo 권한 부여 (패스워드 없이)
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack

# DevStack 작업 디렉토리 생성
sudo mkdir -p /opt/stack
sudo chown stack:stack /opt/stack
sudo chmod +x /opt/stack
```

**주의**: 패스워드 없는 sudo 권한은 개발/테스트 환경에서만 사용해야 함.

### 3. DevStack 리포지토리 클론

```bash
cd /opt/stack
git clone https://opendev.org/openstack/devstack
```

### 4. local.conf 파일 설정

DevStack의 핵심 설정 파일을 생성함.

```bash
cd /opt/stack/devstack
cp samples/local.conf local.conf
vim local.conf
```

**local.conf 내용**:

```ini
[[local|localrc]]
# OpenStack 서비스 및 대시보드 관리자 패스워드
ADMIN_PASSWORD=secretopenstack
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

# 호스트 IP 주소 (VM의 실제 IP 주소)
# ip a 명령어로 확인한 ens33 인터페이스의 IP 주소 입력
HOST_IP=a.b.c.d

# Floating IP 범위 (외부 네트워크에서 인스턴스 접근용)
# nmap 스캔으로 사용하지 않는 IP 대역 확인 후 설정
FLOATING_RANGE=a.b.c.x/28

# Fixed IP 범위 (인스턴스 내부 네트워크)
FIXED_RANGE=10.0.0.0/24
FIXED_NETWORK_SIZE=256

# DNS 서버
DNS_SERVER=8.8.8.8

# Horizon 대시보드 활성화
enable_service horizon

# 로그 파일 설정
LOGFILE=/opt/stack/logs/stack.sh.log
SCREEN_LOGDIR=/opt/stack/logs

# sudo 강제 사용 (권한 문제 해결)
force_sudo=True

# Swift 오브젝트 스토리지 설정
SWIFT_HASH=66a3d6b56c1f479c8b4e70ab5c2000f5
SWIFT_REPLICAS=1
SWIFT_DATA_DIR=$DEST/data

# 로그 파일 자동 삭제 (일 단위)
LOGDAYS=2
```

### 5. IP 주소 및 네트워크 설정 확인

#### HOST_IP 확인

```bash
ip a
```

ens33 인터페이스의 inet 주소를 확인하여 `HOST_IP`에 입력해야 함.

#### FLOATING_RANGE 설정

FLOATING_RANGE는 OpenStack 인스턴스가 외부 네트워크에서 접근할 수 있도록 하는 IP 대역임. 물리 네트워크와 충돌하지 않는 사용하지 않는 IP 대역을 찾아서 설정해야 함.

```bash
# 1. 현재 네트워크 대역에서 사용 중인 IP 확인
nmap -sn a.b.c.0/24

# 2. 스캔 결과에서 "Host is up"으로 표시되지 않는 IP 대역 찾기
# 예: a.b.c.192/28 대역이 비어있다면 이를 FLOATING_RANGE로 사용
# /28 서브넷은 14개의 사용 가능한 IP 주소를 제공 (a.b.c.193 ~ a.b.c.206)

# 3. local.conf 파일에 해당 대역 설정
FLOATING_RANGE=a.b.c.192/28
```

**FLOATING_RANGE 설정 예시**:
- VM IP가 `192.168.1.100`인 경우 → `nmap -sn 192.168.1.0/24` 실행
- 스캔 결과 `192.168.1.192/28` 대역이 비어있음을 확인
- `FLOATING_RANGE=192.168.1.192/28`로 설정

### 6. DevStack 설치 실행

```bash
cd /opt/stack/devstack
./stack.sh
```

## 문제 해결

### 설치 중 에러 발생 시

#### 스크린 세션 확인

```bash
screen -ls              # 세션 목록 확인
screen -r [세션ID]      # 세션 재접속
```

#### 로그 파일 확인

```bash
tail -f /opt/stack/logs/stack.sh.log
```

#### 환경 초기화 후 재시도

```bash
./clean.sh  # 환경 초기화
./stack.sh  # 재설치
```

## 설치 완료 및 접속

설치 성공 시 다음과 같은 메시지가 출력됩니다:

```
This is your host IP address: a.b.c.d
This is your host IPv6 address: ::1
Horizon is now available at http://a.b.c.d/dashboard
Keystone is serving at http://a.b.c.d/identity/
The default users are: admin and demo
The password: secretopenstack

Services are running under systemd unit files.
For more information see:
https://docs.openstack.org/devstack/latest/systemd.html

DevStack Version: 2025.2
Change: aa988423427d56e7f02879a64aa65319deed9e3b Merge "keystone: Set user_enabled_default for LDAP domain" 2025-07-23 19:41:04 +0000
OS Version: Ubuntu 22.04 jammy
```

### OpenStack 대시보드 접속

1. 웹 브라우저에서 `http://[HOST_IP]/dashboard` 접속
2. 로그인 정보:
   - **Username**: `admin`
   - **Password**: `secretopenstack`

## 서비스 관리

```bash
# DevStack 서비스 시작
cd /opt/stack/devstack && ./stack.sh

# DevStack 서비스 중지
cd /opt/stack/devstack && ./unstack.sh

# DevStack 환경 완전 삭제
cd /opt/stack/devstack && ./clean.sh
```

## 참고 자료

- [DevStack 공식 문서](https://docs.openstack.org/devstack/latest/)
- [OpenStack 공식 사이트](https://www.openstack.org/)

---

**주의사항**: 이 가이드는 개발 및 테스트 환경용임. 프로덕션 환경에서는 보안 설정을 강화해야 함.
