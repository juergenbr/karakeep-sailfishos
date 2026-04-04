#include "appsettings.h"

static const char *KEY_SERVER_URL = "connection/serverUrl";
static const char *KEY_API_KEY    = "connection/apiKey";

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
    , m_settings("harbour-karakeep", "harbour-karakeep")
{
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
    emit apiKeyChanged();
    emit configuredChanged();
}

bool AppSettings::isConfigured() const
{
    return !serverUrl().isEmpty() && !apiKey().isEmpty();
}
