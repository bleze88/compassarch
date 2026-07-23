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
# `linux`), fixe les HOOKS de /etc/mkinitcpio.conf en y insérant "plymouth"
# au bon endroit (après base+udev, avant autodetect/kms - le module Calamares
# "initcpiocfg" ne sait faire que prepend/append en bout de liste, pas
# d'insertion positionnée, d'où ce script séparé), et force l'inclusion de
# modules de contrôleurs de stockage virtualisés courants dans MODULES (voir
# plus bas - "autodetect" seul s'est avéré insuffisant sur certaines config
# VMware, causant un timeout au boot). Le module "initcpio" qui suit dans la
# séquence se charge ensuite de lancer mkinitcpio -p linux avec cette
# configuration corrigée.
#
# PIÈGE CRITIQUE (débogué en lisant /init et /init_functions dans le shell de
# secours d'une VM cible) : mkinitcpio charge /etc/mkinitcpio.conf PUIS les
# fragments /etc/mkinitcpio.conf.d/*.conf par ordre alphabétique, et chaque
# HOOKS= rencontré ÉCRASE entièrement la valeur précédente (pas de fusion).
# Le fragment live archiso.conf définit son propre HOOKS=(... archiso
# archiso_loop_mnt archiso_pxe_* memdisk ...) - s'il reste présent sur la
# cible, il écrase silencieusement notre correction ci-dessous au moment où
# mkinitcpio régénère l'image. Le hook "archiso" ainsi réactivé attend un
# média de boot amovible (ISO/USB) qui n'existe jamais sur un système
# installé sur disque : boot bloqué indéfiniment sur "ERROR: '' device did
# not show up after N seconds..." (/hooks/archiso), un message qui n'a
# RIEN à voir avec root=/UUID (lesquels sont corrects) - d'où l'inefficacité
# de rootdelay= ou de vérifier l'UUID/fstab. Ce script doit donc supprimer
# ce fragment AVANT que le module Calamares "initcpio" ne lance mkinitcpio.
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

# Supprime le(s) fragment(s) mkinitcpio.conf.d hérités du live (archiso.conf
# notamment) - voir le commentaire en tête de fichier : leur propre HOOKS=
# écraserait sinon silencieusement notre correction ci-dessous au moment de
# la régénération de l'initramfs par le module Calamares "initcpio".
rm -f /etc/mkinitcpio.conf.d/archiso.conf

if [[ -f /etc/mkinitcpio.conf ]] && grep -q '^HOOKS=' /etc/mkinitcpio.conf; then
    sed -i -E 's/^HOOKS=\(.*\)/HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/' \
        /etc/mkinitcpio.conf
fi

# "autodetect" ne bundle que les modules pour le matériel vu au moment du
# build - suffisant en théorie puisque mkinitcpio tourne ici dans la VM
# cible elle-même, mais certains contrôleurs de stockage virtualisés
# (VMware notamment) se sont avérés trop lents à s'initialiser avant le
# timeout de 30s du hook "block", faisant échouer le boot avec "device did
# not show up". On ajoute donc ces modules explicitement en plus de
# l'autodétection, par robustesse (coût: initramfs un peu plus gros, sans
# risque de casser un boot qui fonctionnait déjà).
if [[ -f /etc/mkinitcpio.conf ]] && grep -q '^MODULES=' /etc/mkinitcpio.conf; then
    sed -i -E 's/^MODULES=\(.*\)/MODULES=(virtio_blk virtio_scsi virtio_pci vmw_pvscsi mptspi mptscsih mptbase mpt2sas mpt3sas ahci nvme sd_mod sr_mod)/' \
        /etc/mkinitcpio.conf
fi

# Thème Plymouth par défaut (voir
# usr/share/plymouth/themes/compass-arch/ - installé via packages.x86_64
# du point de vue paquets, mais le thème lui-même est un simple overlay
# airootfs) - avant la régénération de l'initramfs par le module Calamares
# "initcpio" qui suit dans la séquence, pour que le bon thème soit déjà
# embarqué. Non-bloquant délibérément (|| true) : un thème manquant ne doit
# pas faire échouer toute l'installation, seule la partie mkinitcpio
# ci-dessus est critique pour le boot.
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme compass-arch || true
fi
