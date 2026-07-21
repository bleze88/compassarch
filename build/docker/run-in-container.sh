#!/usr/bin/env bash
# Construit l'image Docker (si besoin) puis lance build/build.sh dedans.
# C'est le point d'entrée à utiliser depuis macOS/Windows - archiso/mkarchiso
# exige root + loop devices + chroot, qu'un conteneur Linux privilégié fournit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$ROOT/tools/lib/strings.sh"

require_cmd docker

IMAGE_TAG="distro-iso-builder"

log_info "Construction de l'image Docker de build ($IMAGE_TAG)..."
docker build -t "$IMAGE_TAG" "$SCRIPT_DIR"

log_info "Lancement du build dans le conteneur (privileged: requis pour loop devices/chroot)..."
# Pas de -it : ce script tourne aussi bien en tâche de fond/CI que dans un
# terminal interactif, et -t échoue sèchement si stdin n'est pas un vrai tty.
#
# build/work/ est un volume Docker nommé (pas un bind-mount du dépôt) :
# c'est là que pacstrap/mkarchiso créent des chroots avec de vrais nœuds de
# périphériques et des verrous flock() - le bind-mount 9p de macOS/colima ne
# supporte pas correctement flock() (pacman échoue avec "unable to lock
# database"). Un volume Docker vit sur le vrai filesystem Linux de la VM,
# donc ces opérations fonctionnent normalement. Seule build/out/ (le
# résultat final) doit être visible sur l'hôte.
docker volume create "${IMAGE_TAG}-work" >/dev/null

# Cache le clonage AUR + les sources/objets compilés de "builder" entre deux
# runs (voir local-repo/build-local-repo.sh) - sans ça, chaque `docker run
# --rm` repart d'un home vide et recompile calamares (long, C++/Qt6) depuis
# zéro à chaque tentative, y compris quand l'échec vient d'une étape
# ultérieure du pipeline.
docker volume create "${IMAGE_TAG}-builder-home" >/dev/null

docker run --rm \
    --privileged \
    -v "$ROOT":/workspace \
    -v "${IMAGE_TAG}-work":/workspace/build/work \
    -v "${IMAGE_TAG}-builder-home":/home/builder \
    -w /workspace \
    "$IMAGE_TAG" \
    ./build/build.sh

log_ok "Terminé. L'ISO se trouve dans build/out/ (sur l'hôte, hors du conteneur)."
