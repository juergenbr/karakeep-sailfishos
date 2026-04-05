import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"

ApplicationWindow {
    id: appWindow

    // Shared state for the cover page
    property int totalBookmarkCount: 0
    property string lastBookmarkTitle: ""

    // Cover action coordination: MainPage watches this
    signal addBookmarkRequested()

    initialPage: Component { MainPage {} }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations
}
