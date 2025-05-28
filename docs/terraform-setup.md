# Terraform 인프라 자동화 설정 가이드

> **파일 위치**: `docs/terraform-setup.md`

본 문서는 OpenStack 인프라를 Terraform으로 자동화하는 4단계 과정을 안내합니다.

## 목차

1. [Terraform 설치 및 설정](#1-terraform-설치-및-설정)
2. [OpenStack Provider 구성](#2-openstack-provider-구성)
3. [인프라 코드 작성](#3-인프라-코드-작성)
4. [환경별 변수 관리](#4-환경별-변수-관리)
5. [자동 프로비저닝 테스트](#5-자동-프로비저닝-테스트)

---

## 1. Terraform 설치 및 설정

### 1.1 Terraform 설치

```bash
# Terraform 설치 (Ubuntu)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com jammy main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# 설치 확인
terraform version
```

### 1.2 작업 디렉터리 생성

```bash
# 프로젝트 루트로 이동
cd private-cloud-multi-tenant-platform

# Terraform 디렉터리 구조 생성
mkdir -p infrastructure/terraform/{modules/{network,compute,security},environments/{dev,staging,prod}}
```

---

## 2. OpenStack Provider 구성

### 2.1 Provider 설정 파일 생성

**파일**: `infrastructure/terraform/versions.tf`
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
    }
  }
}

provider "openstack" {
  user_name   = var.openstack_user_name
  tenant_name = var.openstack_tenant_name
  password    = var.openstack_password
  auth_url    = var.openstack_auth_url
  region      = var.openstack_region
}
```

### 2.2 변수 정의 파일 생성

**파일**: `infrastructure/terraform/variables.tf`
```hcl
# OpenStack 인증 정보
variable "openstack_user_name" {
  description = "OpenStack username"
  type        = string
  default     = "admin"
}

variable "openstack_tenant_name" {
  description = "OpenStack tenant name"
  type        = string
  default     = "admin"
}

variable "openstack_password" {
  description = "OpenStack password"
  type        = string
  sensitive   = true
}

variable "openstack_auth_url" {
  description = "OpenStack auth URL"
  type        = string
  default     = "http://localhost:5000/v3"
}

variable "openstack_region" {
  description = "OpenStack region"
  type        = string
  default     = "RegionOne"
}

# 인프라 설정 변수
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "private-cloud"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "nova"
}
```

---

## 3. 인프라 코드 작성

### 3.1 네트워크 모듈

**파일**: `infrastructure/terraform/modules/network/main.tf`
```hcl
# 네트워크 생성
resource "openstack_networking_network_v2" "network" {
  name           = "${var.project_name}-${var.environment}-network"
  admin_state_up = "true"
}

# 서브넷 생성
resource "openstack_networking_subnet_v2" "subnet" {
  name       = "${var.project_name}-${var.environment}-subnet"
  network_id = openstack_networking_network_v2.network.id
  cidr       = var.subnet_cidr
  ip_version = 4
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
}

# 라우터 생성
resource "openstack_networking_router_v2" "router" {
  name                = "${var.project_name}-${var.environment}-router"
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.external.id
}

# 라우터 인터페이스 연결
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router.id
  subnet_id = openstack_networking_subnet_v2.subnet.id
}

# 외부 네트워크 데이터 소스
data "openstack_networking_network_v2" "external" {
  name = "public"
}
```

**파일**: `infrastructure/terraform/modules/network/variables.tf`
```hcl
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.1.0/24"
}
```

**파일**: `infrastructure/terraform/modules/network/outputs.tf`
```hcl
output "network_id" {
  description = "Network ID"
  value       = openstack_networking_network_v2.network.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = openstack_networking_subnet_v2.subnet.id
}

output "router_id" {
  description = "Router ID"
  value       = openstack_networking_router_v2.router.id
}
```

### 3.2 보안 그룹 모듈

**파일**: `infrastructure/terraform/modules/security/main.tf`
```hcl
# 기본 보안 그룹
resource "openstack_compute_secgroup_v2" "default" {
  name        = "${var.project_name}-${var.environment}-default"
  description = "Default security group for ${var.environment}"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 80
    to_port     = 80
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 443
    to_port     = 443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = -1
    to_port     = -1
    ip_protocol = "icmp"
    cidr        = "0.0.0.0/0"
  }
}

# Kubernetes 보안 그룹
resource "openstack_compute_secgroup_v2" "kubernetes" {
  name        = "${var.project_name}-${var.environment}-k8s"
  description = "Kubernetes security group for ${var.environment}"

  # Kubernetes API Server
  rule {
    from_port   = 6443
    to_port     = 6443
    ip_protocol = "tcp"
    cidr        = "10.0.0.0/8"
  }

  # etcd
  rule {
    from_port   = 2379
    to_port     = 2380
    ip_protocol = "tcp"
    cidr        = "10.0.0.0/8"
  }

  # Kubelet API
  rule {
    from_port   = 10250
    to_port     = 10250
    ip_protocol = "tcp"
    cidr        = "10.0.0.0/8"
  }

  # NodePort Services
  rule {
    from_port   = 30000
    to_port     = 32767
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}
```

**파일**: `infrastructure/terraform/modules/security/variables.tf`
```hcl
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
```

**파일**: `infrastructure/terraform/modules/security/outputs.tf`
```hcl
output "default_security_group_id" {
  description = "Default security group ID"
  value       = openstack_compute_secgroup_v2.default.id
}

output "kubernetes_security_group_id" {
  description = "Kubernetes security group ID"
  value       = openstack_compute_secgroup_v2.kubernetes.id
}
```

### 3.3 컴퓨팅 모듈

**파일**: `infrastructure/terraform/modules/compute/main.tf`
```hcl
# 키페어 생성
resource "openstack_compute_keypair_v2" "keypair" {
  name       = "${var.project_name}-${var.environment}-keypair"
  public_key = file(var.public_key_path)
}

# 마스터 노드 생성
resource "openstack_compute_instance_v2" "master" {
  count           = var.master_count
  name            = "${var.project_name}-${var.environment}-master-${count.index + 1}"
  image_name      = var.image_name
  flavor_name     = var.master_flavor
  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = var.security_groups
  availability_zone = var.availability_zone

  network {
    uuid = var.network_id
  }

  user_data = templatefile("${path.module}/templates/master-userdata.sh", {
    node_index = count.index + 1
  })
}

# 워커 노드 생성
resource "openstack_compute_instance_v2" "worker" {
  count           = var.worker_count
  name            = "${var.project_name}-${var.environment}-worker-${count.index + 1}"
  image_name      = var.image_name
  flavor_name     = var.worker_flavor
  key_pair        = openstack_compute_keypair_v2.keypair.name
  security_groups = var.security_groups
  availability_zone = var.availability_zone

  network {
    uuid = var.network_id
  }

  user_data = templatefile("${path.module}/templates/worker-userdata.sh", {
    node_index = count.index + 1
  })
}

# 플로팅 IP 생성 및 할당
resource "openstack_networking_floatingip_v2" "master_fip" {
  count = var.master_count
  pool  = "public"
}

resource "openstack_compute_floatingip_associate_v2" "master_fip" {
  count       = var.master_count
  floating_ip = openstack_networking_floatingip_v2.master_fip[count.index].address
  instance_id = openstack_compute_instance_v2.master[count.index].id
}
```

**파일**: `infrastructure/terraform/modules/compute/variables.tf`
```hcl
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "network_id" {
  description = "Network ID"
  type        = string
}

variable "security_groups" {
  description = "Security groups"
  type        = list(string)
}

variable "image_name" {
  description = "Image name"
  type        = string
  default     = "Ubuntu-22.04"
}

variable "master_flavor" {
  description = "Master node flavor"
  type        = string
  default     = "m1.medium"
}

variable "worker_flavor" {
  description = "Worker node flavor"
  type        = string
  default     = "m1.small"
}

variable "master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "public_key_path" {
  description = "Path to public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "availability_zone" {
  description = "Availability zone"
  type        = string
  default     = "nova"
}
```

**파일**: `infrastructure/terraform/modules/compute/outputs.tf`
```hcl
output "master_ips" {
  description = "Master node private IPs"
  value       = openstack_compute_instance_v2.master[*].access_ip_v4
}

output "worker_ips" {
  description = "Worker node private IPs"
  value       = openstack_compute_instance_v2.worker[*].access_ip_v4
}

output "master_floating_ips" {
  description = "Master node floating IPs"
  value       = openstack_networking_floatingip_v2.master_fip[*].address
}

output "keypair_name" {
  description = "Keypair name"
  value       = openstack_compute_keypair_v2.keypair.name
}
```

### 3.4 사용자 데이터 템플릿

**파일**: `infrastructure/terraform/modules/compute/templates/master-userdata.sh`
```bash
#!/bin/bash

# 시스템 업데이트
apt-get update
apt-get upgrade -y

# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Kubernetes 저장소 추가
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

# Kubernetes 설치
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# 호스트명 설정
hostnamectl set-hostname k8s-master-${node_index}

# 완료 표시
touch /tmp/userdata-complete
```

**파일**: `infrastructure/terraform/modules/compute/templates/worker-userdata.sh`
```bash
#!/bin/bash

# 시스템 업데이트
apt-get update
apt-get upgrade -y

# Docker 설치
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Kubernetes 저장소 추가
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

# Kubernetes 설치
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# 호스트명 설정
hostnamectl set-hostname k8s-worker-${node_index}

# 완료 표시
touch /tmp/userdata-complete
```

---

## 4. 환경별 변수 관리

### 4.1 개발 환경 설정

**파일**: `infrastructure/terraform/environments/dev/terraform.tfvars`
```hcl
# 환경 설정
environment = "dev"
project_name = "private-cloud"

# OpenStack 인증 정보
openstack_password = "secret"
openstack_auth_url = "http://192.168.1.100:5000/v3"

# 인스턴스 설정
master_count = 1
worker_count = 2
master_flavor = "m1.medium"
worker_flavor = "m1.small"

# 네트워크 설정
subnet_cidr = "10.0.10.0/24"
```

**파일**: `infrastructure/terraform/environments/dev/main.tf`
```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

module "network" {
  source = "../../modules/network"
  
  project_name = var.project_name
  environment  = var.environment
  subnet_cidr  = var.subnet_cidr
}

module "security" {
  source = "../../modules/security"
  
  project_name = var.project_name
  environment  = var.environment
}

module "compute" {
  source = "../../modules/compute"
  
  project_name     = var.project_name
  environment      = var.environment
  network_id       = module.network.network_id
  security_groups  = [module.security.default_security_group_id, module.security.kubernetes_security_group_id]
  master_count     = var.master_count
  worker_count     = var.worker_count
  master_flavor    = var.master_flavor
  worker_flavor    = var.worker_flavor
  availability_zone = var.availability_zone
}
```

### 4.2 스테이징 환경 설정

**파일**: `infrastructure/terraform/environments/staging/terraform.tfvars`
```hcl
# 환경 설정
environment = "staging"
project_name = "private-cloud"

# OpenStack 인증 정보
openstack_password = "secret"
openstack_auth_url = "http://192.168.1.100:5000/v3"

# 인스턴스 설정
master_count = 1
worker_count = 3
master_flavor = "m1.large"
worker_flavor = "m1.medium"

# 네트워크 설정
subnet_cidr = "10.0.20.0/24"
```

### 4.3 프로덕션 환경 설정

**파일**: `infrastructure/terraform/environments/prod/terraform.tfvars`
```hcl
# 환경 설정
environment = "prod"
project_name = "private-cloud"

# OpenStack 인증 정보
openstack_password = "secret"
openstack_auth_url = "http://192.168.1.100:5000/v3"

# 인스턴스 설정
master_count = 3
worker_count = 5
master_flavor = "m1.xlarge"
worker_flavor = "m1.large"

# 네트워크 설정
subnet_cidr = "10.0.30.0/24"
```

---

## 5. 자동 프로비저닝 테스트

### 5.1 개발 환경 배포

```bash
# 개발 환경 디렉터리로 이동
cd infrastructure/terraform/environments/dev

# Terraform 초기화
terraform init

# 실행 계획 확인
terraform plan

# 인프라 배포
terraform apply

# 배포 결과 확인
terraform output
```

### 5.2 배포 스크립트 생성

**파일**: `scripts/deploy-infrastructure.sh`
```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-dev}
ACTION=${2:-apply}

echo "=== Terraform $ACTION for $ENVIRONMENT environment ==="

cd "infrastructure/terraform/environments/$ENVIRONMENT"

case $ACTION in
  "plan")
    terraform plan
    ;;
  "apply")
    terraform apply -auto-approve
    ;;
  "destroy")
    terraform destroy -auto-approve
    ;;
  *)
    echo "Usage: $0 <environment> <plan|apply|destroy>"
    exit 1
    ;;
esac

echo "=== Terraform $ACTION completed ==="
```

### 5.3 출력 확인 스크립트

**파일**: `scripts/get-infrastructure-info.sh`
```bash
#!/bin/bash

ENVIRONMENT=${1:-dev}

echo "=== Infrastructure Information for $ENVIRONMENT ==="

cd "infrastructure/terraform/environments/$ENVIRONMENT"

echo "Master nodes:"
terraform output master_ips

echo "Worker nodes:"
terraform output worker_ips

echo "Master floating IPs:"
terraform output master_floating_ips

echo "Keypair name:"
terraform output keypair_name
```

### 5.4 인벤토리 생성 스크립트

**파일**: `scripts/generate-inventory.sh`
```bash
#!/bin/bash

ENVIRONMENT=${1:-dev}

cd "infrastructure/terraform/environments/$ENVIRONMENT"

# Terraform 출력 가져오기
MASTER_IPS=$(terraform output -json master_floating_ips | jq -r '.[]')
WORKER_IPS=$(terraform output -json worker_ips | jq -r '.[]')

# Ansible 인벤토리 생성
cat > ../../../ansible/inventory/$ENVIRONMENT.ini << EOF
[masters]
$(echo "$MASTER_IPS" | sed 's/^/master-/' | nl -v1 -w1 | sed 's/\t/ ansible_host=/')

[workers]
$(echo "$WORKER_IPS" | sed 's/^/worker-/' | nl -v1 -w1 | sed 's/\t/ ansible_host=/')

[k8s_cluster:children]
masters
workers

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

echo "Inventory file created: ansible/inventory/$ENVIRONMENT.ini"
```

---

## 검증 및 테스트

### 5.1 인프라 상태 확인

```bash
# OpenStack 리소스 확인
source /opt/stack/devstack/openrc admin admin
openstack server list
openstack network list
openstack security group list

# Terraform 상태 확인
cd infrastructure/terraform/environments/dev
terraform state list
terraform show
```

### 5.2 SSH 접속 테스트

```bash
# 마스터 노드 접속 테스트
MASTER_IP=$(cd infrastructure/terraform/environments/dev && terraform output -raw master_floating_ips)
ssh -i ~/.ssh/id_rsa ubuntu@$MASTER_IP

# 워커 노드 접속 테스트 (내부 네트워크)
WORKER_IP=$(cd infrastructure/terraform/environments/dev && terraform output -json worker_ips | jq -r '.[0]')
ssh -i ~/.ssh/id_rsa ubuntu@$WORKER_IP
```

---

## 다음 단계

Terraform 인프라 자동화가 완료되면 다음 단계로 진행합니다:

1. **Kubernetes 클러스터 구축**: `docs/kubernetes-setup.md`
2. **Jenkins CI/CD 파이프라인 구축**: `docs/jenkins-setup.md`

---

## 참고 자료

- [Terraform OpenStack Provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs)
- [Terraform 모듈 작성 가이드](https://learn.hashicorp.com/tutorials/terraform/module-create)
- [OpenStack CLI 레퍼런스](https://docs.openstack.org/python-openstackclient/latest/)
