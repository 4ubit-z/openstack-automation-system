# OpenStack 기반 프라이빗 클라우드 설치 가이드

본 문서는 프라이빗 클라우드 멀티 테넌트 플랫폼 구축을 위한 1-3단계 설치 과정을 안내합니다.

## 목차

1. [환경 준비 및 기본 설정](#1-환경-준비-및-기본-설정)
2. [하이퍼바이저 구축](#2-하이퍼바이저-구축)
3. [OpenStack 설치 및 구성](#3-openstack-설치-및-구성)

---

## 1. 환경 준비 및 기본 설정

### 1.1 시스템 요구사항

#### 최소 하드웨어 요구사항
- **CPU**: 8코어 이상 (가상화 지원 필수)
- **메모리**: 32GB RAM 이상
- **스토리지**: 500GB 이상 (SSD 권장)
- **네트워크**: 기가비트 이더넷

#### 권장 하드웨어 요구사항
- **CPU**: 16코어 이상
- **메모리**: 64GB RAM 이상
- **스토리지**: 1TB SSD
- **네트워크**: 10Gb 이더넷

### 1.2 운영체제 설치

#### 지원 운영체제
- Ubuntu 20.04 LTS 또는 22.04 LTS (권장)
- CentOS Stream 8/9
- RHEL 8/9

#### Ubuntu 22.04 LTS 기준 설치
```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 기본 패키지 설치
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools \
    python3 \
    python3-pip \
    python3-dev \
    build-essential
```

### 1.3 네트워크 설정

#### 호스트명 설정
```bash
# 호스트명 변경
sudo hostnamectl set-hostname openstack-controller

# /etc/hosts 파일 수정
sudo tee -a /etc/hosts << EOF
127.0.0.1 localhost
YOUR_IP_ADDRESS openstack-controller
EOF
```

#### 방화벽 설정
```bash
# UFW 비활성화 (OpenStack 설치 중)
sudo ufw disable

# 또는 필요한 포트만 허용
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5000/tcp  # Keystone
sudo ufw allow 8774/tcp  # Nova API
sudo ufw allow 9696/tcp  # Neutron API
```

### 1.4 프로젝트 저장소 설정

```bash
# Git 사용자 설정
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 프로젝트 클론 (또는 초기 구조 생성)
git clone https://github.com/yourusername/openstack-cicd-platform.git
cd openstack-cicd-platform

# 또는 직접 디렉터리 구조 생성
mkdir -p {docs,infrastructure/{setup,terraform,scripts},kubernetes/manifests}
mkdir -p {cicd/{jenkins,pipelines},monitoring/grafana-dashboards}
mkdir -p {applications/demo-app,scripts}
```

---

## 2. 하이퍼바이저 구축

### 2.1 가상화 지원 확인

```bash
# CPU 가상화 지원 확인
egrep -c '(vmx|svm)' /proc/cpuinfo

# 결과가 0이 아니면 가상화 지원
# KVM 모듈 로드 확인
lsmod | grep kvm

# 가상화 확장 기능 확인
sudo apt install -y cpu-checker
sudo kvm-ok
```

### 2.2 KVM/QEMU 설치 스크립트 생성

`infrastructure/setup/install-hypervisor.sh` 파일을 생성합니다:

```bash
#!/bin/bash
# infrastructure/setup/install-hypervisor.sh

set -e

echo "=== KVM/QEMU 하이퍼바이저 설치 시작 ==="

# KVM 및 관련 패키지 설치
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    cpu-checker \
    libguestfs-tools \
    libosinfo-bin

# 사용자를 libvirt 그룹에 추가
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

echo "그룹 변경사항을 적용하려면 다시 로그인하세요."

# Libvirt 서비스 시작 및 활성화
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# 기본 네트워크 시작
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default

echo "=== KVM/QEMU 설치 완료 ==="

# 설치 확인
echo "설치 확인 중..."
sudo systemctl is-active libvirtd
sudo virsh list --all

echo "하이퍼바이저 설치가 완료되었습니다."
```

### 2.3 Libvirt 설정

```bash
# 설치 스크립트 실행 권한 부여 및 실행
chmod +x infrastructure/setup/install-hypervisor.sh
./infrastructure/setup/install-hypervisor.sh

# 그룹 변경사항 적용 (재로그인 대신)
newgrp libvirt
```

### 2.4 네트워크 브리지 설정

#### 네트워크 설정 스크립트 생성

`infrastructure/scripts/setup-bridge.sh` 파일을 생성합니다:

```bash
#!/bin/bash
# infrastructure/scripts/setup-bridge.sh

set -e

INTERFACE=${1:-enp0s3}  # 기본값, 실제 인터페이스명으로 변경 필요

echo "=== 브리지 네트워크 설정 시작 ==="

# 현재 네트워크 설정 백업
sudo cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak

# 브리지 네트워크 설정 파일 생성
sudo tee /etc/netplan/01-bridge.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: false
      dhcp6: false
  bridges:
    br0:
      interfaces: [$INTERFACE]
      dhcp4: true
      parameters:
        stp: false
        forward-delay: 0
EOF

echo "네트워크 설정을 적용합니다..."
sudo netplan apply

echo "=== 브리지 네트워크 설정 완료 ==="
```

### 2.5 가상화 환경 테스트

```bash
# 네트워크 브리지 설정 (실제 인터페이스명으로 변경)
chmod +x infrastructure/scripts/setup-bridge.sh
# ./infrastructure/scripts/setup-bridge.sh enp0s3

# KVM 설치 확인
sudo systemctl is-active libvirtd
sudo virsh list --all
```

---

## 3. OpenStack 설치 및 구성

### 3.1 OpenStack 설치 스크립트 생성

`infrastructure/setup/install-openstack.sh` 파일을 생성합니다:

```bash
#!/bin/bash
# infrastructure/setup/install-openstack.sh

set -e

echo "=== OpenStack DevStack 설치 시작 ==="

# stack 사용자 생성
if ! id -u stack >/dev/null 2>&1; then
    sudo useradd -s /bin/bash -d /opt/stack -m stack
    sudo chmod +x /opt/stack
    echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack
fi

# DevStack 다운로드
sudo -u stack bash << 'EOF'
cd /opt/stack
if [ ! -d "devstack" ]; then
    git clone https://opendev.org/openstack/devstack
fi
cd devstack
EOF

echo "DevStack 다운로드 완료"
echo "이제 local.conf 파일을 설정하고 ./stack.sh를 실행하세요."
```

### 3.2 DevStack 설정 파일 생성

`infrastructure/setup/local.conf` 파일을 생성합니다:

```ini
# infrastructure/setup/local.conf

[[local|localrc]]

# 관리자 비밀번호 설정
ADMIN_PASSWORD=openstack123
DATABASE_PASSWORD=$ADMIN_PASSWORD
RABBIT_PASSWORD=$ADMIN_PASSWORD
SERVICE_PASSWORD=$ADMIN_PASSWORD

# 호스트 IP 설정 (실제 IP로 변경 필요)
HOST_IP=192.168.1.100

# 서비스 활성화
ENABLED_SERVICES=rabbit,mysql,key

# Nova (Compute) 서비스
ENABLED_SERVICES+=,n-api,n-cpu,n-cond,n-sch,n-novnc,n-cauth

# Neutron (Network) 서비스
ENABLED_SERVICES+=,q-svc,q-agt,q-dhcp,q-l3,q-meta

# Horizon (Dashboard)
ENABLED_SERVICES+=,horizon

# Cinder (Block Storage)
ENABLED_SERVICES+=,c-api,c-vol,c-sch

# Glance (Image) 서비스
ENABLED_SERVICES+=,g-api,g-reg

# 네트워크 설정
FLOATING_RANGE=192.168.1.224/27
FIXED_RANGE=10.11.12.0/24
FIXED_NETWORK_SIZE=256
FLAT_INTERFACE=br0

# 로그 설정
LOGFILE=/opt/stack/logs/stack.sh.log
VERBOSE=True
LOG_COLOR=True
SCREEN_LOGDIR=/opt/stack/logs

# 이미지 다운로드 설정
DOWNLOAD_DEFAULT_IMAGES=True
IMAGE_URLS+=",https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

# 멀티 테넌트를 위한 설정
ENABLED_SERVICES+=,tempest
```

### 3.3 전체 설치 자동화 스크립트

`scripts/setup-all.sh` 파일을 생성합니다:

```bash
#!/bin/bash
# scripts/setup-all.sh

set -e

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$PROJECT_ROOT"

echo "=== OpenStack 전체 환경 구축 시작 ==="

# 1. 하이퍼바이저 설치
echo "1. 하이퍼바이저 설치 중..."
./infrastructure/setup/install-hypervisor.sh

# 2. OpenStack 설치 준비
echo "2. OpenStack 설치 준비 중..."
./infrastructure/setup/install-openstack.sh

# 3. DevStack 설정 파일 복사
echo "3. DevStack 설정 중..."
sudo cp infrastructure/setup/local.conf /opt/stack/devstack/

# 4. DevStack 설치 실행
echo "4. DevStack 설치 실행 중... (약 30-60분 소요)"
sudo -u stack bash -c "cd /opt/stack/devstack && ./stack.sh"

echo "=== OpenStack 설치 완료 ==="
echo "Dashboard URL: http://$(hostname -I | awk '{print $1}')/dashboard"
echo "Username: admin"
echo "Password: openstack123"
```

### 3.4 설치 실행

```bash
# 전체 스크립트 실행 권한 부여
chmod +x scripts/setup-all.sh
chmod +x infrastructure/setup/*.sh
chmod +x infrastructure/scripts/*.sh

# HOST_IP 수정 (실제 서버 IP로 변경)
sed -i 's/HOST_IP=192.168.1.100/HOST_IP=YOUR_ACTUAL_IP/' infrastructure/setup/local.conf

# 전체 설치 실행
./scripts/setup-all.sh
```

### 3.5 멀티 테넌트 환경 구성 스크립트

`infrastructure/scripts/setup-multi-tenant.sh` 파일을 생성합니다:

```bash
#!/bin/bash
# infrastructure/scripts/setup-multi-tenant.sh

set -e

echo "=== 멀티 테넌트 환경 구성 시작 ==="

# OpenStack CLI 환경 변수 로드
source /opt/stack/devstack/openrc admin admin

# 개발팀 프로젝트 생성
echo "개발 환경 프로젝트 생성 중..."
openstack project create --description "Development Team" development
openstack user create --project development --password devpass123 developer
openstack role add --project development --user developer member

# 스테이징 프로젝트 생성
echo "스테이징 환경 프로젝트 생성 중..."
openstack project create --description "Staging Environment" staging
openstack user create --project staging --password stagepass123 staging-user
openstack role add --project staging --user staging-user member

# 프로덕션 프로젝트 생성
echo "프로덕션 환경 프로젝트 생성 중..."
openstack project create --description "Production Environment" production
openstack user create --project production --password prodpass123 prod-user
openstack role add --project production --user prod-user member

# 각 프로젝트별 네트워크 생성
echo "프로젝트별 네트워크 생성 중..."

# 개발 환경 네트워크
openstack network create --project development dev-network
openstack subnet create --project development --network dev-network \
    --subnet-range 10.10.10.0/24 --dns-nameserver 8.8.8.8 dev-subnet

# 스테이징 환경 네트워크
openstack network create --project staging stage-network
openstack subnet create --project staging --network stage-network \
    --subnet-range 10.10.20.0/24 --dns-nameserver 8.8.8.8 stage-subnet

# 프로덕션 환경 네트워크
openstack network create --project production prod-network
openstack subnet create --project production --network prod-network \
    --subnet-range 10.10.30.0/24 --dns-nameserver 8.8.8.8 prod-subnet

# 기본 보안 그룹 규칙 추가
echo "보안 그룹 설정 중..."
openstack security group rule create --protocol tcp --dst-port 22 default
openstack security group rule create --protocol tcp --dst-port 80 default
openstack security group rule create --protocol tcp --dst-port 443 default
openstack security group rule create --protocol icmp default

echo "=== 멀티 테넌트 환경 구성 완료 ==="
```

### 3.6 설치 검증 스크립트

`infrastructure/scripts/verify-installation.sh` 파일을 생성합니다:

```bash
#!/bin/bash
# infrastructure/scripts/verify-installation.sh

set -e

echo "=== OpenStack 설치 검증 시작 ==="

# OpenStack CLI 환경 변수 로드
source /opt/stack/devstack/openrc admin admin

echo "1. OpenStack 서비스 확인"
openstack service list

echo "2. 엔드포인트 확인"
openstack endpoint list

echo "3. 네트워크 확인"
openstack network list

echo "4. 이미지 확인"
openstack image list

echo "5. 플레이버 확인"
openstack flavor list

echo "6. 프로젝트 확인"
openstack project list

echo "7. 사용자 확인"
openstack user list

# 테스트 인스턴스 생성
echo "8. 테스트 인스턴스 생성"
if ! openstack keypair show mykey >/dev/null 2>&1; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa >/dev/null 2>&1 || true
    openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey
fi

echo "=== 설치 검증 완료 ==="
echo "모든 서비스가 정상적으로 동작하고 있습니다."
```

### 3.7 정리 스크립트

`scripts/cleanup-all.sh` 파일을 생성합니다:

```bash
#!/bin/bash
# scripts/cleanup-all.sh

set -e

echo "=== OpenStack 환경 정리 시작 ==="

# DevStack 정리
if [ -d "/opt/stack/devstack" ]; then
    echo "DevStack 정리 중..."
    sudo -u stack bash -c "cd /opt/stack/devstack && ./unstack.sh" || true
    sudo -u stack bash -c "cd /opt/stack/devstack && ./clean.sh" || true
fi

# 네트워크 설정 복원
if [ -f "/etc/netplan/00-installer-config.yaml.bak" ]; then
    echo "네트워크 설정 복원 중..."
    sudo cp /etc/netplan/00-installer-config.yaml.bak /etc/netplan/00-installer-config.yaml
    sudo rm -f /etc/netplan/01-bridge.yaml
    sudo netplan apply
fi

echo "=== 환경 정리 완료 ==="
```

---

## 사용 방법

### 1. 초기 설치
```bash
# 저장소 클론
git clone https://github.com/yourusername/openstack-cicd-platform.git
cd openstack-cicd-platform

# IP 주소 설정 (필수)
sed -i 's/YOUR_ACTUAL_IP/192.168.1.100/' infrastructure/setup/local.conf

# 전체 환경 구축
./scripts/setup-all.sh
```

### 2. 멀티 테넌트 환경 구성
```bash
chmod +x infrastructure/scripts/setup-multi-tenant.sh
./infrastructure/scripts/setup-multi-tenant.sh
```

### 3. 설치 검증
```bash
chmod +x infrastructure/scripts/verify-installation.sh
./infrastructure/scripts/verify-installation.sh
```

### 4. 환경 정리
```bash
./scripts/cleanup-all.sh
```

---

## 다음 단계

설치가 완료되면 다음 문서를 참조하여 진행하세요:

- `docs/02-infrastructure-automation.md` - Terraform 인프라 자동화
- `docs/03-kubernetes-deployment.md` - Kubernetes 클러스터 구축  
- `docs/04-cicd-pipeline.md` - Jenkins CI/CD 파이프라인 구축

---

## 참고 자료

- [OpenStack DevStack 공식 문서](https://docs.openstack.org/devstack/latest/)
- [OpenStack 설치 가이드](https://docs.openstack.org/install-guide/)
- [KVM 가상화 가이드](https://help.ubuntu.com/community/KVM)
- [Libvirt 네트워킹](https://wiki.libvirt.org/page/Networking)
