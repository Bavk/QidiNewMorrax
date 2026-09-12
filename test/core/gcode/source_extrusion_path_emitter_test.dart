import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/gcode/extruder.dart';
import 'package:qidi_flow_flutter/core/gcode/source_extrusion_path_emitter.dart';
import 'package:qidi_flow_flutter/core/geometry/source_arc_fitter.dart';
import 'package:qidi_flow_flutter/core/geometry/source_circle.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polyline.dart';
import 'package:qidi_flow_flutter/core/slicer/extrusion_entity.dart';

const relativeConfig = ExtruderConfigSnapshot(
  useRelativeEDistances: true,
  filamentMap: [1],
  filamentNozzleMap: [1],
  nozzleVolumeTypes: [0],
  extruderTypes: [0],
  filamentDiameters: [1.75],
  filamentDensities: [1.24],
  filamentCosts: [20],
  filamentConfigIndexes: [0],
  filamentFlowRatios: [1],
  retractBeforeWipePercents: [0],
  retractionLengths: [0.8],
  zHops: [0.4],
  retractionSpeeds: [30],
  deretractionSpeeds: [30],
  retractRestartExtras: [0],
  retractLengthsToolchange: [2],
  retractRestartExtrasToolchange: [0],
);

void main() {
  test('GCodeFormatter uses source XYZ=3 and E=5 rounding/trimming', () {
    expect(SourceGCodeFormatter2.axis('X', 1.23456, 3), ' X1.235');
    expect(SourceGCodeFormatter2.axis('Y', -0.0006, 3), ' Y-0.001');
    expect(SourceGCodeFormatter2.axis('E', 0.1570796, 5), ' E0.15708');
    expect(SourceGCodeFormatter2.axis('I', 0, 3), ' I0');
  });

  test('arc fitting metadata emits source-style G3 payload end-to-end', () {
    final path = _quarterArcPath();
    final emitter = SourceExtrusionPathEmitter2(
      extruder: ExtruderState(
        id: 0,
        config: relativeConfig,
        shareExtruder: false,
      ),
    );

    final gcode = emitter.emit(
      path,
      ePerMm: 0.1,
      enableArcFitting: true,
    );

    expect(gcode, 'G3 X0 Y1 I-1 J0 E0.15708\n');
    expect(emitter.currentPosition!.x, 0);
    expect(emitter.currentPosition!.y, 1);
  });

  test('disabled arc fitting falls back to source G1 line iteration', () {
    final path = _quarterArcPath();
    final emitter = SourceExtrusionPathEmitter2(
      extruder: ExtruderState(
        id: 0,
        config: relativeConfig,
        shareExtruder: false,
      ),
    );

    final gcode = emitter.emit(
      path,
      ePerMm: 0.1,
      enableArcFitting: false,
    );

    expect(gcode, isNot(contains('G2')));
    expect(gcode, isNot(contains('G3')));
    expect(RegExp(r'^G1 ', multiLine: true).allMatches(gcode), hasLength(2));
  });

  test('spiral mode disables G2/G3 exactly like source GCode.cpp', () {
    final path = _quarterArcPath();
    final emitter = SourceExtrusionPathEmitter2(
      extruder: ExtruderState(
        id: 0,
        config: relativeConfig,
        shareExtruder: false,
      ),
    );

    final gcode = emitter.emit(
      path,
      ePerMm: 0.1,
      enableArcFitting: true,
      spiralMode: true,
    );

    expect(gcode, isNot(contains('G2')));
    expect(gcode, isNot(contains('G3')));
    expect(RegExp(r'^G1 ', multiLine: true).allMatches(gcode), hasLength(2));
  });

  test('force_no_extrusion omits E and does not mutate Extruder E state', () {
    final path = _quarterArcPath()..setForceNoExtrusion(true);
    final extruder = ExtruderState(
      id: 0,
      config: relativeConfig,
      shareExtruder: false,
    );
    final emitter = SourceExtrusionPathEmitter2(extruder: extruder);

    final gcode = emitter.emit(
      path,
      ePerMm: 0.1,
      enableArcFitting: true,
    );

    expect(gcode, 'G3 X0 Y1 I-1 J0\n');
    expect(extruder.absoluteE, 0);
  });

  test('origin/extruder/plate transforms match source and do not alter I/J', () {
    final emitter = SourceExtrusionPathEmitter2(
      extruder: ExtruderState(
        id: 0,
        config: relativeConfig,
        shareExtruder: false,
      ),
      coordinates: const SourceGCodeCoordinateContext(
        originX: 10,
        originY: 20,
        extruderOffsetX: 1,
        extruderOffsetY: 2,
        plateOffsetX: 3,
        plateOffsetY: 4,
      ),
    );

    final gcode = emitter.emit(
      _quarterArcPath(),
      ePerMm: 0.1,
      enableArcFitting: true,
    );

    // end (0,1) -> point_to_gcode (9,19) -> plate (6,15).
    // I/J are point_to_gcode(center)-point_to_gcode(start), so translations
    // cancel and the center offset stays (-1,0).
    expect(gcode, 'G3 X6 Y15 I-1 J0 E0.15708\n');
  });

  test('full source comments use space-semicolon-space formatting', () {
    final emitter = SourceExtrusionPathEmitter2(
      extruder: ExtruderState(
        id: 0,
        config: relativeConfig,
        shareExtruder: false,
      ),
      fullGCodeComment: true,
    );
    final gcode = emitter.emit(
      _quarterArcPath(),
      ePerMm: 0.1,
      enableArcFitting: true,
      description: 'outer wall',
    );
    expect(gcode, endsWith(' ; outer wall\n'));
  });

  test('sloped source path refuses XY-only approximation until XYZ port exists', () {
    final emitter = SourceExtrusionPathEmitter2(
      extruder: ExtruderState(
        id: 0,
        config: relativeConfig,
        shareExtruder: false,
      ),
    );
    expect(
      () => emitter.emit(
        _quarterArcPath(),
        ePerMm: 0.1,
        enableArcFitting: true,
        sloped: true,
      ),
      throwsUnsupportedError,
    );
  });
}

ExtrusionPath2 _quarterArcPath() {
  final polyline = SourcePolyline2(const [
    SourcePoint2(100000, 0),
    SourcePoint2(70710, 70710),
    SourcePoint2(0, 100000),
  ]);
  polyline.fittingResult.add(PathFittingData2(
    startPointIndex: 0,
    endPointIndex: 2,
    pathType: MovePathType2.arcCcw,
    arcData: SourceArcSegment2(
      center: const SourcePoint2(0, 0),
      radius: 100000,
      startPoint: const SourcePoint2(100000, 0),
      endPoint: const SourcePoint2(0, 100000),
      direction: ArcDirection2.ccw,
    ),
  ));
  return ExtrusionPath2(
    polyline: polyline,
    role: ExtrusionRole.externalPerimeter,
    mm3PerMm: 0.05,
    width: 0.45,
    height: 0.2,
  );
}
