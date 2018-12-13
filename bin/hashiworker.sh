#!/bin/bash

apt-get -y update
apt-get -y install unzip dnsmasq default-jre

# Get variables
export IP_ADDRESS=$(curl -s http://169.254.169.254/metadata/v1/interfaces/private/0/ipv4/address)

# Install Nomad
curl -sSL https://releases.hashicorp.com/nomad/0.8.6/nomad_0.8.6_linux_amd64.zip > nomad.zip
unzip nomad.zip
mv nomad /usr/local/bin

mkdir -p /var/lib/nomad /etc/nomad
rm -rf nomad.zip

cat >/etc/nomad/client.hcl <<EOL
addresses {
    rpc  = "$${IP_ADDRESS}"
    http = "$${IP_ADDRESS}"
}
advertise {
    http = "$${IP_ADDRESS}:4646"
    rpc  = "$${IP_ADDRESS}:4647"
}
data_dir  = "/var/lib/nomad"
log_level = "DEBUG"
client {
    enabled = true
    servers = [
      "${master_address}"
    ]
    options {
        "driver.raw_exec.enable" = "1"
    }
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
  -data-dir=/var/lib/consul \
  -advertise=$${IP_ADDRESS} \
  -retry-join=${master_address}

ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOL

systemctl enable consul
systemctl start consul

# DNS settings
echo "server=/consul/127.0.0.1#8600" > /etc/dnsmasq.d/10-consul
echo "server=1.1.1.1" > /etc/dnsmasq.d/20-cloudflare
echo "conf-dir=/etc/dnsmasq.d" >> /etc/dnsmasq.conf
systemctl stop systemd-resolved
systemctl disable systemd-resolved
systemctl restart dnsmasq