/* Module "adjoinview" - page Calamares "Rejoindre un domaine Active Directory".
 * Voir CMakeLists.txt pour le contexte général du module. */
#pragma once

#include <QObject>
#include <QString>

class Config : public QObject
{
    Q_OBJECT

    // Décoché par défaut : l'étape est entièrement optionnelle ("skip" = ne
    // rien faire), cf. exigence "facilite l'installation" - un utilisateur
    // qui n'a pas de domaine AD clique juste sur Suivant.
    Q_PROPERTY( bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged )

    Q_PROPERTY( QString domain READ domain WRITE setDomain NOTIFY domainChanged )
    Q_PROPERTY( QString ou READ ou WRITE setOu NOTIFY ouChanged )
    Q_PROPERTY( QString adminUser READ adminUser WRITE setAdminUser NOTIFY adminUserChanged )
    Q_PROPERTY( QString adminPassword READ adminPassword WRITE setAdminPassword NOTIFY adminPasswordChanged )
    Q_PROPERTY( QString computerName READ computerName WRITE setComputerName NOTIFY computerNameChanged )

    // true si "enabled" est faux (rien à valider) ou si tous les champs
    // requis sont renseignés. Lu par ADJoinQmlViewStep::isNextEnabled() et
    // bindé en QML pour griser le bouton Suivant / afficher les erreurs.
    Q_PROPERTY( bool isValid READ isValid NOTIFY validityChanged )

    // Textes affichés par adjoinview.qml, exposés comme propriétés C++
    // plutôt qu'en qsTr() direct dans le QML : le QQmlEngine "nu" utilisé par
    // Calamares (pas QQmlApplicationEngine) ne ré-évalue pas automatiquement
    // les qsTr() quand un nouveau QTranslator est installé après coup (voir
    // docs/AD-JOIN-MODULE.md) - alors qu'une Q_PROPERTY avec NOTIFY se
    // rebind normalement dès qu'on émet le signal, retranslate() ci-dessous
    // s'en charge à chaque fois que la langue active est (re)vérifiée.
    Q_PROPERTY( QString pageTitle READ pageTitle NOTIFY translationsChanged )
    Q_PROPERTY( QString pageDescription READ pageDescription NOTIFY translationsChanged )
    Q_PROPERTY( QString joinCheckboxText READ joinCheckboxText NOTIFY translationsChanged )
    Q_PROPERTY( QString domainLabel READ domainLabel NOTIFY translationsChanged )
    Q_PROPERTY( QString domainPlaceholder READ domainPlaceholder NOTIFY translationsChanged )
    Q_PROPERTY( QString ouLabel READ ouLabel NOTIFY translationsChanged )
    Q_PROPERTY( QString ouPlaceholder READ ouPlaceholder NOTIFY translationsChanged )
    Q_PROPERTY( QString adminUserLabel READ adminUserLabel NOTIFY translationsChanged )
    Q_PROPERTY( QString adminUserPlaceholder READ adminUserPlaceholder NOTIFY translationsChanged )
    Q_PROPERTY( QString adminPasswordLabel READ adminPasswordLabel NOTIFY translationsChanged )
    Q_PROPERTY( QString computerNameLabel READ computerNameLabel NOTIFY translationsChanged )
    Q_PROPERTY( QString validationErrorText READ validationErrorText NOTIFY translationsChanged )
    Q_PROPERTY( QString retryNoteText READ retryNoteText NOTIFY translationsChanged )

public:
    explicit Config( QObject* parent = nullptr );

    bool enabled() const { return m_enabled; }
    QString domain() const { return m_domain; }
    QString ou() const { return m_ou; }
    QString adminUser() const { return m_adminUser; }
    QString adminPassword() const { return m_adminPassword; }
    QString computerName() const { return m_computerName; }
    bool isValid() const;

    QString pageTitle() const;
    QString pageDescription() const;
    QString joinCheckboxText() const;
    QString domainLabel() const;
    QString domainPlaceholder() const;
    QString ouLabel() const;
    QString ouPlaceholder() const;
    QString adminUserLabel() const;
    QString adminUserPlaceholder() const;
    QString adminPasswordLabel() const;
    QString computerNameLabel() const;
    QString validationErrorText() const;
    QString retryNoteText() const;

    void setEnabled( bool enabled );
    void setDomain( const QString& domain );
    void setOu( const QString& ou );
    void setAdminUser( const QString& adminUser );
    void setAdminPassword( const QString& adminPassword );
    void setComputerName( const QString& computerName );

    // Appelé une fois par ADJoin.qml (Component.onCompleted) pour préremplir
    // le nom de machine avec celui déjà saisi dans la page "users" - lu à la
    // demande dans GlobalStorage (clé "hostname"), jamais mis en cache avant
    // ça puisque la page "users" peut être remplie après le chargement du
    // module.
    Q_INVOKABLE void prefillComputerName();

    // Écrit les champs dans GlobalStorage["adjoin"] pour que le module job
    // "adjoinjob" (phase exec) puisse les lire. Appelé depuis
    // ADJoinQmlViewStep::onLeave().
    void commitToGlobalStorage();

    // Recharge le .qm correspondant à la langue active de Calamares si elle a
    // changé depuis le dernier appel, et émet translationsChanged() le cas
    // échéant. Appelé par ADJoinQmlViewStep à plusieurs points d'entrée
    // (constructeur, prettyName(), getConfig(), onActivate()) car les vues
    // Calamares sont construites avant que l'utilisateur ait choisi une
    // langue - voir le .cpp pour le détail complet.
    void retranslate();

signals:
    void enabledChanged( bool enabled );
    void domainChanged( QString domain );
    void ouChanged( QString ou );
    void adminUserChanged( QString adminUser );
    void adminPasswordChanged( QString adminPassword );
    void computerNameChanged( QString computerName );
    void validityChanged( bool isValid );
    void translationsChanged();

private:
    bool m_enabled = false;
    QString m_domain;
    QString m_ou;
    QString m_adminUser;
    QString m_adminPassword;
    QString m_computerName;
    QString m_loadedLangCode;
};
