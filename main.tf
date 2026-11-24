locals {
  vpc_cidr     = "10.0.0.0/16"
  public_cidr  = cidrsubnet(local.vpc_cidr, 8, 1) # 10.0.1.0/24
  private_cidr = cidrsubnet(local.vpc_cidr, 8, 2) # 10.0.2.0/24
}

# Create docker network
resource "docker_network" "kind" {
  name   = "kind"
  driver = "bridge"

  ipam_config {
    aux_address = {}
    gateway     = "10.0.0.1"
    subnet      = local.vpc_cidr
  }
}

resource "tls_private_key" "oidc_ca" {
  algorithm = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "oidc_ca" {
  private_key_pem       = tls_private_key.oidc_ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 8760
  allowed_uses          = ["cert_signing", "crl_signing"]
  subject { common_name = "sandbox-oidc-ca" }
}

resource "local_file" "oidc_ca_crt" {
  content  = tls_self_signed_cert.oidc_ca.cert_pem
  filename = "${path.module}/oidc-ca.crt"
}

# Create cluster that uses docker network
resource "kind_cluster" "dev" {
  depends_on     = [docker_network.kind]
  name           = "pe-sandbox"
  node_image     = "kindest/node:v1.35.0"
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
      extra_port_mappings {   # For Keycloak NodePort
        container_port = 30080
        host_port      = 30080
      }
      extra_mounts {
        host_path = "/mnt/proxmox"
        container_path = "/mnt/thumbdrive"
      }

      kubeadm_config_patches = [<<-EOT
        kind: ClusterConfiguration
        apiServer:
          extraArgs:
            oidc-issuer-url: https://keycloak.localtest.me:30443/auth/realms/kubernetes
            oidc-client-id: kubernetes
            oidc-username-claim: preferred_username
            oidc-username-prefix: "oidc:"
            oidc-groups-claim: groups
            oidc-groups-prefix: "oidc:"
            oidc-ca-file: /etc/oidc/ca.crt
          extraVolumes:
            - name: oidc-ca
              hostPath: /etc/oidc/ca.crt
              mountPath: /etc/oidc/ca.crt
              readOnly: true
              pathType: File
      EOT
      ]
    }

    node {
      role = "worker"

      extra_mounts {
        host_path = "/mnt/proxmox"
        container_path = "/mnt/thumbdrive"
      }
    }
  }

  # write kubeconfig to local file
  # kubeconfig_path = "kubeconfig"
}

resource "kubernetes_config_map_v1_data" "local_path_config" {
  metadata {
    name      = "local-path-config"
    namespace = "local-path-storage"
  }

  data = {
    "config.json" = jsonencode({
      nodePathMap = [{
        node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
        paths = ["/mnt/thumbdrive/dynamic"]
      }]
    })
  }

  force         = true
  field_manager = "terraform"

  depends_on = [kind_cluster.dev]
}

resource "null_resource" "restart_local_path" {
  triggers = {
    config = kubernetes_config_map_v1_data.local_path_config.data["config.json"]
  }

  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${kind_cluster.dev.kubeconfig_path} -n local-path-storage rollout restart deploy/local-path-provisioner"
  }
}

# Bootstrap fluxcd inside of cluster
resource "flux_bootstrap_git" "sandbox" {
  depends_on = [kind_cluster.dev]
  path       = "environments/sandbox"
}

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
  depends_on = [kind_cluster.dev]
}

resource "kubernetes_secret_v1" "sandbox_ca" {
  metadata {
    name      = "sandbox-ca-keypair"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.oidc_ca.cert_pem
    "tls.key" = tls_private_key.oidc_ca.private_key_pem
  }
}