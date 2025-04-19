resource "hcloud_server" "scb" {
  name        = "scb"
  image       = "ubuntu-24.04"
  server_type = "cax31"
  location    = "fsn1"

  ssh_keys = [ "jannik-zuhause", "jannik-unterwegs" ]

  firewall_ids = [hcloud_firewall.block-incoming-internet.id]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private_network.id
    ip         = "10.0.42.42"
  }

  user_data = <<-EOT
    #cloud-config
    package_update: true
    package_upgrade: true

    runcmd:
      # 1. Install K3s
      - curl -sfL https://get.k3s.io | sh -

      # 2. Enable the K3s service
      - systemctl enable k3s

      # 3. Create the static manifests folder if it doesn't exist
      - mkdir -p /var/lib/rancher/k3s/server/manifests

      # 4. Restart K3s to ensure it loads from the static manifests
      - systemctl restart k3s

    write_files:
      # Example Kubernetes Deployment YAML for static manifests
      - path: /var/lib/rancher/k3s/server/manifests/sample-deployment.yaml
        content: |
          ${indent(6, file("kubernetes-manifests/sample-deployment.yaml"))}
      - path: /var/lib/rancher/k3s/server/manifests/defectdojo.yaml
        content: |
          ${indent(6, file("kubernetes-manifests/defectdojo.yaml"))}

  EOT
}
