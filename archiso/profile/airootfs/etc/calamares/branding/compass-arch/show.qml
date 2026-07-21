/* Diaporama affiché pendant la phase d'installation (exec).
 * Voir CMakeLists.txt/branding.desc: slideshowAPI: 2. */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation
{
    id: presentation

    function nextSlide() {
        presentation.goToNextSlide();
    }

    Timer {
        id: advanceTimer
        interval: 6000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        centeredText: qsTr( "Bienvenue sur Compass Arch, basée sur Arch Linux avec KDE Plasma." )
    }

    Slide {
        centeredText: qsTr( "Un helper AUR (yay) est préinstallé : vous pouvez installer des paquets "
                           + "de l'AUR dès le premier démarrage." )
    }

    Slide {
        centeredText: qsTr( "Si vous avez rejoint un domaine Active Directory pendant l'installation, "
                           + "vos comptes de domaine sont utilisables dès la connexion." )
    }

    Slide {
        centeredText: qsTr( "L'installation continue en arrière-plan, cela peut prendre quelques minutes." )
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }

    function onLeave() {
    }
}
