#!/usr/bin/env bash
# Compile les modules Calamares custom (archiso/calamares-modules/) contre le
# paquet `calamares` déjà installé sur la machine de build, puis installe le
# résultat (DESTDIR) directement dans l'overlay airootfs, comme s'il
# s'agissait d'un paquet pacman de plus.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT/tools/lib/strings.sh"

require_cmd cmake
require_cmd pkg-config

SRC_DIR="$ROOT/archiso/calamares-modules"
BUILD_DIR="$ROOT/build/work/calamares-modules"
STAGE_DIR="$ROOT/build/work/calamares-modules-stage"

rm -rf "$STAGE_DIR"
mkdir -p "$BUILD_DIR" "$STAGE_DIR"

log_info "Configuration CMake des modules Calamares custom..."
cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr

log_info "Compilation..."
cmake --build "$BUILD_DIR" --parallel "$(nproc)"

log_info "Installation dans un répertoire de staging (DESTDIR)..."
DESTDIR="$STAGE_DIR" cmake --install "$BUILD_DIR"

log_info "Copie du résultat dans l'overlay airootfs..."
AIROOTFS="$ROOT/archiso/profile/airootfs"
mkdir -p "$AIROOTFS/usr/lib/calamares/modules"
# --no-preserve=ownership: la destination est sur le bind-mount du dépôt
# (macOS/colima, 9p) qui refuse tout changement/préservation de propriétaire
# (root ne peut pas non plus s'auto-chown dessus) - voir docs/ARCHITECTURE.md.
cp -a --no-preserve=ownership "$STAGE_DIR/usr/lib/calamares/modules/." "$AIROOTFS/usr/lib/calamares/modules/"
if [[ -d "$STAGE_DIR/usr/share/calamares/modules" ]]; then
    mkdir -p "$AIROOTFS/usr/share/calamares/modules"
    cp -a --no-preserve=ownership "$STAGE_DIR/usr/share/calamares/modules/." "$AIROOTFS/usr/share/calamares/modules/"
fi

log_ok "Modules Calamares custom prêts pour le build ISO (adjoinview, adjoinjob)."
