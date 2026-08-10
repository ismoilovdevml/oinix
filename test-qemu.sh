#!/usr/bin/env bash
#
# Boot the freshly built OINIX ISO in QEMU.
#
# Usage:
#   ./test-qemu.sh                 UEFI boot, graphical window
#   ./test-qemu.sh --bios          legacy BIOS boot
#   ./test-qemu.sh --headless      no window; serial console on stdio
#   ./test-qemu.sh --iso path.iso  test a specific image
#
# On an Apple Silicon host QEMU has to emulate x86_64 in software, so expect
# the live session to take several minutes to reach the desktop.
#

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT

firmware='uefi'
display='gui'
iso=''
memory='4096'

while (( $# )); do
    case "$1" in
        --bios)     firmware='bios' ;;
        --uefi)     firmware='uefi' ;;
        --headless) display='headless' ;;
        --iso)      iso="$2"; shift ;;
        --memory)   memory="$2"; shift ;;
        -h|--help)  sed -n '3,12p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *)          printf 'unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v qemu-system-x86_64 >/dev/null 2>&1 \
    || die 'qemu-system-x86_64 not found. Install it with: brew install qemu'

if [[ -z "${iso}" ]]; then
    # shellcheck disable=SC2012  # ISO names are build-generated and shell-safe
    iso="$(ls -t "${ROOT}"/out/*.iso 2>/dev/null | head -1 || true)"
    [[ -n "${iso}" ]] || die "no ISO in ${ROOT}/out — run ./build.sh first."
fi
[[ -f "${iso}" ]] || die "no such file: ${iso}"

# shellcheck disable=SC2054  # QEMU arguments contain commas by design
qemu=(
    qemu-system-x86_64
    -machine q35
    -cpu qemu64
    -smp "$(sysctl -n hw.ncpu 2>/dev/null || nproc)"
    -m "${memory}"
    -device virtio-net-pci,netdev=net0
    -netdev user,id=net0
    -device qemu-xhci
    -device usb-tablet
    -drive "file=${iso},media=cdrom,readonly=on"
    -boot order=d
    -audiodev none,id=snd0
)

if [[ "${firmware}" == 'uefi' ]]; then
    ovmf=''
    for candidate in \
        /opt/homebrew/share/qemu/edk2-x86_64-code.fd \
        /usr/local/share/qemu/edk2-x86_64-code.fd \
        /usr/share/edk2/x64/OVMF_CODE.4m.fd \
        /usr/share/OVMF/OVMF_CODE.fd
    do
        [[ -f "${candidate}" ]] && { ovmf="${candidate}"; break; }
    done
    [[ -n "${ovmf}" ]] || die 'no OVMF firmware found; use --bios instead.'

    vars="${ROOT}/out/OVMF_VARS.test.fd"
    if [[ ! -f "${vars}" ]]; then
        for candidate in \
            /opt/homebrew/share/qemu/edk2-i386-vars.fd \
            /usr/local/share/qemu/edk2-i386-vars.fd \
            /usr/share/edk2/x64/OVMF_VARS.4m.fd
        do
            [[ -f "${candidate}" ]] && { cp "${candidate}" "${vars}"; break; }
        done
    fi
    qemu+=(-drive "if=pflash,format=raw,unit=0,readonly=on,file=${ovmf}")
    [[ -f "${vars}" ]] && qemu+=(-drive "if=pflash,format=raw,unit=1,file=${vars}")
fi

if [[ "${display}" == 'headless' ]]; then
    qemu+=(-display none -serial mon:stdio)
else
    # shellcheck disable=SC2054
    qemu+=(-display default,show-cursor=on -vga virtio -serial file:"${ROOT}/out/serial.log")
fi

printf '==> Booting %s (%s, %s)\n' "$(basename "${iso}")" "${firmware}" "${display}"
exec "${qemu[@]}"
