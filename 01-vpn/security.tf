resource "aws_security_group" "vpn" {
  name_prefix = "${var.name}-gw-"
  description = "OpenVPN gateway"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.name}-gw-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpn_udp" {
  security_group_id = aws_security_group.vpn.id
  description       = "OpenVPN"
  ip_protocol       = "udp"
  from_port         = var.vpn_port
  to_port           = var.vpn_port
  cidr_ipv4         = var.vpn_allowed_cidr
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.vpn.id
  description       = "SSH admin"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_allowed_cidr
}

# Lets private-subnet hosts send traffic through the gateway (NAT)
resource "aws_vpc_security_group_ingress_rule" "from_private" {
  security_group_id = aws_security_group.vpn.id
  description       = "Private subnet via NAT"
  ip_protocol       = "-1"
  cidr_ipv4         = var.private_subnet_cidr
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.vpn.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

