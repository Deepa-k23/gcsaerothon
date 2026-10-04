set(QGC_APP_NAME "AeroTHON-GCS" CACHE STRING "Application name" FORCE)
set(QGC_APPIMAGE_APPDATA_DEVELOPER "aerothon" CACHE STRING "AppImage developer" FORCE)
set(QGC_QT_MAXIMUM_VERSION "6.11.2" CACHE STRING "Maximum supported Qt version" FORCE)
# Enable custom MAVLink dialect
set(QGC_MAVLINK_DIALECT "aerothon" CACHE STRING "MAVLink dialect" FORCE)
set(QGC_MAVLINK_DIALECT_FILE "${CMAKE_SOURCE_DIR}/custom/mavlink/aerothon.xml" CACHE FILEPATH
    "Custom MAVLink dialect definition" FORCE)
