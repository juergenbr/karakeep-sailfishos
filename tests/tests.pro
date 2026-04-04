TARGET = tst_karakeepapi

QT += testlib network
QT -= gui

CONFIG += testcase console
CONFIG -= app_bundle

TEMPLATE = app

include(../karakeep_backend.pri)

SOURCES += tst_karakeepapi.cpp
