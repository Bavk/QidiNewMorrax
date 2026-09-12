import '../geometry/source_arc_fitter.dart';
import '../geometry/source_geometry.dart';
import '../slicer/extrusion_entity.dart';
import 'extruder.dart';

class SourceGCodePoint2 {
  const SourceGCodePoint2(this.x, this.y);

  final double x;
  final double y;

  SourceGCodePoint2 operator -(SourceGCodePoint2 other) =>
      SourceGCodePoint2(x - other.x, y - other.y);
}

/// Coordinate transforms used by source `GCode::point_to_gcode()` and then by
/// `GCodeWriter::{extrude_to_xy,extrude_arc_to_xy}` plate-offset handling.
class SourceGCodeCoordinateContext {
  const SourceGCodeCoordinateContext({
    this.originX = 0,
    this.originY = 0,
    this.extruderOffsetX = 0,
    this.extruderOffsetY = 0,
    this.plateOffsetX = 0,
    this.plateOffsetY = 0,
  });

  final double originX;
  final double originY;
  final double extruderOffsetX;
  final double extruderOffsetY;
  final double plateOffsetX;
  final double plateOffsetY;

  SourceGCodePoint2 pointToGCode(SourcePoint2 point) => SourceGCodePoint2(
        Slic3rUnits.unscale(point.x) + originX - extruderOffsetX,
        Slic3rUnits.unscale(point.y) + originY - extruderOffsetY,
      );

  SourceGCodePoint2 pointOnPlate(SourceGCodePoint2 point) => SourceGCodePoint2(
        point.x - plateOffsetX,
        point.y - plateOffsetY,
      );
}

/// Port of `GCodeFormatter::emit_axis()` for the fields emitted by this
/// migration unit. Source uses XYZF=3 digits and E=5 digits, rounds with
/// `std::round()`, inserts a decimal point, then removes trailing zeros.
class SourceGCodeFormatter2 {
  const SourceGCodeFormatter2._();

  static const int xyzfDigits = 3;
  static const int eDigits = 5;

  static String axis(String axis, double value, int digits) {
    final factor = _pow10(digits);
    final scaled = _cppRound(value * factor);
    final negative = scaled < 0;
    final raw = scaled.abs().toString().padLeft(digits + 1, '0');

    String number;
    if (digits == 0) {
      number = raw;
    } else {
      final split = raw.length - digits;
      final integer = raw.substring(0, split);
      var fraction = raw.substring(split);
      fraction = fraction.replaceFirst(RegExp(r'0+$'), '');
      number = fraction.isEmpty ? integer : '$integer.$fraction';
    }

    if (negative && scaled != 0) number = '-$number';
    return ' $axis$number';
  }

  static String g1({
    required SourceGCodePoint2 point,
    double? e,
    String comment = '',
    bool fullComment = false,
  }) {
    final out = StringBuffer('G1')
      ..write(axis('X', point.x, xyzfDigits))
      ..write(axis('Y', point.y, xyzfDigits));
    if (e != null) out.write(axis('E', e, eDigits));
    if (fullComment && comment.isNotEmpty) out.write(' ; $comment');
    return '${out.toString()}\n';
  }

  static String g2g3({
    required bool isCcw,
    required SourceGCodePoint2 point,
    required SourceGCodePoint2 centerOffset,
    double? e,
    String comment = '',
    bool fullComment = false,
  }) {
    final out = StringBuffer(isCcw ? 'G3' : 'G2')
      ..write(axis('X', point.x, xyzfDigits))
      ..write(axis('Y', point.y, xyzfDigits))
      ..write(axis('I', centerOffset.x, xyzfDigits))
      ..write(axis('J', centerOffset.y, xyzfDigits));
    if (e != null) out.write(axis('E', e, eDigits));
    if (fullComment && comment.isNotEmpty) out.write(' ; $comment');
    return '${out.toString()}\n';
  }

  static int _cppRound(double value) =>
      value >= 0 ? (value + 0.5).floor() : (value - 0.5).ceil();

  static int _pow10(int digits) {
    var out = 1;
    for (var i = 0; i < digits; i++) out *= 10;
    return out;
  }
}

/// Port of the source `GCode.cpp` branch that consumes
/// `path.polyline.fitting_result` and of the movement payload emitted by
/// `GCodeWriter::extrude_to_xy()` / `extrude_arc_to_xy()`.
///
/// This deliberately does **not** claim the entire source extrusion state
/// machine: `set_extrude_acceleration()` and sloped XYZ extrusion remain
/// separate pending source units. Sloped input therefore fails explicitly
/// rather than silently emitting a different XY-only move.
class SourceExtrusionPathEmitter2 {
  SourceExtrusionPathEmitter2({
    required this.extruder,
    this.coordinates = const SourceGCodeCoordinateContext(),
    this.fullGCodeComment = false,
  });

  final ExtruderState extruder;
  final SourceGCodeCoordinateContext coordinates;
  final bool fullGCodeComment;

  SourceGCodePoint2? _currentPosition;
  SourceGCodePoint2? get currentPosition => _currentPosition;

  String emit(
    ExtrusionPath2 path, {
    required double ePerMm,
    required bool enableArcFitting,
    bool spiralMode = false,
    bool sloped = false,
    String description = '',
  }) {
    if (sloped) {
      throw UnsupportedError(
        'GCode sloped XYZ extrusion must be ported before emitting sloped '
        'paths; the source deliberately disables G2/G3 in this mode.',
      );
    }

    final output = StringBuffer();
    final fitting = path.polyline.fittingResult;

    // Literal source decision: G1 if arc fitting is disabled, fitting metadata
    // is absent, spiral mode is active, or a sloped path is supplied. The
    // sloped case has already failed above because its XYZ behavior is pending.
    if (!enableArcFitting || fitting.isEmpty || spiralMode) {
      for (final line in path.polyline.lines()) {
        final lineLength = Slic3rUnits.unscaleDouble(line.length);
        if (lineLength < Slic3rUnits.epsilon) continue;
        output.write(_emitLinear(
          line.b,
          ePerMm * lineLength,
          description,
          path.isForceNoExtrusion,
        ));
      }
      return output.toString();
    }

    for (final data in fitting) {
      switch (data.pathType) {
        case MovePathType2.linear:
          for (var pointIndex = data.startPointIndex + 1;
              pointIndex <= data.endPointIndex;
              pointIndex++) {
            final a = path.polyline.points[pointIndex - 1];
            final b = path.polyline.points[pointIndex];
            final lineLength = Slic3rUnits.unscaleDouble((b - a).length);
            if (lineLength < Slic3rUnits.epsilon) continue;
            output.write(_emitLinear(
              b,
              ePerMm * lineLength,
              description,
              path.isForceNoExtrusion,
            ));
          }
          break;

        case MovePathType2.arcCw:
        case MovePathType2.arcCcw:
          final arc = data.arcData;
          final arcLength = Slic3rUnits.unscaleDouble(arc.length);
          if (arcLength < Slic3rUnits.epsilon) continue;

          final end = coordinates.pointToGCode(arc.endPoint);
          final centerOffset = coordinates.pointToGCode(arc.center) -
              coordinates.pointToGCode(arc.startPoint);
          _currentPosition = end;

          double? emittedE;
          if (!path.isForceNoExtrusion) {
            extruder.extrude(ePerMm * arcLength);
            emittedE = extruder.e;
          }

          output.write(SourceGCodeFormatter2.g2g3(
            isCcw: data.pathType == MovePathType2.arcCcw,
            point: coordinates.pointOnPlate(end),
            centerOffset: centerOffset,
            e: emittedE,
            comment: description,
            fullComment: fullGCodeComment,
          ));
          break;

        case MovePathType2.noop:
        case MovePathType2.count:
          throw StateError(
            'Source GCode fitting_result must never contain ${data.pathType}',
          );
      }
    }
    return output.toString();
  }

  String _emitLinear(
    SourcePoint2 destination,
    double deltaE,
    String comment,
    bool forceNoExtrusion,
  ) {
    final destinationGCode = coordinates.pointToGCode(destination);
    _currentPosition = destinationGCode;
    final pointOnPlate = coordinates.pointOnPlate(destinationGCode);

    if (forceNoExtrusion) {
      return SourceGCodeFormatter2.g1(
        point: pointOnPlate,
        comment: comment,
        fullComment: fullGCodeComment,
      );
    }

    extruder.extrude(deltaE);
    return SourceGCodeFormatter2.g1(
      point: pointOnPlate,
      e: extruder.e,
      comment: comment,
      fullComment: fullGCodeComment,
    );
  }
}
