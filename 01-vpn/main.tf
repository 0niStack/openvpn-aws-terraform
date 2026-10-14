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

# Allocated separately from the instance so user_data can embed the address
resource "aws_eip" "vpn" {
  domain = "vpc"
  tags   = { Name = "${var.name}-eip" }

  depends_on = [aws_internet_gateway.main]
}

locals {
  user_data = templatefile("${path.module}/templates/openvpn-user-data.sh.tpl", {
    public_ip      = aws_eip.vpn.public_ip
    vpn_port       = var.vpn_port
    vpc_cidr       = var.vpc_cidr
    vpc_network    = cidrhost(var.vpc_cidr, 0)
    vpc_netmask    = cidrnetmask(var.vpc_cidr)
    vpc_dns        = cidrhost(var.vpc_cidr, 2) # AWS VPC resolver
    private_cidr   = var.private_subnet_cidr
    vpn_network    = cidrhost(var.vpn_client_cidr, 0)
    vpn_netmask    = cidrnetmask(var.vpn_client_cidr)
    vpn_cidr       = var.vpn_client_cidr
    client_names   = join(" ", var.client_names)
  })
}

resource "aws_instance" "vpn" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.vpn.id]
  key_name               = var.key_name

  # Required: the instance forwards packets that are not addressed to it
  source_dest_check = false

  user_data                   = local.user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.name}-gateway" }

  lifecycle {
    ignore_changes = [ami] # don't rebuild the VPN (and its PKI) on new AMI releases
  }
}

resource "aws_eip_association" "vpn" {
  instance_id   = aws_instance.vpn.id
  allocation_id = aws_eip.vpn.id
}
