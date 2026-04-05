import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    // Properties passed in by the caller (from list delegate)
    property string bookmarkId
    property string bookmarkTitle
    property string bookmarkUrl
    property string bookmarkType
    property string bookmarkText
    property string bookmarkFavicon
    property string bookmarkImageUrl
    property string bookmarkDescription
    property string bookmarkNote
    property string bookmarkSummary
    property string bookmarkAuthor
    property string bookmarkPublisher
    property string bookmarkTagNames
    property bool   bookmarkFavourited: false
    property bool   bookmarkArchived:   false
    property string bookmarkCreatedAt
    property string bookmarkDomain

    property bool saving: false

    // ── Helpers ───────────────────────────────────────────────────────────────

    function formatDate(isoStr) {
        if (!isoStr) return ""
        var d = new Date(isoStr)
        if (isNaN(d.getTime())) return isoStr
        return Qt.formatDate(d, "d MMM yyyy")
    }

    // ── API connections ───────────────────────────────────────────────────────

    Connections {
        target: KarakeepApi

        onBookmarkUpdated: {
            if (bookmark.id !== bookmarkId) return
            saving = false
            // Refresh local state
            if (bookmark.favourited !== undefined) bookmarkFavourited = bookmark.favourited
            if (bookmark.archived  !== undefined) bookmarkArchived   = bookmark.archived
            if (bookmark.note      !== undefined) bookmarkNote       = bookmark.note
        }

        onBookmarkDeleted: {
            if (id !== bookmarkId) return
            pageStack.pop()
        }

        onRequestError: {
            saving = false
        }
    }

    // ── UI ────────────────────────────────────────────────────────────────────

    SilicaFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: contentCol.height + Theme.paddingLarge

        // ── Pull-down actions ─────────────────────────────────────────────────

        PullDownMenu {
            busy: saving

            MenuItem {
                text: qsTr("Delete")
                onClicked: {
                    var bid = bookmarkId
                    page.remorseAction(qsTr("Deleting bookmark"), function() {
                        KarakeepApi.deleteBookmark(bid)
                    })
                }
            }
            MenuItem {
                text: bookmarkArchived ? qsTr("Unarchive") : qsTr("Archive")
                onClicked: {
                    saving = true
                    KarakeepApi.updateBookmark(bookmarkId, { archived: !bookmarkArchived })
                }
            }
            MenuItem {
                text: bookmarkFavourited ? qsTr("Remove from favourites") : qsTr("Add to favourites")
                onClicked: {
                    saving = true
                    KarakeepApi.updateBookmark(bookmarkId, { favourited: !bookmarkFavourited })
                }
            }
            MenuItem {
                text: qsTr("Add to list…")
                onClicked: {
                    var bId = bookmarkId
                    var picker = pageStack.push(Qt.resolvedUrl("ListPickerDialog.qml"), {})
                    picker.accepted.connect(function() {
                        KarakeepApi.addBookmarkToList(picker.selectedListId, bId)
                    })
                }
            }
            MenuItem {
                text: qsTr("Open in browser")
                visible: bookmarkUrl !== ""
                onClicked: Qt.openUrlExternally(bookmarkUrl)
            }
        }

        Column {
            id: contentCol
            width: parent.width
            spacing: 0

            // ── Hero image ────────────────────────────────────────────────────

            Item {
                width: parent.width
                height: heroImage.status === Image.Ready ? Math.min(heroImage.implicitHeight, parent.width * 0.5) : 0
                visible: height > 0
                clip: true

                Image {
                    id: heroImage
                    anchors.fill: parent
                    source: bookmarkImageUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                }

                // Gradient overlay at the bottom
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height * 0.4
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Theme.overlayBackgroundColor }
                    }
                }
            }

            // ── Page header ───────────────────────────────────────────────────

            PageHeader {
                title: bookmarkTitle || qsTr("Untitled")
                description: bookmarkDomain
            }

            // ── Source row (favicon + domain + status icons) ──────────────────

            Row {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                }
                spacing: Theme.paddingSmall
                visible: bookmarkUrl !== "" || bookmarkType === "text"

                Item {
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: bookmarkFavicon
                        visible: bookmarkFavicon !== "" && status === Image.Ready
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                    }
                    Icon {
                        anchors.fill: parent
                        source: bookmarkType === "text"
                            ? "image://theme/icon-s-note"
                            : "image://theme/icon-s-link"
                        color: Theme.secondaryColor
                        visible: bookmarkFavicon === ""
                    }
                }

                Label {
                    width: parent.width - Theme.iconSizeSmall - Theme.paddingSmall * 2 -
                           (bookmarkFavourited ? Theme.iconSizeSmall + Theme.paddingSmall : 0) -
                           (bookmarkArchived   ? Theme.iconSizeSmall + Theme.paddingSmall : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: bookmarkUrl
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    truncationMode: TruncationMode.Fade
                    visible: bookmarkUrl !== ""
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Qt.openUrlExternally(bookmarkUrl)
                    }
                }

                Icon {
                    source: "image://theme/icon-s-favorite"
                    color: Theme.highlightColor
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    visible: bookmarkFavourited
                }

                Icon {
                    source: "image://theme/icon-s-archive"
                    color: Theme.secondaryColor
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    visible: bookmarkArchived
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            // ── Description ───────────────────────────────────────────────────

            Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                }
                text: bookmarkDescription
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                visible: text !== ""
            }

            Item {
                width: 1
                height: bookmarkDescription !== "" ? Theme.paddingMedium : 0
                visible: bookmarkDescription !== ""
            }

            // ── Text content (for text bookmarks) ─────────────────────────────

            Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                }
                text: bookmarkText
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                visible: bookmarkType === "text" && text !== ""
            }

            Item {
                width: 1
                height: (bookmarkType === "text" && bookmarkText !== "") ? Theme.paddingMedium : 0
                visible: bookmarkType === "text" && bookmarkText !== ""
            }

            // ── AI Summary ────────────────────────────────────────────────────

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: bookmarkSummary !== ""

                SectionHeader {
                    text: qsTr("Summary")
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                    }
                    text: bookmarkSummary
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                }
            }

            // ── Note ──────────────────────────────────────────────────────────

            SectionHeader {
                text: qsTr("Note")
                visible: bookmarkNote !== "" || noteArea.activeFocus
            }

            TextArea {
                id: noteArea
                width: parent.width
                text: bookmarkNote
                placeholderText: qsTr("Add a personal note…")
                label: qsTr("Note")
                wrapMode: TextEdit.WordWrap
                onActiveFocusChanged: {
                    if (!activeFocus && text !== bookmarkNote) {
                        saving = true
                        KarakeepApi.updateBookmark(bookmarkId, { note: text })
                        bookmarkNote = text
                    }
                }
            }

            // ── Tags ──────────────────────────────────────────────────────────

            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: bookmarkTagNames !== ""

                SectionHeader {
                    text: qsTr("Tags")
                }

                Flow {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                    }
                    spacing: Theme.paddingSmall

                    Repeater {
                        model: bookmarkTagNames.split(", ").filter(function(t) { return t !== "" })
                        delegate: Rectangle {
                            height: chipLabel.height + Theme.paddingMedium
                            width: chipLabel.width + Theme.paddingLarge
                            radius: height / 2
                            color: Theme.rgba(Theme.highlightColor, 0.15)

                            Label {
                                id: chipLabel
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.highlightColor
                            }
                        }
                    }
                }

                Item { width: 1; height: Theme.paddingSmall }
            }

            // ── Metadata ──────────────────────────────────────────────────────

            Column {
                width: parent.width
                spacing: 0
                visible: bookmarkAuthor !== "" || bookmarkPublisher !== "" || bookmarkCreatedAt !== ""

                SectionHeader {
                    text: qsTr("Details")
                }

                DetailItem {
                    label: qsTr("Author")
                    value: bookmarkAuthor
                    visible: bookmarkAuthor !== ""
                }

                DetailItem {
                    label: qsTr("Publisher")
                    value: bookmarkPublisher
                    visible: bookmarkPublisher !== ""
                }

                DetailItem {
                    label: qsTr("Saved")
                    value: formatDate(bookmarkCreatedAt)
                    visible: bookmarkCreatedAt !== ""
                }
            }
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors {
            right: parent.right
            bottom: parent.bottom
            rightMargin: Theme.paddingLarge
            bottomMargin: Theme.paddingLarge
        }
        running: saving
        size: BusyIndicatorSize.Small
    }
}
