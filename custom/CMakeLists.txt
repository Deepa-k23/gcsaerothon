message(STATUS "QGC: Adding AeroTHON-GCS V2 custom overlay")

# ─── Resources ────────────────────────────────────────────────────────────────
set(CUSTOM_RESOURCES ${CMAKE_CURRENT_SOURCE_DIR}/custom.qrc CACHE INTERNAL "" FORCE)
set(QGC_RESOURCES ${CUSTOM_RESOURCES} CACHE STRING "Custom resources" FORCE)

# ─── C++ Sources ──────────────────────────────────────────────────────────────
set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AerothonPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AerothonPlugin.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroTHONManager.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroTHONManager.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroTHONSettings.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroTHONSettings.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroAlertModel.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroMessageModel.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroAlertModel.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroDetectionEventModel.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroDetectionEventModel.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroOperationalHealth.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroOperationalHealth.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroSessionRecorder.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroSessionRecorder.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroVideoReceiver.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroVideoReceiver.h
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroAudioCoordinator.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/AeroAudioCoordinator.h
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_INCLUDE_DIRECTORIES ${CMAKE_CURRENT_SOURCE_DIR}/src CACHE INTERNAL "" FORCE)

set(CUSTOM_DEFINITIONS
    QGC_CUSTOM_BUILD
    AEROTHON_HAVE_QGC
    AEROTHON_HAVE_MANAGER
    CUSTOMHEADER="AerothonPlugin.h"
    CUSTOMCLASS=AerothonPlugin
    CACHE INTERNAL "" FORCE
)
