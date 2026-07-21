#include "ADJoinQmlViewStep.h"

CALAMARES_PLUGIN_FACTORY_DEFINITION( ADJoinQmlViewStepFactory, registerPlugin< ADJoinQmlViewStep >(); )

ADJoinQmlViewStep::ADJoinQmlViewStep( QObject* parent )
    : Calamares::QmlViewStep( parent )
    , m_config( new Config( this ) )
{
}

QString
ADJoinQmlViewStep::prettyName() const
{
    // Nom affiché dans la barre latérale de Calamares - sans ça, Calamares
    // retombe sur un nom générique du style "QML Step adjoinview.".
    return tr( "Join Active Directory Domain" );
}

void
ADJoinQmlViewStep::setConfigurationMap( const QVariantMap& configurationMap )
{
    // Pas de clés de configuration pour ce module (NO_CONFIG dans
    // CMakeLists.txt) : tout est saisi par l'utilisateur à l'écran.
    Calamares::QmlViewStep::setConfigurationMap( configurationMap );
}

void
ADJoinQmlViewStep::onLeave()
{
    // Quitte la page (Suivant ou Précédent) : on écrit toujours l'état
    // courant dans GlobalStorage, y compris quand l'utilisateur revient en
    // arrière après avoir décoché "enabled".
    m_config->commitToGlobalStorage();
}

bool
ADJoinQmlViewStep::isNextEnabled() const
{
    return m_config->isValid();
}

bool
ADJoinQmlViewStep::isBackEnabled() const
{
    return true;
}

bool
ADJoinQmlViewStep::isAtBeginning() const
{
    return true;
}

bool
ADJoinQmlViewStep::isAtEnd() const
{
    return true;
}

Calamares::JobList
ADJoinQmlViewStep::jobs() const
{
    // Le travail réel ("realm join" en chroot) est fait par le module job
    // Python séparé "adjoinjob" (phase exec), qui lit GlobalStorage["adjoin"].
    return Calamares::JobList();
}

QObject*
ADJoinQmlViewStep::getConfig()
{
    return m_config;
}
