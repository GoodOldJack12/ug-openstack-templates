module "cluster" {
  source             = "../modules/multi_instance"
  private_count      = 3
  public_flavor      = "CPUv1.medium"
  public_image  = "Rocky-9"
  cluster_name       = "MyCluster"
}
output "cluster" {
  value = module.cluster.Connections
}