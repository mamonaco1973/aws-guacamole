#!/bin/bash
set -euo pipefail

# ================================================================================
# XRDP: RDP logins start an Xfce session
# ================================================================================
#
# Guacamole connects with RDP security "tls": XRDP does not do NLA. The login
# is checked by PAM, so once the instance has joined the domain (SSSD), AD
# users sign in with their AD password and get a home directory on first use.
#
# ================================================================================

export DEBIAN_FRONTEND=noninteractive

echo "NOTE: [xrdp] installing xrdp"
apt-get update -y
apt-install-retry -y xrdp xorgxrdp

# XRDP reads the private key of its TLS certificate (the snakeoil pair).
adduser xrdp ssl-cert

echo "NOTE: [xrdp] Xfce session for every login"
tee /etc/xrdp/startwm.sh >/dev/null <<'WM'
#!/bin/sh
if test -r /etc/profile; then
    . /etc/profile
fi

if test -r ~/.profile; then
    . ~/.profile
fi

export DESKTOP_SESSION=xfce
export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE

exec startxfce4
WM
chmod 755 /etc/xrdp/startwm.sh

echo "NOTE: [xrdp] PAM: environment, then the system stack (SSSD + mkhomedir)"
tee /etc/pam.d/xrdp-sesman >/dev/null <<'PAM'
#%PAM-1.0
auth required pam_env.so readenv=1
auth required pam_env.so readenv=1 envfile=/etc/default/locale
@include common-auth
@include common-account
@include common-session
@include common-password
PAM

# Remote sessions otherwise get polkit prompts for colour management and
# package refreshes ("Authentication is required to create a color profile").
echo "NOTE: [xrdp] polkit: no prompts for colord / packagekit refresh"
mkdir -p /etc/polkit-1/rules.d
tee /etc/polkit-1/rules.d/45-xrdp-quiet.rules >/dev/null <<'RULES'
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.freedesktop.color-manager.") === 0 ||
      action.id === "org.freedesktop.packagekit.system-sources-refresh") {
    return polkit.Result.YES;
  }
});
RULES

# systemd 258+ prints "OSC 3008" context escapes at every bash prompt
# (/etc/profile.d/80-systemd-osc-context.sh). Guacamole's terminal does not
# understand them and shows the raw text ("start=...;type=shell;cwd=...").
# A dpkg diversion renames the file out of /etc/profile.d's *.sh glob and
# keeps it renamed across systemd upgrades.
echo "NOTE: [xrdp] disabling systemd's OSC 3008 prompt escapes"
if [ -e /etc/profile.d/80-systemd-osc-context.sh ]; then
  dpkg-divert --local --rename --divert /etc/profile.d/80-systemd-osc-context.sh.disabled \
    --add /etc/profile.d/80-systemd-osc-context.sh
fi

systemctl enable xrdp

echo "NOTE: [xrdp] done"
