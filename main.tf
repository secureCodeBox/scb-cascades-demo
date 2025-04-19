terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.45.0"
    }
  }
}

# Configure the Hetzner Cloud Provider
# Assumes HCLOUD_TOKEN environment variable is set
provider "hcloud" {}

# --- Network Configuration ---

resource "hcloud_network" "private_network" {
  name     = "private-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "private_subnet" {
  network_id   = hcloud_network.private_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.42.0/24"
}

resource "hcloud_firewall" "block-incoming-internet" {
  name = "block-incoming-internet"
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
  }
}
resource "hcloud_server" "juice_shop" {
  name        = "juice-shop"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "fsn1"

  ssh_keys = [ "jannik-zuhause", "jannik-unterwegs" ]

  firewall_ids = [hcloud_firewall.block-incoming-internet.id]

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private_network.id
    ip         = "10.0.42.2"
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
      - podman pull bkimminich/juice-shop
      - podman run --restart -d -p 80:3000 --name juice-shop docker.io/bkimminich/juice-shop:v17.2.0
  EOT
}

resource "hcloud_server" "bad_postgres" {
  name        = "bad-postgres"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "fsn1"

  ssh_keys = [ "jannik-zuhause", "jannik-unterwegs" ]

  firewall_ids = [hcloud_firewall.block-incoming-internet.id]

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private_network.id
    ip         = "10.0.42.3"
  }

  user_data = <<-EOT
    #cloud-config

    package_update: true
    package_upgrade: true
    packages:
      - postgresql
      - postgresql-contrib

    runcmd:
      # Change the default PostgreSQL user password
      - sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"

      # Configure PostgreSQL to allow password authentication
      - sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/16/main/postgresql.conf
      - echo "host    all             all             0.0.0.0/0               md5" >> /etc/postgresql/16/main/pg_hba.conf

      # Restart PostgreSQL to apply changes
      - systemctl restart postgresql

    final_message: "PostgreSQL has been installed and configured successfully!"
  EOT
}

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
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: nginx-deployment
            labels:
              app: nginx
          spec:
            replicas: 2
            selector:
              matchLabels:
                app: nginx
            template:
              metadata:
                labels:
                  app: nginx
              spec:
                containers:
                - name: nginx
                  image: nginx:stable
                  ports:
                  - containerPort: 80
  EOT
}