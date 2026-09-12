import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_arachne_extrusion_line_variable_width.dart';
import 'source_arachne_extrusion_order.dart';
import 'source_arachne_overhang.dart';
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
    this.lowerLayerPolygons = const [],
    this.overhangFlow,
    this.nozzleDiameterMm = 0,
    this.enableOverhangSpeed = false,
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

  /// Pinned `m_lower_slices_polygons`: the lower slices already grown by half
  /// the active wall nozzle diameter before `traverse_extrusions()` is called.
  final List<SourcePolygon2> lowerLayerPolygons;
  final Flow? overhangFlow;
  final double nozzleDiameterMm;

  /// `is_enable_overhang_speed()` after process/filament override resolution.
  /// The speed-graded branch is the next explicit migration seam.
  final bool enableOverhangSpeed;
  final bool zDirectionOutwallSpeedContinuous;
}

/// Source-order slice of `PerimeterGenerator::traverse_extrusions()`.
///
/// This composes the represented fuzzy-skin transform, Arachne
/// `to_thick_polyline()`, source variable-width adapters, loop/open entity
/// construction, orientation restoration and circle-compensation propagation.
/// The active overhang branch is represented for the source path where
/// overhang-speed grading is disabled (or fuzzy skin disallows it), including
/// width-carrying clipping, unsupported bridge-wall classification and
/// path re-chaining. The speed-graded overhang branch and QIDI loop-node
/// producer remain explicit seams.
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

      late final List<ExtrusionPath2> paths;
      if (settings.detectOverhangWall && settings.layerId > settings.raftLayers) {
        if (settings.enableOverhangSpeed) {
          throw UnsupportedError(
            'Pinned Arachne speed-graded overhang traversal is not yet composed',
          );
        }
        final overhangFlow = settings.overhangFlow;
        if (overhangFlow == null) {
          throw ArgumentError(
            'Pinned Arachne overhang traversal requires overhangFlow',
          );
        }
        paths = SourceArachneOverhang2.splitWithoutSpeedGrading(
          extrusion: extrusion,
          lowerLayerPolygons: settings.lowerLayerPolygons,
          nozzleDiameterMm: settings.nozzleDiameterMm,
          supportedRole: role,
          supportedFlow: flow,
          overhangFlow: overhangFlow,
        );
      } else {
        final converted = variableWidth.thickPolylineToMultiPath(
          extrusion.toThickPolylineSource(),
          role,
          flow,
          SourceVariableWidth2.qidiTolerance,
          Slic3rUnits.scaledEpsilon.toDouble(),
          0,
        );
        paths = converted.paths;
      }
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
