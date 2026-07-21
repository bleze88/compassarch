# Module de vue Calamares (C++/QML) "Rejoindre un domaine Active Directory".
#
# Pattern calqué sur le module "mobile" de calamares-extensions
# (https://github.com/calamares/calamares-extensions/tree/master/modules/mobile) :
# un plugin viewmodule minimal basé sur Calamares::QmlViewStep, avec toute la
# mise en page dans un fichier QML embarqué en ressource Qt, et une classe
# Config exposée à QML sous le nom "config".
#
# Ce module ne fait AUCUN travail privilégié lui-même : il se contente
# d'écrire les choix de l'utilisateur dans GlobalStorage (mémoire du
# processus Calamares, jamais sérialisé sur disque). Le vrai travail
# (`realm join` en chroot) est fait par le module job Python voisin
# ../adjoinjob, exécuté plus tard dans la phase exec (voir settings.conf).
# createJobs() renvoie donc une liste vide, comme le fait le module "welcome".

calamares_add_plugin( adjoinview
    TYPE viewmodule
    EXPORT_MACRO PLUGINDLLEXPORT_PRO
    SOURCES
        Config.cpp
        ADJoinQmlViewStep.cpp
    RESOURCES
        adjoinview.qrc
    SHARED_LIB
    NO_CONFIG
)
