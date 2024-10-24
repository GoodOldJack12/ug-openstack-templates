variable "crontabs" {
  type = map(object({
    cron_time = string
    cron_user = optional(string,"root")
    script = string 
  }))
  default = {}
}

resource "null_resource" "cron" {
  for_each = {
    for k,v in local.crons : k => v
    if local.scripts_enabled
  }
  depends_on = [ null_resource.testconnection ]
  triggers = {
    user = local.ssh_user
    port = local.ports.ssh
    ip = data.openstack_networking_floatingip_v2.public.address
    content = each.value.script
  }
  connection {
    type     = "ssh"
    user     = self.triggers.user
    agent = true
    host     = self.triggers.ip
    timeout = "5m"
    port = self.triggers.port
  }
  provisioner "file" {
    destination = "/home/${local.ssh_user}/${random_id.obscure[each.key].id}-${each.key}.sh"
    content = each.value.script
  }
  provisioner "file" {
    destination = "/home/${local.ssh_user}/${random_id.obscure[each.key].id}-${each.key}.cron"
    content = <<-EOT
    ${each.value.cron_time} ${each.value.cron_user} /opt/vsc/cron/${each.key}.sh

    EOT
  }
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "sudo cp /home/${local.ssh_user}/${random_id.obscure[each.key].id}-${each.key}.sh /opt/vsc/cron/${each.key}.sh",
      "sudo chmod +x /opt/vsc/cron/${each.key}.sh",
      "sudo mv /home/${local.ssh_user}/${random_id.obscure[each.key].id}-${each.key}.cron /etc/cron.d/${each.key}",
      "sudo chown root:root /etc/cron.d/${each.key}",
      "sudo restorecon /etc/cron.d/${each.key} || echo \"SELinux not installed?\""
     ]
  }
  provisioner "remote-exec" {
    when = destroy
    on_failure = continue
    inline = [ 
      "sudo rm /etc/cron.d/${each.key}",
      "sudo rm /opt/vsc/cron/${each.key}.sh"
     ]
  }
}
resource "random_id" "obscure" {
  for_each = local.crons
  byte_length = 8
}
locals {
  crons = var.is_windows ? {} : merge(var.crontabs,local.default_crons)
  default_crons = {}
}