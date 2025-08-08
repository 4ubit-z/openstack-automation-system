# 외부(public) 네트워크 정보 가져오기 (Floating IP용)
data "openstack_networking_network_v2" "public" {
  name = "public"
}

# 내부 서브넷 정보 가져오기 (예: shared-subnet)
data "openstack_networking_subnet_v2" "internal_subnet" {
  name = var.subnet_name
}

# 라우터 생성 (내부 ↔ 외부 통신)
resource "openstack_networking_router_v2" "router1" {
  name                = "router1"
  external_network_id = data.openstack_networking_network_v2.public.id
}

# 라우터에 내부 서브넷 연결
resource "openstack_networking_router_interface_v2" "router_interface" {
  router_id = openstack_networking_router_v2.router1.id
  subnet_id = data.openstack_networking_subnet_v2.internal_subnet.id
}

# 보안 그룹 생성 (SSH, ping, HTTP 허용)
resource "openstack_networking_secgroup_v2" "secgroup_ssh" {
  name = "allow_ssh_icmp_http"
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup_ssh.id
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_icmp" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup_ssh.id
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup_ssh.id
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_jenkins" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8080
  port_range_max    = 8080
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup_ssh.id
}

resource "openstack_networking_secgroup_rule_v2" "secgroup_rule_gitlab" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8081
  port_range_max    = 8081
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup_ssh.id
}


# Floating IP 생성
resource "openstack_networking_floatingip_v2" "fip_1" {
  pool = data.openstack_networking_network_v2.public.name
}

# 인스턴스 생성 (볼륨 부팅, 삭제 시 볼륨도 삭제됨)
resource "openstack_compute_instance_v2" "vm_1" {
  name        = var.instance_name
  flavor_name = var.flavor_name
  key_pair    = var.key_name

  block_device {
    uuid                  = var.image_id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.volume_size
    delete_on_termination = true
    boot_index            = 0
  }

  network {
    name = var.network_name
  }

  security_groups = [openstack_networking_secgroup_v2.secgroup_ssh.name]
}

# Floating IP 연결
resource "openstack_compute_floatingip_associate_v2" "fip_assoc_1" {
  floating_ip = openstack_networking_floatingip_v2.fip_1.address
  instance_id = openstack_compute_instance_v2.vm_1.id
}
