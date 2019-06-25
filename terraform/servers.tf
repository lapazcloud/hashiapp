provider "digitalocean" {
}

resource "digitalocean_database_cluster" "db" {
  name       = "hashidb"
  engine     = "pg"
  version    = "11"
  size       = "db-s-1vcpu-1gb"
  region     = "nyc3"
  node_count = 1
}

data "digitalocean_ssh_key" "mykey" {
  name = "jala"
}

resource "digitalocean_droplet" "master" {
  name               = "master"
  size               = "s-1vcpu-1gb"
  image              = "ubuntu-18-10-x64"
  region             = "nyc3"
  private_networking = true
  ipv6               = false
  ssh_keys           = [data.digitalocean_ssh_key.mykey.fingerprint]
  user_data          = file("../bin/hashimaster.sh")
}

resource "digitalocean_droplet" "worker" {
  count              = 2
  name               = format("worker-%03d", count.index + 1)
  size               = "s-1vcpu-1gb"
  image              = "ubuntu-18-10-x64"
  region             = "nyc3"
  private_networking = true
  ipv6               = false
  ssh_keys           = [data.digitalocean_ssh_key.mykey.fingerprint]
  user_data          = templatefile("../bin/hashiworker.sh", { master_address = digitalocean_droplet.master.ipv4_address_private })
}

resource "digitalocean_loadbalancer" "hashilb" {
  name   = "hashilb"
  region = "nyc3"

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 9999
    target_protocol = "http"
  }

  healthcheck {
    port     = 9999
    protocol = "tcp"
  }

  droplet_ids = digitalocean_droplet.worker.*.id
}

output "load-balancer" {
  value = "http://${digitalocean_loadbalancer.hashilb.ip}/"
}

output "master-ip" {
  value = digitalocean_droplet.master.ipv4_address
}

output "master-internal-ip" {
  value = digitalocean_droplet.master.ipv4_address_private
}

output "consul-ui" {
  value = "http://${digitalocean_droplet.master.ipv4_address}:8500"
}

output "nomad-ui" {
  value = "http://${digitalocean_droplet.master.ipv4_address}:4646"
}

output "vault-ui" {
  value = "http://${digitalocean_droplet.master.ipv4_address}:8200/ui/"
}

output "vault-export" {
  value = "export VAULT_ADDR='http://${digitalocean_droplet.master.ipv4_address_private}:8200'"
}

output "worker-ips" {
  value = digitalocean_droplet.worker.*.ipv4_address
}

output "internal-worker-ips" {
  value = digitalocean_droplet.worker.*.ipv4_address_private
}

