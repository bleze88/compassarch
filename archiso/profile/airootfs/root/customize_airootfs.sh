#!/usr/bin/env bash
# Exécuté par mkarchiso via arch-chroot juste après pacstrap (voir
# _make_customize_airootfs dans archiso/mkarchiso), puis supprimé du profil
# final. Tâches nécessitant un vrai chroot (création d'utilisateur, sudoers,
# activation de service via systemctl) qui ne peuvent pas être de simples
# fichiers d'overlay.

set -e -u

# Affiche un résumé système à l'ouverture de chaque terminal, pour tout
# nouvel utilisateur (liveuser ci-dessous, et les comptes créés par
# Calamares/AD ensuite). Fait ici (après pacstrap, avant la copie de skel
# par useradd -m) plutôt que via un fichier d'overlay statique : bash/zsh
# et grml-zsh-config fournissent déjà leurs propres /etc/skel/.bashrc et
# .zshrc, et un fichier d'overlay au même chemin ferait échouer pacstrap
# avec un conflit de fichier ("exists in filesystem").
for rc in /etc/skel/.bashrc /etc/skel/.zshrc; do
    touch "$rc"
    if ! grep -q 'fastfetch' "$rc"; then
        printf '\n# System summary on terminal open.\ncommand -v fastfetch >/dev/null 2>&1 && fastfetch\n' >> "$rc"
    fi
done

# Utilisateur live avec autologin (voir sddm.conf.d/10-wayland-default.conf),
# membre de wheel pour sudo sans mot de passe pendant la session live
# (facilite le lancement de Calamares et la configuration réseau/partitions).
useradd -m -G wheel,storage,power,network -s /usr/bin/zsh liveuser
passwd -d liveuser >/dev/null

echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/99-liveuser
chmod 0440 /etc/sudoers.d/99-liveuser
