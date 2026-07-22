#include "Config.h"

#include "GlobalStorage.h"
#include "JobQueue.h"

#include <QCoreApplication>
#include <QFile>
#include <QLocale>
#include <QTranslator>
#include <QVariantMap>

Config::Config( QObject* parent )
    : QObject( parent )
{
    retranslate();
}

QString
Config::pageTitle() const
{
    return tr( "Join Active Directory Domain" );
}

QString
Config::pageDescription() const
{
    return tr( "Optional: if this computer should join a Windows Active Directory domain, "
               "fill in the details below. You can always do this later after installation "
               "with the 'realm join' command." );
}

QString
Config::joinCheckboxText() const
{
    return tr( "Join an Active Directory domain during installation" );
}

QString
Config::domainLabel() const
{
    return tr( "Domain (e.g. example.local)" );
}

QString
Config::domainPlaceholder() const
{
    return tr( "example.local" );
}

QString
Config::ouLabel() const
{
    return tr( "Organizational unit (optional)" );
}

QString
Config::ouPlaceholder() const
{
    return tr( "OU=Workstations,DC=example,DC=local" );
}

QString
Config::adminUserLabel() const
{
    return tr( "Domain admin username" );
}

QString
Config::adminUserPlaceholder() const
{
    return tr( "administrator" );
}

QString
Config::adminPasswordLabel() const
{
    return tr( "Domain admin password" );
}

QString
Config::computerNameLabel() const
{
    return tr( "This computer's name" );
}

QString
Config::validationErrorText() const
{
    return tr( "Domain, admin username, password, and computer name are all required to continue." );
}

QString
Config::retryNoteText() const
{
    return tr( "If the join fails, installation continues normally: you can retry manually "
               "after the first boot." );
}

void
Config::retranslate()
{
    // Voir Config.h : ce module hors-arbre n'a pas accès au système de
    // traduction interne de Calamares (calamares_qrc_translations), et le
    // QQmlEngine "nu" qu'il utilise (pas QQmlApplicationEngine) ne
    // ré-évalue pas automatiquement les qsTr() QML après l'installation
    // d'un nouveau QTranslator - d'où l'exposition de tous les textes en
    // Q_PROPERTY ci-dessus, rebindées via translationsChanged() plutôt que
    // via la retraduction QML automatique.
    //
    // Le module "welcome" écrit la langue choisie dans GlobalStorage["LANG"]
    // (voir Calamares::Locale::insertGS dans src/modules/welcome/Config.cpp)
    // - c'est la source la plus fiable. QLocale() sert de repli si
    // GlobalStorage n'est pas encore renseigné (les vues sont construites
    // avant que l'utilisateur n'ait rien choisi sur la page Bienvenue).
    QString lang;
    if ( auto* jq = Calamares::JobQueue::instance() )
    {
        if ( auto* gs = jq->globalStorage() )
        {
            lang = gs->value( "LANG" ).toString();
        }
    }
    if ( lang.isEmpty() )
    {
        lang = QLocale().name();
    }
    lang = lang.section( '_', 0, 0 ).section( '.', 0, 0 );  // "fr_FR.UTF-8" -> "fr"

    if ( lang.isEmpty() || lang == m_loadedLangCode )
    {
        return;  // déjà à jour (ou rien à faire)
    }

    if ( lang == QStringLiteral( "en" ) )
    {
        m_loadedLangCode = lang;
        emit translationsChanged();
        return;  // anglais = langue source, rien à charger
    }

    const QString qmPath = QStringLiteral( "/usr/lib/calamares/modules/adjoinview/translations/adjoinview_%1.qm" )
                                .arg( lang );
    if ( !QFile::exists( qmPath ) )
    {
        m_loadedLangCode = lang;  // pas de traduction pour cette langue - inutile de réessayer
        return;
    }

    auto* translator = new QTranslator( qApp );
    if ( translator->load( qmPath ) )
    {
        qApp->installTranslator( translator );
        m_loadedLangCode = lang;
        emit translationsChanged();
    }
    else
    {
        translator->deleteLater();
    }
}

bool
Config::isValid() const
{
    if ( !m_enabled )
    {
        return true;  // étape sautée, rien à valider
    }
    return !m_domain.trimmed().isEmpty() && !m_adminUser.trimmed().isEmpty() && !m_adminPassword.isEmpty()
        && !m_computerName.trimmed().isEmpty();
}

void
Config::setEnabled( bool enabled )
{
    if ( m_enabled != enabled )
    {
        m_enabled = enabled;
        emit enabledChanged( m_enabled );
        emit validityChanged( isValid() );
    }
}

void
Config::setDomain( const QString& domain )
{
    if ( m_domain != domain )
    {
        m_domain = domain;
        emit domainChanged( m_domain );
        emit validityChanged( isValid() );
    }
}

void
Config::setOu( const QString& ou )
{
    if ( m_ou != ou )
    {
        m_ou = ou;
        emit ouChanged( m_ou );
    }
}

void
Config::setAdminUser( const QString& adminUser )
{
    if ( m_adminUser != adminUser )
    {
        m_adminUser = adminUser;
        emit adminUserChanged( m_adminUser );
        emit validityChanged( isValid() );
    }
}

void
Config::setAdminPassword( const QString& adminPassword )
{
    if ( m_adminPassword != adminPassword )
    {
        m_adminPassword = adminPassword;
        emit adminPasswordChanged( m_adminPassword );
        emit validityChanged( isValid() );
    }
}

void
Config::setComputerName( const QString& computerName )
{
    if ( m_computerName != computerName )
    {
        m_computerName = computerName;
        emit computerNameChanged( m_computerName );
        emit validityChanged( isValid() );
    }
}

void
Config::prefillComputerName()
{
    if ( !m_computerName.isEmpty() )
    {
        return;  // l'utilisateur (ou un appel précédent) a déjà une valeur
    }
    auto* gs = Calamares::JobQueue::instance()->globalStorage();
    if ( gs && gs->contains( "hostname" ) )
    {
        setComputerName( gs->value( "hostname" ).toString() );
    }
}

void
Config::commitToGlobalStorage()
{
    QVariantMap adjoin;
    adjoin.insert( "enabled", m_enabled );
    adjoin.insert( "domain", m_domain.trimmed() );
    adjoin.insert( "ou", m_ou.trimmed() );
    adjoin.insert( "adminUser", m_adminUser.trimmed() );
    adjoin.insert( "adminPassword", m_adminPassword );
    adjoin.insert( "computerName", m_computerName.trimmed() );

    auto* gs = Calamares::JobQueue::instance()->globalStorage();
    if ( gs )
    {
        gs->insert( "adjoin", adjoin );
    }
}
