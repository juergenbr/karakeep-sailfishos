import QtQuick 2.0
import Sailfish.Silica 1.0

// A list picker presented as a Silica Dialog.
// Push with pageStack.push(); connect to accepted signal to receive result.
//
// Usage:
//   var d = pageStack.push(Qt.resolvedUrl("ListPickerDialog.qml"),
//                          { excludeListId: currentListId })
//   d.accepted.connect(function() {
//       doSomething(d.selectedListId, d.selectedListName)
//   })
Dialog {
    id: dialog
    allowedOrientations: Orientation.All

    // Optionally exclude one list (e.g. the list the bookmark already belongs to)
    property string excludeListId: ""

    // Result — populated when the user taps a list and the dialog accepts
    property string selectedListId:   ""
    property string selectedListName: ""

    // Accept only once a list has been chosen (tap triggers accept() directly)
    canAccept: selectedListId !== ""

    property bool   loading:  false
    property bool   hasError: false
    property string errorMessage: ""

    ListModel { id: listsModel }

    // ── API connections ───────────────────────────────────────────────────────

    Connections {
        target: KarakeepApi

        onListsFetched: {
            loading = false
            listsModel.clear()
            for (var i = 0; i < lists.length; i++) {
                if (lists[i].id !== excludeListId)
                    listsModel.append(lists[i])
            }
        }

        onRequestError: {
            if (operation !== "fetchLists") return
            loading = false
            hasError = true
            errorMessage = message
        }
    }

    Component.onCompleted: {
        loading = true
        KarakeepApi.fetchLists()
    }

    // ── Header ────────────────────────────────────────────────────────────────

    DialogHeader {
        id: header
        title: qsTr("Choose a list")
        // No accept button — selection via tap
        acceptText: ""
        cancelText: qsTr("Cancel")
    }

    // ── Body ──────────────────────────────────────────────────────────────────

    SilicaListView {
        id: listView
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        model: listsModel
        clip: true

        delegate: ListItem {
            id: listItem
            width: listView.width
            contentHeight: Math.max(iconItem.height, textCol.height) + 2 * Theme.paddingSmall

            onClicked: {
                dialog.selectedListId   = model.id
                dialog.selectedListName = model.name
                dialog.accept()
            }

            Row {
                anchors {
                    left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                }
                spacing: Theme.paddingMedium

                // Icon
                Item {
                    id: iconItem
                    width: Theme.iconSizeMedium
                    height: Theme.iconSizeMedium
                    anchors.verticalCenter: textCol.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall / 2
                        color: Theme.rgba(Theme.highlightColor, 0.10)
                        visible: model.icon !== ""
                    }

                    Label {
                        anchors.centerIn: parent
                        text: model.icon
                        font.pixelSize: Theme.fontSizeMedium
                        visible: model.icon !== ""
                    }

                    Icon {
                        anchors.centerIn: parent
                        source: model.type === "smart"
                            ? "image://theme/icon-m-search"
                            : "image://theme/icon-m-note"
                        color: listItem.highlighted ? Theme.highlightColor : Theme.secondaryColor
                        width: Theme.iconSizeMedium
                        height: Theme.iconSizeMedium
                        visible: model.icon === ""
                    }
                }

                // Text
                Column {
                    id: textCol
                    width: parent.width - iconItem.width - Theme.paddingMedium
                    spacing: Theme.paddingSmall / 4
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        width: parent.width
                        text: model.name
                        color: listItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                        font.pixelSize: Theme.fontSizeMedium
                        truncationMode: TruncationMode.Fade
                    }

                    Label {
                        width: parent.width
                        text: model.description
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        truncationMode: TruncationMode.Fade
                        visible: model.description !== ""
                    }
                }
            }
        }

        // ── Placeholder / busy ────────────────────────────────────────────────

        ViewPlaceholder {
            enabled: !loading && listsModel.count === 0 && !hasError
            text: qsTr("No lists available")
        }

        ViewPlaceholder {
            enabled: hasError
            text: qsTr("Could not load lists")
            hintText: errorMessage
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: loading && listsModel.count === 0
            size: BusyIndicatorSize.Large
        }

        VerticalScrollDecorator {}
    }
}
