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

resource "hcloud_network" "private_net" {
  name     = "scb-demo-network"
  ip_range = "10.42.0.0/16" # Wider range for the network itself
}

resource "hcloud_network_subnet" "private_subnet" {
  network_id   = hcloud_network.private_net.id
  type         = "cloud"
  network_zone = "eu-central" # Matches the location fsn1
  ip_range     = "10.42.0.0/24" # Your desired subnet range
}

# --- Custom Network Route for Internet-bound Traffic ---
resource "hcloud_network_route" "internet_route" {
  network_id  = hcloud_network.private_net.id
  destination = "0.0.0.0/0"     # Route for all Internet-bound traffic
  gateway     = "10.42.0.2"     # NAT gateway's private IP
}

# --- NAT Gateway Server ---

resource "hcloud_server" "nat_gateway" {
  name        = "nat-gateway"
  server_type = "cax11"
  image       = "ubuntu-22.04"
  location    = "fsn1"
  ssh_keys    = ["jannik-zuhause", "jannik-unterwegs"]

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private_net.id
    ip         = "10.42.0.2" # Assign a predictable private IP
  }

  user_data = <<-EOF
#cloud-config
package_update: true
package_upgrade: false
write_files:
  - path: /etc/netplan/99-custom-routing.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          enp7s0: # Replace with your actual network interface name if needed
            dhcp4: true
            dhcp4-overrides:
              use-routes: false # Ignore routes provided by DHCP
            routes:
              # Direct route for local network traffic
              - to: 10.42.0.0/16
                via: 0.0.0.0 # Use the local interface directly
              # Default route for Internet-bound traffic via NAT gateway
              - to: 0.0.0.0/0
                via: 10.42.0.2
EOF

  # Ensure network is ready before starting server configuration
  depends_on = [hcloud_network_subnet.private_subnet]
}

# --- Private Servers ---

resource "hcloud_server" "private_server" {
  count       = 3
  name        = "private-server-${count.index + 1}"
  server_type = "cax11"
  image       = "ubuntu-22.04"
  location    = "fsn1"
  ssh_keys    = ["jannik-zuhause", "jannik-unterwegs"]

  # Disable public IPs
  public_net {
    ipv4_enabled = false
    ipv6_enabled = false
  }

  # Attach to the private network
  network {
    network_id = hcloud_network.private_net.id
    # IPs will be assigned automatically from 10.42.0.0/24 range
  }

  # Cloud-init script to set default route via NAT gateway
  user_data = <<-EOF
#cloud-config
package_update: true
package_upgrade: false
write_files:
  - path: /etc/netplan/99-custom-routing.yaml
    permissions: '0644'
    content: |
      network:
        version: 2
        ethernets:
          enp7s0: # Replace with your actual network interface name if needed
            dhcp4: true
            dhcp4-overrides:
              use-routes: false # Ignore routes provided by DHCP
            routes:
              # Direct route for local network traffic
              - to: 10.42.0.0/16
                via: 0.0.0.0 # Use the local interface directly
              # Default route for Internet-bound traffic via NAT gateway
              - to: 0.0.0.0/0
                via: 10.42.0.2
EOF

  # Ensure NAT gateway is created first
  depends_on = [hcloud_server.nat_gateway]
}

# --- Outputs ---

# --- Outputs ---

output "nat_gateway_public_ipv4" {
  description = "Public IPv4 address of the NAT gateway"
  value       = hcloud_server.nat_gateway.ipv4_address
}

output "nat_gateway_public_ipv6" {
  description = "Public IPv6 address of the NAT gateway"
  value       = hcloud_server.nat_gateway.ipv6_address
}

output "nat_gateway_private_ip" {
  description = "Private IP address of the NAT gateway"
  # Convert the set to a list first, then access the first element
  value       = tolist(hcloud_server.nat_gateway.network)[0].ip
}

output "private_server_private_ips" {
  description = "Private IP addresses of the private servers"
  # Apply the same tolist() logic within the for loop
  value       = [for server in hcloud_server.private_server : tolist(server.network)[0].ip]
}

output "ssh_command_nat_gateway" {
  description = "Command to SSH into the NAT gateway"
  value       = "ssh root@${hcloud_server.nat_gateway.ipv4_address}"
}

output "ssh_command_private_servers_via_gateway" {
  description = "Example command to SSH into the first private server via the NAT gateway"
  # Apply the same tolist() logic here as well
  value       = "ssh -J root@${hcloud_server.nat_gateway.ipv4_address} root@${tolist(hcloud_server.private_server[0].network)[0].ip}"
  # Note: Requires SSH Agent Forwarding or key available on the gateway
}