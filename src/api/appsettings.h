#pragma once

#include <QObject>
#include <QSettings>

class AppSettings : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(QString apiKey   READ apiKey    WRITE setApiKey    NOTIFY apiKeyChanged)
    Q_PROPERTY(bool configured  READ isConfigured                 NOTIFY configuredChanged)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString serverUrl() const;
    void    setServerUrl(const QString &url);

    QString apiKey() const;
    void    setApiKey(const QString &key);

    // Returns true when both serverUrl and apiKey are non-empty
    bool isConfigured() const;

signals:
    void serverUrlChanged();
    void apiKeyChanged();
    void configuredChanged();

private:
    QSettings m_settings;
};
