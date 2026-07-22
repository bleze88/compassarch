/* Page Calamares "Join Active Directory Domain" (module adjoinview).
 *
 * Purement de la présentation : chaque champ est bindé à une propriété de
 * Config (exposée ici sous le nom "config", cf. ADJoinQmlViewStep::getConfig()).
 * Le bouton Suivant/Précédent standard de Calamares pilote la navigation ;
 * ADJoinQmlViewStep::isNextEnabled() se contente de refléter config.isValid.
 *
 * Les textes affichés viennent de propriétés C++ (config.pageTitle, etc.)
 * et non d'appels qsTr() directs : le QQmlEngine "nu" utilisé par Calamares
 * (pas QQmlApplicationEngine) ne réévalue pas automatiquement les qsTr()
 * après l'installation d'un nouveau QTranslator, alors qu'une Q_PROPERTY
 * avec NOTIFY se rebind normalement - voir Config::retranslate() et
 * docs/AD-JOIN-MODULE.md pour le détail de ce piège.
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
            text: config.pageTitle
            font.bold: true
            font.pointSize: 14
        }

        Label {
            text: config.pageDescription
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        CheckBox {
            id: enabledBox
            text: config.joinCheckboxText
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

            Label { text: config.domainLabel }
            TextField {
                id: domainField
                Layout.fillWidth: true
                text: config.domain
                placeholderText: config.domainPlaceholder
                onTextEdited: config.domain = text
            }

            Label { text: config.ouLabel }
            TextField {
                id: ouField
                Layout.fillWidth: true
                text: config.ou
                placeholderText: config.ouPlaceholder
                onTextEdited: config.ou = text
            }

            Label { text: config.adminUserLabel }
            TextField {
                id: adminUserField
                Layout.fillWidth: true
                text: config.adminUser
                placeholderText: config.adminUserPlaceholder
                onTextEdited: config.adminUser = text
            }

            Label { text: config.adminPasswordLabel }
            TextField {
                id: adminPasswordField
                Layout.fillWidth: true
                text: config.adminPassword
                echoMode: TextInput.Password
                onTextEdited: config.adminPassword = text
            }

            Label { text: config.computerNameLabel }
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
            text: config.validationErrorText
        }

        Label {
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            text: config.retryNoteText
            opacity: 0.7
            font.italic: true
        }

        Item { Layout.fillHeight: true }
    }
}
