# Reads vpc / subnet / gateway SG IDs from the 01-vpn stack
data "terraform_remote_state" "vpn" {
  backend = "local"

  config = {
    path = var.vpn_state_path
  }
}

locals {
  vpc_id            = data.terraform_remote_state.vpn.outputs.vpc_id
  private_subnet_id = data.terraform_remote_state.vpn.outputs.private_subnet_id
  vpn_sg_id         = data.terraform_remote_state.vpn.outputs.vpn_security_group_id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "vm" {
  name_prefix = "${var.name}-vm-"
  description = "SSH only from the VPN gateway"
  vpc_id      = local.vpc_id

  tags = { Name = "${var.name}-vm-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# VPN clients are NAT-ed behind the gateway, so their SSH traffic arrives
# from the gateway's security group. Nothing else is allowed in.
resource "aws_vpc_security_group_ingress_rule" "ssh_from_vpn" {
  security_group_id            = aws_security_group.vm.id
  description                  = "SSH from VPN gateway"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = local.vpn_sg_id
}

# Outbound goes out through the gateway (NAT)
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.vm.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = local.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.vm.id]
  key_name                    = var.key_name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.name}-vm" }

  lifecycle {
    ignore_changes = [ami]
  }
}
