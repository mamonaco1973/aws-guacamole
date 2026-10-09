#!/bin/bash
set -euo pipefail

# ================================================================================
# Base packages: SSSD/realmd (the join happens at boot), AWS CLI v2, tools
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

# apt mirrors can be briefly out of step (a package index newer than the files
# behind it, answering 404). Retry with a fresh index instead of failing the
# whole image build.
cat > /usr/local/bin/apt-install-retry <<'SCRIPT'
#!/bin/bash
for attempt in 1 2 3 4 5; do
  if apt-get install "$@"; then exit 0; fi
  echo "WARN: apt-get install failed (attempt ${attempt}); refreshing and retrying"
  sleep $((attempt * 10))
  apt-get update -y || true
done
exit 1
SCRIPT
chmod 755 /usr/local/bin/apt-install-retry

echo "NOTE: [packages] updating and upgrading"
apt-get update -y
apt-get -y -o Dpkg::Options::=--force-confold upgrade

echo "NOTE: [packages] SSSD / realmd for the AD join at boot"
apt-install-retry -y \
  realmd sssd sssd-tools sssd-ad adcli krb5-user samba-common-bin \
  oddjob oddjob-mkhomedir packagekit jq curl unzip

echo "NOTE: [packages] AWS CLI v2"
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q -o /tmp/awscliv2.zip -d /tmp
/tmp/aws/install --update
rm -rf /tmp/aws /tmp/awscliv2.zip

echo "NOTE: [packages] done"
