setup_file() {
export export KUBECONFIG=$(tofu output -raw kubeconfig_path)
export DOCKER_NETWORK=$(tofu output -raw docker_network_name)
export CLUSTER_NAME=$(tofu output -raw cluster_name)
}

@test "docker network exists" {
  run docker network inspect "$DOCKER_NETWORK"
  [ "$status" -eq 0 ]
}

@test "kubernetes cluster is accessible" {
  run kubectl get nodes --no-headers
  [ "$status" -eq 0 ]
  node_count=$(echo "$output" | wc -l)
  [ "$node_count" -ge 1 ]
}




# Nothing to teardown at this point
# teardown_file() {
#   # Cleanup after all tests
#   rm -f kubeconfig.yaml
# }