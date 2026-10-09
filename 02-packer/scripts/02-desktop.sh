#!/bin/bash
set -euo pipefail

# ================================================================================
# Xubuntu core: the Xfce desktop without Xubuntu's full application set
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [desktop] installing xubuntu-core"
apt-get update -y
apt-install-retry -y xubuntu-core xfce4-terminal mousepad

# Things a headless cloud desktop never uses, several of which pop up
# authentication prompts or errors inside an XRDP session.
echo "NOTE: [desktop] removing cloud-irrelevant packages"
apt-get purge -y \
  bluez blueman cups cups-browsed cups-daemon system-config-printer \
  modemmanager speech-dispatcher orca \
  light-locker xfce4-power-manager update-notifier \
  2>/dev/null || true
apt-get autoremove -y

# A display manager on the console is pointless here (XRDP starts its own X
# sessions) and only competes for resources.
systemctl disable lightdm 2>/dev/null || true
systemctl set-default multi-user.target

echo "NOTE: [desktop] done"
