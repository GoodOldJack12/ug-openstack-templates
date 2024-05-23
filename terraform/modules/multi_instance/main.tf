module "main" {
  source        = "../single_instance"
  vm_name       = "${var.cluster_name}-public"
  image_name    = var.public_image
  flavor_name   = var.public_flavor
  nginx_enabled = var.public_nginx_enabled
  cloud         = var.cloud
  project_name  = var.project_name
  access_key    = var.access_key
  vsc_enabled   = var.public_vsc_enabled
  playbook_url  = var.playbook_url
  is_windows = false
}
module "private" {
  count        = var.private_count
  source       = "../single_instance"
  vm_name      = "${var.cluster_name}-private-${count.index}"
  image_name   = local.private_image
  flavor_name  = local.private_flavor
  cloud        = var.cloud
  project_name = var.project_name
  access_key   = var.access_key
  public       = false
  is_windows = false
}
output "main" {
  value = module.main.Connections
}
locals {
  private_connections = join("\n", [for instance in module.private : "${instance.Name}:\n ${instance.Connections}"])
}
output "Connections" {
  value = <<EOT
Main:
${module.main.Connections}

Private:
Note: SSH to main server first
${local.private_connections}
  EOT
}
