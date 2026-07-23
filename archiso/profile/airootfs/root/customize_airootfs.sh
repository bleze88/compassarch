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

# Thème Plymouth par défaut pour le média live lui-même (le système
# installé le refixe indépendamment dans usr/local/bin/fix-target-mkinitcpio.sh,
# voir docs/ARCHITECTURE.md - les deux initramfs sont générés séparément).
plymouth-set-default-theme compass-arch || true

# Fond d'écran par défaut de Plasma (usr/share/wallpapers/CompassArch/, voir
# docs/ARCHITECTURE.md "Fond d'écran par défaut"). Les fichiers "defaults"
# des paquets look-and-feel (org.kde.breeze.desktop, org.kde.breezedark.desktop
# - fournis par plasma-workspace) référencent le fond d'écran par son nom de
# paquet ("Image=Next" par défaut) : édité ici, après pacstrap, plutôt qu'en
# overlay statique, car ce sont des fichiers appartenant à un paquet pacman
# (même piège que pour /etc/skel/.bashrc plus haut).
for lnf in org.kde.breeze.desktop org.kde.breezedark.desktop org.kde.breezetwilight.desktop; do
    defaults="/usr/share/plasma/look-and-feel/$lnf/contents/defaults"
    [[ -f "$defaults" ]] && sed -i 's/^Image=Next$/Image=CompassArch/' "$defaults"
done
