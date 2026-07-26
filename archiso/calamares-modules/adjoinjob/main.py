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
    # Piège vécu en conditions réelles : `sudo`/`visudo` matchent le groupe
    # via getgrnam() (résolution NSS), qui - avec `use_fully_qualified_names`
    # (activé par défaut par `realm join` avec le provider AD) - ne reconnaît
    # QUE la forme qualifiée "groupe@domaine" ("getent group g_linux" ne
    # renvoie rien, seul "getent group g_linux@montferrini.local" fonctionne),
    # alors que `realm permit --groups` (ci-dessus) accepte très bien le nom
    # court (résolution AD interne, indépendante de NSS). Un admin tapant le
    # même nom court dans les deux champs verrait donc la restriction de
    # connexion fonctionner mais le sudo échouer silencieusement (visudo -cf
    # valide la SYNTAXE, pas l'existence du groupe). On qualifie donc
    # toujours nous-mêmes avec le domaine de la jonction, quel que soit ce
    # que l'admin a saisi (avec ou sans @domaine déjà présent).
    if sudo_group:
        sudo_group_qualified = "{}@{}".format(sudo_group.split("@", 1)[0], domain)
        sudoers_tmp = "/etc/sudoers.d/90-ad-admins.tmp"
        sudoers_final = "/etc/sudoers.d/90-ad-admins"
        sudoers_line = "%{} ALL=(ALL:ALL) ALL\n".format(sudo_group_qualified)
        libcalamares.utils.target_env_call(["sh", "-c", "cat > " + sudoers_tmp], sudoers_line)
        check = libcalamares.utils.target_env_call(["visudo", "-cf", sudoers_tmp])
        if check == 0:
            libcalamares.utils.target_env_call(
                ["sh", "-c", "chmod 0440 {0} && mv {0} {1}".format(sudoers_tmp, sudoers_final)]
            )
            libcalamares.utils.debug(
                "adjoinjob: droits sudo accordés au groupe AD '{}'.".format(sudo_group_qualified)
            )
        else:
            libcalamares.utils.target_env_call(["rm", "-f", sudoers_tmp])
            libcalamares.utils.warning(
                "adjoinjob: nom de groupe sudo '{}' invalide pour sudoers, ignoré.".format(sudo_group_qualified)
            )

    return None
