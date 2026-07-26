#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Rejoint le domaine Active Directory choisi dans la page "adjoinview".

Lit GlobalStorage["adjoin"] (écrit par ADJoinQmlViewStep::onLeave() côté
module de vue "adjoinview") et, si l'utilisateur a coché "enabled", exécute
`realm join` dans le chroot cible via libcalamares.utils.target_env_call().
Le mot de passe admin est transmis par stdin (jamais en argv, jamais sur
disque) et effacé de GlobalStorage dès qu'il a été lu.

Best-effort par conception (voir docs/AD-JOIN-MODULE.md) : un échec de
jonction ne bloque pas le reste de l'installation, il est seulement
journalisé. L'utilisateur peut toujours faire `realm join` manuellement
après le premier démarrage.

Optionnellement, restreint la connexion à un groupe AD (`realm permit
--groups`) et/ou accorde sudo à un groupe AD (fragment /etc/sudoers.d/)
si ces champs ont été renseignés dans la page - vides par défaut, aucun
changement de comportement si non utilisés.
"""

import socket

import libcalamares


def pretty_name():
    return "Joining Active Directory domain"


def run():
    gs = libcalamares.globalstorage
    adjoin = gs.value("adjoin") or {}

    if not adjoin.get("enabled"):
        libcalamares.utils.debug("adjoinjob: jonction AD non demandée, rien à faire.")
        return None

    domain = (adjoin.get("domain") or "").strip()
    ou = (adjoin.get("ou") or "").strip()
    admin_user = (adjoin.get("adminUser") or "").strip()
    admin_password = adjoin.get("adminPassword") or ""
    computer_name = (adjoin.get("computerName") or "").strip()
    allowed_group = (adjoin.get("allowedGroup") or "").strip()
    sudo_group = (adjoin.get("sudoGroup") or "").strip()

    # Le mot de passe n'est utile qu'une fois ; on l'efface de GlobalStorage
    # dès qu'il est capturé dans la variable locale ci-dessus.
    adjoin["adminPassword"] = ""
    gs.insert("adjoin", adjoin)

    if not domain or not admin_user or not admin_password or not computer_name:
        libcalamares.utils.warning(
            "adjoinjob: champs requis manquants (domaine/utilisateur/mot de "
            "passe/nom de machine), jonction AD ignorée."
        )
        return None

    # Positionne le hostname NOYAU (pas juste /etc/hostname de la cible,
    # déjà écrit par le module Calamares "users") avant realm join.
    #
    # Piège vécu en conditions réelles : sans ça, la machine rejoint bien
    # l'AD mais sous le nom "archiso" (hostname du live) au lieu du nom
    # voulu - `realm join`/`adcli` déterminent le nom de l'ordinateur AD via
    # gethostname(), pas en lisant le fichier /etc/hostname de la cible.
    # Un `chroot()` simple (ce que fait target_env_call) ne crée PAS de
    # namespace UTS séparé, donc le hostname noyau reste celui du système
    # live tant qu'on ne le change pas explicitement - d'où ce nom "archiso"
    # incohérent avec le nom final "compass" une fois démarré. Cette
    # incohérence casse ensuite l'authentification Kerberos après
    # installation (SPN enregistrés sous "ARCHISO$" dans l'AD, keytab local
    # généré pour ce même nom, alors que la machine s'appelle "compass" une
    # fois redémarrée) - confirmé par un échec de connexion AD systématique
    # après un premier essai avec ce bug.
    #
    # socket.sethostname() plutôt que hostnamectl (échoue ici, D-Bus
    # indisponible - voir note --install= plus bas) ou la commande
    # `hostname` (fournie par le paquet inetutils, pas dans packages.x86_64) :
    # cet appel Python tourne directement sur le système live (ce process
    # n'est PAS chrooté, contrairement aux commandes lancées via
    # target_env_call), et comme chroot() ne sépare pas le namespace UTS,
    # changer le hostname ici affecte bien le même noyau que celui vu par
    # `realm join` ensuite (chrooté ou non).
    try:
        socket.sethostname(computer_name)
    except OSError as exc:
        libcalamares.utils.warning(
            "adjoinjob: impossible de positionner le hostname noyau à '{}' ({}) - "
            "la jonction AD risque d'utiliser le nom du live à la place.".format(computer_name, exc)
        )

    # /etc/resolv.conf du système cible est un symlink vers
    # /run/systemd/resolve/stub-resolv.conf (voir airootfs/etc/resolv.conf) -
    # ça fonctionne sur le live, où systemd-resolved tourne réellement, mais
    # PAS dans ce chroot (juste un chroot(), pas un vrai système avec ses
    # services démarrés : pas de stub-resolv.conf peuplé dans son /run).
    # Confirmé en conditions réelles : chronyd bloquait 30s (impossible de
    # résoudre les serveurs NTP) et realm join échouait avec "No such realm
    # found" malgré un `realm discover` réussi sur le live - la résolution
    # DNS échouait silencieusement dans le chroot, pas un souci
    # réseau/identifiants/domaine. Fix : on lit les vrais serveurs DNS
    # (fichier "uplink" de systemd-resolved, avec de vraies IP, pas le stub
    # 127.0.0.53) depuis CE process (qui tourne sur le live, pas chrooté) et
    # on les écrit dans le resolv.conf de la cible avant d'aller plus loin.
    #
    # Piège : un premier essai avec juste "cat > /etc/resolv.conf" a échoué
    # ("No such file or directory") - /etc/resolv.conf est un symlink vers
    # /run/systemd/resolve/stub-resolv.conf, et cette cible n'existe pas
    # dans ce chroot (son /run est vide, pas de service en cours), donc la
    # redirection suit le lien mort et ne peut rien créer. Il faut d'abord
    # supprimer le symlink pour écrire un vrai fichier à sa place.
    for candidate in ("/run/systemd/resolve/resolv.conf", "/etc/resolv.conf"):
        try:
            with open(candidate) as f:
                resolv_content = f.read()
        except OSError:
            continue
        if "nameserver" in resolv_content:
            libcalamares.utils.target_env_call(
                ["sh", "-c", "rm -f /etc/resolv.conf && cat > /etc/resolv.conf"], resolv_content
            )
            break

    # Kerberos est sensible au décalage d'horloge : on force une synchro
    # ponctuelle avant la jonction (chronyd est déjà activé par
    # services-systemd, voir airootfs/etc/calamares/modules/services-systemd.conf).
    libcalamares.utils.target_env_call(["chronyd", "-q"], "", 30)

    # --install=/ : indispensable dans ce contexte. `realm join` cherche par
    # défaut à parler à realmd via D-Bus système, qui n'existe pas dans le
    # chroot cible utilisé par Calamares (pas de vrai systemd PID 1) - confirmé
    # par un premier échec en conditions réelles : "realm: Couldn't connect to
    # system bus" (avec le message d'aide de realm lui-même : "To run without
    # a DBus bus use the install mode: --install=/"). Ce mode fait exactement
    # ce qu'il faut ici : opérer directement sur "/" (déjà la racine du
    # système cible, du point de vue de ce chroot) sans passer par realmd.
    join_cmd = ["realm", "join", "--install=/", "--user", admin_user, "--verbose"]
    if ou:
        join_cmd += ["--computer-ou", ou]
    join_cmd.append(domain)

    # check_target_env_output (plutôt que target_env_call) capture aussi la
    # sortie de 'realm join' - target_env_call ne renvoie que le code de
    # sortie et jette le texte, qui est pourtant la seule info utile pour
    # diagnostiquer un échec Kerberos/AD après coup (voir
    # /root/.cache/calamares/session.log sur le live, où warning() écrit).
    try:
        output = libcalamares.utils.check_target_env_output(join_cmd, admin_password + "\n", 120)
    except Exception as exc:
        output = getattr(exc, "output", str(exc))
        libcalamares.utils.warning(
            "adjoinjob: 'realm join {}' a échoué. L'installation continue ; "
            "jonction manuelle possible après coup avec 'realm join'.\n"
            "--- sortie de realm join ---\n{}".format(domain, output)
        )
        return None

    libcalamares.utils.debug(
        "adjoinjob: sortie de realm join --verbose :\n{}".format(output)
    )

    libcalamares.utils.target_env_call(["systemctl", "enable", "sssd.service"])
    libcalamares.utils.debug("adjoinjob: jonction au domaine {} réussie.".format(domain))

    # `realm join` laisse /etc/krb5.conf au contenu par défaut du paquet
    # `krb5` ([realms]/[domain_realm] avec des exemples MIT.EDU/CMU.EDU,
    # aucune entrée pour notre propre domaine) - Kerberos retrouve quand
    # même le KDC via découverte DNS (SRV) automatique, mais cette
    # découverte répétée à chaque opération ajoute une dépendance de plus
    # à un DNS qui peut être lent/perturbé (voir le piège mDNS/".local"
    # documenté dans docs/AD-JOIN-MODULE.md). On fige donc explicitement le
    # KDC trouvé via son enregistrement SRV, ce qui rend Kerberos
    # indépendant de cette découverte pour les opérations suivantes.
    # Best-effort : si `dig` échoue ou ne renvoie rien (domaine sans SRV,
    # pas de `bind` installé...), on n'ajoute rien et on retombe sur la
    # découverte DNS automatique de Kerberos, qui reste le comportement
    # par défaut sans ce bloc.
    try:
        srv_output = libcalamares.utils.check_target_env_output(
            ["sh", "-c", "dig +short SRV _kerberos._tcp.{} | sort -n | head -1".format(domain)],
            "",
            15,
        )
        kdc_host = srv_output.split()[-1].rstrip(".") if srv_output.strip() else ""
    except Exception:
        kdc_host = ""

    if kdc_host:
        try:
            krb5_conf = libcalamares.utils.check_target_env_output(["cat", "/etc/krb5.conf"], "", 15)
        except Exception:
            krb5_conf = ""

        if krb5_conf:
            realm_upper = domain.upper()
            realm_block = "    {} = {{\n        kdc = {}\n        admin_server = {}\n    }}\n".format(
                realm_upper, kdc_host, kdc_host
            )
            domain_realm_block = "    .{0} = {1}\n    {0} = {1}\n".format(domain, realm_upper)

            new_lines = []
            for line in krb5_conf.splitlines(keepends=True):
                new_lines.append(line)
                stripped = line.strip()
                if stripped == "[realms]":
                    new_lines.append(realm_block)
                elif stripped == "[domain_realm]":
                    new_lines.append(domain_realm_block)
            new_krb5_conf = "".join(new_lines)

            libcalamares.utils.target_env_call(["sh", "-c", "cat > /etc/krb5.conf"], new_krb5_conf)
            libcalamares.utils.debug(
                "adjoinjob: KDC '{}' figé dans /etc/krb5.conf pour le royaume {}.".format(
                    kdc_host, realm_upper
                )
            )
    else:
        libcalamares.utils.debug(
            "adjoinjob: pas de KDC trouvé via SRV, /etc/krb5.conf laissé tel quel "
            "(découverte DNS automatique de Kerberos utilisée à la place)."
        )

    # `realm join` génère /etc/sssd/sssd.conf avec use_fully_qualified_names
    # à True par défaut - corrigé ici à False (login court "mtf0001" plutôt
    # que "mtf0001@domaine"), avec case_sensitive à False (AD est
    # intrinsèquement insensible à la casse). Confirmé en conditions
    # réelles, dans cet ordre précis :
    #   1. Avec use_fully_qualified_names=True (défaut), la connexion SDDM
    #      pour un compte AD authentifiait correctement (pam_sss) mais la
    #      session Plasma plantait juste après avec un écran noir - log
    #      Wayland : "Could not create wayland socket", kwin_wayland tué
    #      par SIGABRT. Cause racine (confirmée via `userdbctl user
    #      <compte>` + `SYSTEMD_LOG_LEVEL=debug`) :
    #      io.systemd.UserDatabase.ConflictingRecordFound - le multiplexeur
    #      userdb de systemd fait une comparaison stricte, casse comprise,
    #      entre le nom saisi et le nom canonique retourné par NSS/sssd, et
    #      refuse l'enregistrement en cas de moindre différence (ici : la
    #      casse saisie par l'utilisateur au login ne correspondait pas
    #      exactement à celle stockée/retournée). pam_systemd traite cet
    #      échec comme PAM_USER_UNKNOWN et retourne SANS créer
    #      /run/user/<uid>, d'où le crash Wayland qui en dépend.
    #   2. use_fully_qualified_names=False seul n'a pas suffi tant qu'une
    #      DEUXIÈME occurrence de la clé (le "True" d'origine généré par
    #      realm join, plus loin dans le fichier) restait présente - un
    #      fichier ini avec une clé dupliquée garde la DERNIÈRE valeur, qui
    #      gagnait alors sur celle qu'on venait d'insérer juste après l'en-
    #      tête de section. D'où la réécriture complète ci-dessous (on
    #      retire toute occurrence existante des deux clés avant de
    #      réinjecter la nôtre une seule fois), plutôt qu'un simple ajout.
    #   3. Une fois use_fully_qualified_names réellement à False (une seule
    #      occurrence, sans le "True" fantôme), la connexion avec juste le
    #      nom court ("mtf0001", en respectant sa casse canonique) a
    #      fonctionné de bout en bout, session Plasma incluse.
    # Documenté en détail dans docs/AD-JOIN-MODULE.md.
    try:
        conf = libcalamares.utils.check_target_env_output(["cat", "/etc/sssd/sssd.conf"], "", 15)
    except Exception:
        conf = ""

    if conf:
        domain_header = "[domain/{}]".format(domain.upper())
        in_domain_section = False
        filtered_lines = []
        for line in conf.splitlines():
            stripped = line.strip()
            if stripped.startswith("["):
                in_domain_section = stripped == domain_header
                filtered_lines.append(line)
                continue
            if in_domain_section and stripped.split("=", 1)[0].strip() in (
                "use_fully_qualified_names",
                "case_sensitive",
            ):
                continue  # retiré, réinjecté une seule fois juste après l'en-tête ci-dessous
            filtered_lines.append(line)

        final_lines = []
        for line in filtered_lines:
            final_lines.append(line)
            if line.strip() == domain_header:
                final_lines.append("use_fully_qualified_names = False")
                final_lines.append("case_sensitive = False")
        new_conf = "\n".join(final_lines) + "\n"

        libcalamares.utils.target_env_call(["sh", "-c", "cat > /etc/sssd/sssd.conf"], new_conf)
        libcalamares.utils.target_env_call(["chmod", "0600", "/etc/sssd/sssd.conf"])
        libcalamares.utils.debug(
            "adjoinjob: use_fully_qualified_names=False / case_sensitive=False appliqués à sssd.conf."
        )
    else:
        libcalamares.utils.warning(
            "adjoinjob: impossible de lire /etc/sssd/sssd.conf après la jonction, "
            "réglages use_fully_qualified_names/case_sensitive non appliqués."
        )

    # Restriction de connexion (optionnelle) : par défaut, N'IMPORTE QUEL
    # compte du domaine peut se connecter une fois la jonction faite (aucune
    # restriction dans sssd.conf/NSS) - voir docs/AD-JOIN-MODULE.md. Si un
    # groupe a été renseigné, on utilise `realm permit`/`deny` plutôt que
    # d'éditer sssd.conf à la main : c'est l'outil prévu pour ça, il
    # regénère la config sssd correctement.
    if allowed_group:
        try:
            libcalamares.utils.check_target_env_output(["realm", "deny", "--all"], "", 30)
            libcalamares.utils.check_target_env_output(
                ["realm", "permit", "--groups", allowed_group], "", 30
            )
            libcalamares.utils.debug(
                "adjoinjob: connexion restreinte au groupe AD '{}'.".format(allowed_group)
            )
        except Exception as exc:
            libcalamares.utils.warning(
                "adjoinjob: échec de la restriction de connexion au groupe '{}' : {}".format(
                    allowed_group, getattr(exc, "output", str(exc))
                )
            )

    # Droits sudo (optionnels) : aucun compte AD n'a sudo automatiquement
    # sinon (seul le groupe local "wheel" en a, voir packages.x86_64/
    # customize_airootfs.sh). Le fragment est d'abord écrit dans un fichier
    # .tmp et validé avec `visudo -cf` avant d'être activé (permissions
    # 0440) - pour ne jamais risquer de casser sudo avec une syntaxe
    # invalide (ex: nom de groupe AD contenant des caractères spéciaux).
    #
    # Nom COURT (pas de "@domaine") : `sudo`/`visudo` matchent le groupe via
    # getgrnam() (résolution NSS), qui suit le réglage
    # use_fully_qualified_names - forcé à False juste au-dessus - donc
    # "getent group g_linux" (sans domaine) est la forme qui résout
    # réellement. Avec l'ancien défaut (True) c'était l'inverse (il fallait
    # "g_linux@domaine", voir l'historique dans docs/AD-JOIN-MODULE.md) -
    # piège à surveiller si ce défaut est un jour rendu configurable.
    if sudo_group:
        sudo_group_short = sudo_group.split("@", 1)[0]
        sudoers_tmp = "/etc/sudoers.d/90-ad-admins.tmp"
        sudoers_final = "/etc/sudoers.d/90-ad-admins"
        sudoers_line = "%{} ALL=(ALL:ALL) ALL\n".format(sudo_group_short)
        libcalamares.utils.target_env_call(["sh", "-c", "cat > " + sudoers_tmp], sudoers_line)
        check = libcalamares.utils.target_env_call(["visudo", "-cf", sudoers_tmp])
        if check == 0:
            libcalamares.utils.target_env_call(
                ["sh", "-c", "chmod 0440 {0} && mv {0} {1}".format(sudoers_tmp, sudoers_final)]
            )
            libcalamares.utils.debug(
                "adjoinjob: droits sudo accordés au groupe AD '{}'.".format(sudo_group_short)
            )
        else:
            libcalamares.utils.target_env_call(["rm", "-f", sudoers_tmp])
            libcalamares.utils.warning(
                "adjoinjob: nom de groupe sudo '{}' invalide pour sudoers, ignoré.".format(sudo_group_short)
            )

    # Écran de connexion SDDM en saisie libre (nom d'utilisateur + mot de
    # passe, comme sur Windows) plutôt qu'une liste de comptes cliquables -
    # demandé par l'utilisateur après avoir remarqué qu'un compte AD (non
    # énuméré par sssd, voir plus haut) n'apparaît jamais dans cette liste,
    # qui ne montre donc que le compte local créé par le module Calamares
    # "users". Confirmé fonctionnel en conditions réelles : masquer ce seul
    # compte local (`HideUsers`) fait basculer SDDM en saisie manuelle du
    # nom d'utilisateur (le thème Breeze bascule automatiquement en champ
    # de texte quand la liste est vide) - `RememberLastUser=false` en plus
    # pour que ce champ ne reste pas pré-rempli avec le dernier utilisateur
    # connecté (un premier essai avec seulement `HideUsers`, dans un
    # fichier séparé ajouté ensuite, n'a pas suffi : une deuxième section
    # "[Users]" dans le même fichier écrasait apparemment la première au
    # lieu de fusionner - d'où l'écriture groupée des deux clés dans une
    # seule section ci-dessous).
    #
    # Seulement si la jonction AD a été demandée : sur une install sans AD,
    # cacher le seul compte local existant serait contre-productif (plus
    # aucun moyen simple de se connecter depuis l'écran de bienvenue).
    local_username = (gs.value("username") or "").strip()
    if local_username:
        sddm_conf = "[Users]\nHideUsers={}\nRememberLastUser=false\n".format(local_username)
        libcalamares.utils.target_env_call(["mkdir", "-p", "/etc/sddm.conf.d"])
        libcalamares.utils.target_env_call(
            ["sh", "-c", "cat > /etc/sddm.conf.d/90-hide-local-user.conf"], sddm_conf
        )
        libcalamares.utils.debug(
            "adjoinjob: écran SDDM basculé en saisie libre (compte local '{}' masqué de la liste).".format(
                local_username
            )
        )
    else:
        libcalamares.utils.warning(
            "adjoinjob: nom d'utilisateur local introuvable dans GlobalStorage, "
            "écran SDDM laissé en mode liste."
        )

    return None
