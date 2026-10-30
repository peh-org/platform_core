locals {
  vpc_cidr     = "10.0.0.0/16"
  public_cidr  = cidrsubnet(local.vpc_cidr, 8, 1)   # 10.0.1.0/24
  private_cidr = cidrsubnet(local.vpc_cidr, 8, 2)   # 10.0.2.0/24
}

# Kind uses a Docker network named "kind" and reuses it if it already exists,
# so creating it first with your subnet controls the node IPs.
resource "docker_network" "kind" {
  name   = "kind"
  driver = "bridge"

  ipam_config {
    aux_address = {}
    gateway = "10.0.0.1"
    subnet = local.vpc_cidr
  }
}

resource "kind_cluster" "dev" {
  depends_on = [docker_network.kind]
  name = "pe-sandbox"
  node_image = "kindest/node:v1.31.0"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    networking {
      pod_subnet     = "10.244.0.0/16"
      service_subnet = "10.96.0.0/12"
    }

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 80
        host_port      = 8080
      }
      extra_port_mappings {
        container_port = 443
        host_port      = 8443
      }
    }

    node {
      role = "worker"
    }
  }

  # write kubeconfig to local file
  # kubeconfig_path = "kubeconfig"
}