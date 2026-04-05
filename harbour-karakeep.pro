TARGET = harbour-karakeep

CONFIG += sailfishapp

include(karakeep_backend.pri)

SOURCES += src/harbour-karakeep.cpp

DISTFILES += \
    qml/harbour-karakeep.qml \
    qml/cover/CoverPage.qml \
    qml/pages/MainPage.qml \
    qml/pages/SettingsPage.qml \
    qml/pages/BookmarkDetailPage.qml \
    qml/pages/AddBookmarkPage.qml \
    qml/pages/ListsPage.qml \
    qml/pages/ListDetailPage.qml \
    qml/pages/ListPickerDialog.qml \
    rpm/harbour-karakeep.changes \
    rpm/harbour-karakeep.spec \
    translations/*.ts \
    harbour-karakeep.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n
TRANSLATIONS += translations/harbour-karakeep-de.ts
