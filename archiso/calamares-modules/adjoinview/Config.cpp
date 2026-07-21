#include "Config.h"

#include "GlobalStorage.h"
#include "JobQueue.h"

#include <QVariantMap>

Config::Config( QObject* parent )
    : QObject( parent )
{
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
