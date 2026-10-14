output "vm_private_ip" {
  value = aws_instance.vm.private_ip
}

output "ssh_command" {
  description = "Run this while connected to the VPN"
  value       = "ssh -i <path-to-${var.key_name}.pem> ubuntu@${aws_instance.vm.private_ip}"
}
