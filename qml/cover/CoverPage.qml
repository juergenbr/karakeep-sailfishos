import QtQuick 2.0
import Sailfish.Silica 1.0

CoverBackground {
    id: cover

    Column {
        anchors {
            left: parent.left
            right: parent.right
            leftMargin: Theme.paddingMedium
            rightMargin: Theme.paddingMedium
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.paddingSmall

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "image://theme/icon-m-link"
            width: Theme.iconSizeLarge
            height: Theme.iconSizeLarge
            color: Theme.primaryColor
            opacity: 0.7
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "KaraKeep"
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: Theme.primaryColor
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: appWindow.totalBookmarkCount > 0
                ? appWindow.totalBookmarkCount + " " + qsTr("bookmarks")
                : AppSettings.configured
                    ? qsTr("Loading…")
                    : qsTr("Not configured")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.secondaryColor
        }

        Item { width: 1; height: Theme.paddingSmall }

        Label {
            anchors {
                left: parent.left
                right: parent.right
            }
            text: appWindow.lastBookmarkTitle
            font.pixelSize: Theme.fontSizeTiny
            color: Theme.secondaryHighlightColor
            truncationMode: TruncationMode.Fade
            horizontalAlignment: Text.AlignHCenter
            visible: appWindow.lastBookmarkTitle !== ""
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }
    }

    CoverActionList {
        CoverAction {
            iconSource: "image://theme/icon-cover-new"
            onTriggered: {
                appWindow.addBookmarkRequested()
                appWindow.activate()
            }
        }
    }
}
