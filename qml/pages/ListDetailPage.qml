import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    // Properties passed in by ListsPage
    property string listId
    property string listName
    property string listDescription: ""
    property string listIcon:        ""
    property string listType:        "manual"   // "manual" | "smart"
    property bool   listIsPublic:    false

    property string nextCursor: ""
    property bool   loading:    false
    property bool   hasError:   false
    property string errorMessage: ""

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

    function refresh() {
        loading = true
        hasError = false
        nextCursor = ""
        bookmarkModel.clear()
        KarakeepApi.fetchListBookmarks(listId, "", 20)
    }

    function loadMore() {
        if (nextCursor === "" || loading) return
        loading = true
        KarakeepApi.fetchListBookmarks(listId, nextCursor, 20)
    }

    // ── API connections ───────────────────────────────────────────────────────

    Connections {
        target: KarakeepApi

        onListBookmarksFetched: {
            if (fetchedListId !== page.listId) return
            loading = false
            for (var i = 0; i < bookmarks.length; i++)
                bookmarkModel.append(processBookmark(bookmarks[i]))
            page.nextCursor = nextCursor
        }

        onBookmarkUpdated: {
            var processed = processBookmark(bookmark)
            for (var i = 0; i < bookmarkModel.count; i++) {
                if (bookmarkModel.get(i).id === processed.id) {
                    bookmarkModel.set(i, processed)
                    break
                }
            }
        }

        onBookmarkDeleted: {
            for (var i = 0; i < bookmarkModel.count; i++) {
                if (bookmarkModel.get(i).id === id) {
                    bookmarkModel.remove(i)
                    break
                }
            }
        }

        // Bookmark added to this list from AddBookmarkPage or elsewhere — reload
        onBookmarkAddedToList: {
            if (listId !== page.listId) return
            refresh()
        }

        // Bookmark removed from this list: remove from local model immediately
        onBookmarkRemovedFromList: {
            if (listId !== page.listId) return
            for (var i = 0; i < bookmarkModel.count; i++) {
                if (bookmarkModel.get(i).id === bookmarkId) {
                    bookmarkModel.remove(i)
                    break
                }
            }
        }

        onRequestError: {
            if (operation !== "fetchListBookmarks") return
            loading = false
            hasError = true
            errorMessage = message
        }
    }

    // ── Initial load ──────────────────────────────────────────────────────────

    Component.onCompleted: refresh()

    // ── UI ────────────────────────────────────────────────────────────────────

    SilicaListView {
        id: listView
        anchors.fill: parent
        model: bookmarkModel

        // ── Pull-down menu ────────────────────────────────────────────────────

        PullDownMenu {
            busy: loading

            MenuItem {
                text: qsTr("Refresh")
                onClicked: refresh()
            }
            MenuItem {
                text: qsTr("Add note")
                visible: listType !== "smart"
                onClicked: pageStack.push(Qt.resolvedUrl("AddBookmarkPage.qml"), {
                    bookmarkType: "text",
                    targetListId: page.listId
                })
            }
            MenuItem {
                text: qsTr("Add link")
                visible: listType !== "smart"
                onClicked: pageStack.push(Qt.resolvedUrl("AddBookmarkPage.qml"), {
                    bookmarkType: "link",
                    targetListId: page.listId
                })
            }
        }

        // ── Header ────────────────────────────────────────────────────────────

        header: Column {
            width: parent.width
            spacing: 0

            // List icon banner
            Item {
                width: parent.width
                height: listIcon !== "" ? iconBannerLabel.height + 2 * Theme.paddingLarge : 0
                visible: listIcon !== ""

                Label {
                    id: iconBannerLabel
                    anchors.centerIn: parent
                    text: listIcon
                    font.pixelSize: Theme.fontSizeHuge * 2
                }
            }

            PageHeader {
                title: listName
                description: {
                    var parts = []
                    if (listDescription !== "") parts.push(listDescription)
                    if (bookmarkModel.count > 0)
                        parts.push(bookmarkModel.count + (nextCursor !== "" ? "+" : "") + " " + qsTr("bookmarks"))
                    return parts.join(" · ")
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
                        left: parent.left; right: parent.right
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

            // ── Context menu ──────────────────────────────────────────────────

            menu: ContextMenu {
                // List-specific actions
                MenuItem {
                    text: qsTr("Move to another list")
                    visible: listType !== "smart"
                    onClicked: {
                        var bId    = model.id
                        var bIndex = index
                        var picker = pageStack.push(
                            Qt.resolvedUrl("ListPickerDialog.qml"),
                            { excludeListId: page.listId })
                        picker.accepted.connect(function() {
                            // Optimistic removal from this view
                            for (var i = 0; i < bookmarkModel.count; i++) {
                                if (bookmarkModel.get(i).id === bId) {
                                    bookmarkModel.remove(i)
                                    break
                                }
                            }
                            KarakeepApi.removeBookmarkFromList(page.listId, bId)
                            KarakeepApi.addBookmarkToList(picker.selectedListId, bId)
                        })
                    }
                }
                MenuItem {
                    text: qsTr("Remove from list")
                    visible: listType !== "smart"
                    onClicked: {
                        var bId = model.id
                        listItem.remorseAction(qsTr("Removing"), function() {
                            KarakeepApi.removeBookmarkFromList(page.listId, bId)
                        })
                    }
                }

                // Standard bookmark actions
                MenuItem {
                    text: model.favourited
                        ? qsTr("Remove from favourites")
                        : qsTr("Add to favourites")
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
                        var bId  = model.id
                        item.remorseAction(qsTr("Deleting"), function() {
                            KarakeepApi.deleteBookmark(bId)
                        })
                    }
                }
            }

            ListView.onRemove: animateRemoval(listItem)

            onClicked: pageStack.push(Qt.resolvedUrl("BookmarkDetailPage.qml"), {
                bookmarkId:          model.id,
                bookmarkTitle:       model.title,
                bookmarkUrl:         model.url,
                bookmarkType:        model.type,
                bookmarkText:        model.text,
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

            // ── Content ───────────────────────────────────────────────────────

            Row {
                id: contentRow
                anchors {
                    left: parent.left; right: parent.right; top: parent.top
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    topMargin: Theme.paddingSmall
                }
                spacing: Theme.paddingMedium

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

            // Status icons
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
                    width: Theme.iconSizeSmall; height: Theme.iconSizeSmall
                    visible: model.favourited
                }
                Icon {
                    source: "image://theme/icon-s-archive"
                    color: Theme.secondaryColor
                    width: Theme.iconSizeSmall; height: Theme.iconSizeSmall
                    visible: model.archived
                }
            }

            // Tags row
            Flow {
                id: tagRow
                anchors {
                    left: parent.left; right: parent.right; bottom: parent.bottom
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

        // ── Placeholder / busy ────────────────────────────────────────────────

        ViewPlaceholder {
            enabled: !loading && bookmarkModel.count === 0 && !hasError
            text: qsTr("No bookmarks in this list")
            hintText: listType !== "smart"
                ? qsTr("Pull down to add a link or note")
                : qsTr("This smart list has no matching bookmarks")
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: loading && bookmarkModel.count === 0
            size: BusyIndicatorSize.Large
        }

        VerticalScrollDecorator {}
    }
}
