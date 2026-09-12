import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/point.dart';
import 'package:qidi_flow_flutter/core/gcode/gcode_writer.dart';
import 'package:qidi_flow_flutter/core/slicer/toolpath.dart';

void main() {
  test('writes deterministic relative-extrusion G-code', () {
    const plan = ToolpathPlan(layers: [ToolpathLayer(z: 0.2, paths: [ToolpathPolyline(points: [Point2(0, 0), Point2(10, 0)], kind: ToolpathKind.infill, closed: false)])]);
    final gcode = const GCodeWriter().write(plan);
    expect(gcode, contains('G90 ; absolute XYZ'));
    expect(gcode, contains('M83 ; relative extrusion'));
    expect(gcode, contains(';LAYER:0'));
    expect(gcode, contains(';TYPE:FILL'));
    expect(gcode, contains('G1 X10 Y0 E'));
    expect(gcode, endsWith('M84\n'));
  });
}
