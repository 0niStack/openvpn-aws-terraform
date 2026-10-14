variable "name" {
  description = "Prefix used for naming/tagging all resources"
  type        = string
  default     = "openvpn"
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access to the gateway"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH to the gateway (e.g. your public IP as x.x.x.x/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0)) && var.ssh_allowed_cidr != "0.0.0.0/0"
    error_message = "Provide a valid CIDR and do not use 0.0.0.0/0 for SSH."
  }
}

variable "vpn_allowed_cidr" {
  description = "CIDR allowed to reach the OpenVPN port. Open by default because clients roam."
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "vpn_client_cidr" {
  description = "Address pool handed to VPN clients (must not overlap the VPC or your home LAN)"
  type        = string
  default     = "10.8.0.0/24"
}

variable "vpn_port" {
  type    = number
  default = 1194
}

variable "client_names" {
  description = "One .ovpn profile is generated per name"
  type        = list(string)
  default     = ["client1"]
}
