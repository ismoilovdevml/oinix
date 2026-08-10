# Reproducible OINIX build environment.
#
# Always built/run for linux/amd64: mkarchiso pacstraps x86_64 packages, so the
# container has to be x86_64 even when the host is an Apple Silicon Mac.
FROM archlinux:base-devel

# pacman >= 7 sandboxes downloads with landlock+seccomp, which is unavailable
# under Docker Desktop's emulation layer.
RUN printf 'DisableSandbox\n' >> /etc/pacman.conf

RUN pacman -Syu --noconfirm --needed \
        archiso \
        git \
        sudo \
        base-devel \
        cmake \
        ninja \
        pacman-contrib \
        qemu-user-static-binfmt \
    && pacman -Scc --noconfirm

# makepkg refuses to run as root, so package builds happen as `builder`.
RUN useradd --create-home --shell /bin/bash builder \
    && printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder

WORKDIR /oinix
