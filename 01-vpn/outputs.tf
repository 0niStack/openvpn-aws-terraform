output "vpn_public_ip" {
  description = "Elastic IP clients connect to"
  value       = aws_eip.vpn.public_ip
}

output "gateway_private_ip" {
  value = aws_instance.vpn.private_ip
}

output "fetch_client_profiles" {
  description = "Run after ~3 minutes to download the .ovpn profiles"
  value       = "scp -i <path-to-${var.key_name}.pem> ubuntu@${aws_eip.vpn.public_ip}:/home/ubuntu/ovpn-clients/*.ovpn ."
}

# ---- consumed by ../02-vm via terraform_remote_state ----
output "aws_region" {
  value = var.aws_region
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "vpn_security_group_id" {
  value = aws_security_group.vpn.id
}
