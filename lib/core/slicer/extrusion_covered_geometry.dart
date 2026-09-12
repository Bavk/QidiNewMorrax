import '../geometry/clipper_geometry.dart';
import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'extrusion_entity.dart';

/// Source `ExtrusionEntity::polygons_covered_by_width()` dispatch.
///
/// The C++ implementation is virtual, while the Dart entity hierarchy predates
/// this ported method. Keeping the dispatch in an extension preserves the same
/// dynamic behavior without changing copy/clone semantics of every entity type.
extension ExtrusionEntityCoveredGeometry2 on ExtrusionEntity2 {
  List<SourcePolygon2> polygonsCoveredByWidth({
    double scaledEpsilon = 0,
    ClipperGeometry clipper = const ClipperGeometry(),
  }) {
    if (!scaledEpsilon.isFinite) {
      throw ArgumentError.value(
        scaledEpsilon,
        'scaledEpsilon',
        'must be finite',
      );
    }

    if (this is ExtrusionPath2) {
      final path = this as ExtrusionPath2;
      final scaledHalfWidth = Slic3rUnits.scaleTruncated(path.width / 2.0);
      final delta = scaledHalfWidth.toDouble() + scaledEpsilon;
      if (delta <= 0) {
        throw StateError(
          'ExtrusionPath width must produce a positive covered-area offset',
        );
      }
      return clipper.offsetSourceOpenPolyline(path.polyline.points, delta);
    }

    if (this is ExtrusionMultiPath2) {
      final output = <SourcePolygon2>[];
      for (final path in (this as ExtrusionMultiPath2).paths) {
        output.addAll(path.polygonsCoveredByWidth(
          scaledEpsilon: scaledEpsilon,
          clipper: clipper,
        ));
      }
      return List.unmodifiable(output);
    }

    if (this is ExtrusionLoop2) {
      final output = <SourcePolygon2>[];
      for (final path in (this as ExtrusionLoop2).paths) {
        output.addAll(path.polygonsCoveredByWidth(
          scaledEpsilon: scaledEpsilon,
          clipper: clipper,
        ));
      }
      return List.unmodifiable(output);
    }

    if (this is ExtrusionEntityCollection2) {
      final output = <SourcePolygon2>[];
      for (final entity in (this as ExtrusionEntityCollection2).entities) {
        output.addAll(entity.polygonsCoveredByWidth(
          scaledEpsilon: scaledEpsilon,
          clipper: clipper,
        ));
      }
      return List.unmodifiable(output);
    }

    throw StateError(
      'Unsupported extrusion entity for polygons_covered_by_width: '
      '$runtimeType',
    );
  }
}

extension ExtrusionEntitiesCoveredGeometry2 on Iterable<ExtrusionEntity2> {
  List<SourcePolygon2> polygonsCoveredByWidth({
    double scaledEpsilon = 0,
    ClipperGeometry clipper = const ClipperGeometry(),
  }) {
    final output = <SourcePolygon2>[];
    for (final entity in this) {
      output.addAll(entity.polygonsCoveredByWidth(
        scaledEpsilon: scaledEpsilon,
        clipper: clipper,
      ));
    }
    return List.unmodifiable(output);
  }
}
