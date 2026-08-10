#!/usr/bin/env python3
"""Headless boot smoke test for the OINIX ISO.

Boots the image in QEMU without a window and grabs the framebuffer at a series
of deadlines, so a build can be checked for "does it actually reach the
desktop" from a terminal or from CI.

    tests/boot-check.py --firmware bios
    tests/boot-check.py --firmware uefi --at 60,300,900

Screenshots land in out/boot-check/<firmware>/ as PNGs (PPM if ImageMagick and
sips are both unavailable).
"""

from __future__ import annotations

import argparse
import json
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

OVMF_CODE_CANDIDATES = (
    "/opt/homebrew/share/qemu/edk2-x86_64-code.fd",
    "/usr/local/share/qemu/edk2-x86_64-code.fd",
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd",
    "/usr/share/OVMF/OVMF_CODE.fd",
)
OVMF_VARS_CANDIDATES = (
    "/opt/homebrew/share/qemu/edk2-i386-vars.fd",
    "/usr/local/share/qemu/edk2-i386-vars.fd",
    "/usr/share/edk2/x64/OVMF_VARS.4m.fd",
)


def first_existing(paths: tuple[str, ...]) -> Path | None:
    for candidate in paths:
        path = Path(candidate)
        if path.is_file():
            return path
    return None


class Qmp:
    """Minimal QMP client — just enough to drive screendump."""

    def __init__(self, path: Path, timeout: float = 120.0) -> None:
        deadline = time.monotonic() + timeout
        while True:
            try:
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                self.sock.connect(str(path))
                break
            except OSError:
                if time.monotonic() > deadline:
                    raise
                time.sleep(0.2)
        self.sock.settimeout(60)
        self.buffer = b""
        self.read_message()  # greeting
        self.command("qmp_capabilities")

    def read_message(self) -> dict:
        while b"\n" not in self.buffer:
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ConnectionError("QMP socket closed")
            self.buffer += chunk
        line, self.buffer = self.buffer.split(b"\n", 1)
        return json.loads(line)

    def command(self, name: str, **arguments) -> dict:
        payload = {"execute": name}
        if arguments:
            payload["arguments"] = arguments
        self.sock.sendall(json.dumps(payload).encode() + b"\n")
        while True:
            message = self.read_message()
            if "return" in message or "error" in message:
                return message


ABS_MAX = 32767


def send_click(qmp: "Qmp", x: int, y: int, width: int, height: int,
               times: int = 1) -> None:
    """Move the absolute pointer to a pixel and click it."""
    move = [
        {"type": "abs", "data": {"axis": "x", "value": round(x / width * ABS_MAX)}},
        {"type": "abs", "data": {"axis": "y", "value": round(y / height * ABS_MAX)}},
    ]
    qmp.command("input-send-event", events=move)
    time.sleep(0.4)
    for _ in range(times):
        qmp.command("input-send-event",
                    events=[{"type": "btn", "data": {"down": True, "button": "left"}}])
        time.sleep(0.05)
        qmp.command("input-send-event",
                    events=[{"type": "btn", "data": {"down": False, "button": "left"}}])
        time.sleep(0.12)


def to_png(ppm: Path) -> Path:
    png = ppm.with_suffix(".png")
    if shutil.which("sips"):
        subprocess.run(
            ["sips", "-s", "format", "png", str(ppm), "--out", str(png)],
            check=True, capture_output=True,
        )
    elif shutil.which("magick"):
        subprocess.run(["magick", str(ppm), str(png)], check=True)
    else:
        return ppm
    ppm.unlink()
    return png


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--iso", help="image to boot (default: newest in out/)")
    parser.add_argument("--firmware", choices=("bios", "uefi"), default="bios")
    parser.add_argument("--at", default="45,120,300,600,900",
                        help="comma-separated seconds at which to grab the screen")
    parser.add_argument("--double-click", action="append", default=[], metavar="X,Y@T",
                        help="double-click the guest at pixel X,Y once T seconds "
                             "have passed (repeatable); needs the usb-tablet device")
    parser.add_argument("--click", action="append", default=[], metavar="X,Y@T",
                        help="single-click the guest at pixel X,Y at T seconds (repeatable)")
    parser.add_argument("--width", type=int, default=1280,
                        help="guest framebuffer width, used to map click coordinates")
    parser.add_argument("--height", type=int, default=800,
                        help="guest framebuffer height, used to map click coordinates")
    parser.add_argument("--memory", default="4096")
    parser.add_argument("--disk", metavar="SIZE",
                        help="attach a scratch disk of this size (e.g. 25G) so the "
                             "installer has somewhere to install to")
    args = parser.parse_args()

    clicks = []
    for kind, specs in (("dblclick", args.double_click), ("click", args.click)):
        for spec in specs:
            position, _, when = spec.partition("@")
            x_str, _, y_str = position.partition(",")
            clicks.append((int(when), kind, (int(x_str), int(y_str))))

    iso = Path(args.iso) if args.iso else None
    if iso is None:
        images = sorted((ROOT / "out").glob("*.iso"), key=lambda p: p.stat().st_mtime)
        if not images:
            print("error: no ISO in out/ — run ./build.sh first", file=sys.stderr)
            return 1
        iso = images[-1]
    if not iso.is_file():
        print(f"error: no such file: {iso}", file=sys.stderr)
        return 1

    shots_dir = ROOT / "out" / "boot-check" / args.firmware
    shots_dir.mkdir(parents=True, exist_ok=True)
    serial_log = shots_dir / "serial.log"
    qmp_path = shots_dir / "qmp.sock"
    qmp_path.unlink(missing_ok=True)

    command = [
        "qemu-system-x86_64",
        "-machine", "q35",
        "-cpu", "qemu64",
        "-smp", "4",
        "-m", args.memory,
        "-drive", f"file={iso},media=cdrom,readonly=on",
        "-boot", "order=d",
        "-netdev", "user,id=net0",
        "-device", "virtio-net-pci,netdev=net0",
        "-device", "qemu-xhci",
        "-device", "usb-tablet",
        "-vga", "std",
        "-display", "none",
        "-serial", f"file:{serial_log}",
        "-qmp", f"unix:{qmp_path},server,nowait",
    ]

    if args.disk:
        scratch = shots_dir / "scratch.qcow2"
        if not scratch.exists():
            subprocess.run(
                ["qemu-img", "create", "-f", "qcow2", str(scratch), args.disk],
                check=True, capture_output=True,
            )
        command += [
            "-drive", f"file={scratch},if=none,id=disk0,format=qcow2",
            "-device", "virtio-blk-pci,drive=disk0",
        ]

    if args.firmware == "uefi":
        code = first_existing(OVMF_CODE_CANDIDATES)
        if code is None:
            print("error: no OVMF firmware found; use --firmware bios", file=sys.stderr)
            return 1
        vars_src = first_existing(OVMF_VARS_CANDIDATES)
        vars_copy = shots_dir / "OVMF_VARS.fd"
        if vars_src and not vars_copy.exists():
            shutil.copy(vars_src, vars_copy)
        command += ["-drive", f"if=pflash,format=raw,unit=0,readonly=on,file={code}"]
        if vars_copy.exists():
            command += ["-drive", f"if=pflash,format=raw,unit=1,file={vars_copy}"]

    # Screenshots and clicks share one timeline, ordered by their deadline.
    events: list[tuple[int, str, tuple]] = [
        (int(value), "shot", ()) for value in args.at.split(",")
    ]
    events += clicks
    events.sort(key=lambda event: (event[0], event[1] == "shot"))

    print(f"==> Booting {iso.name} ({args.firmware}); "
          f"{len(events)} timed events over {events[-1][0]}s")

    qemu = subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        qmp = Qmp(qmp_path)
        start = time.monotonic()
        for deadline, kind, payload in events:
            remaining = deadline - (time.monotonic() - start)
            if remaining > 0:
                time.sleep(remaining)
            if qemu.poll() is not None:
                stderr = qemu.stderr.read().decode(errors="replace") if qemu.stderr else ""
                print(f"error: QEMU exited early ({qemu.returncode})\n{stderr}", file=sys.stderr)
                return 1

            if kind in ("click", "dblclick"):
                x, y = payload
                send_click(qmp, x, y, args.width, args.height,
                           times=2 if kind == "dblclick" else 1)
                print(f"    t={deadline:>4}s -> {kind} at ({x}, {y})")
                continue

            ppm = shots_dir / f"t{deadline:04d}.ppm"
            result = qmp.command("screendump", filename=str(ppm))
            if "error" in result:
                print(f"    screendump failed at {deadline}s: {result['error']}")
                continue
            # screendump is asynchronous; give QEMU a moment to flush the file.
            for _ in range(50):
                if ppm.exists() and ppm.stat().st_size:
                    break
                time.sleep(0.2)
            print(f"    t={deadline:>4}s -> {to_png(ppm).name}")
    finally:
        qemu.terminate()
        try:
            qemu.wait(timeout=20)
        except subprocess.TimeoutExpired:
            qemu.kill()
        qmp_path.unlink(missing_ok=True)

    print(f"==> Screenshots in {shots_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
