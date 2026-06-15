import QtQuick 2.0
import Sailfish.Silica 1.0

Page {
    id: page
    allowedOrientations: Orientation.All

    property bool testInProgress: false
    property bool testSuccess: false
    property bool testDone: false
    property string testMessage: ""
    property bool settingsDirty: false
    property string settingsStateMessage: ""

    onStatusChanged: {
        if (status === PageStatus.Deactivating && hasUnsavedChanges())
            saveSettings()
    }

    function normalizedServerUrl(text) {
        var url = text.trim()
        // Strip trailing slash (Qt 5.6 safe — no endsWith)
        while (url.length > 0 && url.charAt(url.length - 1) === "/")
            url = url.slice(0, url.length - 1)
        return url
    }

    function hasUnsavedChanges() {
        return normalizedServerUrl(serverUrlField.text) !== AppSettings.serverUrl
            || apiKeyField.text.trim() !== AppSettings.apiKey
    }

    function updateSettingsState(savedNow) {
        settingsDirty = hasUnsavedChanges()
        if (settingsDirty)
            settingsStateMessage = qsTr("You have unsaved changes.")
        else if (savedNow)
            settingsStateMessage = qsTr("Settings saved.")
        else
            settingsStateMessage = ""
    }

    function saveUrl() {
        var url = normalizedServerUrl(serverUrlField.text)
        AppSettings.serverUrl = url
    }

    function saveKey() {
        AppSettings.apiKey = apiKeyField.text.trim()
    }

    function saveSettings() {
        saveUrl()
        saveKey()
        updateSettingsState(true)
    }

    function testConnection() {
        saveSettings()
        testDone = false
        if (!AppSettings.configured) {
            testDone = true
            testSuccess = false
            testMessage = qsTr("Please fill in both fields first.")
            return
        }
        testInProgress = true
        KarakeepApi.whoAmI()
    }

    Connections {
        target: KarakeepApi
        onWhoAmIFetched: {
            testInProgress = false
            testDone = true
            testSuccess = true
            testMessage = (typeof user.email !== "undefined" && user.email !== "")
                ? qsTr("Connected as %1").arg(user.email)
                : qsTr("Connected successfully")
        }
        onRequestError: {
            if (operation !== "whoAmI") return
            testInProgress = false
            testDone = true
            testSuccess = false
            testMessage = httpStatus > 0
                ? qsTr("Error %1: %2").arg(httpStatus).arg(message)
                : qsTr("Could not reach server: %1").arg(message)
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: 0

            PageHeader {
                title: qsTr("Settings")
            }

            SectionHeader {
                text: qsTr("Server")
            }

            TextField {
                id: serverUrlField
                width: parent.width
                label: qsTr("Server URL")
                placeholderText: qsTr("https://karakeep.example.com")
                text: AppSettings.serverUrl
                inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoPredictiveText
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: apiKeyField.focus = true
                onTextChanged: updateSettingsState(false)
                onActiveFocusChanged: { if (!activeFocus) { saveSettings(); testDone = false } }
            }

            PasswordField {
                id: apiKeyField
                width: parent.width
                label: qsTr("API Key")
                placeholderText: qsTr("Your Karakeep API key")
                text: AppSettings.apiKey
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: { focus = false; testConnection() }
                onTextChanged: updateSettingsState(false)
                onActiveFocusChanged: { if (!activeFocus) { saveSettings(); testDone = false } }
            }

            Item { width: 1; height: Theme.paddingLarge }

            Column {
                width: parent.width
                spacing: Theme.paddingMedium

                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Test connection")
                    preferredWidth: Theme.buttonWidthLarge
                    enabled: !testInProgress
                    onClicked: testConnection()

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: testInProgress
                        size: BusyIndicatorSize.Small
                        visible: testInProgress
                    }
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                    }
                    text: testMessage
                    color: testSuccess ? Theme.highlightColor : Theme.errorColor
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: testDone && !testInProgress
                }

                Label {
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.horizontalPageMargin
                        rightMargin: Theme.horizontalPageMargin
                    }
                    text: settingsStateMessage
                    color: settingsDirty ? Theme.secondaryColor : Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    visible: settingsStateMessage !== ""
                }
            }

            Item { width: 1; height: Theme.paddingLarge * 2 }

            SectionHeader {
                text: qsTr("How to get an API key")
            }

            Label {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: Theme.horizontalPageMargin
                    rightMargin: Theme.horizontalPageMargin
                }
                text: qsTr("Open your Karakeep web interface, go to Settings \u2192 API Keys, and create a new key with full access.")
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            Item { width: 1; height: Theme.paddingLarge }

            SectionHeader { text: qsTr("About") }

            DetailItem {
                label: qsTr("Version")
                value: "0.3.1"  // x-release-please-version
            }
        }

        VerticalScrollDecorator {}
    }
}
