#include "appsettings.h"
#include <QProcessEnvironment>
#include <QStandardPaths>

static const char *KEY_SERVER_URL = "connection/serverUrl";
static const char *KEY_API_KEY    = "connection/apiKey";

// Must match [X-Sailjail] OrganizationName/ApplicationName in harbour-karakeep.desktop.
// Sailjail whitelists (and pre-creates) the directory
//   $HOME/.config/<OrganizationName>/<ApplicationName>/
// but not sibling files such as the default QSettings file
//   $HOME/.config/<OrganizationName>/<ApplicationName>.conf
// which only exist in the sandbox tmpfs overlay and are lost when the app exits.
static const char *ORGANIZATION_NAME = "org.karakeep";
static const char *APPLICATION_NAME  = "KaraKeep";

static QString settingsFilePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
            + QLatin1Char('/') + QLatin1String(ORGANIZATION_NAME)
            + QLatin1Char('/') + QLatin1String(APPLICATION_NAME)
            + QLatin1String("/settings.conf");
}

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_settings(settingsFilePath(), QSettings::NativeFormat)
{
    // Seed from env vars on first run (debug convenience)
    const QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    if (m_settings.value(KEY_SERVER_URL).toString().isEmpty()) {
        const QString envUrl = env.value("KARAKEEP_URL");
        if (!envUrl.isEmpty())
            m_settings.setValue(KEY_SERVER_URL, envUrl);
    }
    if (m_settings.value(KEY_API_KEY).toString().isEmpty()) {
        QString envKey = env.value("KARAKEEP_API_KEY");
        if (envKey.isEmpty())
            envKey = env.value("KARAKEEP_KEY");
        if (!envKey.isEmpty())
            m_settings.setValue(KEY_API_KEY, envKey);
    }
    m_settings.sync();
}

QString AppSettings::serverUrl() const
{
    return m_settings.value(KEY_SERVER_URL).toString();
}

void AppSettings::setServerUrl(const QString &url)
{
    if (serverUrl() == url)
        return;
    m_settings.setValue(KEY_SERVER_URL, url);
    m_settings.sync();
    emit serverUrlChanged();
    emit configuredChanged();
}

QString AppSettings::apiKey() const
{
    return m_settings.value(KEY_API_KEY).toString();
}

void AppSettings::setApiKey(const QString &key)
{
    if (apiKey() == key)
        return;
    m_settings.setValue(KEY_API_KEY, key);
    m_settings.sync();
    emit apiKeyChanged();
    emit configuredChanged();
}

bool AppSettings::isConfigured() const
{
    return !serverUrl().isEmpty() && !apiKey().isEmpty();
}
