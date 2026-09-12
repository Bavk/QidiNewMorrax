import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/slicer/flow.dart';

void main() {
  group('translated tests/fff_print/test_flow.cpp math fixtures', () {
    const nozzle = 0.4;
    const layerHeight = 0.4;

    test('auto external perimeter spacing uses 1.125 * nozzle width', () {
      final flow = Flow.newFromConfigWidth(
        role: FlowRole.externalPerimeter,
        configuredWidth: 0,
        nozzleDiameter: nozzle,
        height: layerHeight,
      );
      expect(
        flow.spacing,
        closeTo(
          1.125 * nozzle - layerHeight * (1 - math.pi / 4),
          1e-12,
        ),
      );
    });

    test('auto internal perimeter spacing uses 1.125 * nozzle width', () {
      final flow = Flow.newFromConfigWidth(
        role: FlowRole.perimeter,
        configuredWidth: 0,
        nozzleDiameter: nozzle,
        height: layerHeight,
      );
      expect(flow.width, closeTo(1.125 * nozzle, 1e-12));
      expect(
        flow.spacing,
        closeTo(
          1.125 * nozzle - layerHeight * (1 - math.pi / 4),
          1e-12,
        ),
      );
    });

    test('manual width spacing follows rounded rectangle model', () {
      final flow = Flow.newFromConfigWidth(
        role: FlowRole.externalPerimeter,
        configuredWidth: 1,
        nozzleDiameter: nozzle,
        height: layerHeight,
      );
      expect(
        flow.spacing,
        closeTo(1 - layerHeight * (1 - math.pi / 4), 1e-12),
      );
    });

    test('bridge width and spacing reproduce source fixture', () {
      final flow = Flow.bridging(
        diameter: nozzle * math.sqrt(1),
        nozzleDiameter: nozzle,
      );
      expect(flow.width, nozzle);
      expect(flow.height, nozzle);
      expect(flow.spacing, closeTo(nozzle + 0.05, 1e-12));
    });
  });

  group('Flow::extrusion_width source config behavior', () {
    test('role-specific zero falls back to line_width then auto nozzle width', () {
      const config = FlowConfigSnapshot(
        widthOptions: {
          'outer_wall_line_width': FlowWidthOption(0),
          'line_width': FlowWidthOption(0),
        },
        scalarOptions: {'layer_height': 0.2},
        nozzleDiameters: [0.4],
      );
      expect(
        Flow.resolveExtrusionWidth('outer_wall_line_width', config),
        closeTo(1.125 * 0.4, 1e-12),
      );
    });

    test('percentage width resolves against layer height', () {
      const config = FlowConfigSnapshot(
        widthOptions: {
          'outer_wall_line_width': FlowWidthOption(150, percent: true),
        },
        scalarOptions: {'layer_height': 0.2},
        nozzleDiameters: [0.4],
      );
      expect(
        Flow.resolveExtrusionWidth('outer_wall_line_width', config),
        closeTo(0.3, 1e-12),
      );
    });

    test('initial-layer percentage uses initial_layer_print_height', () {
      const config = FlowConfigSnapshot(
        widthOptions: {
          'initial_layer_line_width': FlowWidthOption(120, percent: true),
        },
        scalarOptions: {
          'layer_height': 0.2,
          'initial_layer_print_height': 0.3,
        },
        nozzleDiameters: [0.4],
      );
      expect(
        Flow.resolveExtrusionWidth('initial_layer_line_width', config),
        closeTo(0.36, 1e-12),
      );
    });

    test('initial-layer zero fallback deliberately switches to layer_height', () {
      const config = FlowConfigSnapshot(
        widthOptions: {
          'initial_layer_line_width': FlowWidthOption(0),
          'line_width': FlowWidthOption(150, percent: true),
        },
        scalarOptions: {
          'layer_height': 0.2,
          'initial_layer_print_height': 0.3,
        },
        nozzleDiameters: [0.4],
      );
      expect(
        Flow.resolveExtrusionWidth('initial_layer_line_width', config),
        closeTo(0.3, 1e-12),
      );
    });
  });

  group('Flow source formulas', () {
    test('non-bridge mm3/mm is rounded-rectangle cross section', () {
      final flow = Flow.nonBridging(
        width: 0.45,
        height: 0.2,
        nozzleDiameter: 0.4,
      );
      expect(
        flow.mm3PerMm,
        closeTo(0.2 * (0.45 - 0.2 * (1 - math.pi / 4)), 1e-12),
      );
    });

    test('bridge mm3/mm is circle area', () {
      final flow = Flow.bridging(diameter: 0.4, nozzleDiameter: 0.4);
      expect(flow.mm3PerMm, closeTo(0.4 * 0.4 * 0.25 * math.pi, 1e-12));
    });

    test('withSpacing preserves source air-gap relationship for bridges', () {
      final flow = Flow.bridging(diameter: 0.4, nozzleDiameter: 0.4);
      final changed = flow.withSpacing(0.6);
      expect(changed.spacing, 0.6);
      expect(changed.width, closeTo(0.55, 1e-12));
      expect(changed.height, closeTo(0.55, 1e-12));
    });

    test('negative rounded-rectangle spacing throws source-equivalent error', () {
      expect(
        () => Flow.roundedRectangleExtrusionSpacing(0.01, 1),
        throwsA(isA<FlowNegativeSpacingException>()),
      );
    });
  });
}
