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

### 1.4 Git 저장소 설정

```bash
# Git 사용자 설정
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 프로젝트 클론
git clone https://github.com/yourusername/private-cloud-multi-tenant-platform.git
cd private-cloud-multi-tenant-platform

# 초기 디렉터리 구조 생성
mkdir -p docs infrastructure/openstack/devstack infrastructure/hypervisor
mkdir -p kubernetes monitoring ci-cd applications scripts
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

### 2.2 KVM/QEMU 설치

```bash
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

# 그룹 변경사항 적용을 위해 로그아웃 후 재로그인 또는
newgrp libvirt
```

### 2.3 Libvirt 설정

```bash
# Libvirt 서비스 시작 및 활성화
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
sudo systemctl status libvirtd

# 기본 네트워크 확인
sudo virsh net-list --all
sudo virsh net-start default
sudo virsh net-autostart default
```

### 2.4 네트워크 브리지 설정

#### 브리지 네트워크 생성
```bash
# 현재 네트워크 인터페이스 확인
ip addr show

# 네트워크 설정 파일 백업
sudo cp /etc/netplan/00-installer-config.yaml /etc/netplan/00-installer-config.yaml.bak
```

#### Netplan 설정 (Ubuntu 22.04)
```bash
# 브리지 네트워크 설정
sudo tee /etc/netplan/01-bridge.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:  # 실제 인터페이스명으로 변경
      dhcp4: false
      dhcp6: false
  bridges:
    br0:
      interfaces: [enp0s3]
      dhcp4: true
      parameters:
        stp: false
        forward-delay: 0
EOF

# 네트워크 설정 적용
sudo netplan apply
```

### 2.5 가상화 환경 테스트

```bash
# KVM 설치 확인
sudo systemctl is-active libvirtd
sudo virsh list --all

# 테스트 VM 생성 (선택사항)
sudo virt-install \
    --name test-vm \
    --ram 1024 \
    --disk path=/var/lib/libvirt/images/test-vm.img,size=10 \
    --vcpus 1 \
    --os-type linux \
    --network bridge=br0 \
    --graphics none \
    --console pty,target_type=serial \
    --location 'http://archive.ubuntu.com/ubuntu/dists/jammy/main/installer-amd64/' \
    --extra-args 'console=ttyS0,115200n8 serial'

# 테스트 후 VM 삭제
sudo virsh destroy test-vm
sudo virsh undefine test-vm --remove-all-storage
```

---

## 3. OpenStack 설치 및 구성

### 3.1 DevStack 준비

#### 전용 사용자 생성
```bash
# stack 사용자 생성
sudo useradd -s /bin/bash -d /opt/stack -m stack
sudo chmod +x /opt/stack

# sudo 권한 부여
echo "stack ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/stack

# stack 사용자로 전환
sudo su - stack
```

#### DevStack 다운로드
```bash
# stack 사용자로 실행
cd /opt/stack
git clone https://opendev.org/openstack/devstack
cd devstack
```

### 3.2 DevStack 설정

#### local.conf 파일 생성
```bash
# /opt/stack/devstack/local.conf 파일 생성
tee local.conf << EOF
[[local|localrc]]

# 관리자 비밀번호 설정
ADMIN_PASSWORD=secret
DATABASE_PASSWORD=\$ADMIN_PASSWORD
RABBIT_PASSWORD=\$ADMIN_PASSWORD
SERVICE_PASSWORD=\$ADMIN_PASSWORD

# 호스트 IP 설정 (실제 IP로 변경)
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

# Swift (Object Storage) - 선택사항
# ENABLED_SERVICES+=,s-proxy,s-object,s-container,s-account

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

# 멀티 테넌트를 위한 프로젝트 생성
ENABLED_SERVICES+=,tempest
EOF
```

### 3.3 DevStack 설치 실행

```bash
# DevStack 설치 시작 (30-60분 소요)
cd /opt/stack/devstack
./stack.sh
```

#### 설치 중 참고사항
- 설치 시간: 약 30-60분
- 인터넷 연결 필수
- 설치 로그: `/opt/stack/logs/stack.sh.log`
- 오류 발생 시: `./unstack.sh` 실행 후 재설치

### 3.4 설치 완료 확인

#### 서비스 상태 확인
```bash
# OpenStack 서비스 상태 확인
sudo systemctl list-units --type=service | grep devstack

# 또는 screen 세션 확인
screen -list
```

#### 웹 대시보드 접속 확인
```bash
# 대시보드 URL 확인
echo "Dashboard URL: http://$HOST_IP/dashboard"
echo "Username: admin or demo"
echo "Password: secret"
```

#### CLI 환경 설정
```bash
# OpenStack CLI 환경 변수 로드
source /opt/stack/devstack/openrc admin admin

# OpenStack 서비스 확인
openstack service list
openstack endpoint list
openstack network list
openstack image list
```

### 3.5 멀티 테넌트 환경 구성

#### 추가 프로젝트 생성
```bash
# 개발팀 프로젝트 생성
openstack project create --description "Development Team" development
openstack user create --project development --password devpass developer
openstack role add --project development --user developer member

# 스테이징 프로젝트 생성
openstack project create --description "Staging Environment" staging
openstack user create --project staging --password stagepass staging-user
openstack role add --project staging --user staging-user member

# 프로덕션 프로젝트 생성
openstack project create --description "Production Environment" production
openstack user create --project production --password prodpass prod-user
openstack role add --project production --user prod-user member
```

#### 네트워크 격리 설정
```bash
# 각 프로젝트별 네트워크 생성
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
```

#### 보안 그룹 설정
```bash
# 기본 보안 그룹 규칙 추가
openstack security group rule create --protocol tcp --dst-port 22 default
openstack security group rule create --protocol tcp --dst-port 80 default
openstack security group rule create --protocol tcp --dst-port 443 default
openstack security group rule create --protocol icmp default
```

### 3.6 설치 후 검증

#### 인스턴스 생성 테스트
```bash
# 키페어 생성
openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey

# 플레이버 확인
openstack flavor list

# 이미지 확인
openstack image list

# 네트워크 확인
openstack network list

# 테스트 인스턴스 생성
openstack server create --flavor m1.tiny --image cirros-0.5.2-x86_64-disk \
    --network private --key-name mykey test-instance

# 인스턴스 상태 확인
openstack server list
openstack server show test-instance
```

#### 플로팅 IP 할당
```bash
# 플로팅 IP 생성
openstack floating ip create public

# 플로팅 IP 확인
openstack floating ip list

# 인스턴스에 플로팅 IP 할당
openstack server add floating ip test-instance FLOATING_IP_ADDRESS
```

---

## 다음 단계

설치가 완료되면 다음 단계로 진행할 수 있습니다:

1. **Terraform 설정**: 인프라 자동화 구성
2. **Kubernetes 클러스터 구축**: 컨테이너 오케스트레이션 환경 구성
3. **CI/CD 파이프라인 구축**: Jenkins를 활용한 자동화 배포

---

## 참고 자료

- [OpenStack DevStack 공식 문서](https://docs.openstack.org/devstack/latest/)
- [OpenStack 설치 가이드](https://docs.openstack.org/install-guide/)
- [KVM 가상화 가이드](https://help.ubuntu.com/community/KVM)
- [Libvirt 네트워킹](https://wiki.libvirt.org/page/Networking)
