# Environnement de build Linux pour macOS/Windows : archiso a besoin de root,
# de loop devices et de chroot, indisponibles nativement sur ces plateformes.
FROM archlinux:base-devel

# NOTE: calamares n'est plus dans core/extra (AUR-only, voir
# docs/ARCHITECTURE.md) - il est compilé et installé par
# build/00-build-local-repo.sh, pas ici. Les paquets ci-dessous sont requis
# pour que `find_package(Calamares)` fonctionne quand on construit nos
# modules custom (build/01-build-calamares-modules.sh) : Qt6/ECM, mais aussi
# qt6-tools (fournit Qt6LinguistToolsConfig.cmake, que CalamaresConfig.cmake
# exige even si on n'en a pas besoin nous-mêmes). Explicitement listé ici
# plutôt que de compter sur le fait qu'il soit installé comme dépendance de
# compilation *temporaire* de calamares lui-même : quand ce dernier est
# récupéré depuis le cache local-repo (déjà construit lors d'un run
# précédent, voir la persistance de /home/builder dans
# build/docker/run-in-container.sh), makepkg saute sa recompilation et donc
# n'installe plus ses propres makedepends. Les autres depends/makedepends AUR
# de calamares (kpmcore, boost, yaml-cpp, polkit-qt6...) restent résolus
# automatiquement par makepkg (via sudo pacman) au moment de sa compilation.
RUN pacman -Syu --noconfirm --needed \
        archiso \
        devtools \
        git \
        squashfs-tools \
        dosfstools \
        libisoburn \
        cmake \
        extra-cmake-modules \
        pkgconf \
        qt6-base \
        qt6-declarative \
        qt6-svg \
        qt6-tools \
        qemu-desktop \
        edk2-ovmf \
        sudo \
    && pacman -Scc --noconfirm

# Utilisateur non-root pour compiler les paquets AUR (makepkg refuse de
# tourner en root). Notre conteneur Docker est déjà lui-même un environnement
# jetable (docker run --rm) : pas besoin en plus d'un chroot devtools isolé
# (mkarchroot/makechrootpkg/arch-nspawn nécessitent un vrai systemd PID1, absent
# d'un conteneur Docker classique - voir docs/ARCHITECTURE.md). "builder" a un
# sudo sans mot de passe pour que `makepkg -s` puisse installer ses
# dépendances de compilation, et `makepkg -i` calamares directement sur le
# conteneur (nécessaire pour build/01-build-calamares-modules.sh).
RUN useradd -m -G wheel builder \
    && echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder \
    && chmod 0440 /etc/sudoers.d/builder

WORKDIR /workspace
