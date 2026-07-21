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

    libcalamares.utils.target_env_call(["hostnamectl", "set-hostname", computer_name])

    # Kerberos est sensible au décalage d'horloge : on force une synchro
    # ponctuelle avant la jonction (chronyd est déjà activé par
    # services-systemd, voir airootfs/etc/calamares/modules/services-systemd.conf).
    libcalamares.utils.target_env_call(["chronyd", "-q"], "", 30)

    join_cmd = ["realm", "join", "--user", admin_user]
    if ou:
        join_cmd += ["--computer-ou", ou]
    join_cmd.append(domain)

    exit_code = libcalamares.utils.target_env_call(join_cmd, admin_password + "\n", 120)

    if exit_code != 0:
        libcalamares.utils.warning(
            "adjoinjob: 'realm join {}' a échoué (code {}). L'installation "
            "continue ; jonction manuelle possible après coup avec "
            "'realm join'.".format(domain, exit_code)
        )
        return None

    libcalamares.utils.target_env_call(["systemctl", "enable", "sssd.service"])
    libcalamares.utils.debug("adjoinjob: jonction au domaine {} réussie.".format(domain))
    return None
