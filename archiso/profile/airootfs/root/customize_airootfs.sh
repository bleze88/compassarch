#!/usr/bin/env bash
# Exécuté par mkarchiso via arch-chroot juste après pacstrap (voir
# _make_customize_airootfs dans archiso/mkarchiso), puis supprimé du profil
# final. Tâches nécessitant un vrai chroot (création d'utilisateur, sudoers,
# activation de service via systemctl) qui ne peuvent pas être de simples
# fichiers d'overlay.

set -e -u

# Utilisateur live avec autologin (voir sddm.conf.d/10-wayland-default.conf),
# membre de wheel pour sudo sans mot de passe pendant la session live
# (facilite le lancement de Calamares et la configuration réseau/partitions).
useradd -m -G wheel,storage,power,network -s /usr/bin/zsh liveuser
passwd -d liveuser >/dev/null

echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-liveuser
chmod 0440 /etc/sudoers.d/99-liveuser
