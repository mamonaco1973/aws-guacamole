#!/bin/bash
set -euo pipefail

# ================================================================================
# Xubuntu core: the Xfce desktop without Xubuntu's full application set
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [desktop] installing xubuntu-core"
apt-get update -y
apt-install-retry -y xubuntu-core xfce4-terminal mousepad

# Firefox from the Snap Store, Ubuntu's default packaging. Snaps need the
# XAUTHORITY export in /etc/xrdp/startwm.sh (03-xrdp.sh) to open windows in
# an XRDP session. Wait for snapd's first-boot seeding before installing.
echo "NOTE: [desktop] installing firefox (snap)"
snap wait system seed.loaded
snap install firefox

# A snap registers no Debian alternatives, so Xfce's default "Web Browser"
# (debian-sensible-browser -> www-browser) found nothing: "Failed to execute
# child process www-browser". Register Firefox for both names, and make it
# Xfce's preferred browser for every user.
#
# Through a wrapper, not a symlink: /snap/bin/firefox is itself a symlink to
# /usr/bin/snap, which picks the app from the name it is invoked by -- run
# as "www-browser" it does not know it means Firefox.
cat > /usr/local/bin/firefox-snap <<'WRAPPER'
#!/bin/sh
exec /snap/bin/firefox "$@"
WRAPPER
chmod 755 /usr/local/bin/firefox-snap
for name in x-www-browser www-browser; do
  update-alternatives --install "/usr/bin/$name" "$name" /usr/local/bin/firefox-snap 200
done
sed -i 's/^WebBrowser=.*/WebBrowser=firefox/' /etc/xdg/xfce4/helpers.rc

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
