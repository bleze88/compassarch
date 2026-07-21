#!/usr/bin/env bash
# Construit l'ISO avec mkarchiso (archiso). Doit être exécuté en root
# (loop devices, chroot), typiquement dans le conteneur build/docker/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT/tools/lib/strings.sh"

require_root
require_cmd mkarchiso

WORK_DIR="$ROOT/build/work/iso"
OUT_DIR="$ROOT/build/out"

# mkarchiso mémorise, par répertoire de travail, les étapes déjà exécutées
# (_run_once) et les saute au run suivant - y compris si le profil source a
# changé entre-temps (ex: renommage via tools/rename-distro.sh). Un work dir
# laissé en place peut donc faire produire une ISO silencieusement obsolète.
# On repart donc toujours de zéro ici ; le vrai gain de vitesse vient du
# cache de compilation AUR (voir build/docker/run-in-container.sh), pas de
# la réutilisation de ce répertoire.
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"

log_info "Lancement de mkarchiso..."
mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$ROOT/archiso/profile"

log_ok "ISO générée dans $OUT_DIR :"
ls -lh "$OUT_DIR"/*.iso
