import '../geometry/source_polygon.dart';
import 'classic_perimeter_fill_boundary.dart';
import 'extrusion_entity.dart';
import 'source_arachne_extrusion_order.dart';
import 'source_arachne_extrusion_traversal.dart';
import 'source_arachne_infill_contour.dart';
import 'source_arachne_process_surface.dart';
import 'source_arachne_top_one_wall.dart';
import 'source_fuzzy_skin_geometry.dart';
import 'surface.dart';

class SourceArachneProcessPipelineSettings2 {
  const SourceArachneProcessPipelineSettings2({
    required this.surfaceSettings,
    required this.traversalSettings,
    required this.externalMixedSpacingSource,
    required this.solidInfillSpacingSource,
    required this.infillWallOverlap,
  });

  final SourceArachneSurfaceProcessSettings2 surfaceSettings;
  final SourceArachneExtrusionTraversalSettings2 traversalSettings;

  /// Pinned `ext_perimeter_spacing2 = scaled<coord_t>(0.5f *
  /// (ext_perimeter_flow.spacing() + perimeter_flow.spacing()))`.
  ///
  /// The value is supplied after the caller's exact Flow/float conversion so
  /// this composition layer does not re-derive and normalize that boundary.
  final int externalMixedSpacingSource;
  final int solidInfillSpacingSource;
  final SourceFloatOrPercent2 infillWallOverlap;
}

class SourceArachneProcessPipelineResult2 {
  const SourceArachneProcessPipelineResult2({
    required this.surfaceResult,
    required this.orderedExtrusions,
    required this.extrusionCollection,
    required this.appendedLoopCollection,
    required this.infillResult,
    required this.spacingSource,
  });

  final SourceArachneSurfaceProcessResult2 surfaceResult;
  final List<SourceArachneOrderedExtrusion2> orderedExtrusions;
  final ExtrusionEntityCollection2 extrusionCollection;

  /// Mirrors `if (!extrusion_coll.empty()) loops->append(extrusion_coll)`.
  final bool appendedLoopCollection;
  final SourceArachneInfillContourResult2 infillResult;
  final int spacingSource;
}

/// Final represented per-surface source-order boundary of pinned
/// `PerimeterGenerator::process_arachne()`.
///
/// The caller owns the three global destination vectors just like the source
/// generator (`loops`, `fill_surfaces`, `fill_no_overlap`). This method appends
/// to them in source order after wall generation, ordering and traversal.
class SourceArachneProcessPipeline2 {
  const SourceArachneProcessPipeline2._();

  static SourceArachneProcessPipelineResult2 processSurface({
    required Surface2 surface,
    required SourceArachneProcessPipelineSettings2 settings,
    required int layerIndex,
    required SourceFuzzyUnitRandom2 random,
    required List<ExtrusionEntityCollection2> loops,
    required List<Surface2> fillSurfaces,
    required List<SourceExPolygon2> fillNoOverlap,
  }) {
    if (settings.traversalSettings.layerId != layerIndex) {
      throw ArgumentError(
        'Pinned process_arachne traversal layer must match surface layer',
      );
    }
    if (settings.externalMixedSpacingSource <= 0 ||
        settings.solidInfillSpacingSource <= 0) {
      throw ArgumentError(
        'Pinned Arachne process spacings must be positive source coords',
      );
    }

    final surfaceResult = SourceArachneProcessSurface2.process(
      surface: surface,
      settings: settings.surfaceSettings,
      layerIndex: layerIndex,
    );

    final orderedExtrusions = SourceArachneExtrusionOrder2.order(
      totalPerimeters: surfaceResult.totalPerimeters,
      wallSequence: settings.surfaceSettings.planning.wallSequence,
      layerId: layerIndex,
    );

    final extrusionCollection = SourceArachneExtrusionTraversal2.traverse(
      orderedExtrusions: orderedExtrusions,
      settings: settings.traversalSettings,
      random: random,
    );
    final appendedLoopCollection = !extrusionCollection.isEmpty;
    if (appendedLoopCollection) {
      loops.add(extrusionCollection);
    }

    final spacingSource = surfaceResult.totalPerimeters.length == 1
        ? settings.externalMixedSpacingSource
        : settings.surfaceSettings.perimeterSpacing;
    final infillContour = _toExPolygons(surfaceResult.infillContour);
    final infillResult = const SourceArachneInfillContour2().build(
      infillContour: infillContour,
      loops: surfaceResult.plan.loopNumber,
      isInnerPart: false,
      settings: SourceArachneInfillContourSettings2(
        externalPerimeterSpacingSource:
            settings.surfaceSettings.planning.extPerimeterSpacing,
        perimeterSpacingSource: settings.surfaceSettings.perimeterSpacing,
        solidInfillSpacingSource: settings.solidInfillSpacingSource,
        spacingSource: spacingSource,
        surfaceSimplifyResolutionSource:
            settings.surfaceSettings.surfaceSimplifyResolutionSource.toInt(),
        infillWallOverlap: settings.infillWallOverlap,
      ),
    );
    fillSurfaces.addAll(infillResult.fillSurfaces);
    fillNoOverlap.addAll(infillResult.fillNoOverlap);

    return SourceArachneProcessPipelineResult2(
      surfaceResult: surfaceResult,
      orderedExtrusions: List.unmodifiable(orderedExtrusions),
      extrusionCollection: extrusionCollection,
      appendedLoopCollection: appendedLoopCollection,
      infillResult: infillResult,
      spacingSource: spacingSource,
    );
  }

  /// Rebuild source `ExPolygons` from the flattened polygon representation
  /// returned by the currently represented WallToolPaths/Clipper layer.
  /// `union_ex()` returns CCW outer contours and CW holes on this source grid.
  static List<SourceExPolygon2> _toExPolygons(
    List<SourcePolygon2> polygons,
  ) {
    final normalized = SourceArachneTopOneWall2.union(polygons);
    if (normalized.isEmpty) return const [];

    final contours = <SourcePolygon2>[
      for (final polygon in normalized)
        if (!polygon.isClockwise) polygon,
    ];
    final holes = <SourcePolygon2>[
      for (final polygon in normalized)
        if (polygon.isClockwise) polygon,
    ];
    if (contours.isEmpty && holes.isNotEmpty) {
      throw StateError(
        'Pinned Arachne union produced holes without an outer contour',
      );
    }

    final groupedHoles = <SourcePolygon2, List<SourcePolygon2>>{
      for (final contour in contours) contour: <SourcePolygon2>[],
    };
    for (final hole in holes) {
      if (hole.points.isEmpty) continue;
      SourcePolygon2? owner;
      for (final contour in contours) {
        if (!contour.contains(hole.points.first)) continue;
        if (owner == null || contour.area < owner.area) owner = contour;
      }
      if (owner == null) {
        throw StateError('Pinned Arachne hole has no containing contour');
      }
      groupedHoles[owner]!.add(hole);
    }

    return List.unmodifiable([
      for (final contour in contours)
        SourceExPolygon2(
          contour: contour,
          holes: groupedHoles[contour]!,
        ),
    ]);
  }
}
