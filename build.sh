#!/usr/bin/env bash
#
# OINIX Linux build driver.
#
# mkarchiso needs an x86_64 Linux host with mount/loop privileges, so the real
# work happens inside a privileged linux/amd64 container. This script only sets
# that container up and hands over to build/build-iso.sh.
#
# Usage:
#   ./build.sh                 build the ISO (installer included)
#   ./build.sh --no-installer  build the ISO without Calamares
#   ./build.sh --installer     (re)build the Calamares package only
#   ./build.sh --shell         open a shell in the build container
#   ./build.sh --clean         remove work/, out/ and localrepo/
#
# Options:
#   --fast    use zstd instead of xz for squashfs (much quicker, bigger ISO)
#

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT
readonly IMAGE='oinix-builder:latest'
readonly PLATFORM='linux/amd64'

msg()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null 2>&1 || die 'docker is required but was not found.'
docker info >/dev/null 2>&1 || die 'the Docker daemon is not running.'

action='iso'
comp='xz'
with_installer='1'

while (( $# )); do
    case "$1" in
        --no-installer) with_installer='0' ;;
        --installer)    action='calamares' ;;
        --shell)        action='shell' ;;
        --clean)        action='clean' ;;
        --fast)         comp='zstd' ;;
        -h|--help)      sed -n '3,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *)              die "unknown option: $1" ;;
    esac
    shift
done

if [[ "${action}" == 'clean' ]]; then
    msg 'Removing build artefacts'
    rm -rf "${ROOT}/work" "${ROOT}/out" "${ROOT}/localrepo"
    exit 0
fi

msg "Building the ${IMAGE} image (${PLATFORM})"
docker build --platform "${PLATFORM}" -t "${IMAGE}" "${ROOT}/build"

mkdir -p "${ROOT}/out" "${ROOT}/localrepo"

# --privileged: pacstrap bind-mounts /dev, /proc and /sys into the chroot.
# seccomp=unconfined: pacman's landlock/seccomp sandbox is unavailable under
# Docker Desktop's x86_64 emulation.
docker_run=(
    docker run --rm --platform "${PLATFORM}"
    --privileged --security-opt seccomp=unconfined
    -v "${ROOT}:/oinix"
    # Persist the package cache so repeat builds do not re-download ~3 GB.
    -v 'oinix-pacman-cache:/var/cache/pacman/pkg'
    -e "OINIX_SQUASHFS_COMP=${comp}"
    -e "OINIX_WITH_INSTALLER=${with_installer}"
    -e "SOURCE_DATE_EPOCH=$(date +%s)"
)

case "${action}" in
    calamares)
        msg 'Building the Calamares package'
        "${docker_run[@]}" -u builder "${IMAGE}" \
            bash /oinix/build/build-calamares.sh /oinix/localrepo
        ;;
    shell)
        "${docker_run[@]}" -it "${IMAGE}" bash
        ;;
    iso)
        if [[ "${with_installer}" == '1' && ! -e "${ROOT}/localrepo/oinix-local.db.tar.gz" ]]; then
            msg 'Calamares package not found; building it first'
            "${docker_run[@]}" -u builder "${IMAGE}" \
                bash /oinix/build/build-calamares.sh /oinix/localrepo
        fi
        msg "Building the ISO (squashfs compression: ${comp})"
        "${docker_run[@]}" "${IMAGE}" bash /oinix/build/build-iso.sh
        msg 'Done'
        ls -lh "${ROOT}/out"
        ;;
esac
