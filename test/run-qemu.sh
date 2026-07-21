#!/usr/bin/env bash
# Boote la dernière ISO construite dans QEMU (UEFI/OVMF) pour vérification
# manuelle : démarrage live, session Plasma/SDDM, lancement de Calamares.
# `run_archiso` est fourni par le paquet archiso (donc à lancer depuis le
# conteneur build/docker/, ou toute machine Linux avec archiso installé).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT/tools/lib/strings.sh"

require_cmd run_archiso

OUT_DIR="$ROOT/build/out"
ISO="$(find "$OUT_DIR" -maxdepth 1 -name '*.iso' -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -n1)"

[[ -n "$ISO" ]] || die "Aucune ISO trouvée dans $OUT_DIR - lancez d'abord build/build.sh (ou build/docker/run-in-container.sh)."

log_info "Boot UEFI (OVMF) de $ISO..."
run_archiso -u -i "$ISO"
