# Module map — post-Orca cutover

The application is now divided by ownership rather than by attempts to port the native slicer into Dart.

| Area | Owner |
|---|---|
| slicing geometry / Clipper / walls / Arachne | OrcaSlicer v2.4.2 |
| infill / support / seam / bridge / travel / G-code | OrcaSlicer v2.4.2 |
| engine process and artifact boundary | `lib/core/orca` |
| model/project I/O | `lib/core/model_io` |
| QIDI profile loading/resolution | `lib/core/profiles` |
| G-code parsing | `lib/core/gcode/gcode_parser.dart` |
| Prepare/editor | `lib/features/prepare` |
| Preview | `lib/features/preview` |
| Device/cloud/local printer | `lib/features/device` |
| calibration | `lib/features/calibration` |
| workspace orchestration | `lib/features/workspace` |

The former `lib/core/slicer` module has been removed. Do not recreate a parallel production slicer in Dart; extend the Orca engine boundary or application-side project/state integration instead.
