#!/bin/bash
# Rendered by Terraform. Installs OpenVPN, builds a PKI, enables NAT/forwarding
# and writes one .ovpn profile per client to /home/ubuntu/ovpn-clients/.
set -euxo pipefail
exec > >(tee /var/log/openvpn-bootstrap.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y openvpn easy-rsa iptables-persistent

# ---------- PKI ----------
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
export EASYRSA_BATCH=1
export EASYRSA_REQ_CN="openvpn-ca"
export EASYRSA_ALGO=ec
export EASYRSA_CURVE=secp384r1

./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass

install -d -m 750 /etc/openvpn/server
cp pki/ca.crt pki/issued/server.crt pki/private/server.key /etc/openvpn/server/
openvpn --genkey secret /etc/openvpn/server/tls-crypt.key
chmod 600 /etc/openvpn/server/server.key /etc/openvpn/server/tls-crypt.key

# ---------- Server config ----------
cat > /etc/openvpn/server/server.conf <<CONF
port ${vpn_port}
proto udp
dev tun
topology subnet
server ${vpn_network} ${vpn_netmask}

ca ca.crt
cert server.crt
key server.key
dh none
tls-crypt tls-crypt.key
tls-version-min 1.2

data-ciphers AES-256-GCM:AES-128-GCM
auth SHA256

# Split tunnel: only VPC traffic goes through the VPN
push "route ${vpc_network} ${vpc_netmask}"
push "dhcp-option DNS ${vpc_dns}"

keepalive 10 120
explicit-exit-notify 1
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn-status.log
verb 3
CONF

# ---------- Forwarding + NAT ----------
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl --system

IFACE=$(ip -o -4 route show to default | awk '{print $5; exit}')

# VPN clients -> VPC (private hosts see the gateway's private IP)
iptables -t nat -A POSTROUTING -s ${vpn_cidr} -d ${vpc_cidr} -o "$IFACE" -j MASQUERADE
# Private subnet -> internet (NAT gateway role)
iptables -t nat -A POSTROUTING -s ${private_cidr} ! -d ${vpc_cidr} -o "$IFACE" -j MASQUERADE
netfilter-persistent save

systemctl enable --now openvpn-server@server

# ---------- Client profiles ----------
OUT=/home/ubuntu/ovpn-clients
install -d -m 700 -o ubuntu -g ubuntu "$OUT"

for CLIENT in ${client_names}; do
  ./easyrsa build-client-full "$CLIENT" nopass
  {
    echo "client"
    echo "dev tun"
    echo "proto udp"
    echo "remote ${public_ip} ${vpn_port}"
    echo "resolv-retry infinite"
    echo "nobind"
    echo "persist-key"
    echo "persist-tun"
    echo "remote-cert-tls server"
    echo "data-ciphers AES-256-GCM:AES-128-GCM"
    echo "auth SHA256"
    echo "verb 3"
    echo "<ca>";         cat pki/ca.crt;                                          echo "</ca>"
    echo "<cert>";       sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "pki/issued/$CLIENT.crt"; echo "</cert>"
    echo "<key>";        cat "pki/private/$CLIENT.key";                           echo "</key>"
    echo "<tls-crypt>";  cat /etc/openvpn/server/tls-crypt.key;                   echo "</tls-crypt>"
  } > "$OUT/$CLIENT.ovpn"
  chown ubuntu:ubuntu "$OUT/$CLIENT.ovpn"
  chmod 600 "$OUT/$CLIENT.ovpn"
done
