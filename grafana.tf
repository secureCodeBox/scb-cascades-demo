resource "hcloud_firewall" "allow-monitoring" {
  name = "allow-monitoring"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "3000"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "9090"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}


resource "hcloud_server" "monitoring" {
  name        = "monitoring"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "fsn1"

  ssh_keys = ["primary"]

  firewall_ids = [
    hcloud_firewall.block-incoming-internet.id,
    hcloud_firewall.allow-monitoring.id,
  ]

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private_network.id
    ip         = "10.0.42.6"  # Changed IP address
  }

  user_data = <<-EOT
    #cloud-config

    package_reboot_if_required: true
    package_update: true
    package_upgrade: true

    packages:
      - curl
      - podman

    runcmd:
      - podman pull docker.io/grafana/grafana:8.1.8
      - podman run --restart=always -d --name grafana -p 80:3000 docker.io/grafana/grafana:8.1.8
  EOT
}