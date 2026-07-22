#!/usr/bin/env bash
# Copie le noyau (et le microcode CPU) du média live vers la cible, après
# unpackfs et avant fix-target-mkinitcpio.sh/initcpio (voir settings.conf,
# instance shellprocess "copykernel").
#
# Pourquoi : mkarchiso copie le noyau/initramfs construits dans le squashfs
# vers le média ISO lui-même (arch/boot/x86_64/), PUIS VIDE /boot dans le
# squashfs pour ne pas les dupliquer sur l'image (voir _cleanup_pacstrap_dir
# dans archiso/mkarchiso). Comme on installe par copie directe du squashfs
# (unpackfs), le /boot de la cible est donc vide - "mkinitcpio" échoue avec
# "'/boot/vmlinuz-linux' must be readable" tant qu'on n'a pas remis le noyau
# en place depuis le média live (encore monté, lui, sous
# /run/archiso/bootmnt/ - voir aussi unpackfs.conf qui utilise ce même
# chemin pour le squashfs). L'initramfs lui-même n'a pas besoin d'être
# copié : fix-target-mkinitcpio.sh + le module Calamares "initcpio" le
# régénèrent de toute façon.
#
# Appelé avec dontChroot: true (tourne donc sur le système LIVE, pas dans le
# chroot cible) car /run/archiso/bootmnt n'est pas visible depuis l'intérieur
# du chroot cible. $1 est le point de montage de la cible (${ROOT}, résolu
# par Calamares).
set -euo pipefail

TARGET="${1:?usage: copy-kernel-to-target.sh <target-root-mount-point>}"
BOOT_SRC="/run/archiso/bootmnt/arch/boot/x86_64"
UCODE_SRC="/run/archiso/bootmnt/arch/boot"

mkdir -p "$TARGET/boot"

cp -f "$BOOT_SRC/vmlinuz-linux" "$TARGET/boot/vmlinuz-linux"

# Microcode CPU (Intel/AMD) - facultatif, ne doit pas faire échouer
# l'installation si absent.
for ucode in "$UCODE_SRC"/*-ucode.img; do
    [[ -e "$ucode" ]] || continue
    cp -f "$ucode" "$TARGET/boot/$(basename "$ucode")"
done
