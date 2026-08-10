<p align="center"><img src="assets/Vector.svg" width="180" alt="OINIX"></p>
<p align="center"><b>A minimal Arch-based Linux distribution by the <a href="https://xinux.uz">Xinux community</a>, Uzbekistan</b></p>
<p align="center">
  <img src="https://img.shields.io/badge/base-Arch%20Linux-1793d1" alt="Arch Linux">
  <img src="https://img.shields.io/badge/desktop-Xfce%204-6A7EFC" alt="Xfce">
  <img src="https://img.shields.io/badge/installer-Calamares-2a323c" alt="Calamares">
  <img src="https://img.shields.io/badge/boot-BIOS%20%2B%20UEFI-1b2027" alt="BIOS and UEFI">
</p>

---

An [archiso](https://gitlab.archlinux.org/archlinux/archiso) profile that builds
a hybrid BIOS/UEFI live ISO: Xfce desktop, autologin, and a branded Calamares
installer.

<p align="center"><img src="assets/screenshots/desktop.png" width="90%" alt="OINIX live desktop"></p>

| | |
|---|---|
| Base | Arch Linux, rolling |
| Desktop | Xfce 4, styled after macOS: top menu bar, global menu, Plank dock |
| Theme | WhiteSur (GTK, icons, cursors) · Inter · JetBrains Mono |
| Installer | Calamares 3.4, `oinix` branding |
| Boot | `bios.syslinux` + `uefi.systemd-boot` |
| Live user | `oinix` / `oinix` (autologin); `root` has no password |

### The desktop

A 28px panel across the top stands in for the macOS menu bar: the OINIX logo
opens a system menu (About, Settings, Sleep, Restart, Shut Down), and next to
it `vala-panel-appmenu` renders the focused application's own menubar. Window
controls sit on the left. Plank provides the dock. `Super` takes the place of
`Command`, so `Super+Space` opens the application finder as Spotlight does.

## Build

`mkarchiso` needs an x86_64 Linux host with mount privileges, so `build.sh`
runs it inside a privileged `linux/amd64` container. On the host you only need
**Docker** — including Docker Desktop on Apple Silicon.

```sh
./build.sh                  # release ISO (xz squashfs)
./build.sh --fast           # zstd squashfs: much quicker, larger image
./build.sh --no-installer   # skip Calamares while iterating
./build.sh --installer      # rebuild the Calamares package only
./build.sh --clean          # drop work/, out/ and localrepo/
```

The image and its `.sha256`/`.b2` checksums land in `out/`. The package cache
lives in a Docker volume, so repeat builds skip the ~1.5 GB download.

`make` on its own lists the equivalent targets.

## Test

```sh
./test-qemu.sh              # UEFI boot in a QEMU window
./test-qemu.sh --bios       # legacy BIOS

tests/boot-check.py --firmware uefi --disk 25G \
    --double-click 59,392@330 --at 300,375
```

`boot-check.py` boots headless and writes framebuffer grabs to
`out/boot-check/`. `--click`/`--double-click X,Y@T` drive the guest pointer, so
the installer can be launched and stepped through unattended — that is how the
screenshots below were produced.

<p align="center">
  <img src="assets/screenshots/installer-welcome.png" width="49%" alt="Calamares welcome page with OINIX branding">
  <img src="assets/screenshots/installer-partitions.png" width="49%" alt="Calamares partitioning page">
</p>

## Layout

| Path | Purpose |
|---|---|
| `profiledef.sh` | ISO name, label, boot modes, squashfs compression |
| `packages.x86_64` | every package in the live system |
| `pacman.conf` | build-time repositories, incl. the local Calamares repo |
| `airootfs/` | files overlaid onto the live root |
| `airootfs/root/customize_airootfs.sh` | in-chroot setup: locales, live user, services |
| `airootfs/etc/calamares/` | installer module configuration |
| `airootfs/usr/share/calamares/branding/oinix/` | installer branding |
| `syslinux/` · `efiboot/loader/` · `grub/` | BIOS · UEFI · loopback boot menus |
| `build/` | container image and in-container build scripts |
| `tests/boot-check.py` | unattended headless boot test |

## Notes

**Packages Arch does not ship are built, not vendored.** Calamares and the
WhiteSur themes come from the AUR: `build/build-aur.sh` builds everything in
`build/aur-packages.txt` into `localrepo/`, which `pacman.conf` exposes as
`[oinix-local]`. OINIX supplies only the branding and the configuration.

**No Apple assets are redistributed.** Apple licenses the SF font family for
designing software for Apple platforms, and its wallpapers are copyrighted, so
neither can ship inside an image that is handed to other people. The interface
font is [Inter](https://rsms.me/inter/), the closest open equivalent, and the
wallpapers in `airootfs/usr/share/backgrounds/oinix/` are generated for OINIX.

**The installer is removed on install.** `modules/packages.conf` drops
Calamares and the other live-only packages from the target system, and
`shellprocess-final.conf` clears the live medium's autologin, password-less
polkit rule and archiso scaffolding before the first boot.

## Credits

The desktop stands on other people's work:

- [WhiteSur GTK theme, icons and cursors](https://github.com/vinceliuice) — vinceliuice
- [vala-panel-appmenu](https://gitlab.com/vala-panel-project/vala-panel-appmenu) — the global menu
- [Plank](https://launchpad.net/plank) — the dock
- [Calamares](https://calamares.io/) — the installer
- [archiso](https://gitlab.archlinux.org/archlinux/archiso) — the image builder
- [Inter](https://rsms.me/inter/) — the interface font

The panel layout, the OINIX system menu and the Plank theme are adapted from
[ismoilovdevml/de-config](https://github.com/ismoilovdevml/de-config) (MIT).

## License

GPL-3.0 — see [LICENSE](LICENSE).

<p align="center">OINIX &copy; <a href="https://xinux.uz">Xinux Jamiyati</a></p>
