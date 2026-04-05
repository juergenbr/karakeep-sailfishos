# Architecture

## Application layers

KaraKeep follows the standard SailfishOS pattern: a C++ backend compiled into the application binary, registered as named context properties, and consumed by a QML/Silica UI.

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#1e3a5f', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3b6ea5', 'lineColor': '#64748b', 'clusterBkg': '#f1f5f9', 'clusterBorder': '#cbd5e1', 'titleColor': '#1e293b'}}}%%
flowchart TB
    subgraph QML["QML / Silica UI"]
        direction LR
        COVER[CoverPage]
        MAIN[MainPage]
        DETAIL[BookmarkDetailPage]
        ADD[AddBookmarkPage]
        SETTINGS[SettingsPage]
    end

    subgraph CPP["C++ Backend  (Qt 5.6)"]
        direction LR
        AS["AppSettings\n─────────────\nserverUrl\napiKey\nconfigured"]
        KA["KarakeepApi\n─────────────\nslots → HTTP calls\nsignals → results"]
    end

    subgraph SRV["Karakeep Server"]
        REST["REST API\n/api/v1/…"]
    end

    QML -- "context properties\nslot calls  ↓  signal callbacks  ↑" --> CPP
    KA -- "Bearer token\nGET · POST · PATCH · DELETE" --> SRV

    classDef qmlNode fill:#1d4ed8,stroke:#1e40af,color:#fff
    classDef cppNode  fill:#15803d,stroke:#166534,color:#fff
    classDef srvNode  fill:#7c3aed,stroke:#6d28d9,color:#fff

    class COVER,MAIN,DETAIL,ADD,SETTINGS qmlNode
    class AS,KA cppNode
    class REST srvNode
```

### Context properties

`src/harbour-karakeep.cpp` registers two singletons before the QML engine starts:

| Property name | C++ type | Responsibility |
|---|---|---|
| `AppSettings` | `AppSettings*` | Persists `serverUrl` and `apiKey` via `QSettings`; exposes `configured` (bool) |
| `KarakeepApi` | `KarakeepApi*` | All network I/O; async slots invoked from QML, results delivered as signals |

### Async contract

Every `KarakeepApi` operation follows the same pattern:

1. QML calls a **slot** (e.g. `KarakeepApi.fetchBookmarks(…)`)
2. C++ starts an async `QNetworkReply` and increments an internal `m_pending` counter
3. The reply's `finished` lambda fires on the Qt event loop:
   - On success → emits a typed **success signal** (e.g. `bookmarksFetched(bookmarks, nextCursor)`)
   - On error → emits the uniform **error signal**: `requestError(operation, httpStatus, message)`
4. QML pages connect to signals via `Connections { target: KarakeepApi }` and update their local `ListModel` or page state

`httpStatus == 0` means a network-level failure with no HTTP response.

### Data types and the C++/QML boundary

All API response types are plain structs in `src/api/karakeeptypes.h`:

```
Bookmark        BookmarkTag      Tag
BookmarkList    KarakeepUser
```

Each struct has two static methods:

| Method | Direction | Used for |
|--------|-----------|----------|
| `fromJson(QJsonObject)` | JSON → struct | Parsing API responses |
| `toVariantMap()` | struct → `QVariantMap` | Crossing the C++/QML boundary via signals |

QML only ever receives `QVariantMap` / `QVariantList` — never typed C++ objects. This avoids the need to register metatypes and keeps QML property access simple.

`parseIsoDateTime()` (also in `karakeeptypes.h`) is a Qt 5.6 workaround: Qt 5.6 cannot parse ISO 8601 timestamps that include milliseconds or timezone offsets.

---

## Page navigation

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'primaryColor': '#1e3a5f', 'primaryTextColor': '#fff', 'primaryBorderColor': '#3b6ea5', 'lineColor': '#475569', 'clusterBkg': '#f8fafc', 'clusterBorder': '#e2e8f0'}}}%%
flowchart TD
    AW["ApplicationWindow\n(harbour-karakeep.qml)"]

    AW -->|initialPage| MAIN

    MAIN["MainPage\n─────────────────\n• bookmark list\n• search & filter\n• pull-down menu"]

    MAIN -->|"pull-down: Settings"| SETTINGS["SettingsPage\n────────────\nServer URL\nAPI Key\nTest connection"]
    MAIN -->|"pull-down: Add link / Add note\nor cover action"| ADD["AddBookmarkPage\n────────────────\nDialog\nURL · text\ntitle · tags"]
    MAIN -->|"tap list item"| DETAIL["BookmarkDetailPage\n───────────────────\nhero image · desc\nsummary · note editor\ntags · metadata"]

    MAIN -->|"auto-push on first launch\n(not configured)"| SETTINGS

    AW -. "addBookmarkRequested()\nsignal from cover" .-> MAIN

    classDef page  fill:#1d4ed8,stroke:#1e40af,color:#fff
    classDef root  fill:#7c3aed,stroke:#6d28d9,color:#fff
    classDef dlg   fill:#15803d,stroke:#166534,color:#fff

    class AW root
    class MAIN,SETTINGS,DETAIL page
    class ADD dlg
```

`ApplicationWindow` holds shared state and signals used by both `MainPage` and `CoverPage`:
- `totalBookmarkCount` — updated by `MainPage` after each fetch (all-bookmarks filter only)
- `lastBookmarkTitle` — title of the most recently fetched first bookmark
- `addBookmarkRequested()` — signal fired by the cover page action; `MainPage` listens and pushes `AddBookmarkPage`

---

## Shared backend: `karakeep_backend.pri`

Both the main app and the integration test harness include `karakeep_backend.pri`, which adds `src/api/appsettings.*`, `src/api/karakeepapi.*`, `src/api/karakeeptypes.h`, and `QT += network`. To add a new API class, add it to this `.pri` file so the test suite picks it up automatically.

---

## Qt 5.6 compatibility notes

| Issue | Safe pattern |
|-------|-------------|
| No `String.endsWith()` in V4 JS engine | `str.charAt(str.length - 1) === "/"` |
| ISO 8601 timestamps with ms / timezone fail `Qt::ISODate` | Use `parseIsoDateTime()` from `karakeeptypes.h` |
| `QVariant(void*)` constructor deleted | Never pass `QQuickItem*` to `setContextProperty()` |
| `sendCustomRequest` requires `QIODevice*`, not `QByteArray` | Use `sendWithBody()` in `karakeepapi.cpp` |
| QNAM silently hangs on reused connections the server has closed | `req.setRawHeader("Connection", "close")` on every request |
