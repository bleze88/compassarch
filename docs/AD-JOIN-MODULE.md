# Module Calamares : jonction Active Directory

Deux modules Calamares custom, dans `archiso/calamares-modules/` :

## `adjoinview` (page graphique)

- Type `view`, interface `qtplugin` : un plugin C++/QML, calqué sur le
  pattern `Calamares::QmlViewStep` utilisé par le module `mobile` de
  [calamares-extensions](https://github.com/calamares/calamares-extensions/tree/master/modules/mobile).
- `Config.h/.cpp` : expose à QML (sous le nom `config`) les propriétés
  `enabled`, `domain`, `ou`, `adminUser`, `adminPassword`, `computerName`,
  une propriété calculée `isValid`, et tous les **textes affichés** de la
  page (`pageTitle`, `pageDescription`, `joinCheckboxText`, `domainLabel`,
  etc. - voir la liste complète dans `Config.h`).
- `adjoinview.qml` : le formulaire, purement déclaratif - chaque `Label`/
  `placeholderText` est bindé à `config.xxx`, jamais à un `qsTr()` direct
  (voir "Traductions" ci-dessous pour le pourquoi). Case à cocher
  "Rejoindre un domaine AD" **décochée par défaut** - si elle reste
  décochée, l'utilisateur peut cliquer sur Suivant immédiatement (étape
  100% optionnelle).
- À la sortie de la page (`onLeave()`), les valeurs sont écrites dans
  `GlobalStorage["adjoin"]` (mémoire du processus Calamares - **jamais
  sérialisé sur disque**, y compris le mot de passe).
- `createJobs()` renvoie une liste vide : ce module ne fait aucun travail
  privilégié lui-même (voir `adjoinjob` ci-dessous).
- **Traductions** : l'anglais est la langue source (`tr()` dans
  `Config.cpp` et `ADJoinQmlViewStep.cpp`). Les traductions vivent dans
  `translations/adjoinview_<code langue>.ts` (un fichier par langue, écrit
  à la main - pas de `lupdate` disponible pour ce module hors-arbre) et
  sont compilées en `.qm` par `CMakeLists.txt`, installées à côté du
  plugin (`.../adjoinview/translations/`). `Config::retranslate()` charge
  au runtime le `.qm` correspondant à la langue active de Calamares
  (lue dans `GlobalStorage["LANG"]`, avec repli sur `QLocale()`), et émet
  `translationsChanged()` pour rebinder le QML.
  **Piège évité** : Calamares utilise un `QQmlEngine` "nu" (pas
  `QQmlApplicationEngine`), qui ne réévalue **pas** automatiquement les
  `qsTr()` QML quand un nouveau `QTranslator` est installé après coup
  (contrairement à ce que ferait `QQmlApplicationEngine`). Comme les vues
  Calamares sont toutes construites au démarrage - avant que l'utilisateur
  n'ait choisi de langue sur la page Bienvenue - un simple `qsTr()` dans le
  QML restait figé sur la langue de démarrage. D'où le choix d'exposer les
  textes en `Q_PROPERTY` avec `NOTIFY translationsChanged` : un mécanisme de
  binding Qt standard, fiable indépendamment de ce détail interne de
  Calamares. `Config::retranslate()` est rappelée à plusieurs points d'entrée
  (constructeur, `prettyName()`, `getConfig()`, `onActivate()`) pour
  rattraper le choix de langue quel que soit le moment où il est fait.
  Pour ajouter une langue : copier `translations/adjoinview_fr.ts`, traduire
  les `<translation>`, et ajouter le fichier à `ADJOINVIEW_TS_FILES` dans
  `CMakeLists.txt`.

## `adjoinjob` (exécution)

- Type `job`, interface `python` (`main.py`).
- Placé dans la phase `exec` de `settings.conf`, **après**
  `services-systemd` (sssd/chronyd déjà activés sur la cible) et **avant**
  `bootloader`.
- Lit `GlobalStorage["adjoin"]`. Si `enabled` est faux, ne fait rien.
- Sinon, dans le chroot cible (`libcalamares.utils.target_env_call`) :
  1. Écrit un `/etc/resolv.conf` fonctionnel dans la cible (voir piège
     DNS ci-dessous)
  2. `chronyd -q` (synchro horloge ponctuelle - Kerberos est sensible au
     décalage d'horloge)
  3. `realm join --install=/ --user <adminUser> [--computer-ou <ou>] <domain>`,
     avec le mot de passe transmis **par stdin** (jamais en argument de
     commande visible dans `/proc`, jamais écrit sur disque)
  4. `systemctl enable sssd.service`
  (Pas de `hostnamectl set-hostname` : le hostname est déjà positionné par
  le module Calamares `users` avant que ce job ne s'exécute, et
  `hostnamectl` échouerait de toute façon ici - voir piège ci-dessous.)

  **Piège critique - DNS ne fonctionne pas dans le chroot** :
  `airootfs/etc/resolv.conf` est un symlink vers
  `/run/systemd/resolve/stub-resolv.conf` (setup `systemd-resolved`
  standard). Ça fonctionne très bien sur le live, où `systemd-resolved`
  tourne réellement en tant que service - mais **pas** dans le chroot cible
  utilisé par Calamares (`target_env_call` fait un simple `chroot()`, pas un
  vrai système avec ses services démarrés : le `/run` du chroot n'a pas de
  stub-resolv.conf peuplé). Confirmé en conditions réelles : `chronyd -q`
  bloquait systématiquement 30 secondes (impossible de résoudre les
  serveurs NTP) et `realm join` échouait avec `realm: No such realm found`
  **alors qu'un `realm discover` lancé sur le live (hors chroot) trouvait le
  domaine sans problème** - la résolution DNS échouait silencieusement dans
  le chroot, pas un souci réseau/identifiants/domaine réel. Fix : avant
  toute autre chose, le job lit les vrais serveurs DNS depuis
  `/run/systemd/resolve/resolv.conf` (le fichier "uplink" de
  systemd-resolved, avec de vraies IP - pas `/etc/resolv.conf`, qui pointe
  vers le stub `127.0.0.53`) **depuis ce process Python lui-même** (qui
  tourne sur le live, pas chrooté) et les écrit dans le `/etc/resolv.conf`
  de la cible via `target_env_call`.

  **Piège critique - `--install=/` indispensable** : `realm join` cherche
  par défaut à parler au démon `realmd` via D-Bus **système**, qui n'existe
  pas dans le chroot cible utilisé par Calamares (pas de vrai `systemd`
  PID 1, donc pas de bus système actif). Confirmé en conditions réelles :
  la jonction échouait systématiquement avec `realm: Couldn't connect to
  system bus: Could not connect: No such file or directory` (et
  `hostnamectl` avec `System has not been booted with systemd as init
  system (PID 1)`), alors même que `realm list` (côté live, avant install)
  ne montrait donc jamais rien et qu'aucune machine n'apparaissait dans
  l'annuaire AD - pas un souci réseau/Kerberos/identifiants, un simple
  problème d'environnement d'exécution. `realm` documente lui-même la
  solution dans son propre message d'erreur : `--install=DIR` fait
  opérer `realm`/`adcli` directement sur le système cible (ici `/`, déjà la
  racine vue depuis ce chroot) sans passer par `realmd`/D-Bus - c'est le
  mécanisme prévu précisément pour les installations hors-ligne/chroot.
- Le mot de passe est effacé de `GlobalStorage` dès qu'il a été lu, avant
  même d'exécuter `realm join`.
- **Best-effort par conception** : si `realm join` échoue, le job journalise
  un avertissement et renvoie `None` (succès du point de vue de Calamares)
  au lieu de faire échouer toute l'installation. L'utilisateur peut
  toujours faire `realm join` manuellement après le premier démarrage. Ce
  choix UX est documenté dans le code (`adjoinjob/main.py`) - à revoir si
  vous préférez un comportement bloquant.
- **Diagnostiquer un échec** : `realm join` est appelé via
  `libcalamares.utils.check_target_env_output` (pas `target_env_call`, qui
  ne renvoie qu'un code de sortie et jette la sortie texte) - la sortie
  complète de `realm join --verbose` est journalisée dans le log de session
  Calamares en cas d'échec (avertissement) comme en cas de succès (debug).
  Ce log vit sur le système **live** (RAM, perdu au redémarrage) à
  `/root/.cache/calamares/session.log` (chemin déterminé par
  `QStandardPaths::CacheLocation` pour l'utilisateur root, sous lequel
  Calamares tourne via `pkexec` - **pas** `/var/log/Calamares.log`, piège
  déjà rencontré) - à récupérer **avant** de redémarrer si besoin de le
  consulter après coup. Une fois le système installé démarré, l'état réel
  de la jonction se vérifie directement : `realm list` (domaines rejoints),
  `journalctl -u sssd`, et `/var/log/sssd/*.log` (le plus détaillé pour les
  problèmes Kerberos/LDAP spécifiquement).

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
