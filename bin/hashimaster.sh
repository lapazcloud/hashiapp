#!/bin/bash
set -e

apt-get -y update
apt-get -y install unzip

# Get variables
IP_ADDRESS=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)

# Install Nomad
curl -sSL https://releases.hashicorp.com/nomad/0.8.6/nomad_0.8.6_linux_amd64.zip > nomad.zip
unzip nomad.zip
mv nomad /usr/local/bin

mkdir -p /var/lib/nomad /etc/nomad
rm -rf nomad.zip

cat >/etc/nomad/server.hcl <<EOL
addresses {
    rpc  = "${IP_ADDRESS}"
    serf = "${IP_ADDRESS}"
}
advertise {
    http = "${IP_ADDRESS}:4646"
    rpc  = "${IP_ADDRESS}:4647"
    serf = "${IP_ADDRESS}:4648"
}
bind_addr = "0.0.0.0"
data_dir  = "/var/lib/nomad"
log_level = "DEBUG"
server {
    enabled = true
    bootstrap_expect = 1
}
EOL

cat >/etc/systemd/system/nomad.service <<EOF
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
[Service]
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl enable nomad
systemctl start nomad

# Install Consul
curl -sSL https://releases.hashicorp.com/consul/1.4.0/consul_1.4.0_linux_amd64.zip > consul.zip
unzip consul.zip
mv consul /usr/local/bin/
rm -f consul.zip

mkdir -p /var/lib/consul

cat >/etc/systemd/system/consul.service <<EOL
[Unit]
Description=consul
Documentation=https://consul.io/docs/
[Service]
ExecStart=/usr/local/bin/consul agent \
  -advertise=${IP_ADDRESS} \
  -bind=0.0.0.0 \
  -bootstrap-expect=1 \
  -client=0.0.0.0 \
  -data-dir=/var/lib/consul \
  -server \
  -ui

ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOL

systemctl enable consul
systemctl start consul

# Install Vault
curl -sSL https://releases.hashicorp.com/vault/1.0.0/vault_1.0.0_linux_amd64.zip > vault.zip
unzip vault.zip
mv vault /usr/local/bin/vault
rm -f vault.zip

mkdir -p /etc/vault

cat >/etc/vault/vault.hcl <<EOL
ui = true
backend "consul" {
  advertise_addr = "http://${IP_ADDRESS}:8200"
  address = "127.0.0.1:8500"
  path = "vault"
}
listener "tcp" {
  address = "${IP_ADDRESS}:8200"
  tls_disable = 1
}
EOL

cat > /etc/systemd/system/vault.service <<'EOF'
[Unit]
Description=Vault
Documentation=https://vaultproject.io/docs/
[Service]
ExecStart=/usr/local/bin/vault server \
  -config /etc/vault/vault.hcl

ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl enable vault
systemctl start vault

