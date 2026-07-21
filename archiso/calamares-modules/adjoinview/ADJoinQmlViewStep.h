/* Module "adjoinview" - page Calamares "Rejoindre un domaine Active Directory".
 * Squelette calqué sur MobileQmlViewStep de calamares-extensions. */
#pragma once

#include "Config.h"

#include "utils/PluginFactory.h"
#include "viewpages/QmlViewStep.h"

#include <DllMacro.h>

#include <QObject>
#include <QVariantMap>

class PLUGINDLLEXPORT ADJoinQmlViewStep : public Calamares::QmlViewStep
{
    Q_OBJECT

public:
    explicit ADJoinQmlViewStep( QObject* parent = nullptr );

    QString prettyName() const override;

    bool isNextEnabled() const override;
    bool isBackEnabled() const override;
    bool isAtBeginning() const override;
    bool isAtEnd() const override;

    Calamares::JobList jobs() const override;

    void setConfigurationMap( const QVariantMap& configurationMap ) override;
    void onLeave() override;
    QObject* getConfig() override;

private:
    Config* m_config;
};

CALAMARES_PLUGIN_FACTORY_DECLARATION( ADJoinQmlViewStepFactory )
