#include "../src/api/appsettings.h"
#include "../src/api/karakeepapi.h"

#include <QSignalSpy>
#include <QTest>
#include <functional>

// ── Helpers ──────────────────────────────────────────────────────────────────

static const char *SERVER_URL   = "https://hoarder.breitenbaumer.com";
static const int   TIMEOUT_MS   = 15000;
static const char *TEST_TAG     = "__sailfish_test__";
static const char *TEST_URL     = "https://example.com/sailfish-test-bookmark";
static const char *TEST_TEXT    = "SailfishOS test text note __sailfish_test__";

// Wait for exactly one emission from a spy, with timeout.
// Returns false and prints a diagnostic on timeout.
static bool waitForSignal(QSignalSpy &spy, int ms = TIMEOUT_MS)
{
    if (spy.isEmpty() && !spy.wait(ms)) {
        qWarning() << "Signal" << spy.signal() << "not received within" << ms << "ms";
        return false;
    }
    return true;
}

// RAII scope guard — runs a cleanup function when it goes out of scope.
struct ScopeGuard {
    std::function<void()> fn;
    ~ScopeGuard() { if (fn) fn(); }
};

// ── Test class ───────────────────────────────────────────────────────────────

class TestKarakeepApi : public QObject
{
    Q_OBJECT

private slots:
    // ── Suite setup / teardown ───────────────────────────────────────────────
    void initTestCase();
    void cleanupTestCase();

    // ── Per-test setup / teardown (fresh API instance each test) ────────────
    void init();
    void cleanup();

    // ── Direct network diagnostic ────────────────────────────────────────────
    void testDirectFetchBookmarks();

    // ── Connectivity ────────────────────────────────────────────────────────
    void testWhoAmI();
    void testWhoAmIBadKey();

    // ── Bookmarks (read) ────────────────────────────────────────────────────
    void testFetchBookmarks();
    void testFetchBookmarksPagination();
    void testFetchBookmarkById();
    void testFetchBookmarkByIdNotFound();

    // ── Bookmarks (write + cleanup) ──────────────────────────────────────────
    void testCreateAndDeleteLinkBookmark();
    void testCreateAndDeleteTextBookmark();
    void testCreateLinkBookmarkWithTags();
    void testUpdateBookmark();

    // ── Tag attachment ───────────────────────────────────────────────────────
    void testAttachAndDetachTags();

    // ── Lists ────────────────────────────────────────────────────────────────
    void testFetchLists();
    void testAddAndRemoveBookmarkFromList();

    // ── Search ───────────────────────────────────────────────────────────────
    void testSearchBookmarks();

    // ── Tags ─────────────────────────────────────────────────────────────────
    void testFetchTags();
    void testFetchTagsFiltered();

private:
    // Create a bookmark and return its id. Fails the test if creation fails.
    QString createTestLinkBookmark(const QString &url  = TEST_URL,
                                   const QString &title = "Sailfish Test");

    // Delete a bookmark and verify. Fails the test if deletion fails.
    void deleteTestBookmark(const QString &id);

    AppSettings  *m_settings = nullptr;
    KarakeepApi  *m_api      = nullptr;
    QString       m_apiKey;
};

// ── initTestCase / cleanupTestCase ───────────────────────────────────────────

void TestKarakeepApi::initTestCase()
{
    const QString apiKey = qgetenv("KARAKEEP_API_KEY");
    QVERIFY2(!apiKey.isEmpty(),
             "Set KARAKEEP_API_KEY environment variable before running tests.");

    m_apiKey = apiKey;

    m_settings = new AppSettings(this);
    m_settings->setServerUrl(SERVER_URL);
    m_settings->setApiKey(m_apiKey);

    QVERIFY(m_settings->isConfigured());
}

void TestKarakeepApi::cleanupTestCase()
{
    // Nothing extra — each write test cleans up after itself.
}

void TestKarakeepApi::init()
{
    // Restore real API key: testWhoAmIBadKey writes to the shared QSettings cache,
    // which is shared by all AppSettings instances with the same org/app name.
    m_settings->setApiKey(m_apiKey);

    // Fresh KarakeepApi per test: avoids Qt 5.6 stale keep-alive connection hangs
    m_api = new KarakeepApi(m_settings, this);
}

void TestKarakeepApi::cleanup()
{
    delete m_api;
    m_api = nullptr;
}

// ── Direct network diagnostic ─────────────────────────────────────────────────

void TestKarakeepApi::testDirectFetchBookmarks()
{
    // Bypass KarakeepApi entirely — test raw QNAM to isolate Qt vs. code issues
    QNetworkAccessManager nam;
    QNetworkRequest req(QUrl(QString("%1/api/v1/bookmarks?limit=3").arg(SERVER_URL)));
    req.setRawHeader("Authorization",
        QByteArray("Bearer ") + m_apiKey.toUtf8());
    req.setRawHeader("Connection", "close");

    QSignalSpy spy(&nam, SIGNAL(finished(QNetworkReply*)));
    QNetworkReply *reply = nam.get(req);

    qDebug() << "Direct GET:" << reply->url().toString();

    bool ok = spy.wait(15000);
    qDebug() << "Finished fired:" << ok
             << "error:" << reply->error()
             << "status:" << reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt()
             << "bytes:" << reply->bytesAvailable();

    QVERIFY(ok);
    QCOMPARE(reply->error(), QNetworkReply::NoError);
    reply->deleteLater();
}

// ── Connectivity ─────────────────────────────────────────────────────────────

void TestKarakeepApi::testWhoAmI()
{
    QSignalSpy okSpy(m_api, &KarakeepApi::whoAmIFetched);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->whoAmI();

    QVERIFY(waitForSignal(okSpy));
    QCOMPARE(errSpy.count(), 0);

    const QVariantMap user = okSpy.first().first().toMap();
    QVERIFY(!user.value("id").toString().isEmpty());
}

void TestKarakeepApi::testWhoAmIBadKey()
{
    AppSettings badSettings;
    badSettings.setServerUrl(SERVER_URL);
    badSettings.setApiKey("ak2_invalid_key_for_test");
    KarakeepApi badApi(&badSettings);

    QSignalSpy errSpy(&badApi, &KarakeepApi::requestError);
    badApi.whoAmI();

    QVERIFY(waitForSignal(errSpy));
    const int httpStatus = errSpy.first().at(1).toInt();
    QCOMPARE(httpStatus, 401);
}

// ── Bookmarks (read) ─────────────────────────────────────────────────────────

void TestKarakeepApi::testFetchBookmarks()
{
    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarksFetched);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->fetchBookmarks();

    QVERIFY(waitForSignal(okSpy));
    QCOMPARE(errSpy.count(), 0);

    // bookmarksFetched(QVariantList, QString)
    const QVariantList bookmarks = okSpy.first().at(0).toList();
    QVERIFY(bookmarks.count() >= 0); // could legitimately be empty

    // Each item must have an "id" field
    for (const QVariant &v : bookmarks) {
        const QVariantMap bm = v.toMap();
        QVERIFY(!bm.value("id").toString().isEmpty());
    }
}

void TestKarakeepApi::testFetchBookmarksPagination()
{
    // Request only 2 items; if nextCursor is set we know pagination works
    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarksFetched);
    m_api->fetchBookmarks(QString(), 2);
    QVERIFY(waitForSignal(okSpy));

    const QVariantList page1  = okSpy.first().at(0).toList();
    const QString      cursor = okSpy.first().at(1).toString();

    // If there are 2 or more bookmarks total, we should get a cursor
    if (page1.count() == 2) {
        QVERIFY(!cursor.isEmpty());

        // Fetch second page
        okSpy.clear();
        m_api->fetchBookmarks(cursor, 2);
        QVERIFY(waitForSignal(okSpy));
        // No assertion on count — there may or may not be more items
    }
}

void TestKarakeepApi::testFetchBookmarkById()
{
    // Fetch the first bookmark from the list, then fetch it by id
    QSignalSpy listSpy(m_api, &KarakeepApi::bookmarksFetched);
    m_api->fetchBookmarks(QString(), 1);
    QVERIFY(waitForSignal(listSpy));

    const QVariantList bookmarks = listSpy.first().at(0).toList();
    if (bookmarks.isEmpty()) {
        QSKIP("No bookmarks on server — skipping single-bookmark fetch test.");
    }

    const QString id = bookmarks.first().toMap().value("id").toString();
    QVERIFY(!id.isEmpty());

    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkFetched);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);
    m_api->fetchBookmark(id);

    QVERIFY(waitForSignal(okSpy));
    QCOMPARE(errSpy.count(), 0);
    QCOMPARE(okSpy.first().first().toMap().value("id").toString(), id);
}

void TestKarakeepApi::testFetchBookmarkByIdNotFound()
{
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);
    m_api->fetchBookmark("nonexistent_id_xyz_123");

    QVERIFY(waitForSignal(errSpy));
    const int httpStatus = errSpy.first().at(1).toInt();
    QCOMPARE(httpStatus, 404);
}

// ── Bookmarks (write + cleanup) ───────────────────────────────────────────────

void TestKarakeepApi::testCreateAndDeleteLinkBookmark()
{
    const QString id = createTestLinkBookmark();
    QVERIFY(!id.isEmpty());
    deleteTestBookmark(id);
}

void TestKarakeepApi::testCreateAndDeleteTextBookmark()
{
    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkCreated);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->createTextBookmark(TEST_TEXT, "Sailfish Test Note");

    QVERIFY(waitForSignal(okSpy));
    QCOMPARE(errSpy.count(), 0);

    const QVariantMap bm = okSpy.first().first().toMap();
    QCOMPARE(bm.value("type").toString(), QString("text"));

    deleteTestBookmark(bm.value("id").toString());
}

void TestKarakeepApi::testCreateLinkBookmarkWithTags()
{
    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkCreated);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->createLinkBookmark(TEST_URL, "Tagged Test", {TEST_TAG});

    QVERIFY(waitForSignal(okSpy, TIMEOUT_MS * 2)); // extra time for tag attach + re-fetch
    QCOMPARE(errSpy.count(), 0);

    const QVariantMap bm   = okSpy.first().first().toMap();
    const QVariantList tags = bm.value("tags").toList();

    const bool hasTestTag = std::any_of(tags.constBegin(), tags.constEnd(),
        [](const QVariant &v) {
            return v.toMap().value("name").toString() == TEST_TAG;
        });
    QVERIFY(hasTestTag);

    deleteTestBookmark(bm.value("id").toString());
}

void TestKarakeepApi::testUpdateBookmark()
{
    const QString id = createTestLinkBookmark();
    QVERIFY(!id.isEmpty());

    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkUpdated);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->updateBookmark(id, {{"favourited", true}, {"note", "Test note"}});

    QVERIFY(waitForSignal(okSpy));
    QCOMPARE(errSpy.count(), 0);

    const QVariantMap updated = okSpy.first().first().toMap();
    QVERIFY(updated.value("favourited").toBool());
    QCOMPARE(updated.value("note").toString(), QString("Test note"));

    deleteTestBookmark(id);
}

// ── Tag attachment ────────────────────────────────────────────────────────────

void TestKarakeepApi::testAttachAndDetachTags()
{
    const QString id = createTestLinkBookmark();
    QVERIFY(!id.isEmpty());

    // Attach
    {
        QSignalSpy okSpy(m_api, &KarakeepApi::tagsAttached);
        QSignalSpy errSpy(m_api, &KarakeepApi::requestError);
        m_api->attachTags(id, {TEST_TAG});
        QVERIFY(waitForSignal(okSpy));
        QCOMPARE(errSpy.count(), 0);
        QCOMPARE(okSpy.first().first().toString(), id);
    }

    // Verify tag is present
    {
        QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkFetched);
        m_api->fetchBookmark(id);
        QVERIFY(waitForSignal(okSpy));

        const QVariantList tags = okSpy.first().first().toMap().value("tags").toList();
        const bool hasTag = std::any_of(tags.constBegin(), tags.constEnd(),
            [](const QVariant &v) {
                return v.toMap().value("name").toString() == TEST_TAG;
            });
        QVERIFY(hasTag);
    }

    // Detach
    {
        QSignalSpy okSpy(m_api, &KarakeepApi::tagsDetached);
        QSignalSpy errSpy(m_api, &KarakeepApi::requestError);
        m_api->detachTags(id, {TEST_TAG});
        QVERIFY(waitForSignal(okSpy));
        QCOMPARE(errSpy.count(), 0);
    }

    // Verify tag is gone
    {
        QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkFetched);
        m_api->fetchBookmark(id);
        QVERIFY(waitForSignal(okSpy));

        const QVariantList tags = okSpy.first().first().toMap().value("tags").toList();
        const bool stillHasTag = std::any_of(tags.constBegin(), tags.constEnd(),
            [](const QVariant &v) {
                return v.toMap().value("name").toString() == TEST_TAG;
            });
        QVERIFY(!stillHasTag);
    }

    deleteTestBookmark(id);
}

// ── Lists ─────────────────────────────────────────────────────────────────────

void TestKarakeepApi::testFetchLists()
{
    QSignalSpy okSpy(m_api, &KarakeepApi::listsFetched);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->fetchLists();

    QVERIFY(waitForSignal(okSpy));
    QCOMPARE(errSpy.count(), 0);

    const QVariantList lists = okSpy.first().first().toList();
    for (const QVariant &v : lists) {
        const QVariantMap list = v.toMap();
        QVERIFY(!list.value("id").toString().isEmpty());
        QVERIFY(!list.value("name").toString().isEmpty());
    }

    // If there are any lists, fetch the first one's bookmarks too
    if (!lists.isEmpty()) {
        const QString listId = lists.first().toMap().value("id").toString();
        QSignalSpy lbSpy(m_api, &KarakeepApi::listBookmarksFetched);
        m_api->fetchListBookmarks(listId, QString(), 5);
        QVERIFY(waitForSignal(lbSpy));
        QCOMPARE(lbSpy.first().at(0).toString(), listId);
    }
}

void TestKarakeepApi::testAddAndRemoveBookmarkFromList()
{
    // Find the first manual list — smart lists are read-only
    QSignalSpy listsSpy(m_api, &KarakeepApi::listsFetched);
    m_api->fetchLists();
    QVERIFY(waitForSignal(listsSpy));
    const QVariantList lists = listsSpy.first().first().toList();

    QString targetListId;
    for (const QVariant &v : lists) {
        const QVariantMap l = v.toMap();
        if (l.value("type").toString() == QLatin1String("manual")) {
            targetListId = l.value("id").toString();
            break;
        }
    }
    if (targetListId.isEmpty())
        QSKIP("No manual list found on server — skipping list membership test.");

    // Create a scratch bookmark; the scope guard ensures it is deleted even if
    // an assertion below fails and the function returns early.
    const QString bookmarkId = createTestLinkBookmark();
    QVERIFY(!bookmarkId.isEmpty());
    ScopeGuard cleanup{ [this, &bookmarkId]() { deleteTestBookmark(bookmarkId); } };

    // ── Add to list ──────────────────────────────────────────────────────────

    {
        QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkAddedToList);
        QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

        m_api->addBookmarkToList(targetListId, bookmarkId);

        QVERIFY(waitForSignal(okSpy));
        QCOMPARE(errSpy.count(), 0);
        QCOMPARE(okSpy.first().at(0).toString(), targetListId);
        QCOMPARE(okSpy.first().at(1).toString(), bookmarkId);
    }

    // Verify the bookmark is visible in the list
    {
        QSignalSpy lbSpy(m_api, &KarakeepApi::listBookmarksFetched);
        m_api->fetchListBookmarks(targetListId, QString(), 50);
        QVERIFY(waitForSignal(lbSpy));

        const QVariantList items = lbSpy.first().at(1).toList();
        const bool found = std::any_of(items.constBegin(), items.constEnd(),
            [&bookmarkId](const QVariant &v) {
                return v.toMap().value("id").toString() == bookmarkId;
            });
        QVERIFY2(found, "Bookmark not found in list after addBookmarkToList");
    }

    // ── Remove from list ─────────────────────────────────────────────────────

    {
        QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkRemovedFromList);
        QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

        m_api->removeBookmarkFromList(targetListId, bookmarkId);

        QVERIFY(waitForSignal(okSpy));
        QCOMPARE(errSpy.count(), 0);
        QCOMPARE(okSpy.first().at(0).toString(), targetListId);
        QCOMPARE(okSpy.first().at(1).toString(), bookmarkId);
    }

    // Verify the bookmark is gone from the list
    {
        QSignalSpy lbSpy(m_api, &KarakeepApi::listBookmarksFetched);
        m_api->fetchListBookmarks(targetListId, QString(), 50);
        QVERIFY(waitForSignal(lbSpy));

        const QVariantList items = lbSpy.first().at(1).toList();
        const bool stillPresent = std::any_of(items.constBegin(), items.constEnd(),
            [&bookmarkId](const QVariant &v) {
                return v.toMap().value("id").toString() == bookmarkId;
            });
        QVERIFY2(!stillPresent, "Bookmark still present in list after removeBookmarkFromList");
    }
    // cleanup is handled by the ScopeGuard declared after bookmark creation
}

// ── Search ────────────────────────────────────────────────────────────────────

void TestKarakeepApi::testSearchBookmarks()
{
    // Baseline: unfiltered first page
    QSignalSpy allSpy(m_api, &KarakeepApi::bookmarksFetched);
    m_api->fetchBookmarks(QString(), 20);
    QVERIFY(waitForSignal(allSpy));
    const int unfilteredCount = allSpy.first().at(0).toList().count();
    qDebug() << "Unfiltered count (first 20):" << unfilteredCount;
    if (unfilteredCount == 0) {
        QSKIP("No bookmarks on server — skipping search test.");
    }

    // Fresh API instance to avoid stale keep-alive issues
    delete m_api;
    m_api = new KarakeepApi(m_settings, this);

    // Search for "Prusa"
    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarksFetched);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->fetchBookmarks(QString(), 20, false, false, "Prusa");

    QVERIFY2(waitForSignal(okSpy), "Search request timed out — API may not support /bookmarks/search");
    QCOMPARE(errSpy.count(), 0);

    const QVariantList results = okSpy.first().at(0).toList();
    qDebug() << "Search results for 'Prusa':" << results.count();
    for (int i = 0; i < qMin(results.count(), 5); ++i) {
        const QVariantMap bm = results.at(i).toMap();
        qDebug() << "  " << i
                 << bm.value("title").toString()
                 << bm.value("url").toString();
    }

    // Search must produce a different result set from the unfiltered query.
    // A count comparison is unreliable when both queries return a full page (e.g. 20 items).
    // Instead compare bookmark IDs: at least one ID must differ.
    const QVariantList unfilteredResults = allSpy.first().at(0).toList();
    QSet<QString> unfilteredIds;
    for (const QVariant &v : unfilteredResults)
        unfilteredIds.insert(v.toMap().value("id").toString());
    QSet<QString> searchIds;
    for (const QVariant &v : results)
        searchIds.insert(v.toMap().value("id").toString());
    QVERIFY2(results.count() == 0 || unfilteredIds != searchIds,
             qPrintable(QString("Search returned the exact same %1 bookmarks as unfiltered — "
                                "API may be ignoring the /bookmarks/search q parameter.")
                        .arg(results.count())));

    // Every returned bookmark should relate to "Prusa".
    // The server does full-text search including crawled page content and AI summaries,
    // so not every result will mention "Prusa" in the fields returned by the API.
    // We check what we can see and warn on misses rather than failing hard.
    int relevantCount = 0;
    for (const QVariant &v : results) {
        const QVariantMap bm = v.toMap();
        const QString title   = bm.value("title").toString();
        const QString desc    = bm.value("description").toString();
        const QString text    = bm.value("text").toString();
        const QString url     = bm.value("url").toString();
        const QString summary = bm.value("summary").toString();
        const bool relevant   = title.contains("prusa",   Qt::CaseInsensitive)
                             || desc.contains("prusa",    Qt::CaseInsensitive)
                             || text.contains("prusa",    Qt::CaseInsensitive)
                             || url.contains("prusa",     Qt::CaseInsensitive)
                             || summary.contains("prusa", Qt::CaseInsensitive);
        if (relevant)
            ++relevantCount;
        else
            qWarning() << "Result not visibly Prusa-related (may match via crawled content):"
                       << title << url;
    }
    // At least half the results should visibly mention Prusa
    QVERIFY2(relevantCount * 2 >= results.count(),
             qPrintable(QString("Only %1 of %2 results visibly mention 'Prusa' — "
                                "search may be returning poorly-ranked results")
                        .arg(relevantCount).arg(results.count())));
}

// ── Tags ──────────────────────────────────────────────────────────────────────

void TestKarakeepApi::testFetchTags()
{
    QSignalSpy okSpy(m_api, &KarakeepApi::tagsFetched);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->fetchTags();

    QVERIFY(waitForSignal(okSpy));
    QCOMPARE(errSpy.count(), 0);

    const QVariantList tags = okSpy.first().first().toList();
    for (const QVariant &v : tags) {
        const QVariantMap tag = v.toMap();
        QVERIFY(!tag.value("id").toString().isEmpty());
        QVERIFY(!tag.value("name").toString().isEmpty());
    }
}

void TestKarakeepApi::testFetchTagsFiltered()
{
    // Filtering by a string that is unlikely to exist should return zero results
    // (not an error).
    QSignalSpy okSpy(m_api, &KarakeepApi::tagsFetched);
    m_api->fetchTags("zz_unlikely_tag_name_xq9z");
    QVERIFY(waitForSignal(okSpy));
    // Just verify no crash / error — the list may be empty
    QVERIFY(okSpy.first().first().toList().count() >= 0);
}

// ── Private helpers ───────────────────────────────────────────────────────────

QString TestKarakeepApi::createTestLinkBookmark(const QString &url,
                                                  const QString &title)
{
    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkCreated);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->createLinkBookmark(url, title);

    if (!waitForSignal(okSpy) || !errSpy.isEmpty()) {
        QWARN("Failed to create test bookmark");
        return QString();
    }
    return okSpy.first().first().toMap().value("id").toString();
}

void TestKarakeepApi::deleteTestBookmark(const QString &id)
{
    QSignalSpy okSpy(m_api, &KarakeepApi::bookmarkDeleted);
    QSignalSpy errSpy(m_api, &KarakeepApi::requestError);

    m_api->deleteBookmark(id);

    QVERIFY(waitForSignal(okSpy));
    QCOMPARE(errSpy.count(), 0);
    QCOMPARE(okSpy.first().first().toString(), id);
}

QTEST_MAIN(TestKarakeepApi)
#include "tst_karakeepapi.moc"
