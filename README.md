# Compass Arch

Distribution Linux basée sur **Arch Linux**, avec :

- **KDE Plasma** comme environnement de bureau (Wayland par défaut via SDDM)
- **Calamares** comme installeur graphique pas-à-pas (accessible aux débutants)
- **yay** (helper AUR) préinstallé de base
- **sssd + adcli + samba + realmd** préinstallés, avec une étape dédiée dans
  l'installeur pour rejoindre un domaine **Active Directory** Windows

## Structure du dépôt

```
distro.conf                    Identité de la distro (nom, id, branding) - une seule source de vérité
tools/                          rename-distro.sh et helpers shell partagés
archiso/
  profile/                      Profil archiso (dérivé de releng), construit l'ISO live
  calamares-modules/            Modules Calamares custom (adjoinview, adjoinjob) - jonction AD
local-repo/                     Dépôt pacman local pour yay/realmd (absents des dépôts officiels)
build/                          Scripts de build (dépôt local -> modules Calamares -> mkarchiso)
test/                           Script de boot QEMU pour vérification manuelle
docs/                           Documentation détaillée
```

Voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) pour le détail de comment
ces pièces s'assemblent, et [docs/BUILD.md](docs/BUILD.md) pour construire
l'ISO.

## Démarrage rapide

```sh
# Depuis macOS/Windows (ou toute machine sans root/loop devices disponibles) :
./build/docker/run-in-container.sh

# Depuis une machine Linux avec archiso/devtools/calamares déjà installés :
sudo ./build/build.sh

# Tester l'ISO produite dans QEMU (UEFI) :
./test/run-qemu.sh
```

L'ISO finale se trouve dans `build/out/`.

## Renommer le projet

Toute l'identité de la distribution (nom affiché, id court, étiquette ISO,
branding Calamares...) est centralisée dans [distro.conf](distro.conf).
Pour appliquer un nouveau nom partout dans le dépôt :

```sh
$EDITOR distro.conf
tools/rename-distro.sh --check   # aperçu des remplacements
tools/rename-distro.sh           # applique
```

## Intégration Active Directory

Voir [docs/AD-JOIN-MODULE.md](docs/AD-JOIN-MODULE.md) pour le détail du
module Calamares custom qui permet de rejoindre un domaine AD pendant
l'installation (page optionnelle, "skip" par défaut).

## Licence

À définir par le mainteneur du projet (aucune licence n'est présumée ici).
