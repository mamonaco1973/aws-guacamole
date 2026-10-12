# ================================================================================
# FILE: xubuntu.tf
#
# Purpose:
#   - The Xubuntu desktop host: Ubuntu 26.04 with Xfce and XRDP, from the AMI
#     02-packer builds. Private, joined to the mini-AD with SSSD at boot.
#     Users reach it through Guacamole over RDP (a desktop) or SSH. Admin
#     access is SSM Session Manager.
# ================================================================================

# ================================================================================
# DATA: Canonical Ubuntu 24.04 AMI (the Guacamole server's base image)
# ================================================================================
data "aws_ssm_parameter" "ubuntu_24_04" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ubuntu_24_04.value]
  }
}

# ================================================================================
# DATA: the newest Xubuntu + XRDP image built by 02-packer
# ================================================================================
data "aws_ami" "xubuntu" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["xubuntu_xrdp_2604_*"]
  }
}

locals {
  # Base DN derived from the DNS zone (mcloud.mikecloud.com -> DC=mcloud,...).
  base_dn = join(",", [for p in split(".", var.dns_zone) : "DC=${p}"])
}

# ================================================================================
# RESOURCE: aws_instance.xubuntu
# ================================================================================
resource "aws_instance" "xubuntu" {
  ami           = data.aws_ami.xubuntu.id
  instance_type = "t3.medium" # a desktop session per user

  subnet_id                   = data.aws_subnet.server_subnet.id
  vpc_security_group_ids      = [aws_security_group.xubuntu_sg.id]
  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

  user_data = templatefile("./scripts/userdata_xubuntu.sh", {
    admin_secret = "admin_ad_credentials_guac"
    domain_fqdn  = var.dns_zone
    hostname     = "xubuntu" # -> AD computer object name on join
  })

  tags = { Name = "xubuntu" }
}
