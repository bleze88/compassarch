<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="fr">
<!--
  Traduction française du module Calamares "adjoinview" (page de jonction
  Active Directory). L'anglais est la langue source ; ce fichier n'est PAS
  généré par lupdate (pas de build Qt disponible pour l'écrire à la main puis
  le maintenir) - toute nouvelle chaîne ajoutée au code doit être reportée ici
  manuellement. Pour ajouter une langue : copier ce fichier en
  adjoinview_<code>.ts et traduire les <translation>, puis lister le fichier
  dans CMakeLists.txt (ADJOINVIEW_TS_FILES).

  Contextes : "ADJoinQmlViewStep" pour le nom court dans la barre latérale
  (tr() direct, C++). "Config" pour tous les textes de la page elle-même :
  exposés en Q_PROPERTY (voir Config.h/.cpp) plutôt qu'en qsTr() direct dans
  adjoinview.qml, car le QQmlEngine "nu" utilisé par Calamares (pas
  QQmlApplicationEngine) ne réévalue pas automatiquement les qsTr() après
  l'installation d'un nouveau QTranslator - voir docs/AD-JOIN-MODULE.md.
-->
<context>
    <name>ADJoinQmlViewStep</name>
    <message>
        <source>Join Domain</source>
        <translation>Rejoindre un domaine</translation>
    </message>
</context>
<context>
    <name>Config</name>
    <message>
        <source>Join Active Directory Domain</source>
        <translation>Rejoindre un domaine Active Directory</translation>
    </message>
    <message>
        <source>Optional: if this computer should join a Windows Active Directory domain, fill in the details below. You can always do this later after installation with the 'realm join' command.</source>
        <translation>Optionnel : si cet ordinateur doit rejoindre un domaine Active Directory Windows, renseignez les informations ci-dessous. Vous pourrez toujours le faire plus tard après l'installation avec la commande 'realm join'.</translation>
    </message>
    <message>
        <source>Join an Active Directory domain during installation</source>
        <translation>Rejoindre un domaine Active Directory pendant l'installation</translation>
    </message>
    <message>
        <source>Domain (e.g. example.local)</source>
        <translation>Domaine (ex : exemple.local)</translation>
    </message>
    <message>
        <source>example.local</source>
        <translation>exemple.local</translation>
    </message>
    <message>
        <source>Organizational unit (optional)</source>
        <translation>Unité d'organisation (optionnel)</translation>
    </message>
    <message>
        <source>OU=Workstations,DC=example,DC=local</source>
        <translation>OU=Postes,DC=exemple,DC=local</translation>
    </message>
    <message>
        <source>Domain admin username</source>
        <translation>Nom d'utilisateur admin du domaine</translation>
    </message>
    <message>
        <source>administrator</source>
        <translation>administrateur</translation>
    </message>
    <message>
        <source>Domain admin password</source>
        <translation>Mot de passe admin du domaine</translation>
    </message>
    <message>
        <source>This computer's name</source>
        <translation>Nom de cet ordinateur</translation>
    </message>
    <message>
        <source>Domain, admin username, password, and computer name are all required to continue.</source>
        <translation>Domaine, utilisateur admin, mot de passe et nom de machine sont requis pour continuer.</translation>
    </message>
    <message>
        <source>If the join fails, installation continues normally: you can retry manually after the first boot.</source>
        <translation>En cas d'échec de la jonction, l'installation continue normalement : vous pourrez réessayer manuellement après le premier démarrage.</translation>
    </message>
</context>
</TS>
