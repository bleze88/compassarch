# Helpers partagés par les scripts shell du projet.
# À sourcer avec: source "$(dirname "${BASH_SOURCE[0]}")/lib/strings.sh"

log_info()  { printf '\033[1;34m[info]\033[0m %s\n' "$*" >&2; }
log_warn()  { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
log_error() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }
log_ok()    { printf '\033[1;32m[ok]\033[0m %s\n' "$*" >&2; }

die() {
    log_error "$*"
    exit 1
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        die "Ce script doit être exécuté en root (utilisez sudo ou le conteneur build/docker/)."
    fi
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || die "Commande requise introuvable: $cmd"
}

repo_root() {
    # Racine du dépôt = deux niveaux au-dessus de tools/lib/
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}
