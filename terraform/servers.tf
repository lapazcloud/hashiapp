provider "digitalocean" {}
provider "cloudflare" {}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group_rule" "allow_psql" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "sg-e9a79ba2"
}

resource "aws_db_instance" "db" {
  identifier          = "hashidb"
  allocated_storage   = 10
  storage_type        = "gp2"
  engine              = "postgres"
  instance_class      = "db.t2.micro"
  name                = "hashidb"
  username            = "hashiuser"
  password            = ""
  apply_immediately   = true
  publicly_accessible = true
  skip_final_snapshot = true
}

data "digitalocean_ssh_key" "mykey" {
  name = "macbook"
}

resource "digitalocean_droplet" "master" {
  name               = "master"
  size               = "s-1vcpu-1gb"
  image              = "ubuntu-18-10-x64"
  region             = "nyc3"
  private_networking = true
  ipv6               = false
  ssh_keys           = ["${data.digitalocean_ssh_key.mykey.fingerprint}"]
  user_data          = "${file("../bin/hashimaster.sh")}"
}

data "template_file" "worker" {
  template = "${file("../bin/hashiworker.sh")}"

  vars {
    master_address = "${digitalocean_droplet.master.ipv4_address_private}"
  }
}

resource "digitalocean_droplet" "worker" {
  count              = 2
  name               = "${format("worker-%03d", count.index + 1)}"
  size               = "s-1vcpu-1gb"
  image              = "ubuntu-18-10-x64"
  region             = "nyc3"
  private_networking = true
  ipv6               = false
  ssh_keys           = ["${data.digitalocean_ssh_key.mykey.fingerprint}"]
  user_data          = "${data.template_file.worker.rendered}"
}

resource "digitalocean_loadbalancer" "hashilb" {
  name = "hashilb"
  region = "nyc3"

  forwarding_rule {
    entry_port = 80
    entry_protocol = "http"

    target_port = 9999
    target_protocol = "http"
  }

  healthcheck {
    port = 9999
    protocol = "tcp"
  }

  droplet_ids = ["${digitalocean_droplet.worker.*.id}"]
}

resource "cloudflare_record" "domain" {
  domain = "lapazcloud.com"
  name = "@"
  value = "${digitalocean_loadbalancer.hashilb.ip}"
  type = "A"
  ttl = 1
}

output "load-balancer" {
  value = "http://${digitalocean_loadbalancer.hashilb.ip}/"
}

output "db-address" {
  value = "${aws_db_instance.db.endpoint}"
}

output "master-ip" {
  value = "${digitalocean_droplet.master.ipv4_address}"
}

output "master-internal-ip" {
  value = "${digitalocean_droplet.master.ipv4_address_private}"
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
  value = "${digitalocean_droplet.worker.*.ipv4_address}"
}

output "internal-worker-ips" {
  value = "${digitalocean_droplet.worker.*.ipv4_address_private}"
}
