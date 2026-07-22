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

# Traductions (voir translations/adjoinview_fr.ts) : compilées en .qm et
# installées à côté du plugin, chargées au runtime par
# ADJoinQmlViewStep::loadTranslations() (pas d'intégration au système de
# traduction interne de Calamares, dont l'API n'est pas exposée aux modules
# hors-arbre - voir docs/AD-JOIN-MODULE.md).
find_package( Qt6 REQUIRED COMPONENTS LinguistTools )
set( ADJOINVIEW_TS_FILES translations/adjoinview_fr.ts )
qt6_add_translation( ADJOINVIEW_QM_FILES ${ADJOINVIEW_TS_FILES} )
add_custom_target( adjoinview_translations ALL DEPENDS ${ADJOINVIEW_QM_FILES} )

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
add_dependencies( ${adjoinview_TARGET} adjoinview_translations )

install( FILES ${ADJOINVIEW_QM_FILES} DESTINATION ${CMAKE_INSTALL_LIBDIR}/calamares/modules/adjoinview/translations )
