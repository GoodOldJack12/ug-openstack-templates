output "VM_ip_address" {
  value = data.openstack_networking_floatingip_v2.public.address
}
output "VM_private_ip" {
  value = openstack_compute_instance_v2.instance_01.access_ip_v4
}
output "VM_port" {
  value = local.ports.ssh
}
output "Connections" {
  value = trimspace(<<Connections
${var.is_windows ? local.windows_string : local.ssh_string}
${local.http_string}
${length(openstack_networking_portforwarding_v2.custom) > 0 ? local.custom_ports : ""}
  Connections
  )
}
output "ports" {
  value = local.custom_ports
}
output "Name" {
  value = openstack_compute_instance_v2.instance_01.name
}
output "ssh-user" {
  value = local.ssh_user
}
output "volumes" {
  value = openstack_compute_volume_attach_v2.custom_volume
}
locals {
  ssh_users = {
    "AlmaLinux-8"     = "almalinux"
    "Rocky-9"         = "rocky"
    "CentOS-8-stream" = "centos"
    "Debian-11"       = "debian"
    "Debian-12"       = "debian"
    "RHEL-9.2"        = "cloud-user"
    "Ubuntu-20.04"    = "ubuntu"
    "Ubuntu-22.04"    = "ubuntu"
    "Ubuntu-24.04"    = "ubuntu"
  }
  ssh_user           = contains(keys(local.ssh_users), var.image_name) ? local.ssh_users[var.image_name] : "root"
  private_ssh_string = "SSH: ssh -A ${local.ssh_user}@${openstack_compute_instance_v2.instance_01.network[0].fixed_ip_v4}"
  ssh_string         = var.public ? "SSH: ssh -A -p ${local.ports.ssh} ${local.ssh_user}@${data.openstack_networking_floatingip_v2.public.address}" : local.private_ssh_string
  windows_string     = var.is_windows ? "xfreerdp /dynamic-resolution /u:admin /port:${local.ports.ssh} /v:${data.openstack_networking_floatingip_v2.public.address} /p:${random_string.winpass[0].result}" : ""
  http_string        = var.nginx_enabled ? "HTTP: http://${data.openstack_networking_floatingip_v2.public.address}:${local.ports.http}" : ""
}
