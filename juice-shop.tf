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
      - podman run --restart=always -d -p "80:3000" --name juice-shop docker.io/bkimminich/juice-shop:v17.2.0
  EOT
}