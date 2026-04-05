#pragma once

#include "appsettings.h"

#include <QByteArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class KarakeepApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit KarakeepApi(AppSettings *settings, QObject *parent = nullptr);

    bool busy() const;

public slots:
    // ── Connectivity ────────────────────────────────────────────────────────
    void whoAmI();

    // ── Bookmarks ────────────────────────────────────────────────────────────
    void fetchBookmarks(const QString &cursor   = QString(),
                        int            limit    = 20,
                        bool           archived = false,
                        bool           favourited = false,
                        const QString &search   = QString());

    void fetchBookmark(const QString &id);

    void createLinkBookmark(const QString     &url,
                            const QString     &title    = QString(),
                            const QStringList &tagNames = QStringList());

    void createTextBookmark(const QString     &text,
                            const QString     &title    = QString(),
                            const QStringList &tagNames = QStringList());

    void updateBookmark(const QString     &id,
                        const QVariantMap &fields);

    void deleteBookmark(const QString &id);

    // ── Tags on bookmarks ────────────────────────────────────────────────────
    void attachTags(const QString &bookmarkId, const QStringList &tagNames);
    void detachTags(const QString &bookmarkId, const QStringList &tagNames);

    // ── Lists ────────────────────────────────────────────────────────────────
    void fetchLists();

    void fetchListBookmarks(const QString &listId,
                            const QString &cursor = QString(),
                            int            limit  = 20);

    // ── Tags ─────────────────────────────────────────────────────────────────
    void fetchTags(const QString &nameContains = QString(),
                   int            limit        = 100);

    // ── List membership ───────────────────────────────────────────────────────
    void addBookmarkToList(const QString &listId, const QString &bookmarkId);
    void removeBookmarkFromList(const QString &listId, const QString &bookmarkId);

signals:
    // ── Success ──────────────────────────────────────────────────────────────
    void whoAmIFetched(const QVariantMap &user);

    void bookmarksFetched(const QVariantList &bookmarks,
                          const QString      &nextCursor);

    void bookmarkFetched(const QVariantMap &bookmark);
    void bookmarkCreated(const QVariantMap &bookmark);
    void bookmarkUpdated(const QVariantMap &bookmark);
    void bookmarkDeleted(const QString     &id);

    void tagsAttached(const QString &bookmarkId);
    void tagsDetached(const QString &bookmarkId);

    void listsFetched(const QVariantList &lists);

    void listBookmarksFetched(const QString      &fetchedListId,
                              const QVariantList &bookmarks,
                              const QString      &nextCursor);

    void bookmarkAddedToList(const QString &listId, const QString &bookmarkId);
    void bookmarkRemovedFromList(const QString &listId, const QString &bookmarkId);

    void tagsFetched(const QVariantList &tags);

    // ── Error ─────────────────────────────────────────────────────────────────
    // operation: human-readable name of the failed call
    // httpStatus: HTTP status code (0 = network error, no server response)
    // message: human-readable description
    void requestError(const QString &operation,
                      int            httpStatus,
                      const QString &message);

    // ── State ────────────────────────────────────────────────────────────────
    void busyChanged();

private:
    // Build a full API URL with optional query parameters
    QUrl buildUrl(const QString &path,
                  const QVariantMap &params = QVariantMap()) const;

    // Authenticated GET
    QNetworkReply *get(const QString     &path,
                       const QVariantMap &params = QVariantMap());

    // Authenticated POST / PATCH / DELETE with JSON body
    QNetworkReply *post(const QString  &path,
                        const QJsonObject &body = QJsonObject());
    QNetworkReply *patch(const QString &path,
                         const QJsonObject &body);
    QNetworkReply *deleteResource(const QString     &path,
                                  const QJsonObject &body = QJsonObject());

    QNetworkRequest authenticatedRequest(const QUrl &url) const;

    // Qt 5.6 helper: sendCustomRequest requires a QIODevice*
    QNetworkReply *sendWithBody(const QByteArray      &verb,
                                const QNetworkRequest &req,
                                const QByteArray      &data);

    // Extract error details from a finished reply; emits requestError
    void handleReplyError(QNetworkReply *reply, const QString &operation);

    void setBusy(bool b);

    // Create a bookmark then attach tags; used by createLink/Text helpers
    void attachTagsAfterCreate(const QVariantMap &bookmark,
                               const QStringList &tagNames);

    AppSettings          *m_settings;
    QNetworkAccessManager m_nam;
    int                   m_pending = 0;
};
