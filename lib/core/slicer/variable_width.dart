import 'dart:math' as math;
import 'dart:typed_data';

import '../geometry/source_geometry.dart';
import '../geometry/thick_polyline.dart';
import 'extrusion_entity.dart';
import 'flow.dart';

/// Direct port of `libslic3r/VariableWidth.cpp` from the supplied QIDI source.
///
/// There are deliberately two conversion paths here because the source keeps
/// both algorithms:
///
/// * [thickPolylineToMultiPath] is the older 1.9.5 path still used by Arachne
///   utility adapters;
/// * [variableWidth] uses QIDI's newer
///   `thick_polyline_to_extrusion_paths_2()` fragmentation filter and is what
///   classic thin walls and gap fill call.
///
/// Width values in [ThickPolyline2] are source scaled-coordinate spacings.
class SourceVariableWidth2 {
  const SourceVariableWidth2();

  /// Source `scale_(0.05)`, retained in source-coordinate units.
  static const double qidiTolerance = 0.05 / Slic3rUnits.scalingFactor;

  /// Port of public source `thick_polyline_to_multi_path()`.
  ExtrusionMultiPath2 thickPolylineToMultiPath(
    ThickPolyline2 thickPolyline,
    ExtrusionRole role,
    Flow flow,
    double tolerance,
    double mergeTolerance,
    double overhang,
  ) {
    final multiPath = ExtrusionMultiPath2();
    var path = ExtrusionPath2(role: role);
    final lines = _mutableLines(thickPolyline);

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      assert(
        line.aWidth >= Slic3rUnits.scaledEpsilon &&
            line.bWidth >= Slic3rUnits.scaledEpsilon,
      );

      final lineLength = line.length;
      if (lineLength < Slic3rUnits.scaledEpsilon) {
        // Literal source behavior. The old helper consumes a tiny line by
        // moving a neighbouring endpoint instead of assigning it a width.
        if (!path.isEmpty) {
          path.polyline.points[path.polyline.points.length - 1] = line.b;
        } else if (i + 1 < lines.length) {
          lines[i + 1].a = line.a;
        } else if (multiPath.paths.isNotEmpty) {
          final last = multiPath.paths.last.polyline.points;
          last[last.length - 1] = line.b;
        }
        i++;
        continue;
      }

      var thicknessDelta = (line.aWidth - line.bWidth).abs();
      if (thicknessDelta > tolerance) {
        _splitLine(lines, i, tolerance);
        // Source erases/reinserts the line, decrements i, then the for-loop
        // increments it again: process the first replacement at the same index.
        continue;
      }

      final width = math.max(line.aWidth, line.bWidth);
      final newFlow = role == ExtrusionRole.overhangPerimeter && flow.bridge
          ? flow
          : flow.withWidth(_sourceWidthFromSpacing(width, flow.height));

      if (path.polyline.points.isEmpty) {
        path.polyline
          ..append(line.a)
          ..append(line.b);
        path
          ..mm3PerMm = newFlow.mm3PerMm
          ..width = newFlow.width
          ..height = newFlow.height;
      } else {
        assert(path.width >= Slic3rUnits.epsilon);
        thicknessDelta =
            (path.width - newFlow.width).abs() / Slic3rUnits.scalingFactor;
        if (thicknessDelta <= mergeTolerance) {
          path.polyline.append(line.b);
        } else {
          multiPath.paths.add(path);
          path = ExtrusionPath2(role: role);
          // Source decrements i so this line initializes the new path.
          continue;
        }
      }
      i++;
    }

    if (path.polyline.isValid) {
      path.overhangDegree = overhang;
      multiPath.paths.add(path);
    }
    return multiPath;
  }

  /// Source `variable_width()`.
  ///
  /// Open QIDI variable-width paths are appended as independent
  /// [ExtrusionPath2] entities. A closed result is wrapped in one
  /// [ExtrusionLoop2], matching the source's front/back point test.
  void variableWidth(
    Iterable<ThickPolyline2> polylines,
    ExtrusionRole role,
    Flow flow,
    List<ExtrusionEntity2> out,
  ) {
    for (final polyline in polylines) {
      final paths = _thickPolylineToExtrusionPaths2(
        polyline,
        role,
        flow,
        qidiTolerance,
      );
      if (paths.isEmpty) continue;

      if (paths.first.firstPoint == paths.last.lastPoint) {
        out.add(ExtrusionLoop2(paths: paths));
      } else {
        // Source allocates each moved path as a separate entity rather than
        // wrapping the connected set in ExtrusionMultiPath.
        out.addAll(paths);
      }
    }
  }

  /// QIDI-only `thick_polyline_to_extrusion_paths_2()`.
  List<ExtrusionPath2> _thickPolylineToExtrusionPaths2(
    ThickPolyline2 thickPolyline,
    ExtrusionRole role,
    Flow flow,
    double tolerance,
  ) {
    final paths = <ExtrusionPath2>[];
    final lines = _mutableLines(thickPolyline);
    var startIndex = 0;
    var maxWidth = 0.0;
    var minWidth = 0.0;

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (i == 0) {
        maxWidth = line.aWidth;
        minWidth = line.aWidth;
      }

      final lineLength = line.length;
      if (lineLength < Slic3rUnits.scaledEpsilon) {
        // Unlike thick_polyline_to_multi_path(), QIDI's newer helper merely
        // skips this line during range analysis. It is still included later in
        // the averaged path accumulation. Preserve that source quirk.
        i++;
        continue;
      }

      var thicknessDelta = math.max(
        (maxWidth - line.bWidth).abs(),
        (minWidth - line.bWidth).abs(),
      );

      if (thicknessDelta > tolerance) {
        // 1. Emit [startIndex, i), not including the current segment.
        if (startIndex != i) {
          final emitted = _averagedPath(
            lines,
            startIndex,
            i,
            lines[i].a,
            role,
            flow,
          );
          if (emitted != null) paths.add(emitted);
        }

        startIndex = i;
        maxWidth = line.aWidth;
        minWidth = line.aWidth;

        // 2. If the current line itself changes by more than tolerance, split
        // it into source-coordinate segments and process the first replacement
        // again at this same index.
        thicknessDelta = (line.aWidth - line.bWidth).abs();
        if (thicknessDelta > tolerance) {
          _splitLine(lines, i, tolerance);
          continue;
        }
      } else {
        maxWidth = math.max(maxWidth, math.max(line.aWidth, line.bWidth));
        minWidth = math.min(minWidth, math.min(line.aWidth, line.bWidth));
      }

      i++;
    }

    // Source handles the complete remaining range, including tiny segments
    // skipped by the analysis loop above.
    if (startIndex < lines.length) {
      final emitted = _averagedPath(
        lines,
        startIndex,
        lines.length,
        lines.last.b,
        role,
        flow,
      );
      if (emitted != null) paths.add(emitted);
    }

    return paths;
  }

  ExtrusionPath2? _averagedPath(
    List<_VariableWidthLine2> lines,
    int start,
    int end,
    SourcePoint2 terminalPoint,
    ExtrusionRole role,
    Flow flow,
  ) {
    final path = ExtrusionPath2(role: role);
    var length = 0.0;
    var weightedWidth = 0.0;

    for (var index = start; index < end; index++) {
      final line = lines[index];
      final lineLength = line.length;
      length += lineLength;
      weightedWidth +=
          lineLength * 0.5 * (line.aWidth + line.bWidth);
      path.polyline.append(line.a);
    }
    path.polyline.append(terminalPoint);

    if (length <= Slic3rUnits.scaledEpsilon) return null;

    final averageSpacing = weightedWidth / length;
    final newFlow = flow.withWidth(
      _sourceWidthFromSpacing(averageSpacing, flow.height),
    );
    path
      ..mm3PerMm = newFlow.mm3PerMm
      ..width = newFlow.width
      ..height = newFlow.height;
    return path;
  }

  void _splitLine(
    List<_VariableWidthLine2> lines,
    int index,
    double tolerance,
  ) {
    final line = lines[index];
    final thicknessDelta = (line.aWidth - line.bWidth).abs();
    final segments = (thicknessDelta / tolerance).ceil();
    final lineLength = line.length;
    final segmentLength = lineLength / segments;
    final vector = line.b - line.a;
    final normalizer = lineLength == 0 ? 0.0 : 1.0 / lineLength;

    final points = <SourcePoint2>[line.a];
    final widths = <double>[line.aWidth];
    for (var j = 1; j < segments; j++) {
      final distance = j * segmentLength;
      // Eigen `.cast<coord_t>()` truncates toward zero.
      points.add(SourcePoint2(
        (line.a.x + vector.x * normalizer * distance).truncate(),
        (line.a.y + vector.y * normalizer * distance).truncate(),
      ));
      final width = line.aWidth +
          distance * (line.bWidth - line.aWidth) / lineLength;
      widths
        ..add(width)
        ..add(width);
    }
    points.add(line.b);
    widths.add(line.bWidth);

    assert(points.length == segments + 1);
    assert(widths.length == segments * 2);

    final replacement = <_VariableWidthLine2>[];
    for (var j = 0; j < segments; j++) {
      replacement.add(_VariableWidthLine2(
        a: points[j],
        b: points[j + 1],
        aWidth: widths[2 * j],
        bWidth: widths[2 * j + 1],
      ));
    }
    lines.replaceRange(index, index + 1, replacement);
  }

  List<_VariableWidthLine2> _mutableLines(ThickPolyline2 polyline) => [
        for (final line in polyline.thickLines())
          _VariableWidthLine2(
            a: line.a,
            b: line.b,
            aWidth: line.aWidth,
            bWidth: line.bWidth,
          ),
      ];

  /// `unscale<float>(w) + flow.height() * float(1 - 0.25*PI)`.
  ///
  /// The explicit float32 steps matter because source Flow stores float fields.
  double _sourceWidthFromSpacing(double scaledSpacing, double flowHeight) {
    final spacingMm = _f32(
      _f32(scaledSpacing) * _f32(Slic3rUnits.scalingFactor),
    );
    final correction = _f32(
      _f32(flowHeight) * _f32(1 - 0.25 * math.pi),
    );
    return _f32(spacingMm + correction);
  }

  double _f32(double value) {
    final buffer = Float32List(1)..[0] = value;
    return buffer[0];
  }
}

class _VariableWidthLine2 {
  _VariableWidthLine2({
    required this.a,
    required this.b,
    required this.aWidth,
    required this.bWidth,
  });

  SourcePoint2 a;
  SourcePoint2 b;
  double aWidth;
  double bWidth;

  double get length => (b - a).length;
}
