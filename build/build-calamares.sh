#!/usr/bin/env bash
#
# Build the Calamares installer and publish it into the OINIX local repository
# that the ISO build consumes. Runs inside the container (see build/Dockerfile).
#
# The oinix-installer checkout pins Calamares 3.3.0-alpha3, which is a Qt5
# code base; Arch no longer ships a Qt5 kpmcore, so that revision cannot be
# compiled against current Arch. We therefore package upstream Calamares
# (Qt6) via its AUR PKGBUILD and layer the OINIX branding on top from
# airootfs/usr/share/calamares/branding/oinix/.
#

set -euo pipefail

readonly REPO_DIR="${1:-/oinix/localrepo}"
readonly REPO_NAME='oinix-local'
readonly WORK="/tmp/calamares-build"

msg() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
    echo 'build-calamares.sh must run as the unprivileged "builder" user.' >&2
    exit 1
fi

sudo install -d -m 0777 "${REPO_DIR}"
rm -rf "${WORK}"
mkdir -p "${WORK}"
cd "${WORK}"

msg 'Refreshing package databases'
sudo pacman -Syu --noconfirm --needed

# ckbcomp is an optional-but-recommended Calamares dependency (keyboard module).
for pkg in ckbcomp calamares; do
    msg "Building ${pkg} from the AUR"
    git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "${WORK}/${pkg}"
    pushd "${WORK}/${pkg}" >/dev/null
    makepkg --syncdeps --install --noconfirm --needed --clean
    # Skip the -debug split packages; they add ~60 MB and the live medium has
    # no use for detached debug symbols.
    for built in *.pkg.tar.*; do
        [[ "${built}" == *-debug-* ]] && continue
        sudo cp -- "${built}" "${REPO_DIR}/"
    done
    popd >/dev/null
done

msg "Publishing the ${REPO_NAME} repository"
cd "${REPO_DIR}"
sudo repo-add --new --remove "${REPO_NAME}.db.tar.gz" ./*.pkg.tar.*

msg 'Local repository contents'
ls -la "${REPO_DIR}"
