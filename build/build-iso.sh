#!/usr/bin/env bash
#
# Build the OINIX ISO with mkarchiso. Runs inside the container as root.
#
# Environment:
#   OINIX_SQUASHFS_COMP   "xz" (default, smallest) or "zstd" (much faster)
#   OINIX_WITH_INSTALLER  "1" (default) to include Calamares, "0" to leave it out
#   SOURCE_DATE_EPOCH     fixes the ISO version/label for reproducible builds
#

set -euo pipefail

readonly SRC='/oinix'
readonly PROFILE='/build/profile'
readonly WORK='/build/work'
readonly OUT="${SRC}/out"

readonly WITH_INSTALLER="${OINIX_WITH_INSTALLER:-1}"

msg() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

msg 'Preparing a clean copy of the profile'
rm -rf "${PROFILE}" "${WORK}"
mkdir -p "${PROFILE}" "${WORK}" "${OUT}"
# Copy only what mkarchiso consumes; the AlterISO leftovers and the build
# tooling itself have no business inside the profile.
for entry in profiledef.sh pacman.conf packages.x86_64 airootfs efiboot syslinux grub; do
    cp -a "${SRC}/${entry}" "${PROFILE}/"
done

if [[ "${WITH_INSTALLER}" != '1' ]]; then
    msg 'Building without the Calamares installer'
    sed -i '/^calamares$/d' "${PROFILE}/packages.x86_64"
    sed -i '/^\[oinix-local\]/,+2d' "${PROFILE}/pacman.conf"
    rm -rf "${PROFILE}/airootfs/etc/calamares" \
           "${PROFILE}/airootfs/usr/share/calamares" \
           "${PROFILE}/airootfs/usr/share/applications/oinix-install.desktop" \
           "${PROFILE}/airootfs/usr/local/bin/oinix-install"
elif [[ ! -e "${SRC}/localrepo/oinix-local.db.tar.gz" ]]; then
    echo "error: ${SRC}/localrepo/oinix-local.db.tar.gz is missing." >&2
    echo "       Run build/build-calamares.sh first, or set OINIX_WITH_INSTALLER=0." >&2
    exit 1
fi

# mkarchiso validates the profile itself before it touches anything, so a
# broken profile fails here within seconds rather than after the pacstrap.
msg 'Building the ISO'
mkarchiso -v -w "${WORK}" -o "${OUT}" "${PROFILE}"

msg 'Generating checksums'
cd "${OUT}"
for iso in *.iso; do
    [[ -e "${iso}" ]] || continue
    sha256sum "${iso}" > "${iso}.sha256"
    b2sum "${iso}" > "${iso}.b2"
done

msg 'Build artefacts'
ls -lh "${OUT}"
