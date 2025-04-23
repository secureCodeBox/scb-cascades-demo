resource "hcloud_server" "bad_postgres" {
  name        = "bad-postgres"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "fsn1"

  ssh_keys = [ "primary" ]

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