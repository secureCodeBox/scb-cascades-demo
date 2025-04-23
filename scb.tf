resource "hcloud_firewall" "allow-https" {
  name = "allow-https"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}

resource "hcloud_firewall" "allow-kubernetes-api" {
  name = "allow-kubernetes-api"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "6443"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}


resource "hcloud_server" "scb" {
  name        = "scb"
  image       = "ubuntu-24.04"
  server_type = "cax31"
  location    = "fsn1"

  ssh_keys = ["primary"]

  firewall_ids = [
    hcloud_firewall.block-incoming-internet.id,
    hcloud_firewall.allow-https.id,
    hcloud_firewall.allow-kubernetes-api.id,
  ]

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
      - path: /var/lib/rancher/k3s/server/manifests/defectdojo.yaml
        content: |
          ${indent(6, file("kubernetes-manifests/defectdojo.yaml"))}
      - path: /var/lib/rancher/k3s/server/manifests/scb-operator.yaml
        content: |
          ${indent(6, file("kubernetes-manifests/scb-operator.yaml"))}
      - path: /var/lib/rancher/k3s/server/manifests/scb-scan-setup.yaml
        content: |
          ${indent(6, file("kubernetes-manifests/scb-scan-setup.yaml"))}
      - path: /var/lib/rancher/k3s/server/manifests/cert-manager.yaml
        content: |
          ${indent(6, file("kubernetes-manifests/cert-manager.yaml"))}

  EOT
}
