output "kubeconfig_path" {
  value = resource.kind_cluster.dev.kubeconfig_path
}
output "cluster_name" {
  value = resource.kind_cluster.dev.name
}
output "docker_network_name" {
  value = docker_network.kind.name
}