#
# OINIX Linux
#
# The ISO is built by mkarchiso inside a linux/amd64 container; see build.sh.
#

.PHONY: help iso fast no-installer installer shell clean test test-bios check

help:
	@printf 'OINIX Linux build targets:\n\n'
	@printf '  make iso            build the ISO (xz squashfs, installer included)\n'
	@printf '  make fast           build the ISO with zstd squashfs (quicker, larger)\n'
	@printf '  make no-installer   build the ISO without Calamares\n'
	@printf '  make installer      build the Calamares package only\n'
	@printf '  make shell          open a shell in the build container\n'
	@printf '  make test           boot the latest ISO in QEMU (UEFI)\n'
	@printf '  make test-bios      boot the latest ISO in QEMU (legacy BIOS)\n'
	@printf '  make check          shellcheck the build scripts\n'
	@printf '  make clean          remove work/, out/ and localrepo/\n'

iso:
	./build.sh

fast:
	./build.sh --fast

no-installer:
	./build.sh --no-installer --fast

installer:
	./build.sh --installer

shell:
	./build.sh --shell

test:
	./test-qemu.sh

test-bios:
	./test-qemu.sh --bios

check:
	shellcheck -s bash build.sh test-qemu.sh build/*.sh airootfs/root/customize_airootfs.sh

clean:
	./build.sh --clean
