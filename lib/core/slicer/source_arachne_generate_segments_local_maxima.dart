import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_skeletal_graph.dart';

/// Final source-order leaf of pinned `SkeletalTrapezoidation::generateSegments`:
/// add six-segment odd center loops for isolated noncentral local maxima.
extension SourceArachneGenerateSegmentsLocalMaxima2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void generateLocalMaximaSingleBeads(
    List<List<SourceArachneExtrusionLine2>> generatedToolpaths,
  ) {
    for (final node in nodes) {
      if (!node.data.hasBeading) {
        continue;
      }
      final beading = node.data.beading!.beading;
      if (beading.beadWidths.length.isOdd &&
          node.isLocalMaximum(strict: true) &&
          !node.isCentral) {
        final insetIndex = beading.beadWidths.length ~/ 2;
        while (generatedToolpaths.length <= insetIndex) {
          generatedToolpaths.add(<SourceArachneExtrusionLine2>[]);
        }

        final width = beading.beadWidths[insetIndex];
        final radius = width ~/ 8;
        const segmentCount = 6;
        final junctions = <SourceArachneExtrusionJunction2>[];
        for (var segment = 0; segment < segmentCount; segment++) {
          // Source computes the expression in double, then stores it in float.
          final angle = _f32(2.0 * math.pi / segmentCount * segment);
          final offset = SourcePoint2(
            _lrint(radius * math.cos(angle)),
            _lrint(radius * math.sin(angle)),
          );
          junctions.add(
            SourceArachneExtrusionJunction2(
              p: node.p + offset,
              w: width,
              perimeterIndex: insetIndex,
              holeCompensationFlag: false,
            ),
          );
        }
        generatedToolpaths[insetIndex].add(
          SourceArachneExtrusionLine2(
            insetIndex: insetIndex,
            isOdd: true,
            junctions: junctions,
          ),
        );
      }
    }
  }
}

double _f32(double value) {
  final slot = Float32List(1)..[0] = value;
  return slot[0];
}

/// Default C/C++ `lrint` semantics under FE_TONEAREST: nearest integer with
/// halfway cases rounded to even.
int _lrint(double value) {
  final lower = value.floor();
  final fraction = value - lower;
  if (fraction < 0.5) return lower;
  if (fraction > 0.5) return lower + 1;
  return lower.isEven ? lower : lower + 1;
}
