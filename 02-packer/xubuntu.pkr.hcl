# ==============================================================================
# xubuntu.pkr.hcl -- Ubuntu 26.04 + Xubuntu core (Xfce) + XRDP + SSSD packages
# ==============================================================================
# Builds the AMI for the private desktop host that Guacamole reaches over RDP
# and SSH. The image holds the slow, generic part (desktop, XRDP, the SSSD/
# realmd packages, AWS CLI). The domain join happens at boot in user data
# (03-servers/scripts/userdata_linux.sh): a computer account and keytab are
# per machine and must never be baked into a shared image.
#
# The build instance runs in the public subnet (vm-subnet-1) so Packer can SSH
# to it; its temporary security group admits only this machine's public IP.
# ==============================================================================

packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

# Canonical publishes the current 26.04 AMI id in Parameter Store -- the same
# lookup Terraform uses for the 24.04 image.
data "amazon-parameterstore" "ubuntu_2604" {
  name   = "/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "vpc_id" {
  description = "VPC id, resolved by apply.sh from the Name tag"
  default     = ""
}

variable "subnet_id" {
  description = "Public subnet (vm-subnet-1) for SSH during the build"
  default     = ""
}

locals {
  stamp = formatdate("YYYYMMDD-hhmmss", timestamp())
}

source "amazon-ebs" "xubuntu" {
  region        = var.region
  instance_type = var.instance_type
  source_ami    = data.amazon-parameterstore.ubuntu_2604.value
  ssh_username  = "ubuntu"
  ssh_interface = "public_ip"
  vpc_id        = var.vpc_id
  subnet_id     = var.subnet_id

  associate_public_ip_address               = true
  temporary_security_group_source_public_ip = true

  ami_name = "xubuntu_xrdp_2604_${local.stamp}"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 24
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = "xubuntu_xrdp_2604_${local.stamp}"
    Project = "aws-guacamole"
    Source  = "ubuntu-26.04"
  }
}

build {
  sources = ["source.amazon-ebs.xubuntu"]

  provisioner "shell" {
    script          = "./scripts/01-packages.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  provisioner "shell" {
    script          = "./scripts/02-desktop.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }

  provisioner "shell" {
    script          = "./scripts/03-xrdp.sh"
    execute_command = "sudo -E bash '{{.Path}}'"
  }
}
