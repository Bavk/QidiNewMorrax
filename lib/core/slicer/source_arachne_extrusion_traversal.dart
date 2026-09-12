import '../geometry/source_geometry.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_arachne_extrusion_line_variable_width.dart';
import 'source_arachne_extrusion_order.dart';
import 'source_fuzzy_skin_apply.dart';
import 'source_fuzzy_skin_geometry.dart';
import 'variable_width.dart';

class SourceArachneExtrusionTraversalSettings2 {
  const SourceArachneExtrusionTraversalSettings2({
    required this.perimeterFlow,
    required this.externalPerimeterFlow,
    required this.fuzzyConfig,
    this.perimeterRegions = const [],
    required this.layerId,
    required this.sliceZMm,
    this.detectOverhangWall = false,
    this.raftLayers = 0,
    this.zDirectionOutwallSpeedContinuous = false,
  });

  final Flow perimeterFlow;
  final Flow externalPerimeterFlow;
  final SourceFuzzySkinNoRegionConfig2 fuzzyConfig;
  final List<SourceFuzzySkinPerimeterRegion2> perimeterRegions;
  final int layerId;
  final double sliceZMm;
  final bool detectOverhangWall;
  final int raftLayers;
  final bool zDirectionOutwallSpeedContinuous;
}

/// Source-order slice of `PerimeterGenerator::traverse_extrusions()` for the
/// non-overhang path.
///
/// This composes the already represented fuzzy-skin transform, Arachne
/// `to_thick_polyline()`, the source variable-width adapter, loop/open entity
/// construction, orientation restoration and circle-compensation propagation.
/// The overhang clipping/speed branch and QIDI loop-node producer are rejected
/// explicitly until their complete source dependencies are composed here.
class SourceArachneExtrusionTraversal2 {
  const SourceArachneExtrusionTraversal2._();

  static ExtrusionEntityCollection2 traverse({
    required List<SourceArachneOrderedExtrusion2> orderedExtrusions,
    required SourceArachneExtrusionTraversalSettings2 settings,
    required SourceFuzzyUnitRandom2 random,
  }) {
    if (settings.zDirectionOutwallSpeedContinuous) {
      throw UnsupportedError(
        'Pinned Arachne z-direction outwall loop-node traversal is not yet '
        'composed',
      );
    }
    if (settings.detectOverhangWall && settings.layerId > settings.raftLayers) {
      throw UnsupportedError(
        'Pinned Arachne overhang clipping/speed traversal is not yet composed',
      );
    }

    final collection = ExtrusionEntityCollection2();
    final variableWidth = SourceVariableWidth2();

    for (final ordered in orderedExtrusions) {
      final sourceExtrusion = ordered.extrusion;
      if (sourceExtrusion.isEmpty) continue;

      final extrusion = SourceFuzzySkinApply2.applyExtrusionLine(
        extrusion: sourceExtrusion,
        baseConfig: settings.fuzzyConfig,
        perimeterRegions: settings.perimeterRegions,
        layerIndex: settings.layerId,
        perimeterIndex: sourceExtrusion.insetIndex,
        isContour: !sourceExtrusion.isClosed || ordered.isContour,
        sliceZMm: settings.sliceZMm,
        random: random,
      );

      final isExternal = extrusion.insetIndex == 0;
      final role = isExternal
          ? ExtrusionRole.externalPerimeter
          : ExtrusionRole.perimeter;
      final flow = isExternal
          ? settings.externalPerimeterFlow
          : settings.perimeterFlow;

      final converted = variableWidth.thickPolylineToMultiPath(
        extrusion.toThickPolylineSource(),
        role,
        flow,
        SourceVariableWidth2.qidiTolerance,
        Slic3rUnits.scaledEpsilon.toDouble(),
        0,
      );
      final paths = converted.paths;
      if (paths.isEmpty) continue;

      final applyHoleCompensation =
          extrusion.shouldApplyHoleCompensationSource();

      if (extrusion.isClosed) {
        final loop = ExtrusionLoop2(
          paths: paths,
          loopRole: extrusion.isContourSource()
              ? ExtrusionLoopRoles.defaultRole
              : ExtrusionLoopRoles.perimeterHole,
        );

        // `pg_extrusion.is_contour` records the source orientation before
        // fuzzy/Clipper operations. Restore it literally after conversion.
        if (ordered.isContour) {
          loop.makeCounterClockwise();
        } else {
          loop.makeClockwise();
        }

        if (applyHoleCompensation) {
          for (final path in loop.paths) {
            path.customizeFlag = CustomizeFlag.circleCompensation;
          }
          loop.customizeFlag = CustomizeFlag.circleCompensation;
        }
        collection.append(loop);
        continue;
      }

      // Source release code still contains a defensive split even though the
      // preceding assertion requires all paths from one ExtrusionLine to be
      // connected. Preserve that fallback and its flagging order: only the
      // final multipath receives circle compensation if a numerical seam split
      // actually occurs.
      var currentPaths = <ExtrusionPath2>[paths.first];
      for (var index = 1; index < paths.length; index++) {
        final path = paths[index];
        if (currentPaths.last.lastPoint != path.firstPoint) {
          collection.append(ExtrusionMultiPath2(paths: currentPaths));
          currentPaths = <ExtrusionPath2>[];
        }
        currentPaths.add(path);
      }

      final multiPath = ExtrusionMultiPath2(paths: currentPaths);
      if (applyHoleCompensation) {
        for (final path in multiPath.paths) {
          path.customizeFlag = CustomizeFlag.circleCompensation;
        }
        multiPath.customizeFlag = CustomizeFlag.circleCompensation;
      }
      collection.append(multiPath);
    }

    return collection;
  }
}
