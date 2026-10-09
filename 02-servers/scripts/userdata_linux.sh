#!/bin/bash
# ==============================================================================
# userdata_linux.sh  —  Ubuntu joined to the mini-AD with SSSD (AD provider)
#
# realmd joins the domain (creating a computer object + keytab), and SSSD
# becomes the identity/auth provider over Kerberos. POSIX UIDs come from AD
# (ldap_id_mapping = False). The box is private: users reach it through
# Guacamole's SSH connection, which logs in with their AD password.
# ==============================================================================
set -euo pipefail
exec > >(tee -a /root/userdata.log | logger -t user-data -s 2>/dev/console) 2>&1
trap 'echo "ERROR at line $LINENO"; exit 1' ERR
echo "linux user-data start ($(date -Is))"

# Descriptive hostname BEFORE the join so the AD computer object is identifiable
# instead of the default ip-10-0-0-x name.
hostnamectl set-hostname ${hostname}
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99-preserve-hostname.cfg

export DEBIAN_FRONTEND=noninteractive
export AWS_DEFAULT_REGION=us-east-1

# ------------------------------------------------------------------------------
# Packages — realmd/SSSD/AD provider
# ------------------------------------------------------------------------------
apt-get update -y
apt-get install -y \
  realmd sssd sssd-tools sssd-ad adcli krb5-user samba-common-bin \
  oddjob oddjob-mkhomedir packagekit jq curl unzip

# AWS CLI v2 (the 'awscli' apt package was dropped in Ubuntu 24.04).
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q -o /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip
export PATH="$PATH:/usr/local/bin"

# ------------------------------------------------------------------------------
# Domain admin credential (used only to perform the join)
# ------------------------------------------------------------------------------
secret=$(aws secretsmanager get-secret-value \
  --secret-id ${admin_secret} --query SecretString --output text)
admin_password=$(echo "$secret" | jq -r .password)
admin_user=$(echo "$secret" | jq -r .username | sed 's/.*\\//')

# ------------------------------------------------------------------------------
# Join with SSSD (realmd's default client software)
# ------------------------------------------------------------------------------
echo "$admin_password" | realm join -U "$admin_user" ${domain_fqdn} --verbose

# ------------------------------------------------------------------------------
# SSSD tweaks:
#   - short login names (jsmith, not jsmith@domain)
#   - POSIX mapping: read uidNumber/gidNumber from AD
#   - home under /home/%u
# ------------------------------------------------------------------------------
sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' /etc/sssd/sssd.conf
sed -i 's/ldap_id_mapping = True/ldap_id_mapping = False/'                     /etc/sssd/sssd.conf
sed -i 's|fallback_homedir = /home/%u@%d|fallback_homedir = /home/%u|'         /etc/sssd/sssd.conf

pam-auth-update --enable mkhomedir
systemctl restart sssd

# ------------------------------------------------------------------------------
# Passwordless sudo for the linux-admins domain group
# ------------------------------------------------------------------------------
echo "%linux-admins ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/10-linux-admins
chmod 440 /etc/sudoers.d/10-linux-admins

# ------------------------------------------------------------------------------
# SSH password logins — Guacamole's SSH connection passes the user's AD
# password through. Ubuntu's cloud image turns password auth off in
# 60-cloudimg-settings.conf; sshd takes the first value it reads, so a file
# that sorts earlier wins. Port 22 is open only to the Guacamole server.
# ------------------------------------------------------------------------------
cat > /etc/ssh/sshd_config.d/10-guacamole-password-auth.conf <<'SSHD'
PasswordAuthentication yes
KbdInteractiveAuthentication yes
SSHD
systemctl restart ssh

# ------------------------------------------------------------------------------
# Sanity: resolve/log in as the demo users (also triggers mkhomedir). Non-fatal.
# ------------------------------------------------------------------------------
for u in jsmith rpatel akumar edavis; do
  if id "$u" >/dev/null 2>&1; then echo "OK resolve: $u ($(id -u "$u"))"; else echo "WARN unresolved: $u"; fi
done
echo "linux user-data done ($(date -Is))"
