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

  ssh_keys = ["jannik-zuhause", "jannik-unterwegs"]

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
    ip         = "10.0.42.3"  # Changed IP address
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
      - podman pull grafana/grafana
      - podman pull prom/prometheus
      - mkdir -p /etc/prometheus
      - cat <<EOF > /etc/prometheus/prometheus.yml
        global:
          scrape_interval: 15s
        scrape_configs:
          - job_name: 'prometheus'
            static_configs:
              - targets: ['localhost:9090']
    EOF
      - podman run -d --name prometheus -p 9090:9090 -v /etc/prometheus:/etc/prometheus prom/prometheus --config.file=/etc/prometheus/prometheus.yml
      - podman run -d --name grafana -p 3000:3000 grafana/grafana
  EOT
}