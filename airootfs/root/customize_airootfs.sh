#!/usr/bin/env bash
#
# Runs inside the airootfs chroot, after every package has been installed.
# Everything that needs the real /etc/group, /etc/passwd and the installed
# packages belongs here -- shipping hand-written account files in airootfs/
# would clobber the GIDs that the `filesystem` package defines.
#

set -euo pipefail

readonly LIVE_USER='oinix'
readonly LIVE_PASSWORD='oinix'
readonly LIVE_SHELL='/bin/bash'

msg() { printf '[customize_airootfs] %s\n' "$*"; }

#-- Distribution identity ----------------------------------------------------
# /etc/lsb-release belongs to the lsb-release package and /usr/lib/os-release
# to the filesystem package, so neither can be shipped in airootfs/ without
# tripping pacman's file-conflict check. Write them here instead.
msg 'Writing the distribution identity files'
cat > /etc/lsb-release <<'EOF'
LSB_VERSION=1.4
DISTRIB_ID=OINIX
DISTRIB_RELEASE=2025.01
DISTRIB_CODENAME=rolling
DISTRIB_DESCRIPTION="OINIX Linux 2025.01"
EOF
cp /etc/os-release /usr/lib/os-release

#-- Locales ------------------------------------------------------------------
msg 'Generating locales'
sed -i 's/^#\(en_US\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(uz_UZ\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
sed -i 's/^#\(ru_RU\.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen

#-- root account -------------------------------------------------------------
# Empty password so the rescue console stays reachable from the live medium.
msg 'Configuring the root account'
usermod --shell /usr/bin/zsh root
passwd --delete root

#-- Live user ----------------------------------------------------------------
msg "Creating the live user '${LIVE_USER}'"
getent group autologin >/dev/null || groupadd --system autologin

if ! id -u "${LIVE_USER}" >/dev/null 2>&1; then
    useradd --create-home --shell "${LIVE_SHELL}" \
        --groups wheel,audio,video,storage,optical,network,power,lp,scanner,rfkill,users,autologin \
        --comment 'OINIX Live User' \
        "${LIVE_USER}"
fi
printf '%s:%s\n' "${LIVE_USER}" "${LIVE_PASSWORD}" | chpasswd
chown -R "${LIVE_USER}:${LIVE_USER}" "/home/${LIVE_USER}"

#-- Desktop entry for the installer -----------------------------------------
if [[ -f /usr/share/applications/oinix-install.desktop ]]; then
    msg 'Placing the installer shortcut on the live desktop'
    install -d -o "${LIVE_USER}" -g "${LIVE_USER}" -m 0755 "/home/${LIVE_USER}/Desktop"
    install -o "${LIVE_USER}" -g "${LIVE_USER}" -m 0755 \
        /usr/share/applications/oinix-install.desktop \
        "/home/${LIVE_USER}/Desktop/oinix-install.desktop"
fi

#-- Services -----------------------------------------------------------------
# Units whose enablement creates an alias (lightdm -> display-manager.service)
# have to go through systemctl; the rest are symlinked from airootfs/.
msg 'Enabling system services'
systemctl enable lightdm.service NetworkManager.service

#-- Housekeeping -------------------------------------------------------------
msg 'Updating system databases'
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database --quiet /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache --quiet --force /usr/share/icons/hicolor || true
fi

msg 'Done'
