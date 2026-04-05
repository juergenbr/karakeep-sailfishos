import QtQuick 2.0
import Sailfish.Silica 1.0

Dialog {
    id: dialog
    allowedOrientations: Orientation.All

    property string bookmarkType: "link"   // "link" | "text"

    // Optional: when set, the new bookmark is added to this list after creation
    property string targetListId: ""

    property bool   saving:           false
    property bool   saveError:        false
    property string saveErrorMessage: ""
    property string _pendingBookmarkId: ""   // holds id while waiting for addBookmarkToList

    canAccept: bookmarkType === "link"
        ? urlField.text.trim() !== ""
        : textArea.text.trim() !== ""

    onAccepted: {
        saving = true
        saveError = false
        saveErrorMessage = ""
        if (bookmarkType === "link") {
            KarakeepApi.createLinkBookmark(
                urlField.text.trim(),
                titleField.text.trim(),
                tagsField.text.trim() !== "" ? tagsField.text.trim().split(",").map(function(t) { return t.trim() }) : []
            )
        } else {
            KarakeepApi.createTextBookmark(
                textArea.text.trim(),
                titleField.text.trim(),
                tagsField.text.trim() !== "" ? tagsField.text.trim().split(",").map(function(t) { return t.trim() }) : []
            )
        }
    }

    Connections {
        target: KarakeepApi

        onBookmarkCreated: {
            if (targetListId !== "") {
                // Step 2: add the new bookmark to the target list before popping
                dialog._pendingBookmarkId = bookmark.id
                KarakeepApi.addBookmarkToList(targetListId, bookmark.id)
            } else {
                saving = false
                pageStack.pop()
            }
        }

        onBookmarkAddedToList: {
            if (listId !== targetListId || bookmarkId !== dialog._pendingBookmarkId) return
            saving = false
            pageStack.pop()
        }

        onRequestError: {
            if (operation === "addBookmarkToList") {
                // Bookmark was created; only the list-add step failed — still dismiss
                saving = false
                pageStack.pop()
            } else {
                saving = false
                saveError = true
                saveErrorMessage = message
            }
        }
    }

    DialogHeader {
        id: header
        acceptText: qsTr("Save")
        cancelText: qsTr("Cancel")
        title: bookmarkType === "link" ? qsTr("Add link") : qsTr("Add note")
    }

    SilicaFlickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: 0

            TextField {
                id: urlField
                width: parent.width
                label: qsTr("URL")
                placeholderText: qsTr("https://…")
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                visible: bookmarkType === "link"
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: titleField.focus = true
            }

            TextArea {
                id: textArea
                width: parent.width
                label: qsTr("Text")
                placeholderText: qsTr("Write your note here…")
                wrapMode: TextEdit.WordWrap
                visible: bookmarkType === "text"
            }

            TextField {
                id: titleField
                width: parent.width
                label: qsTr("Title (optional)")
                placeholderText: qsTr("Leave empty to auto-detect")
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: tagsField.focus = true
            }

            TextField {
                id: tagsField
                width: parent.width
                label: qsTr("Tags (optional)")
                placeholderText: qsTr("reading, tech, news")
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    focus = false
                    if (dialog.canAccept) dialog.accept()
                }
            }

            Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                }
                text: saveErrorMessage
                color: Theme.errorColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                visible: saveError
            }
        }

        VerticalScrollDecorator {}
    }

    BusyIndicator {
        anchors.centerIn: parent
        running: saving
        size: BusyIndicatorSize.Large
    }
}
