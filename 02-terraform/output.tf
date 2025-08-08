output "instance_ip" {
  value = openstack_compute_instance_v2.vm_1.access_ip_v4
}

output "floating_ip" {
  description = "VM의 Floating IP 주소"
  value       = openstack_networking_floatingip_v2.fip_1.address
}
