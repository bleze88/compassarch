#!/usr/bin/env bash
# Corrige mkinitcpio pour le système CIBLE (installé), appelé par Calamares
# (module "shellprocess", instance "fixmkinitcpio" - voir settings.conf et
# etc/calamares/modules/shellprocess-fixmkinitcpio.conf) juste avant
# initcpiocfg/initcpio dans la séquence exec.
#
# Pourquoi ce script existe : archiso/profile/airootfs/etc/mkinitcpio.d/linux.preset
# et .../etc/mkinitcpio.conf.d/archiso.conf sont nécessaires pour que mkarchiso
# construise correctement l'initramfs DU MÉDIA LIVE lui-même (hooks
# archiso/archiso_pxe_*/memdisk, requis pour booter depuis l'ISO/USB). Mais
# comme l'installation se fait par copie directe du système live
# (unpackfs, voir docs/ARCHITECTURE.md), ce même linux.preset "live" se
# retrouve tel quel sur le système installé - où il est inadapté : il pointe
# vers .../mkinitcpio.conf.d/archiso.conf (hooks live uniquement) au lieu du
# /etc/mkinitcpio.conf normal, et il manque les hooks utiles à un système
# installé classique (autodetect, keymap, consolefont, fsck).
#
# Ce script remet linux.preset à son contenu standard (celui du paquet
# `linux`) et fixe les HOOKS de /etc/mkinitcpio.conf en y insérant "plymouth"
# au bon endroit (après base+udev, avant autodetect/kms - le module Calamares
# "initcpiocfg" ne sait faire que prepend/append en bout de liste, pas
# d'insertion positionnée, d'où ce script séparé). Le module "initcpio" qui
# suit dans la séquence se charge ensuite de lancer mkinitcpio -p linux avec
# cette configuration corrigée.
set -euo pipefail

cat > /etc/mkinitcpio.d/linux.preset <<'EOF'
# mkinitcpio preset file for the 'linux' package (contenu standard, restauré
# pour le système installé par fix-target-mkinitcpio.sh - voir ce script
# pour le pourquoi).

#ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default' 'fallback')

#default_config="/etc/mkinitcpio.conf"
default_image="/boot/initramfs-linux.img"
#default_options=""

#fallback_config="/etc/mkinitcpio.conf"
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
EOF

if [[ -f /etc/mkinitcpio.conf ]] && grep -q '^HOOKS=' /etc/mkinitcpio.conf; then
    sed -i -E 's/^HOOKS=\(.*\)/HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' \
        /etc/mkinitcpio.conf
fi

# Thème Plymouth par défaut (voir packages.x86_64) - avant la régénération
# de l'initramfs par le module Calamares "initcpio" qui suit dans la séquence,
# pour que le bon thème soit déjà embarqué. Non-bloquant délibérément (||
# true) : un thème manquant ne doit pas faire échouer toute l'installation,
# seule la partie mkinitcpio ci-dessus est critique pour le boot.
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme spinner || true
fi
