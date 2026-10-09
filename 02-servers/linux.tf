# ================================================================================
# FILE: linux.tf
#
# Purpose:
#   - One private Ubuntu 24.04 instance joined to the mini-AD with SSSD (AD
#     provider). No public IP: users reach it through Guacamole's SSH
#     connection, signed in with their AD account. Admin access is SSM
#     Session Manager.
# ================================================================================

# ================================================================================
# DATA: Canonical Ubuntu 24.04 AMI
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

locals {
  # Base DN derived from the DNS zone (mcloud.mikecloud.com -> DC=mcloud,...).
  base_dn = join(",", [for p in split(".", var.dns_zone) : "DC=${p}"])
}

# ================================================================================
# RESOURCE: aws_instance.linux
# ================================================================================
resource "aws_instance" "linux" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t3.small"

  subnet_id                   = data.aws_subnet.server_subnet.id
  vpc_security_group_ids      = [aws_security_group.linux_sg.id]
  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

  user_data = templatefile("./scripts/userdata_linux.sh", {
    admin_secret = "admin_ad_credentials_efs"
    domain_fqdn  = var.dns_zone
    hostname     = "linux-sssd" # -> AD computer object name on join
  })

  tags = { Name = "linux-sssd" }
}
