# OpenVPN on AWS: two Terraform stacks

```
openvpn-aws/
├── 01-vpn/   VPC, subnets, OpenVPN gateway (EIP, NAT for private subnet), client .ovpn profiles
└── 02-vm/    Private VM, SSH allowed only from the VPN gateway
```

```
OpenVPN app ──UDP 1194──> [Gateway, public EIP]──> Private subnet 10.0.2.0/24
                                                      └─ VM (no public IP, SSH only via VPN)
```

## 1. Create the VPN
```bash
cd 01-vpn
cp terraform.tfvars.example terraform.tfvars   # key_name + your public IP (ssh_allowed_cidr)
terraform init && terraform apply
```
Wait ~3 minutes, run the `fetch_client_profiles` output command, and import
the `.ovpn` into OpenVPN Connect. Connect to the VPN.

## 2. Create the VM
```bash
cd ../02-vm
cp terraform.tfvars.example terraform.tfvars   # key_name (+ region if changed)
terraform init && terraform apply
```
`02-vm` reads `01-vpn`'s outputs through `terraform_remote_state`, so apply
01 first. `terraform apply` for 02 doesn't need the VPN to be connected, because
Terraform only talks to the AWS API.

Then, with the VPN connected:
```bash
ssh -i primary-c2-key.pem ubuntu@<vm_private_ip>
```

## Why SSH works only through the VPN
- The VM has no public IP and sits in the private subnet.
- Its security group allows TCP 22 only from the gateway's security group.
  VPN clients are NAT-ed behind the gateway, so their SSH arrives from it.
- Without the VPN there is no route to the VM.

## Teardown
Destroy in reverse order: `02-vm` first, then `01-vpn`.

## Notes
- The gateway itself still allows SSH from `ssh_allowed_cidr` so you can fetch
  the profiles. After that, remove that rule or tighten it.
- Changing `client_names` replaces the gateway and regenerates the PKI.
- Local state is used. For a team, move both stacks to an S3 backend and change
  the `terraform_remote_state` backend to `s3`.
- Keep `.ovpn` and `.pem` files private.
