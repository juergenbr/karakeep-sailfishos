TARGET = harbour-karakeep

CONFIG += sailfishapp

SOURCES += src/harbour-karakeep.cpp

DISTFILES += \
    qml/harbour-karakeep.qml \
    qml/cover/CoverPage.qml \
    qml/pages/MainPage.qml \
    rpm/harbour-karakeep.changes \
    rpm/harbour-karakeep.spec \
    translations/*.ts \
    harbour-karakeep.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n
TRANSLATIONS += translations/harbour-karakeep-de.ts
