variable "name" {
  type    = string
  default = "openvpn"
}

variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "key_name" {
  description = "Existing EC2 key pair used for SSH"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "vpn_state_path" {
  description = "Path to the state file of the 01-vpn stack"
  type        = string
  default     = "../01-vpn/terraform.tfstate"
}
