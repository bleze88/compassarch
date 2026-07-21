# Architecture

## Vue d'ensemble

```
                     ┌─────────────────────────┐
                     │      local-repo/          │  compile yay + realmd
                     │  build-local-repo.sh       │  (AUR-only, absents de
                     └────────────┬────────────┘   core/extra)
                                  │ copié dans
                                  ▼
        archiso/profile/airootfs/repo/local/  (dépôt pacman embarqué)
                                  │
┌─────────────────────────┐      │      ┌──────────────────────────────┐
│ archiso/calamares-modules │     │      │  archiso/profile/              │
│  adjoinview (C++/QML)     │     │      │  packages.x86_64, pacman.conf, │
│  adjoinjob  (Python)      │     │      │  airootfs/ (overlay)           │
└────────────┬─────────────┘     │      └───────────────┬──────────────┘
             │ compilés, copiés  │                      │
             ▼ dans airootfs/    ▼                      ▼
        archiso/profile/airootfs/usr/lib/calamares/modules/
                                  │
                                  ▼
                        build/02-mkarchiso.sh (mkarchiso)
                                  │
                                  ▼
                         build/out/*.iso  (ISO live + installeur)
```

## Pourquoi `unpackfs` plutôt qu'une réinstallation pacman

Calamares peut soit réinstaller les paquets sur la cible avec pacman
(module `packages`), soit copier directement le système live déjà présent
sur l'ISO (module `unpackfs`, voir
`archiso/profile/airootfs/etc/calamares/modules/unpackfs.conf`). Ce projet
utilise **unpackfs** :

- L'ISO live contient déjà Plasma, Calamares, yay, sssd/adcli/samba/realmd
  (voir `archiso/profile/packages.x86_64`).
- `unpackfs` copie ce système tel quel sur la cible : **aucun accès réseau
  n'est nécessaire pendant l'installation**.
- Le dépôt pacman local (`/repo/local`, pour yay/realmd/calamares) est lui
  aussi copié avec le reste du système, donc reste utilisable après coup si
  besoin (ex: réinstaller yay).

## Pourquoi un dépôt pacman local

`realmd`, `adcli`, `ckbcomp` (et l'ancien compagnon `oddjob-mkhomedir`,
finalement pas requis - voir plus bas), `yay`, et **`calamares` lui-même**
(qui a quitté `core`/`extra` pour l'AUR - le développement amont a aussi
migré vers Codeberg, voir https://codeberg.org/Calamares/calamares) ne sont
**pas** dans les dépôts officiels Arch, seulement sur l'AUR - vérifié
exhaustivement (`pacman -Si`) pour tous les paquets ajoutés à
`packages.x86_64` au-delà de la base `releng`, le 2026-07-20. Comme
l'installation cible ne doit pas dépendre d'un accès réseau (voir
ci-dessus), ces paquets sont compilés une fois **au moment du build de
l'ISO** (`local-repo/`) et servis via un mini-dépôt pacman (`repo-add`)
référencé dans `pacman.conf` (`[custom]`, `SigLevel = Optional TrustAll` -
le nom `local` est réservé par pacman lui-même, voir l'encart plus loin).
Ainsi `packages.x86_64` peut lister `yay`, `adcli`, `realmd`, `ckbcomp` et
`calamares` comme n'importe quel autre paquet. Seuls
`sssd`/`samba`/`krb5`/`cifs-utils`/`chrony` restent des
paquets officiels classiques dans le pack Active Directory.

> **Piège évité** : le dépôt custom s'appelle `[custom]`, pas `[local]`.
> `local` est le nom interne de la base de données pacman des paquets
> installés ; l'utiliser comme nom de section donne `error: could not
> register 'local' database (database already registered)` au moment de
> `pacstrap`. Le répertoire sur disque (`/repo/local` dans l'image) peut
> en revanche s'appeler "local" sans problème - seul le nom de *section*
> pacman.conf est réservé.

`local-repo/build-local-repo.sh` compile `adcli` **avant** `realmd` (qui en
dépend au runtime) : `makepkg -si` installe chaque paquet sur le conteneur
de build au fur et à mesure, donc quand vient le tour de `realmd`, `adcli`
est déjà présent au lieu de déclencher une recherche dans core/extra (où il
n'existe plus) et de faire échouer la résolution de dépendances.

**Compilation : `makepkg` direct, pas de chroot devtools imbriqué.** La
pratique habituelle pour compiler des paquets AUR proprement est d'utiliser
les outils "chroot propre" de `devtools` (`mkarchroot`/`makechrootpkg`), qui
s'appuient sur `systemd-nspawn`. Ça s'est avéré incompatible avec un
conteneur Docker classique : `systemd-nspawn` a besoin d'un vrai systemd
PID1 sur l'hôte pour gérer l'enregistrement de machine et la propagation de
points de montage (`/run/systemd/nspawn/propagate/...`), qu'un conteneur
Docker (qui lance juste la commande demandée, pas un init complet) ne
fournit pas - même avec `--privileged`. `local-repo/build-local-repo.sh`
compile donc directement avec `makepkg -si` en tant qu'utilisateur non-root
`builder` (créé par `build/docker/Dockerfile`, sudo sans mot de passe pour
que `makepkg -s` installe ses dépendances de compilation). C'est un
compromis délibéré : pas d'isolation "chroot propre" supplémentaire, mais
notre conteneur de build est déjà lui-même jetable (`docker run --rm`), donc
cette isolation n'apportait rien ici.

`calamares` étant un projet C++/Qt6 conséquent, c'est de loin le plus long
à compiler des trois (raison pour laquelle il est listé en premier dans
`AUR_PACKAGES` de `local-repo/build-local-repo.sh`, pour échouer vite en
cas de problème). Comme `build/01-build-calamares-modules.sh` doit
compiler nos modules custom (`archiso/calamares-modules/`) contre
Calamares via `find_package(Calamares CONFIG)`, `makepkg -si` installe
aussi le paquet `calamares` fraîchement compilé **directement sur la
machine/conteneur de build** (le `-i`), en plus de produire l'archive
publiée dans le dépôt local de l'ISO.

Deux `pacman.conf` distincts existent car ils ne s'exécutent pas au même
endroit :
- `archiso/profile/pacman.conf` : utilisé par `mkarchiso`/`pacstrap` **sur
  la machine de build**, donc `Server = file://` doit être un chemin absolu
  valide sur cette machine (substitué par `build/00-build-local-repo.sh`).
- `archiso/profile/airootfs/etc/pacman.conf` : c'est le fichier qui finit
  réellement sur le système live/installé, donc `Server = file:///repo/local`
  y est un chemin **relatif à ce système lui-même** (valide aussi bien en
  live qu'après `unpackfs`).

## Pourquoi pas `oddjob-mkhomedir`

La création automatique du dossier personnel au premier login d'un
utilisateur du domaine AD est habituellement faite via `oddjobd` +
`pam_oddjob_mkhomedir.so` (c'est la recommandation Fedora/RHEL). Mais
`oddjob`/`oddjob-mkhomedir` sont eux aussi AUR-only sur Arch, alors que le
module PAM standard **`pam_mkhomedir.so`** (fourni directement par le
paquet `pam`, déjà présent dans `base`) fait exactement le même travail et
est justement ce que documente l'ArchWiki pour l'intégration LDAP/AD (voir
`airootfs/etc/pam.d/system-auth`). Ça évite de compiler un paquet AUR de
plus pour un gain nul.

## Modules Calamares custom

Voir [AD-JOIN-MODULE.md](AD-JOIN-MODULE.md).
