# Construire l'ISO

## Prérequis

`mkarchiso` a besoin de root, de loop devices et de `arch-chroot` : ça ne
fonctionne que sur Linux. Deux façons de construire :

### Option A - Depuis macOS/Windows (ou toute machine sans ces prérequis)

Via un conteneur Docker Linux privilégié :

```sh
./build/docker/run-in-container.sh
```

Ça construit l'image (`archlinux:base-devel` + `archiso`, `calamares`,
`qemu-desktop`, etc. - voir `build/docker/Dockerfile`) puis lance
`build/build.sh` dedans, avec le dépôt monté dans `/workspace`. L'ISO
finale apparaît dans `build/out/` **sur l'hôte** (bind-mount).

### Option B - Depuis une machine Arch Linux

```sh
# Note: calamares n'est plus dans core/extra (AUR-only, voir
# docs/ARCHITECTURE.md) - build/00-build-local-repo.sh le compile et
# l'installe automatiquement, pas besoin de l'ajouter ici.
sudo pacman -S --needed archiso devtools git squashfs-tools dosfstools \
    libisoburn cmake extra-cmake-modules pkgconf qt6-base qt6-declarative \
    qt6-svg
sudo ./build/build.sh
```

## Étapes du build (`build/build.sh`)

1. **`build/00-build-local-repo.sh`** - compile `yay` et `realmd` (AUR-only,
   voir `local-repo/`) dans un chroot propre, génère le dépôt pacman local,
   le copie dans `archiso/profile/airootfs/repo/local/`, et câble le chemin
   absolu de build dans `archiso/profile/pacman.conf`.
2. **`build/01-build-calamares-modules.sh`** - compile les modules Calamares
   custom (`archiso/calamares-modules/`) contre le paquet `calamares` déjà
   installé, et copie le résultat dans
   `archiso/profile/airootfs/usr/lib/calamares/modules/`.
3. **`build/02-mkarchiso.sh`** - lance `mkarchiso -v -w build/work/iso -o
   build/out archiso/profile`.

Chaque script est aussi utilisable indépendamment (utile pour ne relancer
que la partie modifiée pendant le développement).

## Tester l'ISO

```sh
./test/run-qemu.sh
```

Boote la dernière ISO de `build/out/` dans QEMU en UEFI (OVMF), via
`run_archiso` (fourni par le paquet `archiso`). Vérifier au minimum :

- Démarrage live jusqu'à SDDM, connexion automatique de `liveuser`
  (mot de passe vide, membre de `wheel` avec sudo sans mot de passe pendant
  la session live - voir `airootfs/root/customize_airootfs.sh`) sur une
  session Plasma Wayland.
- Raccourci bureau "Installer Compass Arch" lance bien Calamares
  (`pkexec calamares` - nécessite `polkit-kde-agent` dans packages.x86_64
  pour le prompt graphique ; le paquet `calamares` compilé via l'AUR ne
  fournit plus de wrapper `calamares_polkit`).
- Dérouler une installation complète en VM, avec et sans la case "Rejoindre
  un domaine Active Directory" cochée.
- Après installation : `yay -Ss <paquet>` fonctionne (dépôt AUR
  opérationnel) ; si un domaine a été rejoint, `realm list` et
  `getent passwd <user>@domaine` renvoient les infos attendues.

## Point de départ du profil archiso

`archiso/profile/` est dérivé du profil officiel `releng`
(https://gitlab.archlinux.org/archlinux/archiso, `configs/releng/`), avec
les ajouts documentés dans `docs/ARCHITECTURE.md`. Pour resynchroniser avec
une nouvelle version d'archiso upstream (ex: nouveaux hooks de boot), le
plus sûr est de re-cloner ce profil dans un dossier à part et de diff/rejouer
manuellement les modifications listées dans ce projet (packages.x86_64,
pacman.conf, profiledef.sh, l'overlay `airootfs/`) plutôt que d'écraser le
dossier - certains fichiers ici (customize_airootfs.sh, pacman.conf, PAM,
NSS, calamares/, sddm.conf.d/, NetworkManager/, systemd unit symlinks) sont
spécifiques à ce projet et n'existent pas dans releng.
