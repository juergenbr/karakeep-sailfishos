INCLUDEPATH += $$PWD/src

HEADERS += \
    $$PWD/src/api/appsettings.h \
    $$PWD/src/api/karakeepapi.h \
    $$PWD/src/api/karakeeptypes.h

SOURCES += \
    $$PWD/src/api/appsettings.cpp \
    $$PWD/src/api/karakeepapi.cpp

QT += network
