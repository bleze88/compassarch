#!/usr/bin/env bash
# Construit le dépôt pacman local (yay, realmd, calamares) puis le rend disponible :
#   1. dans archiso/profile/airootfs/repo/local/ (pour qu'il soit embarqué
#      dans l'image et utilisable au runtime via /repo/local, cf.
#      airootfs/etc/pacman.conf)
#   2. en substituant son chemin absolu dans archiso/profile/pacman.conf
#      (utilisé par mkarchiso/pacstrap au moment du build, cf. le commentaire
#      dans ce fichier)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT/tools/lib/strings.sh"

"$ROOT/local-repo/build-local-repo.sh"

log_info "Copie du dépôt local dans l'overlay airootfs..."
# Le chemin /repo/local (répertoire) reste nommé "local" sans problème - seul
# le NOM DE SECTION pacman.conf "[local]" est réservé (voir
# archiso/profile/pacman.conf) ; d'où les fichiers custom.db*/custom.files*
# (générés avec REPO_NAME="custom" par local-repo/build-local-repo.sh).
DEST="$ROOT/archiso/profile/airootfs/repo/local"
mkdir -p "$DEST"
rm -f "$DEST"/*.pkg.tar.zst "$DEST"/custom.db* "$DEST"/custom.files* "$DEST/.gitkeep"
cp "$ROOT"/local-repo/out/*.pkg.tar.zst "$ROOT"/local-repo/out/custom.db* "$ROOT"/local-repo/out/custom.files* "$DEST/"

log_info "Câblage du chemin absolu du dépôt local dans le pacman.conf de build..."
BUILD_PACMAN_CONF="$ROOT/archiso/profile/pacman.conf"
# Idempotent: remplace soit le token d'origine, soit un chemin déjà substitué
# par un run précédent (au cas où local-repo/out aurait changé d'emplacement).
sed -i.bak -E "s|Server = file://.*|Server = file://${ROOT}/local-repo/out|" "$BUILD_PACMAN_CONF"
rm -f "$BUILD_PACMAN_CONF.bak"

# calamares n'est plus dans core/extra (voir docs/ARCHITECTURE.md) : il doit
# être installé directement sur CE conteneur/machine de build (pas seulement
# publié dans le dépôt local de l'ISO), car build/01-build-calamares-modules.sh
# a besoin de ses fichiers CMake (find_package(Calamares)) pour compiler nos
# modules custom (adjoinview/adjoinjob) contre lui. Normalement déjà fait par
# `makepkg -si` dans local-repo/build-local-repo.sh - ce bloc est un filet de
# sécurité si local-repo/out/ provient d'un run précédent.
if ! pacman -Qi calamares >/dev/null 2>&1; then
    log_info "Installation de calamares sur la machine de build (requis pour compiler adjoinview/adjoinjob)..."
    pacman -Sy --noconfirm
    pacman -U --noconfirm "$ROOT"/local-repo/out/calamares-*.pkg.tar.zst
fi

log_ok "Dépôt local prêt pour le build ISO."
