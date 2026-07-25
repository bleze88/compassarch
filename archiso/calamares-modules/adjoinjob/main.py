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
"""

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

    # Pas de hostnamectl ici : le hostname est déjà positionné par le module
    # Calamares "users" avant que ce job ne s'exécute, et hostnamectl échoue
    # de toute façon dans ce chroot (voir note --install= ci-dessous - même
    # cause : pas de D-Bus système/systemd PID 1 disponible).

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
    return None
