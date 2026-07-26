#!/usr/bin/env bash
# Nettoie sur le système CIBLE (installé) les réglages qui n'ont de sens que
# pour la session live (autologin liveuser), appelé par Calamares
# (module "shellprocess", instance "removeliveartifacts" - voir
# settings.conf et etc/calamares/modules/shellprocess-removeliveartifacts.conf)
# après "users" (création du compte réel) et avant "displaymanager" (qui
# régénère la config SDDM pour la cible).
#
# Pourquoi ce script existe : comme pour usr/local/bin/fix-target-mkinitcpio.sh
# (voir docs/ARCHITECTURE.md), unpackfs copie le système live tel quel sur la
# cible, y compris etc/sddm.conf.d/20-liveuser-autologin.conf. Sans ce
# script, la cible garde l'autologin sur "liveuser" en plus du compte que
# l'utilisateur vient de créer - d'où les "deux sessions" observées après
# installation (liveuser se connecte automatiquement, l'utilisateur doit
# ensuite basculer manuellement sur son propre compte).
set -euo pipefail

rm -f /etc/sddm.conf.d/20-liveuser-autologin.conf

# Icône/entrée de menu "Installer Compass Arch" (Calamares) : n'a de sens
# que sur le live - Calamares dépend de choses propres à l'environnement
# live (unpackfs, /run/archiso/bootmnt...) et ne peut de toute façon pas
# fonctionner correctement lancé depuis le système déjà installé. Sans
# ça, unpackfs copie l'icône telle quelle sur la cible : présente sur le
# bureau du compte qui vient d'être créé (déjà copié depuis
# /etc/skel/Desktop à ce stade, "users" ayant tourné avant ce script -
# voir settings.conf) et resservie à chaque nouveau compte (y compris un
# futur compte AD via pam_mkhomedir) tant que le modèle /etc/skel n'est
# pas nettoyé aussi.
rm -f /usr/share/applications/install-distro.desktop
rm -f /etc/skel/Desktop/install-distro.desktop
rm -f /home/*/Desktop/install-distro.desktop
