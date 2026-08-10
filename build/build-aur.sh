#!/usr/bin/env bash
#
# Build every package listed in build/aur-packages.txt and publish them to the
# OINIX local repository that the ISO build consumes. Runs inside the container
# (see build/Dockerfile) as the unprivileged `builder` user.
#
# Packages are built in file order and installed as they are built, so an entry
# may depend on one listed above it.
#
# On Calamares: the oinix-installer checkout pins Calamares 3.3.0-alpha3, a Qt5
# code base. Arch no longer ships a Qt5 kpmcore, so that revision cannot be
# compiled against current Arch; we package upstream Calamares instead and
# supply the OINIX identity through branding and module configuration.
#

set -euo pipefail

readonly REPO_DIR="${1:-/oinix/localrepo}"
readonly LIST="${2:-/oinix/build/aur-packages.txt}"
readonly REPO_NAME='oinix-local'
readonly WORK='/tmp/aur-build'

msg()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
    echo 'build-aur.sh must run as the unprivileged "builder" user.' >&2
    exit 1
fi

mapfile -t packages < <(grep -vE '^\s*(#|$)' "${LIST}")
(( ${#packages[@]} )) || { echo "no packages listed in ${LIST}" >&2; exit 1; }

sudo install -d -m 0777 "${REPO_DIR}"
rm -rf "${WORK}"
mkdir -p "${WORK}"

msg 'Refreshing package databases'
sudo pacman -Syu --noconfirm --needed

for entry in "${packages[@]}"; do
    # "pkgbase KEY=VALUE ..." -- the overrides tune split-package PKGBUILDs.
    read -ra fields <<<"${entry}"
    pkg="${fields[0]}"
    overrides=("${fields[@]:1}")

    msg "Building ${pkg}${overrides[*]:+ (${overrides[*]})}"
    git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "${WORK}/${pkg}"
    pushd "${WORK}/${pkg}" >/dev/null
    env "${overrides[@]}" makepkg --syncdeps --install --noconfirm --needed --clean
    for built in *.pkg.tar.*; do
        # The -debug split packages carry detached symbols the live medium has
        # no use for, and they are large.
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
