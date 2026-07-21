#!/usr/bin/env bash
# Point d'entrée unique du build : dépôt pacman local -> modules Calamares
# custom -> ISO archiso. À exécuter en root sur Linux (voir build/docker/
# pour lancer tout ça depuis macOS/Windows via un conteneur).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$ROOT/tools/lib/strings.sh"

require_root

"$SCRIPT_DIR/00-build-local-repo.sh"
"$SCRIPT_DIR/01-build-calamares-modules.sh"
"$SCRIPT_DIR/02-mkarchiso.sh"

log_ok "Build terminé."
