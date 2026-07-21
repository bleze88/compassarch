# Projet CMake de premier niveau pour les modules Calamares custom de
# Compass Arch, à construire séparément contre un Calamares déjà installé
# (paquet officiel `calamares`), exactement comme le fait le dépôt
# calamares-extensions officiel (https://github.com/calamares/calamares-extensions).
#
# Construit et installé par build/01-build-calamares-modules.sh, qui copie
# ensuite les fichiers installés (DESTDIR) dans l'overlay
# archiso/profile/airootfs/usr/lib/calamares/modules/ pour qu'ils soient
# embarqués dans l'ISO au même titre que n'importe quel paquet.
cmake_minimum_required( VERSION 3.16 FATAL_ERROR )

project( distro-calamares-modules LANGUAGES CXX )

set( CMAKE_CXX_STANDARD 17 )
set( CMAKE_CXX_STANDARD_REQUIRED ON )

include( GNUInstallDirs )

find_package( Calamares 3.3 CONFIG REQUIRED )
if ( NOT TARGET Calamares::calamares OR NOT TARGET Calamares::calamaresui )
    message( FATAL_ERROR "Calamares (paquet `calamares`, avec ses fichiers de développement) est requis." )
endif()

# Le Calamares::calamares importé par CalamaresConfig.cmake référence
# KF{5,6}::CoreAddons dans son interface de link - il faut le trouver nous-
# même (calamares-extensions fait la même chose dans son CMakeLists.txt de
# premier niveau), sinon CMake échoue avec "target was not found" au moment
# de configurer notre propre module.
if ( Calamares_WITH_QT6 )
    find_package( KF6CoreAddons REQUIRED )
else()
    find_package( KF5CoreAddons REQUIRED )
endif()

set( LIST_SKIPPED_MODULES "" )

# adjoinview : a un CMakeLists.txt -> compilé comme plugin C++/QML.
calamares_add_module_subdirectory( adjoinview LIST_SKIPPED_MODULES )

# adjoinjob : n'a qu'un module.desc + main.py -> copié tel quel (module Python).
calamares_add_module_subdirectory( adjoinjob LIST_SKIPPED_MODULES )

calamares_explain_skipped_modules( ${LIST_SKIPPED_MODULES} )
