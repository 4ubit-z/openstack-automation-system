# OpenStack 기반 Private Cloud 운영 자동화 시스템

## 프로젝트 개요

OpenStack 환경에서 GitLab CI/CD, Terraform, Ansible을 활용한 완전 자동화된 인프라 운영 시스템을 구축합니다. 가상 인프라 프로비저닝부터 애플리케이션 배포, 실시간 모니터링, 장애 대응까지 전체 DevOps 라이프사이클을 다룹니다.

## 프로젝트 목표

- OpenStack 기반 가상 인프라 구축 및 관리
- GitLab CI/CD 파이프라인 구성으로 자동화된 배포 환경 구축
- Infrastructure as Code 실현 (Terraform + Ansible)
- 실시간 모니터링 시스템 구성 및 장애 대응 자동화
- 실무 수준의 운영 문서 작성 및 표준화

## 기술 스택

### 인프라
- **가상화**: KVM/QEMU
- **클라우드 플랫폼**: OpenStack (DevStack)
- **운영체제**: Ubuntu 22.04.5 LTS

### 자동화 도구
- **인프라 관리**: Terraform
- **구성 관리**: Ansible
- **CI/CD**: GitLab CI/CD
- **버전 관리**: Git + GitLab

### 모니터링
- **메트릭 수집**: Prometheus
- **대시보드**: Grafana
- **알림**: Alertmanager

## 구현 단계

### Phase 1: 기반 환경 구성
- Ubuntu 서버에서 DevStack 환경 구성
- 사용자, 네트워크 설정

### Phase 2: 인프라 자동화
- Terraform으로 VM 인스턴스 생성 자동화
- 네트워크 구성, 보안 그룹, 스토리지 볼륨 관리
- 상태 파일 기반 인프라 버전 관리

### Phase 3: 서비스 구성 자동화
- Ansible 플레이북으로 애플리케이션 설치 자동화
- nginx, Jenkins 등 서비스 초기 설정

### Phase 4: CI/CD 파이프라인 구축
- GitLab 저장소 생성 및 Runner 설정
- .gitlab-ci.yml 파이프라인 작성
- Terraform → VM 자동 배포
- Ansible → 서비스 자동 구성

### Phase 5: 모니터링 시스템 구성
- Prometheus 메트릭 수집 서버 구축
- Grafana 대시보드 구성
- Slack, Email 기반 알림 시스템 연동

### Phase 6: 장애 대응 및 문서화
- 장애 시나리오 설계 및 테스트
- 자동 복구 메커니즘 구현
- 운영 매뉴얼 및 장애 대응 가이드 작성

## 프로젝트 구조

```
openstack-automation/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ansible/
│   ├── playbooks/
│   ├── roles/
│   └── inventory/
├── gitlab-ci/
│   ├── .gitlab-ci.yml
│   └── runners/
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   └── alertmanager/
├── scripts/
│   ├── setup-devstack.sh          # OpenStack 초기 설치
│   ├── backup-system.sh           # 시스템 백업 자동화
│   ├── health-check.sh            # 서비스 상태 점검
│   └── automation/
│       ├── vm-provisioning.sh     # VM 대량 생성 스크립트
│       └── service-restart.sh     # 서비스 재시작 자동화
├── docs/
│   ├── architecture/
│   │   ├── system-overview.md     # 전체 시스템 구성도
│   │   └── network-diagram.png    # 네트워크 토폴로지
│   ├── operations/
│   │   ├── daily-checklist.md     # 일일 운영 체크리스트
│   │   └── backup-procedures.md   # 백업 및 복구 절차
│   └── troubleshooting/
│       ├── common-issues.md       # 자주 발생하는 문제들
│       └── performance-tuning.md  # 성능 최적화 가이드
└── README.md
```

## 학습 목표

### 기술적 역량
- OpenStack 클라우드 플랫폼 운영 능력
- Infrastructure as Code 설계 및 구현
- CI/CD 파이프라인 구성 및 최적화
- 클라우드 네이티브 서비스 관리

### 운영 역량
- 시스템 모니터링 및 성능 최적화
- 장애 감지, 분석, 대응 프로세스
- 자동화 스크립트 작성 및 유지보수
- 기술 문서 작성 및 표준화

## 시스템 요구사항

### 하드웨어 (본인[가상환경] 기준)
- CPU: 총 8개의 가상 코어(vCPU)
- RAM: 16GB (DevStack 8GB + 모니터링 4GB + 여유분 4GB)
- 스토리지: SSD 120GB 이상 (OS 40GB + OpenStack 80GB)
- 네트워크: 유선 인터넷 연결 권장 (패키지 다운로드 대용량)

### 소프트웨어
- VMware Workstation Pro
- Ubuntu 22.04.5 LTS
- Git 2.30 이상
- Python 3.8 이상
## 주요 명령어

### Terraform
```bash
# 인프라 계획 확인
terraform plan -var-file="environments/dev.tfvars"

# 인프라 배포
terraform apply -auto-approve

# 특정 리소스만 재배포
terraform apply -target=openstack_compute_instance_v2.web_server

# 인프라 제거
terraform destroy
```

### Ansible
```bash
# 전체 플레이북 실행
ansible-playbook -i inventory/hosts playbooks/site.yml

# 특정 서비스만 설치
ansible-playbook -i inventory/hosts playbooks/site.yml --tags "nginx"

# Dry-run 모드 (실제 변경 없이 확인)
ansible-playbook -i inventory/hosts playbooks/site.yml --check
```

### OpenStack CLI
```bash
# VM 목록 확인
openstack server list

# 네트워크 상태 확인
openstack network list

# 이미지 목록
openstack image list
```

## 모니터링 대시보드

- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090
- OpenStack Horizon: http://localhost/dashboard (admin/stack)

### 알림 설정 예시
```bash
# Slack 알림 테스트
curl -X POST -H 'Content-type: application/json' \
--data '{"text":"OpenStack 시스템 알림 테스트"}' \
YOUR_SLACK_WEBHOOK_URL

# 이메일 알림 설정 (Alertmanager)
# monitoring/alertmanager/alertmanager.yml 파일 참조
```

## 문제 해결

일반적인 문제와 해결 방법은 [docs/troubleshooting](docs/troubleshooting/) 디렉터리를 참조하세요.

### 자주 발생하는 문제
- DevStack 설치 실패: 메모리 부족 확인
- Terraform 상태 충돌: 상태 파일 백업 후 복구
- Ansible 연결 오류: SSH 키 설정 확인

## 참고 자료

### 공식 문서
- [OpenStack Documentation](https://docs.openstack.org/)
- [Terraform OpenStack Provider](https://registry.terraform.io/providers/terraform-provider-openstack/openstack/latest/docs)
- [Ansible OpenStack Collection](https://docs.ansible.com/ansible/latest/collections/openstack/cloud/)

### 학습 자료
- OpenStack 기초 개념 및 구성 요소
- Terraform 상태 관리 및 모듈 설계
- Ansible 역할 기반 플레이북 작성
- GitLab CI/CD 파이프라인 최적화

## 기여하기

1. 이슈 생성으로 문제 리포트 또는 개선 제안
2. 기능 브랜치 생성 후 작업
3. 코드 리뷰를 통한 품질 관리
4. 문서 업데이트 및 테스트 케이스 추가

## 라이센스

이 프로젝트는 MIT 라이센스 하에 배포됩니다. 자세한 내용은 LICENSE 파일을 확인하세요.
