#include "karakeepapi.h"
#include "karakeeptypes.h"

#include <QBuffer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkRequest>
#include <QUrlQuery>

// ── Construction ─────────────────────────────────────────────────────────────

KarakeepApi::KarakeepApi(AppSettings *settings, QObject *parent)
    : QObject(parent)
    , m_settings(settings)
{
    m_nam.setParent(this);
}

// ── Public state ──────────────────────────────────────────────────────────────

bool KarakeepApi::busy() const
{
    return m_pending > 0;
}

// ── Connectivity ─────────────────────────────────────────────────────────────

void KarakeepApi::whoAmI()
{
    QNetworkReply *reply = get("/users/me");
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "whoAmI");
            return;
        }
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        emit whoAmIFetched(KarakeepUser::fromJson(obj).toVariantMap());
    });
}

// ── Bookmarks ────────────────────────────────────────────────────────────────

void KarakeepApi::fetchBookmarks(const QString &cursor,
                                  int            limit,
                                  bool           archived,
                                  bool           favourited,
                                  const QString &search)
{
    // Full-text search uses a dedicated endpoint; the bookmarks list endpoint
    // ignores unknown query parameters and always returns unfiltered results.
    QVariantMap params;
    params["limit"] = limit;
    if (!cursor.isEmpty())
        params["cursor"] = cursor;

    QString path;
    if (!search.isEmpty()) {
        path = "/bookmarks/search";
        params["q"] = search;
    } else {
        path = "/bookmarks";
        if (archived)
            params["archived"] = true;
        if (favourited)
            params["favourited"] = true;
    }

    QNetworkReply *reply = get(path, params);
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "fetchBookmarks");
            return;
        }
        const QJsonObject root  = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonArray  items = root.value("bookmarks").toArray();
        const QString     next  = root.value("nextCursor").toString();

        QVariantList bookmarks;
        for (const QJsonValue &v : items)
            bookmarks.append(Bookmark::fromJson(v.toObject()).toVariantMap());

        emit bookmarksFetched(bookmarks, next);
    });
}

void KarakeepApi::fetchBookmark(const QString &id)
{
    QNetworkReply *reply = get("/bookmarks/" + id);
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "fetchBookmark");
            return;
        }
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        emit bookmarkFetched(Bookmark::fromJson(obj).toVariantMap());
    });
}

void KarakeepApi::createLinkBookmark(const QString     &url,
                                      const QString     &title,
                                      const QStringList &tagNames)
{
    QJsonObject body;
    body["type"]   = "link";
    body["url"]    = url;
    body["source"] = "mobile";
    if (!title.isEmpty())
        body["title"] = title;

    QNetworkReply *reply = post("/bookmarks", body);
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply, tagNames](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "createLinkBookmark");
            return;
        }
        const QJsonObject obj      = QJsonDocument::fromJson(reply->readAll()).object();
        const QVariantMap bookmark = Bookmark::fromJson(obj).toVariantMap();
        if (!tagNames.isEmpty()) {
            attachTagsAfterCreate(bookmark, tagNames);
        } else {
            emit bookmarkCreated(bookmark);
        }
    });
}

void KarakeepApi::createTextBookmark(const QString     &text,
                                      const QString     &title,
                                      const QStringList &tagNames)
{
    QJsonObject body;
    body["type"]   = "text";
    body["text"]   = text;
    body["source"] = "mobile";
    if (!title.isEmpty())
        body["title"] = title;

    QNetworkReply *reply = post("/bookmarks", body);
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply, tagNames](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "createTextBookmark");
            return;
        }
        const QJsonObject obj      = QJsonDocument::fromJson(reply->readAll()).object();
        const QVariantMap bookmark = Bookmark::fromJson(obj).toVariantMap();
        if (!tagNames.isEmpty()) {
            attachTagsAfterCreate(bookmark, tagNames);
        } else {
            emit bookmarkCreated(bookmark);
        }
    });
}

void KarakeepApi::updateBookmark(const QString     &id,
                                  const QVariantMap &fields)
{
    QJsonObject body;
    for (auto it = fields.constBegin(); it != fields.constEnd(); ++it)
        body.insert(it.key(), QJsonValue::fromVariant(it.value()));

    QNetworkReply *reply = patch("/bookmarks/" + id, body);
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "updateBookmark");
            return;
        }
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        emit bookmarkUpdated(Bookmark::fromJson(obj).toVariantMap());
    });
}

void KarakeepApi::deleteBookmark(const QString &id)
{
    QNetworkReply *reply = deleteResource("/bookmarks/" + id);
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply, id](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "deleteBookmark");
            return;
        }
        emit bookmarkDeleted(id);
    });
}

// ── Tag attachment ────────────────────────────────────────────────────────────

static QJsonObject makeTagsBody(const QStringList &tagNames)
{
    QJsonArray arr;
    for (const QString &name : tagNames) {
        QJsonObject t;
        t["tagName"]    = name;
        t["attachedBy"] = "human";
        arr.append(t);
    }
    QJsonObject body;
    body["tags"] = arr;
    return body;
}

void KarakeepApi::attachTags(const QString &bookmarkId, const QStringList &tagNames)
{
    QNetworkReply *reply = post("/bookmarks/" + bookmarkId + "/tags", makeTagsBody(tagNames));
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply, bookmarkId](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "attachTags");
            return;
        }
        emit tagsAttached(bookmarkId);
    });
}

void KarakeepApi::detachTags(const QString &bookmarkId, const QStringList &tagNames)
{
    QNetworkReply *reply = deleteResource("/bookmarks/" + bookmarkId + "/tags", makeTagsBody(tagNames));
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply, bookmarkId](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "detachTags");
            return;
        }
        emit tagsDetached(bookmarkId);
    });
}

// ── Lists ─────────────────────────────────────────────────────────────────────

void KarakeepApi::fetchLists()
{
    QNetworkReply *reply = get("/lists");
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "fetchLists");
            return;
        }
        const QJsonArray items = QJsonDocument::fromJson(reply->readAll())
                                     .object()
                                     .value("lists")
                                     .toArray();
        QVariantList lists;
        for (const QJsonValue &v : items)
            lists.append(BookmarkList::fromJson(v.toObject()).toVariantMap());

        emit listsFetched(lists);
    });
}

void KarakeepApi::fetchListBookmarks(const QString &listId,
                                      const QString &cursor,
                                      int            limit)
{
    QVariantMap params;
    params["limit"] = limit;
    if (!cursor.isEmpty())
        params["cursor"] = cursor;

    QNetworkReply *reply = get("/lists/" + listId + "/bookmarks", params);
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply, listId](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "fetchListBookmarks");
            return;
        }
        const QJsonObject root  = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonArray  items = root.value("bookmarks").toArray();
        const QString     next  = root.value("nextCursor").toString();

        QVariantList bookmarks;
        for (const QJsonValue &v : items)
            bookmarks.append(Bookmark::fromJson(v.toObject()).toVariantMap());

        emit listBookmarksFetched(listId, bookmarks, next);
    });
}

// ── Tags ──────────────────────────────────────────────────────────────────────

void KarakeepApi::fetchTags(const QString &nameContains, int limit)
{
    QVariantMap params;
    params["limit"] = limit;
    params["sort"]  = "name";
    if (!nameContains.isEmpty())
        params["nameContains"] = nameContains;

    QNetworkReply *reply = get("/tags", params);
    connect(&m_nam, &QNetworkAccessManager::finished, reply, [this, reply](QNetworkReply *r) {
        if (r != reply) return;
        reply->deleteLater();
        setBusy(false);
        if (reply->error() != QNetworkReply::NoError) {
            handleReplyError(reply, "fetchTags");
            return;
        }
        const QJsonArray items = QJsonDocument::fromJson(reply->readAll())
                                     .object()
                                     .value("tags")
                                     .toArray();
        QVariantList tags;
        for (const QJsonValue &v : items)
            tags.append(Tag::fromJson(v.toObject()).toVariantMap());

        emit tagsFetched(tags);
    });
}

// ── Private helpers ───────────────────────────────────────────────────────────

QUrl KarakeepApi::buildUrl(const QString &path, const QVariantMap &params) const
{
    QString base = m_settings->serverUrl();
    if (base.endsWith('/'))
        base.chop(1);

    QUrl url(base + "/api/v1" + path);

    if (!params.isEmpty()) {
        QUrlQuery query;
        for (auto it = params.constBegin(); it != params.constEnd(); ++it)
            query.addQueryItem(it.key(), it.value().toString());
        url.setQuery(query);
    }
    return url;
}

QNetworkRequest KarakeepApi::authenticatedRequest(const QUrl &url) const
{
    QNetworkRequest req(url);
    req.setRawHeader("Authorization",
                     QByteArray("Bearer ") + m_settings->apiKey().toUtf8());
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    // Disable keep-alive: Qt 5.6 QNAM silently hangs when reusing a connection
    // the server has already closed. Acceptable cost for a mobile app.
    req.setRawHeader("Connection", "close");
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    return req;
}

QNetworkReply *KarakeepApi::get(const QString &path, const QVariantMap &params)
{
    setBusy(true);
    return m_nam.get(authenticatedRequest(buildUrl(path, params)));
}

QNetworkReply *KarakeepApi::post(const QString &path, const QJsonObject &body)
{
    setBusy(true);
    return m_nam.post(authenticatedRequest(buildUrl(path)),
                      QJsonDocument(body).toJson(QJsonDocument::Compact));
}

QNetworkReply *KarakeepApi::patch(const QString &path, const QJsonObject &body)
{
    setBusy(true);
    QNetworkRequest req = authenticatedRequest(buildUrl(path));
    return sendWithBody("PATCH", req, QJsonDocument(body).toJson(QJsonDocument::Compact));
}

QNetworkReply *KarakeepApi::deleteResource(const QString     &path,
                                            const QJsonObject &body)
{
    setBusy(true);
    if (body.isEmpty()) {
        return m_nam.deleteResource(authenticatedRequest(buildUrl(path)));
    }
    // DELETE with body (used for detaching tags)
    QNetworkRequest req = authenticatedRequest(buildUrl(path));
    return sendWithBody("DELETE", req, QJsonDocument(body).toJson(QJsonDocument::Compact));
}

QNetworkReply *KarakeepApi::sendWithBody(const QByteArray      &verb,
                                          const QNetworkRequest &req,
                                          const QByteArray      &data)
{
    // Qt 5.6 sendCustomRequest requires a QIODevice*, not a QByteArray directly
    QBuffer *buf = new QBuffer;
    buf->setData(data);
    buf->open(QIODevice::ReadOnly);
    QNetworkReply *reply = m_nam.sendCustomRequest(req, verb, buf);
    buf->setParent(reply); // buffer lifetime tied to reply
    return reply;
}

void KarakeepApi::handleReplyError(QNetworkReply *reply, const QString &operation)
{
    int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();

    // Try to extract a server-provided message from the JSON body
    QString message;
    const QByteArray responseBody = reply->readAll();
    if (!responseBody.isEmpty()) {
        const QJsonObject err = QJsonDocument::fromJson(responseBody).object();
        message = err.value("message").toString();
    }
    if (message.isEmpty())
        message = reply->errorString();

    emit requestError(operation, httpStatus, message);
}

void KarakeepApi::setBusy(bool increment)
{
    const bool wasBusy = busy();
    m_pending += increment ? 1 : -1;
    if (m_pending < 0) m_pending = 0;
    if (busy() != wasBusy)
        emit busyChanged();
}

void KarakeepApi::attachTagsAfterCreate(const QVariantMap &bookmark,
                                         const QStringList &tagNames)
{
    const QString id = bookmark.value("id").toString();

    QNetworkReply *tagReply = post("/bookmarks/" + id + "/tags", makeTagsBody(tagNames));
    connect(&m_nam, &QNetworkAccessManager::finished, tagReply, [this, tagReply, id, bookmark](QNetworkReply *r) {
        if (r != tagReply) return;
        tagReply->deleteLater();
        setBusy(false);
        if (tagReply->error() != QNetworkReply::NoError) {
            // Tag attach failed; bookmark was still created — emit with original data
            handleReplyError(tagReply, "attachTagsAfterCreate");
            emit bookmarkCreated(bookmark);
            return;
        }
        // Re-fetch the bookmark so the emitted map includes the newly attached tags
        QNetworkReply *fetchReply = get("/bookmarks/" + id);
        connect(&m_nam, &QNetworkAccessManager::finished, fetchReply, [this, fetchReply, bookmark](QNetworkReply *r2) {
            if (r2 != fetchReply) return;
            fetchReply->deleteLater();
            setBusy(false);
            if (fetchReply->error() != QNetworkReply::NoError) {
                // Fetch failed — report error but still emit with pre-tag data
                handleReplyError(fetchReply, "attachTagsAfterCreate");
                emit bookmarkCreated(bookmark);
                return;
            }
            const QJsonObject obj = QJsonDocument::fromJson(fetchReply->readAll()).object();
            emit bookmarkCreated(Bookmark::fromJson(obj).toVariantMap());
        });
    });
}
