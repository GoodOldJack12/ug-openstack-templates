resource "openstack_blockstorage_volume_v3" "root" {
  name     = "${var.vm_name}-root"
  size     = local.disk_size
  image_id = var.image_name
  enable_online_resize = true
}

resource "openstack_compute_instance_v2" "instance_01" {
  name        = var.vm_name
  flavor_name = var.flavor_name
  key_pair    = local.access_key
  user_data   = file("../scripts/userdata.sh")
  block_device {
    uuid                  = openstack_blockstorage_volume_v3.root.id
    source_type           = "volume"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
  }
  metadata = {
    _SHARE_       = var.nfs_enabled ? module.linux_nfs[0].nfs_path : ""
    _ANSIBLE_URL_ = var.nginx_enabled ? var.playbook_url : ""
    admin_pass    = local.is_windows ? random_string.winpass[0].result : "N/A"
  }
  network {
    port = openstack_networking_port_v2.vm.id
  }
}

resource "openstack_networking_secgroup_v2" "secgroup" {
  name        = "${var.vm_name} security group"
  description = "Generated by terraform"
}
resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = local.ssh_internal_port
  port_range_max    = local.ssh_internal_port
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
}

resource "openstack_networking_port_v2" "vm" {
  network_id         = data.openstack_networking_network_v2.vm.id
  admin_state_up     = "true"
  security_group_ids = ["${openstack_networking_secgroup_v2.secgroup.id}"]

  fixed_ip {
    subnet_id = data.openstack_networking_subnet_ids_v2.vm.ids[0]
  }
}

resource "openstack_networking_portforwarding_v2" "ssh" {
  count               = var.public ? 1 : 0
  floatingip_id       = data.openstack_networking_floatingip_v2.public.id
  external_port       = local.ports.ssh
  internal_port       = local.ssh_internal_port
  internal_port_id    = openstack_networking_port_v2.vm.id
  internal_ip_address = openstack_networking_port_v2.vm.all_fixed_ips[0]
  protocol            = "tcp"
}

## NFS
module "linux_nfs" {
  count              = var.nfs_enabled ? 1 : 0
  source             = "../nfs"
  share_name         = "${local.project_name}_share"
  share_size         = var.nfs_size
  project_name       = local.project_name
  security_group_ids = ["${openstack_networking_secgroup_v2.secgroup.id}"]
  instance_id        = openstack_compute_instance_v2.instance_01.id
  cloud              = var.cloud
}
module "linux_vsc" {
  count             = var.vsc_enabled ? 1 : 0
  source            = "../vsc"
  instance_id       = openstack_compute_instance_v2.instance_01.id
  security_group_id = openstack_networking_secgroup_v2.secgroup.id
  project_name      = local.project_name
  cloud             = var.cloud
}
