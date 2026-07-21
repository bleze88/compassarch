# Module Calamares : jonction Active Directory

Deux modules Calamares custom, dans `archiso/calamares-modules/` :

## `adjoinview` (page graphique)

- Type `view`, interface `qtplugin` : un plugin C++/QML, calqué sur le
  pattern `Calamares::QmlViewStep` utilisé par le module `mobile` de
  [calamares-extensions](https://github.com/calamares/calamares-extensions/tree/master/modules/mobile).
- `Config.h/.cpp` : expose à QML (sous le nom `config`) les propriétés
  `enabled`, `domain`, `ou`, `adminUser`, `adminPassword`, `computerName`,
  et une propriété calculée `isValid`.
- `adjoinview.qml` : le formulaire. Case à cocher "Rejoindre un domaine AD"
  **décochée par défaut** - si elle reste décochée, l'utilisateur peut
  cliquer sur Suivant immédiatement (étape 100% optionnelle).
- À la sortie de la page (`onLeave()`), les valeurs sont écrites dans
  `GlobalStorage["adjoin"]` (mémoire du processus Calamares - **jamais
  sérialisé sur disque**, y compris le mot de passe).
- `createJobs()` renvoie une liste vide : ce module ne fait aucun travail
  privilégié lui-même (voir `adjoinjob` ci-dessous).

## `adjoinjob` (exécution)

- Type `job`, interface `python` (`main.py`).
- Placé dans la phase `exec` de `settings.conf`, **après**
  `services-systemd` (sssd/chronyd déjà activés sur la cible) et **avant**
  `bootloader`.
- Lit `GlobalStorage["adjoin"]`. Si `enabled` est faux, ne fait rien.
- Sinon, dans le chroot cible (`libcalamares.utils.target_env_call`) :
  1. `hostnamectl set-hostname <computerName>`
  2. `chronyd -q` (synchro horloge ponctuelle - Kerberos est sensible au
     décalage d'horloge)
  3. `realm join --user <adminUser> [--computer-ou <ou>] <domain>`, avec le
     mot de passe transmis **par stdin** (jamais en argument de commande
     visible dans `/proc`, jamais écrit sur disque)
  4. `systemctl enable sssd.service`
- Le mot de passe est effacé de `GlobalStorage` dès qu'il a été lu, avant
  même d'exécuter `realm join`.
- **Best-effort par conception** : si `realm join` échoue, le job journalise
  un avertissement et renvoie `None` (succès du point de vue de Calamares)
  au lieu de faire échouer toute l'installation. L'utilisateur peut
  toujours faire `realm join` manuellement après le premier démarrage. Ce
  choix UX est documenté dans le code (`adjoinjob/main.py`) - à revoir si
  vous préférez un comportement bloquant.

## NSS / PAM (statique, hors du module)

Le câblage SSSD dans NSS/PAM n'est **pas** fait par `adjoinjob` (il doit
être en place avant même que l'utilisateur ne login, y compris si la
jonction est refaite manuellement après coup) :

- `archiso/profile/airootfs/etc/nsswitch.conf` : ajoute `sss` à
  `passwd`/`group`/`shadow`/`sudoers`.
- `archiso/profile/airootfs/etc/pam.d/system-auth` : remplace le
  `system-auth` fourni par `pambase` (protégé par pacman comme un fichier
  de config déjà présent - un `.pacnew` apparaîtra si `pambase` est mis à
  jour, à relire manuellement). Ajoute `pam_sss.so` sur les piles
  auth/account/password/session, et `pam_mkhomedir.so` pour créer le home
  au premier login (voir `docs/ARCHITECTURE.md` pour pourquoi pas
  `oddjob-mkhomedir`).
- `archiso/profile/airootfs/etc/realmd.conf` : chemin par défaut des home
  dirs AD (`/home/%D/%U`) et provider par défaut (`sssd`).

Ces trois fichiers sont copiés dans le système live **avant** que
`pacstrap` n'installe les paquets, donc ils sont déjà en place aussi bien
en live que (via `unpackfs`) sur le système installé, indépendamment de la
jonction AD elle-même.

## Étendre / adapter

- Rendre la jonction bloquante en cas d'échec : dans `adjoinjob/main.py`,
  remplacer le `return None` du cas d'échec par
  `return ("Active Directory domain join failed", "...")`.
- Ajouter un champ (ex: choix explicite de l'OS name annoncé à `realmd`) :
  ajouter une `Q_PROPERTY` dans `Config.h/.cpp`, un champ dans
  `adjoinview.qml`, et lire la clé correspondante côté `adjoinjob/main.py`
  (elles voyagent toutes ensemble dans `GlobalStorage["adjoin"]`).
