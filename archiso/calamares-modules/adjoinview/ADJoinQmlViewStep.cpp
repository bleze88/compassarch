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
    // retombe sur un nom générique du style "QML Step adjoinview.". Volontairement
    // court (la barre latérale a peu de place) ; le titre complet est dans
    // Config::pageTitle() (voir adjoinview.qml), qui a plus d'espace pour
    // être descriptif.
    //
    // Rappelé ici à chaque fois (voir Config::retranslate()) car les vues
    // Calamares sont toutes construites au démarrage, avant que
    // l'utilisateur n'ait choisi de langue sur la page Bienvenue - Calamares
    // réinterroge prettyName() à chaque rafraîchissement de la barre
    // latérale, ce qui nous donne assez d'occasions de rattraper son choix.
    m_config->retranslate();
    return tr( "Join Domain" );
}

void
ADJoinQmlViewStep::onActivate()
{
    // Appelé quand l'utilisateur arrive sur cette page - dernière occasion,
    // avant affichage du QML, de rattraper un changement de langue (voir
    // Config::retranslate()).
    m_config->retranslate();
    Calamares::QmlViewStep::onActivate();
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
    // Autre occasion de rattraper un changement de langue (voir
    // Config::retranslate()), juste avant que le QML de la page ne soit
    // instancié.
    m_config->retranslate();
    return m_config;
}
