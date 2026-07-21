/* Page Calamares "Rejoindre un domaine Active Directory" (module adjoinview).
 *
 * Purement de la présentation : chaque champ est bindé à une propriété de
 * Config (exposée ici sous le nom "config", cf. ADJoinQmlViewStep::getConfig()).
 * Le bouton Suivant/Précédent standard de Calamares pilote la navigation ;
 * ADJoinQmlViewStep::isNextEnabled() se contente de refléter config.isValid.
 */
import io.calamares.core 1.0
import io.calamares.ui 1.0

import QtQuick 2.10
import QtQuick.Controls 2.10
import QtQuick.Layouts 1.3

Page {
    id: root

    Component.onCompleted: config.prefillComputerName()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 12

        Label {
            text: qsTr( "Rejoindre un domaine Active Directory" )
            font.bold: true
            font.pointSize: 14
        }

        Label {
            text: qsTr( "Optionnel : si cet ordinateur doit rejoindre un domaine Active Directory "
                       + "Windows, renseignez les informations ci-dessous. Vous pourrez toujours le "
                       + "faire plus tard après l'installation avec la commande 'realm join'." )
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        CheckBox {
            id: enabledBox
            text: qsTr( "Rejoindre un domaine Active Directory pendant l'installation" )
            checked: config.enabled
            onToggled: config.enabled = checked
        }

        GridLayout {
            columns: 2
            columnSpacing: 12
            rowSpacing: 8
            enabled: enabledBox.checked
            opacity: enabledBox.checked ? 1.0 : 0.5
            Layout.fillWidth: true

            Label { text: qsTr( "Domaine (ex: exemple.local)" ) }
            TextField {
                id: domainField
                Layout.fillWidth: true
                text: config.domain
                placeholderText: qsTr( "exemple.local" )
                onTextEdited: config.domain = text
            }

            Label { text: qsTr( "Unité d'organisation (optionnel)" ) }
            TextField {
                id: ouField
                Layout.fillWidth: true
                text: config.ou
                placeholderText: qsTr( "OU=Postes,DC=exemple,DC=local" )
                onTextEdited: config.ou = text
            }

            Label { text: qsTr( "Nom d'utilisateur admin du domaine" ) }
            TextField {
                id: adminUserField
                Layout.fillWidth: true
                text: config.adminUser
                placeholderText: qsTr( "administrateur" )
                onTextEdited: config.adminUser = text
            }

            Label { text: qsTr( "Mot de passe admin du domaine" ) }
            TextField {
                id: adminPasswordField
                Layout.fillWidth: true
                text: config.adminPassword
                echoMode: TextInput.Password
                onTextEdited: config.adminPassword = text
            }

            Label { text: qsTr( "Nom de cet ordinateur" ) }
            TextField {
                id: computerNameField
                Layout.fillWidth: true
                text: config.computerName
                onTextEdited: config.computerName = text
            }
        }

        Label {
            visible: enabledBox.checked && !config.isValid
            color: "#c0392b"
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            text: qsTr( "Domaine, utilisateur admin, mot de passe et nom de machine sont requis pour continuer." )
        }

        Label {
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            text: qsTr( "En cas d'échec de la jonction, l'installation continue normalement : vous pourrez "
                       + "réessayer manuellement après le premier démarrage." )
            opacity: 0.7
            font.italic: true
        }

        Item { Layout.fillHeight: true }
    }
}
