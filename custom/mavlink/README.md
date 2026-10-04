# AeroTHON MAVLink Dialect

This directory contains the custom MAVLink dialect for AeroTHON-GCS.

## Dialect Location

The `aerothon` dialect XML definition is stored at:

```
custom/mavlink/aerothon.xml
```

The dialect name is set via the CMake variable `QGC_MAVLINK_DIALECT "aerothon"` in
`custom/cmake/CustomOverrides.cmake`. The QGC MAVLink integration stages this file
beside the pinned upstream `common.xml` in the build tree before running mavgen.

## Adding Custom Messages

1. Define your messages in `aerothon.xml`, including any upstream dialects
   via `<include>common.xml</include>`.
2. Re-run `just configure` so CMake regenerates the MAVLink C headers.
3. Include generated message headers through `MAVLinkLib.h` or the generated
   `aerothon/mavlink.h` include path.
