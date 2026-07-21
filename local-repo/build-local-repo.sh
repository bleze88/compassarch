#!/usr/bin/env bash
# Construit le dépôt pacman local "custom" contenant les paquets AUR-only
# nécessaires (yay, realmd, calamares) qui ne sont pas dans les dépôts
# officiels Arch. Note: calamares a quitté core/extra pour l'AUR (le
# développement amont a aussi migré vers Codeberg) - voir docs/ARCHITECTURE.md.
#
# Compile chaque paquet avec `makepkg` en tant qu'utilisateur non-root
# ("builder", créé par build/docker/Dockerfile, avec sudo sans mot de passe
# pour que makepkg puisse installer ses dépendances de compilation).
#
# NOTE 1: on n'utilise volontairement PAS les outils "chroot propre" habituels
# de devtools (mkarchroot/makechrootpkg/arch-nspawn) : ils s'appuient sur
# systemd-nspawn, qui a besoin d'un vrai systemd PID1 sur l'hôte - absent
# d'un conteneur Docker classique (voir docs/ARCHITECTURE.md pour le détail
# de cette impasse rencontrée avec Docker/colima sur macOS). Comme notre
# conteneur de build est déjà lui-même jetable (docker run --rm), l'isolation
# supplémentaire d'un chroot imbriqué n'apporte rien ici.
#
# NOTE 2: le clonage AUR + la compilation elle-même se font dans le home de
# "builder" (filesystem natif du conteneur), PAS dans local-repo/pkgbuilds/
# (qui est sur le bind-mount du dépôt hôte). Sur macOS/colima, ce bind-mount
# (9p) refuse tout chown et n'autorise l'écriture par un autre utilisateur
# que via un dossier déjà world-writable - largement insuffisant pour tout
# ce que makepkg écrit pendant un build (sources, objets compilés...). Seuls
# les paquets finis (.pkg.tar.zst) et la base du dépôt sont copiés vers
# local-repo/out/ (bind-mount) à la fin, en tant que root : root peut créer
# de nouveaux fichiers sur ce bind-mount sans problème, seul le changement
# de propriétaire de fichiers existants y est refusé.
#
# Prérequis: makepkg, sudo, un utilisateur "builder" (voir build/docker/Dockerfile).
# Doit être exécuté en root (ou via build/docker/run-in-container.sh) : ce
# script droppe les privilèges vers "builder" pour chaque build.
#
# Usage: local-repo/build-local-repo.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT/tools/lib/strings.sh"

require_root
require_cmd makepkg
require_cmd sudo
require_cmd repo-add
require_cmd git

id builder >/dev/null 2>&1 || die "Utilisateur 'builder' introuvable - ce script attend l'image construite par build/docker/Dockerfile."

OUT_DIR="$SCRIPT_DIR/out"
BUILD_HOME="$(getent passwd builder | cut -d: -f6)"
BUILDS_DIR="$BUILD_HOME/pkgbuilds"
# "local" est un nom RÉSERVÉ par pacman (sa base de données interne des
# paquets installés) - l'utiliser comme nom de dépôt fait échouer pacstrap
# avec "could not register 'local' database (database already registered)".
REPO_NAME="custom"

# Paquets AUR-only requis par le profil - vérifié exhaustivement contre
# core/extra (pacman -Si) le 2026-07-20 pour tous les paquets ajoutés à
# packages.x86_64 au-delà de la base releng ; sssd/samba/krb5/cifs-utils/
# chrony/networkmanager/flatpak/noto-fonts/etc. sont bien officiels et n'ont
# pas besoin d'être compilés ici. calamares est le plus long à compiler
# (C++/Qt6) - listé en premier pour échouer vite en cas de problème plutôt
# qu'après les autres. adcli doit être construit AVANT realmd (qui en dépend
# au runtime) pour que le "makepkg -s" de realmd le trouve déjà installé au
# lieu d'aller chercher un paquet "adcli" inexistant dans core/extra.
AUR_PACKAGES=(calamares yay adcli realmd ckbcomp)

mkdir -p "$OUT_DIR"
sudo -u builder mkdir -p "$BUILDS_DIR"

log_info "Récupération des PKGBUILD AUR (toujours à jour, pas vendorés dans le dépôt git)..."
for pkg in "${AUR_PACKAGES[@]}"; do
    pkg_dir="$BUILDS_DIR/$pkg"
    if [[ -d "$pkg_dir/.git" ]]; then
        sudo -u builder git -C "$pkg_dir" pull --ff-only
    else
        sudo -u builder rm -rf "$pkg_dir"
        sudo -u builder git clone "https://aur.archlinux.org/${pkg}.git" "$pkg_dir"
    fi
done

# Rafraîchit les bases de données pacman (root: builder n'a pas les droits
# d'écrire /var/lib/pacman lui-même ; son "makepkg -s" appellera "sudo pacman
# -S <dep>" en interne pour ses propres dépendances de compilation, ce qui
# ré-escalade correctement vers root via son NOPASSWD sudo).
pacman -Sy --noconfirm

for pkg in "${AUR_PACKAGES[@]}"; do
    pkg_dir="$BUILDS_DIR/$pkg"
    log_info "Compilation de $pkg (makepkg, utilisateur builder)..."
    # -s: installe les dépendances de compilation manquantes via sudo pacman
    # -i: installe aussi le paquet résultant sur CE système - inutile pour
    #     yay/realmd mais nécessaire pour calamares (voir
    #     build/00-build-local-repo.sh et build/01-build-calamares-modules.sh
    #     qui compilent nos modules custom contre lui via find_package(Calamares)).
    #     Sans danger de le faire uniformément: ce conteneur est jetable.
    sudo -u builder bash -c "cd '$pkg_dir' && makepkg -si --noconfirm --needed"
    # Copie vers le bind-mount (root peut créer de nouveaux fichiers ici,
    # voir NOTE 2 ci-dessus) - c'est le seul moment où ce build touche le
    # dépôt hôte pour ces paquets.
    find "$pkg_dir" -maxdepth 1 -name '*.pkg.tar.zst' -exec cp -f {} "$OUT_DIR/" \;
done

log_info "Génération de la base du dépôt pacman ($REPO_NAME)..."
rm -f "$OUT_DIR/${REPO_NAME}.db"* "$OUT_DIR/${REPO_NAME}.files"*
repo-add "$OUT_DIR/${REPO_NAME}.db.tar.zst" "$OUT_DIR"/*.pkg.tar.zst

log_ok "Dépôt local prêt dans $OUT_DIR (paquets: ${AUR_PACKAGES[*]})"
