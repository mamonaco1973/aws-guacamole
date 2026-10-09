# ================================================================================
# FILE: guacamole.tf
#
# Purpose:
#   - The Apache Guacamole server: private, behind the ALB (alb.tf). It signs
#     users in against the mini-AD and opens RDP to the Windows host and SSH
#     to the Linux host on their behalf. Setup is in
#     scripts/userdata_guacamole.sh.
# ================================================================================

locals {
  # The DC's fully-qualified name: Guacamole's LDAPS target and the source of
  # the CA it trusts (http://<dc>/ca.pem). Resolvable because the mini-AD
  # module's DHCP option set points VPC DNS at the DC.
  dc_fqdn = "${var.dc_hostname}.${var.dns_zone}"
}

resource "aws_instance" "guacamole" {
  ami           = data.aws_ami.ubuntu_ami.id
  instance_type = "t3.medium" # guacd + Tomcat + PostgreSQL

  subnet_id                   = data.aws_subnet.server_subnet.id
  vpc_security_group_ids      = [aws_security_group.guacamole_sg.id]
  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.ec2_secrets_profile.name

  root_block_device {
    volume_size = 20 # three container images plus PostgreSQL
  }

  user_data = templatefile("./scripts/userdata_guacamole.sh", {
    admin_secret = "admin_ad_credentials_efs"
    guac_version = "1.6.0"
    dc_fqdn      = local.dc_fqdn
    base_dn      = local.base_dn
    netbios      = var.netbios
    windows_ip   = aws_instance.windows_ad_instance.private_ip
    linux_ip     = aws_instance.linux.private_ip
  })

  # Replace the server if the setup script changes, instead of leaving the
  # old one running with stale configuration.
  user_data_replace_on_change = true

  tags = { Name = "guacamole" }
}
