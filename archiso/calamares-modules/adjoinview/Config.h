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

public:
    explicit Config( QObject* parent = nullptr );

    bool enabled() const { return m_enabled; }
    QString domain() const { return m_domain; }
    QString ou() const { return m_ou; }
    QString adminUser() const { return m_adminUser; }
    QString adminPassword() const { return m_adminPassword; }
    QString computerName() const { return m_computerName; }
    bool isValid() const;

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

signals:
    void enabledChanged( bool enabled );
    void domainChanged( QString domain );
    void ouChanged( QString ou );
    void adminUserChanged( QString adminUser );
    void adminPasswordChanged( QString adminPassword );
    void computerNameChanged( QString computerName );
    void validityChanged( bool isValid );

private:
    bool m_enabled = false;
    QString m_domain;
    QString m_ou;
    QString m_adminUser;
    QString m_adminPassword;
    QString m_computerName;
};
