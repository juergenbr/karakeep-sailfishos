import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property string nextCursor: ""
    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""
    property string filterMode: "all"   // "all" | "favourites" | "archived"
    property string searchQuery: ""

    // ── Data model ────────────────────────────────────────────────────────────

    ListModel { id: bookmarkModel }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function extractDomain(url) {
        if (!url) return ""
        var m = url.match(/^https?:\/\/([^\/]+)/)
        return m ? m[1].replace(/^www\./, "") : url
    }

    function processBookmark(b) {
        var tagNames = []
        if (b.tags) {
            for (var j = 0; j < b.tags.length; j++) {
                var t = b.tags[j]
                tagNames.push(t.name || t)
            }
        }
        return {
            id:          b.id          || "",
            title:       b.title       || "",
            url:         b.url         || "",
            domain:      extractDomain(b.url),
            type:        b.type        || "link",
            archived:    b.archived    || false,
            favourited:  b.favourited  || false,
            favicon:     b.favicon     || "",
            imageUrl:    b.imageUrl    || "",
            description: b.description || "",
            note:        b.note        || "",
            summary:     b.summary     || "",
            text:        b.text        || "",
            author:      b.author      || "",
            publisher:   b.publisher   || "",
            createdAt:   b.createdAt   || "",
            tagNames:    tagNames.join(", ")
        }
    }

    function headerDescription() {
        var parts = []
        if (filterMode === "favourites") parts.push(qsTr("Favourites"))
        else if (filterMode === "archived") parts.push(qsTr("Archived"))
        if (bookmarkModel.count > 0) {
            parts.push(bookmarkModel.count + (nextCursor !== "" ? "+" : "") + " " + qsTr("bookmarks"))
        }
        return parts.join(" · ")
    }

    function refresh() {
        loading = true
        hasError = false
        nextCursor = ""
        bookmarkModel.clear()
        KarakeepApi.fetchBookmarks(
            "",
            20,
            filterMode === "archived",
            filterMode === "favourites",
            searchQuery
        )
    }

    function loadMore() {
        if (nextCursor === "" || loading) return
        loading = true
        KarakeepApi.fetchBookmarks(
            nextCursor,
            20,
            filterMode === "archived",
            filterMode === "favourites",
            searchQuery
        )
    }

    // ── API connections ───────────────────────────────────────────────────────

    Connections {
        target: KarakeepApi

        onBookmarksFetched: {
            loading = false
            for (var i = 0; i < bookmarks.length; i++) {
                bookmarkModel.append(processBookmark(bookmarks[i]))
            }
            page.nextCursor = nextCursor

            if (filterMode === "all" && page.searchQuery === "") {
                appWindow.totalBookmarkCount = bookmarkModel.count
                if (bookmarkModel.count > 0) {
                    appWindow.lastBookmarkTitle = bookmarkModel.get(0).title
                }
            }
        }

        onBookmarkUpdated: {
            var processed = processBookmark(bookmark)
            for (var i = 0; i < bookmarkModel.count; i++) {
                if (bookmarkModel.get(i).id === processed.id) {
                    // Remove item if it no longer belongs in the current filtered view
                    if (filterMode === "favourites" && !processed.favourited) {
                        bookmarkModel.remove(i)
                    } else if (filterMode === "archived" && !processed.archived) {
                        bookmarkModel.remove(i)
                    } else {
                        bookmarkModel.set(i, processed)
                    }
                    break
                }
            }
        }

        onBookmarkDeleted: {
            for (var i = 0; i < bookmarkModel.count; i++) {
                if (bookmarkModel.get(i).id === id) {
                    bookmarkModel.remove(i)
                    if (filterMode === "all") {
                        appWindow.totalBookmarkCount = bookmarkModel.count
                    }
                    break
                }
            }
        }

        onBookmarkCreated: {
            // Prepend newly created bookmark so it appears at the top
            bookmarkModel.insert(0, processBookmark(bookmark))
            if (filterMode === "all") {
                appWindow.totalBookmarkCount = bookmarkModel.count
                appWindow.lastBookmarkTitle = bookmarkModel.get(0).title
            }
        }

        onRequestError: {
            loading = false
            hasError = true
            errorMessage = message
        }
    }

    Connections {
        target: AppSettings
        onConfiguredChanged: {
            if (AppSettings.configured && bookmarkModel.count === 0) {
                refresh()
            }
        }
    }

    Connections {
        target: appWindow
        onAddBookmarkRequested: {
            if (AppSettings.configured) {
                pageStack.push(Qt.resolvedUrl("AddBookmarkPage.qml"),
                               { bookmarkType: "link" })
            }
        }
    }

    // ── Initial load ──────────────────────────────────────────────────────────

    Component.onCompleted: {
        if (!AppSettings.configured) {
            pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
        } else {
            refresh()
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: bookmarkModel

        // ── Pull-down menu ────────────────────────────────────────────────────

        PullDownMenu {
            busy: loading

            MenuItem {
                text: qsTr("Settings")
                onClicked: pageStack.push(Qt.resolvedUrl("SettingsPage.qml"))
            }
            MenuItem {
                text: filterMode === "archived"
                    ? qsTr("All bookmarks")
                    : qsTr("Show archived")
                enabled: AppSettings.configured
                onClicked: {
                    filterMode = filterMode === "archived" ? "all" : "archived"
                    searchQuery = ""
                    refresh()
                }
            }
            MenuItem {
                text: filterMode === "favourites"
                    ? qsTr("All bookmarks")
                    : qsTr("Show favourites")
                enabled: AppSettings.configured
                onClicked: {
                    filterMode = filterMode === "favourites" ? "all" : "favourites"
                    searchQuery = ""
                    refresh()
                }
            }
            MenuItem {
                text: qsTr("Add note")
                enabled: AppSettings.configured
                onClicked: pageStack.push(Qt.resolvedUrl("AddBookmarkPage.qml"),
                                          { bookmarkType: "text" })
            }
            MenuItem {
                text: qsTr("Add link")
                enabled: AppSettings.configured
                onClicked: pageStack.push(Qt.resolvedUrl("AddBookmarkPage.qml"),
                                          { bookmarkType: "link" })
            }
            MenuItem {
                text: qsTr("Refresh")
                enabled: AppSettings.configured
                onClicked: refresh()
            }
        }

        // ── Header ────────────────────────────────────────────────────────────

        header: Column {
            width: parent.width
            spacing: 0

            PageHeader {
                title: "KaraKeep"
                description: headerDescription()
            }

            SearchField {
                id: searchField
                width: parent.width
                placeholderText: qsTr("Search bookmarks…")
                visible: AppSettings.configured
                EnterKey.iconSource: "image://theme/icon-m-search"
                EnterKey.onClicked: {
                    page.searchQuery = text.trim()
                    page.refresh()
                }
                onTextChanged: {
                    // Only update searchQuery when the field is cleared (X button)
                    // to avoid desynchronising the cursor/model with an in-progress query.
                    if (text.trim() === "") {
                        page.searchQuery = ""
                        page.refresh()
                    }
                }
            }

            // Error banner
            Rectangle {
                width: parent.width
                height: errorLabel.height + 2 * Theme.paddingSmall
                color: Theme.rgba(Theme.errorColor, 0.15)
                visible: hasError

                Label {
                    id: errorLabel
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    text: errorMessage
                    color: Theme.errorColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }
        }

        // ── Delegate ──────────────────────────────────────────────────────────

        delegate: ListItem {
            id: listItem
            width: listView.width
            contentHeight: Math.max(contentRow.height, Theme.itemSizeMedium) +
                           (model.tagNames !== "" ? tagRow.height + Theme.paddingSmall : 0)

            menu: ContextMenu {
                MenuItem {
                    text: model.favourited ? qsTr("Remove from favourites") : qsTr("Add to favourites")
                    onClicked: KarakeepApi.updateBookmark(model.id, { favourited: !model.favourited })
                }
                MenuItem {
                    text: model.archived ? qsTr("Unarchive") : qsTr("Archive")
                    onClicked: KarakeepApi.updateBookmark(model.id, { archived: !model.archived })
                }
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: {
                        var item = listItem
                        var bookmarkId = model.id
                        item.remorseAction(qsTr("Deleting"), function() {
                            KarakeepApi.deleteBookmark(bookmarkId)
                        })
                    }
                }
            }

            ListView.onRemove: animateRemoval(listItem)

            onClicked: {
                pageStack.push(Qt.resolvedUrl("BookmarkDetailPage.qml"), {
                    bookmarkId:    model.id,
                    bookmarkTitle: model.title,
                    bookmarkUrl:   model.url,
                    bookmarkType:  model.type,
                    bookmarkText:  model.text,
                    bookmarkFavicon:     model.favicon,
                    bookmarkImageUrl:    model.imageUrl,
                    bookmarkDescription: model.description,
                    bookmarkNote:        model.note,
                    bookmarkSummary:     model.summary,
                    bookmarkAuthor:      model.author,
                    bookmarkPublisher:   model.publisher,
                    bookmarkTagNames:    model.tagNames,
                    bookmarkFavourited:  model.favourited,
                    bookmarkArchived:    model.archived,
                    bookmarkCreatedAt:   model.createdAt,
                    bookmarkDomain:      model.domain
                })
            }

            // Main content row
            Row {
                id: contentRow
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    topMargin: Theme.paddingSmall
                }
                spacing: Theme.paddingMedium

                // Favicon / type icon
                Item {
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    anchors.verticalCenter: textColumn.verticalCenter

                    Image {
                        id: faviconImage
                        anchors.fill: parent
                        source: model.favicon
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: model.favicon !== "" && status === Image.Ready
                    }
                    Icon {
                        anchors.fill: parent
                        source: model.type === "text"
                            ? "image://theme/icon-m-note"
                            : "image://theme/icon-m-link"
                        color: listItem.highlighted ? Theme.highlightColor : Theme.secondaryColor
                        visible: model.favicon === "" || faviconImage.status !== Image.Ready
                    }
                }

                // Text content
                Column {
                    id: textColumn
                    width: parent.width - Theme.iconSizeMedium - Theme.paddingMedium
                    spacing: Theme.paddingSmall / 2

                    Label {
                        width: parent.width
                        text: model.title || model.url || qsTr("Untitled")
                        color: listItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: model.type === "text"
                            ? model.text.substr(0, 80).replace(/\n/g, " ")
                            : model.domain
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeExtraSmall
                        truncationMode: TruncationMode.Fade
                        visible: text !== ""
                    }
                }
            }

            // Status icons (top-right)
            Row {
                anchors {
                    right: parent.right
                    rightMargin: Theme.horizontalPageMargin
                    top: parent.top
                    topMargin: Theme.paddingSmall
                }
                spacing: Theme.paddingSmall

                Icon {
                    source: "image://theme/icon-s-favorite"
                    color: Theme.highlightColor
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    visible: model.favourited
                }
                Icon {
                    source: "image://theme/icon-s-archive"
                    color: Theme.secondaryColor
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    visible: model.archived
                }
            }

            // Tags row (below content)
            Flow {
                id: tagRow
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: Theme.horizontalPageMargin + Theme.iconSizeMedium + Theme.paddingMedium
                    rightMargin: Theme.horizontalPageMargin
                    bottomMargin: Theme.paddingSmall
                }
                spacing: Theme.paddingSmall / 2
                visible: model.tagNames !== ""

                Repeater {
                    model: listItem.model.tagNames !== "" ? listItem.model.tagNames.split(", ") : []
                    delegate: Rectangle {
                        height: tagLabel.height + Theme.paddingSmall
                        width: tagLabel.width + Theme.paddingMedium
                        radius: height / 2
                        color: Theme.rgba(Theme.highlightColor, 0.15)

                        Label {
                            id: tagLabel
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Theme.fontSizeTiny
                            color: Theme.highlightColor
                        }
                    }
                }
            }
        }

        // ── Load-more footer ──────────────────────────────────────────────────

        footer: Item {
            width: listView.width
            height: nextCursor !== "" ? loadMoreButton.height + 2 * Theme.paddingLarge : 0
            visible: nextCursor !== ""

            Button {
                id: loadMoreButton
                anchors.centerIn: parent
                text: qsTr("Load more")
                preferredWidth: Theme.buttonWidthLarge
                onClicked: loadMore()
            }
        }

        // ── Empty / placeholder states ─────────────────────────────────────────

        ViewPlaceholder {
            enabled: !loading && bookmarkModel.count === 0 && !hasError
            text: {
                if (!AppSettings.configured) return qsTr("Server not configured")
                if (searchQuery !== "") return qsTr("No results")
                if (filterMode === "favourites") return qsTr("No favourites yet")
                if (filterMode === "archived") return qsTr("Nothing archived")
                return qsTr("No bookmarks yet")
            }
            hintText: {
                if (!AppSettings.configured) return qsTr("Pull down and tap Settings to get started")
                if (searchQuery !== "") return qsTr("Try a different search term")
                return qsTr("Pull down to add a bookmark")
            }
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: loading && bookmarkModel.count === 0
            size: BusyIndicatorSize.Large
        }

        VerticalScrollDecorator {}
    }
}
