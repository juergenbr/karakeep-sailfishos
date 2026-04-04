#pragma once

#include <QDateTime>
#include <QJsonArray>
#include <QJsonObject>
#include <QRegExp>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

// Qt 5.6 does not support ISO 8601 timestamps with milliseconds via Qt::ISODate.
// Strip sub-second precision and timezone suffix before parsing.
static inline QDateTime parseIsoDateTime(const QString &s)
{
    QString t = s;
    // Remove trailing Z or +HH:MM / -HH:MM offset
    const int plusMinus = t.lastIndexOf(QRegExp("[+-](?=\\d{2}:\\d{2}$)"));
    if (plusMinus != -1)
        t.truncate(plusMinus);
    else if (t.endsWith('Z'))
        t.chop(1);
    // Remove milliseconds (.NNN)
    const int dot = t.lastIndexOf('.');
    if (dot != -1)
        t.truncate(dot);
    QDateTime dt = QDateTime::fromString(t, Qt::ISODate);
    dt.setTimeSpec(Qt::UTC);
    return dt;
}

// ── Tag ──────────────────────────────────────────────────────────────────────

struct BookmarkTag {
    QString id;
    QString name;
    QString attachedBy; // "ai" | "human"

    static BookmarkTag fromJson(const QJsonObject &o) {
        BookmarkTag t;
        t.id         = o.value("id").toString();
        t.name       = o.value("name").toString();
        t.attachedBy = o.value("attachedBy").toString();
        return t;
    }

    QVariantMap toVariantMap() const {
        return {{"id", id}, {"name", name}, {"attachedBy", attachedBy}};
    }
};

struct Tag {
    QString id;
    QString name;
    int numBookmarks = 0;

    static Tag fromJson(const QJsonObject &o) {
        Tag t;
        t.id           = o.value("id").toString();
        t.name         = o.value("name").toString();
        t.numBookmarks = o.value("numBookmarks").toInt();
        return t;
    }

    QVariantMap toVariantMap() const {
        return {{"id", id}, {"name", name}, {"numBookmarks", numBookmarks}};
    }
};

// ── Bookmark ─────────────────────────────────────────────────────────────────

struct Bookmark {
    QString   id;
    QString   title;
    bool      archived   = false;
    bool      favourited = false;
    QDateTime createdAt;
    QDateTime modifiedAt;
    QString   note;
    QString   summary;
    QList<BookmarkTag> tags;

    // Content type: "link" | "text" | "asset" | "unknown"
    QString type;

    // Link content
    QString url;
    QString description;
    QString imageUrl;
    QString favicon;
    QString crawlStatus;
    QString author;
    QString publisher;

    // Text content
    QString text;

    static Bookmark fromJson(const QJsonObject &o) {
        Bookmark b;
        b.id           = o.value("id").toString();
        b.title        = o.value("title").toString();
        b.archived     = o.value("archived").toBool();
        b.favourited   = o.value("favourited").toBool();
        b.note         = o.value("note").toString();
        b.summary      = o.value("summary").toString();
        b.createdAt    = parseIsoDateTime(o.value("createdAt").toString());
        b.modifiedAt   = parseIsoDateTime(o.value("modifiedAt").toString());

        const QJsonArray tagsArr = o.value("tags").toArray();
        for (const QJsonValue &v : tagsArr)
            b.tags.append(BookmarkTag::fromJson(v.toObject()));

        const QJsonObject content = o.value("content").toObject();
        b.type = content.value("type").toString();
        if (b.type == QLatin1String("link")) {
            b.url         = content.value("url").toString();
            b.description = content.value("description").toString();
            b.imageUrl    = content.value("imageUrl").toString();
            b.favicon     = content.value("favicon").toString();
            b.crawlStatus = content.value("crawlStatus").toString();
            b.author      = content.value("author").toString();
            b.publisher   = content.value("publisher").toString();
        } else if (b.type == QLatin1String("text")) {
            b.text = content.value("text").toString();
        }
        return b;
    }

    QVariantMap toVariantMap() const {
        QVariantList tagList;
        for (const BookmarkTag &t : tags)
            tagList.append(t.toVariantMap());

        return {
            {"id",          id},
            {"title",       title},
            {"archived",    archived},
            {"favourited",  favourited},
            {"createdAt",   createdAt.toString(Qt::ISODate)},
            {"modifiedAt",  modifiedAt.toString(Qt::ISODate)},
            {"note",        note},
            {"summary",     summary},
            {"tags",        tagList},
            {"type",        type},
            {"url",         url},
            {"description", description},
            {"imageUrl",    imageUrl},
            {"favicon",     favicon},
            {"crawlStatus", crawlStatus},
            {"author",      author},
            {"publisher",   publisher},
            {"text",        text},
        };
    }
};

// ── List ─────────────────────────────────────────────────────────────────────

struct BookmarkList {
    QString id;
    QString name;
    QString description;
    QString icon;
    QString type;    // "manual" | "smart"
    bool    isPublic = false;

    static BookmarkList fromJson(const QJsonObject &o) {
        BookmarkList l;
        l.id          = o.value("id").toString();
        l.name        = o.value("name").toString();
        l.description = o.value("description").toString();
        l.icon        = o.value("icon").toString();
        l.type        = o.value("type").toString();
        l.isPublic    = o.value("public").toBool();
        return l;
    }

    QVariantMap toVariantMap() const {
        return {
            {"id",          id},
            {"name",        name},
            {"description", description},
            {"icon",        icon},
            {"type",        type},
            {"isPublic",    isPublic},
        };
    }
};

// ── User ─────────────────────────────────────────────────────────────────────

struct KarakeepUser {
    QString id;
    QString name;
    QString email;
    QString role;

    static KarakeepUser fromJson(const QJsonObject &o) {
        KarakeepUser u;
        u.id    = o.value("id").toString();
        u.name  = o.value("name").toString();
        u.email = o.value("email").toString();
        u.role  = o.value("role").toString();
        return u;
    }

    QVariantMap toVariantMap() const {
        return {{"id", id}, {"name", name}, {"email", email}, {"role", role}};
    }
};
