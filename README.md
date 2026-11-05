# platform_core
Core platform runtime

## About
- chose opentofu over terraform because 
    - licensing
    - encrypting plan and state output
- Use Trunk Based Deployment methods for platform infrastructure and service deployments

## outputs
- kubeconfig_path
    - written to pe-sandbox.config in folder
        - file location can be set via `resource.kind_cluster.dev.kubeconfig_path`
    - `$ export KUBECONFIG=$(tofu output -raw kubeconfig_path)`
- cluster_name
    - used in bats tests in `/test/infrastructure.bats`
- docker_network_name
    - used in bats tests in `/test/infrastructure.bats`