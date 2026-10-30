# platform_core
Core platform runtime

## outputs
- kubeconfig_path
    - written to pe-sandbox.config in folder
        - file location can be set via `resource.kind_cluster.dev.kubeconfig_path`
    - `$ export KUBECONFIG=$(tofu output -raw kubeconfig_path)`
- cluster_name
    - used in bats tests in `/test/infrastructure.bats`
- docker_network_name
    - used in bats tests in `/test/infrastructure.bats`