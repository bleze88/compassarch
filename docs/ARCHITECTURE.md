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

## Boot : mkinitcpio, Plymouth et GRUB (piège evité)

`archiso/profile/airootfs/etc/mkinitcpio.d/linux.preset` (hérité de
`releng`) est nécessaire pour que `mkarchiso` construise correctement
l'initramfs **du média live lui-même** (hooks `archiso`/`archiso_pxe_*`/
`memdisk`, indispensables pour booter depuis l'ISO/USB - voir aussi
`airootfs/etc/mkinitcpio.conf.d/archiso.conf`). Problème : comme
l'installation se fait par copie directe du système live (`unpackfs`,
voir plus haut), ce même fichier "live" se retrouve tel quel sur le
système installé, où il est inadapté (il pointe vers la config live au
lieu du `/etc/mkinitcpio.conf` normal, et il manque des hooks utiles à un
système installé classique).

Deuxième conséquence du même mécanisme : `mkarchiso` copie le noyau/
initramfs construits dans le squashfs **vers le média ISO lui-même**
(`arch/boot/x86_64/`), puis **vide `/boot` dans le squashfs** pour ne pas
les dupliquer sur l'image (`_cleanup_pacstrap_dir` dans `archiso/mkarchiso`).
Résultat : `unpackfs` copie un `/boot` **vide** sur la cible, et
`mkinitcpio` échoue avec `'/boot/vmlinuz-linux' must be readable`.

Fix (deux jobs Calamares `shellprocess`, dans `settings.conf`, juste après
`unpackfs`) :
1. `shellprocess@copykernel` → `usr/local/bin/copy-kernel-to-target.sh`
   (`dontChroot: true`, car `/run/archiso/bootmnt` - où se trouve le noyau
   sur le média live encore monté - n'est pas visible depuis l'intérieur
   du chroot cible) : recopie `vmlinuz-linux` et le microcode CPU depuis le
   média live vers `/boot` de la cible. L'ancien `initramfs-*.img` n'a pas
   besoin d'être copié, il est régénéré par mkinitcpio de toute façon.
2. `shellprocess@fixmkinitcpio` → `usr/local/bin/fix-target-mkinitcpio.sh`
   (`dontChroot: false`, dans le chroot cible cette fois), juste avant
   `initcpiocfg`/`initcpio`, qui :
   - restaure un `linux.preset` standard sur la cible ;
   - **supprime `/etc/mkinitcpio.conf.d/archiso.conf`** (voir piège
     ci-dessous - critique, sans quoi le boot de la cible reste bloqué) ;
   - réécrit `HOOKS` dans `/etc/mkinitcpio.conf` en y insérant `plymouth` à
     la bonne position (après `base udev`, avant `autodetect`/`kms`) - le
     module `initcpiocfg` ne sait faire que prepend/append en bout de
     liste, pas d'insertion positionnée, d'où ce script séparé plutôt que
     la config native du module ;
   - fixe le thème Plymouth par défaut (`spinner`), de façon non-bloquante.

**Piège le plus retors de tous - `/etc/mkinitcpio.conf.d/archiso.conf`** :
mkinitcpio charge `/etc/mkinitcpio.conf` PUIS les fragments
`/etc/mkinitcpio.conf.d/*.conf` par ordre alphabétique, et chaque `HOOKS=`
rencontré **écrase entièrement** la valeur précédente (aucune fusion). Le
fragment live `archiso.conf` (copié tel quel sur la cible par `unpackfs`,
comme tout le reste du système live) définit son propre
`HOOKS=(base udev microcode modconf kms memdisk archiso archiso_loop_mnt
archiso_pxe_* block filesystems keyboard)` - s'il reste présent, il écrase
silencieusement la correction du `HOOKS` ci-dessus au moment où mkinitcpio
régénère réellement l'image, **même si `/etc/mkinitcpio.conf` lui-même est
correct**. Le hook `archiso` ainsi réactivé cherche au boot un média
amovible (ISO/USB) qui n'existe jamais sur un système installé sur disque,
et bloque indéfiniment avec `ERROR: '' device did not show up after N
seconds...` (message émis par `/hooks/archiso`, **sans rapport avec
`root=`/UUID**, qui restent corrects). Symptôme trompeur : ce message a
exactement la même forme que l'erreur classique "root device introuvable",
et `rootdelay=`/vérification de l'UUID/de `/etc/fstab` (tous corrects
dans ce cas) n'ont donc aucun effet - le vrai diagnostic nécessite de lire
`/init`, `/init_functions` et `/hooks/*` directement dans le shell de
secours (`grep -rn "did not show up" /hooks/ /init_functions /init`) pour
localiser la fonction fautive plutôt que de suivre la piste (fausse) du
device racine.

**Filet de sécurité supplémentaire** : ce fragment a été observé réapparu
(ou jamais supprimé) sur une installation malgré la suppression par
`fix-target-mkinitcpio.sh`, sans que la cause exacte ait pu être confirmée
(le job ne remonte pas d'échec, donc son `rm -f` s'exécute bien). Par
robustesse, une seconde suppression a été ajoutée comme job Calamares
indépendant (`shellprocess@removearchisoconf`, script inline `rm -f
/etc/mkinitcpio.conf.d/archiso.conf`), positionnée juste avant `initcpio`
(après `initcpiocfg`) plutôt qu'avant - la dernière étape avant que
`mkinitcpio -p linux` ne soit réellement invoqué, pour éliminer toute
fenêtre où ce fragment pourrait persister ou être recréé entre les deux
jobs.

**Piège annexe** : `mkarchiso` ne préserve pas le bit exécutable des
fichiers d'overlay non listés dans `profiledef.sh` (`file_permissions`) -
tout script ajouté sous `airootfs/` (comme ces deux-là) doit y être déclaré
explicitement (`"0:0:755"`), sinon Calamares échoue avec un code de sortie
126 ("permission denied") en essayant de l'exécuter.

**Ce même piège existerait pour n'importe quel réglage qu'on voudrait
appliquer différemment en live vs. installé** (le réflexe: si un fichier
doit être différent selon live/installé, il ne peut pas être un simple
overlay statique - il faut soit un job Calamares comme celui-ci, soit un
module Python dédié comme `adjoinjob`).

## Comptes live et session dupliquée

Même mécanisme racine que le boot (`unpackfs` copie le système live tel
quel, voir plus haut) appliqué aux comptes utilisateur : `liveuser` (créé
par `root/customize_airootfs.sh`, avec autologin SDDM pour la démo sans
mot de passe) se retrouve tel quel sur le système installé aux côtés du
compte que l'utilisateur vient de créer via la page Calamares `users` -
d'où les "deux sessions" observées après une installation (autologin
automatique sur `liveuser` en plus du compte réel).

Fix (deux mécanismes complémentaires, tous deux après `users` et avant
`displaymanager` dans `settings.conf`) :
1. Module Calamares built-in **`removeuser`** (`removeuser.conf`,
   `username: liveuser`) : supprime le compte `liveuser` lui-même
   (`userdel`) sur la cible.
2. `shellprocess@removeliveartifacts` → `usr/local/bin/remove-live-artifacts.sh` :
   supprime `etc/sddm.conf.d/20-liveuser-autologin.conf`. Ce fragment
   d'autologin a été délibérément séparé de `10-wayland-default.conf`
   (qui ne contient plus que les réglages `[Theme]`/`[General]` valables
   aussi bien en live qu'installé) précisément pour pouvoir être ciblé et
   supprimé sans toucher au reste - `removeuser` ne connaît que le compte
   Unix, pas la config SDDM, donc il faut ce second mécanisme même si le
   compte `liveuser` disparaît.

Le splash GRUB (`GRUB_BACKGROUND`, image dans `airootfs/boot/grub/splash.png`)
et `GRUB_CMDLINE_LINUX_DEFAULT="... splash"` (pour activer Plymouth), eux,
n'ont pas ce problème : `/etc/default/grub` n'est utilisé qu'au moment où
Calamares génère `grub.cfg` sur la cible (modules `grubcfg`/`bootloader`),
jamais par le live lui-même (qui boote via syslinux/systemd-boot, pas GRUB -
voir `profiledef.sh`), donc un simple fichier d'overlay statique suffit.

## Image de marque (`branding/compass-arch-background.png`)

Une seule image (logo boussole sur fond métal sombre, voir `branding/` à la
racine du dépôt) est réutilisée à trois endroits, chacun avec sa propre
contrainte technique :
- **GRUB** : copiée telle quelle dans `airootfs/boot/grub/splash.png`
  (référencée par `GRUB_BACKGROUND`, voir plus haut) - simple overlay
  statique, aucune particularité. **Piège observé** : `GRUB_TERMINAL_OUTPUT`
  doit être explicitement `gfxterm` (pas laissé commenté/par défaut) sinon
  GRUB reste en mode texte et ignore `GRUB_BACKGROUND` silencieusement: et
  même avec `gfxterm` activé, `GRUB_GFXMODE=auto` seul s'est avéré
  insuffisant sur une VM VMware testée (détection VBE en échec, retour
  silencieux au mode texte, sans erreur ni image) - la résolution doit être
  forcée explicitement (`GRUB_GFXMODE=1024x768x32,auto`) et les modules
  vidéo précchargés explicitement (`GRUB_PRELOAD_MODULES=".. all_video"`)
  plutôt que de compter sur la détection automatique de `grub-mkconfig`.
- **Plymouth** : thème custom `usr/share/plymouth/themes/compass-arch/`
  (module `script`, voir `compass-arch.script` - image mise à l'échelle
  plein écran avec un léger effet de pulsation d'opacité, pas d'assets
  supplémentaires nécessaires). Activé via `plymouth-set-default-theme
  compass-arch` à deux endroits distincts et indépendants : dans
  `customize_airootfs.sh` (pour l'initramfs du média live lui-même) et dans
  `usr/local/bin/fix-target-mkinitcpio.sh` (pour l'initramfs régénéré sur
  la cible - voir plus haut, ces deux initramfs sont générés séparément).
- **Fond d'écran Plasma** : paquet de fond d'écran
  `usr/share/wallpapers/CompassArch/` (structure KPackage standard :
  `metadata.json` + `contents/images(_dark)/1920x1080.png`), sélectionné
  comme fond par défaut en éditant `Image=Next` → `Image=CompassArch` dans
  les fichiers `defaults` des paquets look-and-feel (`org.kde.breeze.desktop`,
  `org.kde.breezedark.desktop`, fournis par `plasma-workspace`). **Piège
  identique à celui de `/etc/skel/.bashrc`** : ces fichiers `defaults`
  appartiennent à un paquet pacman, donc l'édition se fait via `sed` dans
  `customize_airootfs.sh` **après** pacstrap, jamais via un overlay
  statique au même chemin (qui ferait échouer pacstrap avec un conflit de
  fichier).
