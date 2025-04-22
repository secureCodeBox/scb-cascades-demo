resource "hcloud_firewall" "block-everything" {
  name = "block-everything"
}

resource "hcloud_server" "insecure_ssh" {
  name        = "insecure-ssh"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "fsn1"

  public_net {
    ipv4_enabled = false
    ipv6_enabled = false // completly isolate this one... don't want this to hang in the internet at all...
  }

  network {
    network_id = hcloud_network.private_network.id
    ip         = "10.0.42.5"
  }

  firewall_ids = [
    hcloud_firewall.block-everything.id,
  ]

  user_data = <<-EOT
    #cloud-config

    users:
      - name: admin
        # password is "password"...
        passwd: $6$rounds=4096$P4RAVJxYgMZQ9Axw$ibvf8U8tq8VUv41qqq.GYVxKUL4wjKP/ytQxX9GIp.ZvAPRhGp/2MY0Y2dbltI03FoQ7CS2dD/9DWZ66onhCU0
        lock_passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash

    ssh_pwauth: true

    write_files:
      - path: /etc/ssh/sshd_config
        content: |
          Port 22
          PermitRootLogin yes
          PasswordAuthentication yes
          ChallengeResponseAuthentication no
          UsePAM yes
          X11Forwarding yes
          PrintMotd no
          AcceptEnv LANG LC_*
          Subsystem sftp /usr/lib/openssh/sftp-server
          Ciphers aes128-cbc,3des-cbc,blowfish-cbc,cast128-cbc,aes192-cbc,aes256-cbc
          KexAlgorithms diffie-hellman-group1-sha1,diffie-hellman-group14-sha1
          MACs hmac-md5,hmac-sha1,umac-64@openssh.com

    runcmd:
      - sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
      - systemctl restart sshd
  EOT
}
