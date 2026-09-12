import '../geometry/point.dart';
import 'linear_infill.dart';
import 'mesh_slicer.dart';

class ToolpathPolyline {
  const ToolpathPolyline({required this.points, required this.kind, required this.closed});
  final List<Point2> points;
  final ToolpathKind kind;
  final bool closed;
}

enum ToolpathKind { perimeter, infill }

class ToolpathLayer {
  const ToolpathLayer({required this.z, required this.paths});
  final double z;
  final List<ToolpathPolyline> paths;
}

class ToolpathPlan {
  const ToolpathPlan({required this.layers});
  final List<ToolpathLayer> layers;
}

/// First pure-Dart printable toolpath stage. This does not claim parity with
/// native perimeter offset, Arachne, support or travel planning yet.
class BasicToolpathPlanner {
  const BasicToolpathPlanner({this.infillGenerator = const LinearInfillGenerator()});
  final LinearInfillGenerator infillGenerator;

  ToolpathPlan plan(
    MeshSliceResult slices, {
    double infillDensity = 0.15,
    double lineWidth = 0.42,
    double baseInfillAngleDegrees = 45,
  }) {
    if (infillDensity < 0 || infillDensity > 1) {
      throw ArgumentError.value(infillDensity, 'infillDensity', 'must be between 0 and 1');
    }
    if (lineWidth <= 0) throw ArgumentError.value(lineWidth, 'lineWidth', 'must be > 0');

    final layers = <ToolpathLayer>[];
    for (var layerIndex = 0; layerIndex < slices.layers.length; layerIndex++) {
      final layer = slices.layers[layerIndex];
      if (layer.openPaths.isNotEmpty) {
        throw StateError('Layer $layerIndex at Z=${layer.z} contains ${layer.openPaths.length} open path(s); refusing to create printable toolpaths from invalid geometry.');
      }
      final paths = <ToolpathPolyline>[
        for (final contour in layer.contours)
          ToolpathPolyline(points: contour.points, kind: ToolpathKind.perimeter, closed: true),
      ];
      if (infillDensity > 0 && layer.contours.isNotEmpty) {
        final spacing = lineWidth / infillDensity;
        final angle = baseInfillAngleDegrees + (layerIndex.isOdd ? 90 : 0);
        final infill = infillGenerator.generate(layer.contours, spacing: spacing, angleDegrees: angle, phase: (layerIndex * lineWidth) % spacing);
        paths.addAll([
          for (final segment in infill)
            ToolpathPolyline(points: [segment.a, segment.b], kind: ToolpathKind.infill, closed: false),
        ]);
      }
      layers.add(ToolpathLayer(z: layer.z, paths: List.unmodifiable(paths)));
    }
    return ToolpathPlan(layers: List.unmodifiable(layers));
  }
}
