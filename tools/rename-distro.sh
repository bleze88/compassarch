#!/usr/bin/env bash
# Propage les valeurs de distro.conf dans tout le dépôt en remplaçant les
# tokens littéraux __DISTRO_*__ par leur valeur réelle.
#
# Usage:
#   tools/rename-distro.sh --check   # affiche les remplacements prévus, ne modifie rien
#   tools/rename-distro.sh           # applique les remplacements
#
# Idempotent: peut être relancé sans risque (les tokens déjà remplacés ne
# matchent plus, donc un second run est un no-op).
#
# Compatible bash 3.2 (bash par défaut sur macOS, sans tableaux associatifs
# ni mapfile) aussi bien que bash récent (Linux) : évite volontairement
# `declare -A` et `mapfile`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/strings.sh"

ROOT="$(repo_root)"
CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

source "$ROOT/distro.conf"

# Table token -> valeur, en deux tableaux indexés parallèles (portable bash 3.2).
TOKEN_NAMES=(__DISTRO_NAME__ __DISTRO_ID__ __DISTRO_ISO_LABEL__ __DISTRO_PUBLISHER__ __DISTRO_TAGLINE__ __DISTRO_VERSION__)
TOKEN_VALUES=("$DISTRO_NAME" "$DISTRO_ID" "$DISTRO_ISO_LABEL" "$DISTRO_PUBLISHER" "$DISTRO_TAGLINE" "$DISTRO_VERSION")

# Répertoires à exclure du parcours (artefacts de build, VCS, sorties générées).
EXCLUDE_DIRS=(.git build/work build/out local-repo/out)

find_args=(-type f -not -path "$ROOT/tools/rename-distro.sh")
for d in "${EXCLUDE_DIRS[@]}"; do
    find_args+=(-not -path "$ROOT/$d/*")
done

replacements_planned=0
i=0
while [[ $i -lt ${#TOKEN_NAMES[@]} ]]; do
    token="${TOKEN_NAMES[$i]}"
    value="${TOKEN_VALUES[$i]}"
    i=$((i + 1))

    while IFS= read -r -d '' f; do
        # Ignore les fichiers binaires
        grep -Iq . "$f" 2>/dev/null || continue
        if grep -qF "$token" "$f" 2>/dev/null; then
            replacements_planned=$((replacements_planned + 1))
            if [[ "$CHECK_ONLY" -eq 1 ]]; then
                log_info "${f#"$ROOT"/}: $token -> $value"
            else
                # Utilise | comme séparateur sed pour tolérer les '/' dans la valeur (ex: URL publisher)
                sed -i.bak "s|$token|$value|g" "$f" && rm -f "$f.bak"
            fi
        fi
    done < <(find "$ROOT" "${find_args[@]}" -print0)
done

# Renomme le dossier de branding Calamares placeholder -> DISTRO_ID
BRANDING_PLACEHOLDER="$ROOT/archiso/profile/airootfs/etc/calamares/branding/placeholder-distro"
if [[ -d "$BRANDING_PLACEHOLDER" && "$DISTRO_ID" != "placeholder-distro" ]]; then
    target="$ROOT/archiso/profile/airootfs/etc/calamares/branding/$DISTRO_ID"
    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        log_info "mv $BRANDING_PLACEHOLDER -> $target"
    else
        mv "$BRANDING_PLACEHOLDER" "$target"
        log_ok "Dossier de branding renommé: $DISTRO_ID"
    fi
fi

if [[ "$CHECK_ONLY" -eq 1 ]]; then
    log_info "$replacements_planned remplacement(s) prévu(s). Relancez sans --check pour appliquer."
else
    log_ok "$replacements_planned remplacement(s) appliqué(s)."
fi
