import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property bool loading: false
    property bool hasError: false
    property string errorMessage: ""

    // ── Data model ────────────────────────────────────────────────────────────

    ListModel { id: listsModel }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function refresh() {
        loading = true
        hasError = false
        listsModel.clear()
        KarakeepApi.fetchLists()
    }

    // ── API connections ───────────────────────────────────────────────────────

    Connections {
        target: KarakeepApi

        onListsFetched: {
            loading = false
            for (var i = 0; i < lists.length; i++)
                listsModel.append(lists[i])
        }

        onRequestError: {
            if (operation !== "fetchLists") return
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
        model: listsModel

        PullDownMenu {
            busy: loading
            MenuItem {
                text: qsTr("Refresh")
                onClicked: refresh()
            }
        }

        header: Column {
            width: parent.width
            spacing: 0

            PageHeader {
                title: qsTr("Lists")
                description: listsModel.count > 0 ? listsModel.count + " " + qsTr("lists") : ""
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
            contentHeight: contentRow.height + 2 * Theme.paddingSmall

            onClicked: pageStack.push(Qt.resolvedUrl("ListDetailPage.qml"), {
                listId:          model.id,
                listName:        model.name,
                listDescription: model.description,
                listIcon:        model.icon,
                listType:        model.type,
                listIsPublic:    model.isPublic
            })

            Row {
                id: contentRow
                anchors {
                    left: parent.left; right: parent.right
                    top: parent.top
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                    topMargin: Theme.paddingSmall
                }
                spacing: Theme.paddingMedium

                // ── Icon ──────────────────────────────────────────────────────

                Item {
                    width: Theme.iconSizeLarge
                    height: Theme.iconSizeLarge
                    anchors.verticalCenter: textCol.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.paddingSmall
                        color: Theme.rgba(Theme.highlightColor, 0.10)
                        visible: model.icon !== ""
                    }

                    Label {
                        anchors.centerIn: parent
                        text: model.icon !== "" ? model.icon : ""
                        font.pixelSize: Theme.fontSizeLarge
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

                // ── Text ──────────────────────────────────────────────────────

                Column {
                    id: textCol
                    width: parent.width - Theme.iconSizeLarge - Theme.paddingMedium
                    spacing: Theme.paddingSmall / 2

                    // Name row
                    Row {
                        width: parent.width
                        spacing: Theme.paddingSmall

                        Label {
                            text: model.name
                            color: listItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                            font.pixelSize: Theme.fontSizeMedium
                            truncationMode: TruncationMode.Fade
                            width: Math.min(implicitWidth,
                                           parent.width
                                           - (model.isPublic ? Theme.iconSizeTiny + Theme.paddingSmall : 0)
                                           - (model.type === "smart" ? smartBadge.width + Theme.paddingSmall : 0))
                        }

                        // Smart badge
                        Rectangle {
                            id: smartBadge
                            visible: model.type === "smart"
                            height: smartLabel.height + Theme.paddingSmall
                            width: smartLabel.width + Theme.paddingMedium
                            radius: height / 2
                            color: Theme.rgba(Theme.highlightColor, 0.15)
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                id: smartLabel
                                anchors.centerIn: parent
                                text: qsTr("smart")
                                font.pixelSize: Theme.fontSizeTiny
                                color: Theme.highlightColor
                            }
                        }

                        // Public globe
                        Icon {
                            source: "image://theme/icon-s-global"
                            width: Theme.iconSizeTiny
                            height: Theme.iconSizeTiny
                            visible: model.isPublic
                            color: Theme.secondaryColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Label {
                        width: parent.width
                        text: model.description
                        color: Theme.secondaryColor
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        visible: model.description !== ""
                    }
                }
            }
        }

        // ── Placeholder / busy ────────────────────────────────────────────────

        ViewPlaceholder {
            enabled: !loading && listsModel.count === 0 && !hasError
            text: qsTr("No lists yet")
            hintText: qsTr("Create lists in the Karakeep web interface")
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: loading && listsModel.count === 0
            size: BusyIndicatorSize.Large
        }

        VerticalScrollDecorator {}
    }
}
