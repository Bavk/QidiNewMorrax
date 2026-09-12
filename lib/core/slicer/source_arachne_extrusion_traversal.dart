import '../geometry/source_geometry.dart';
import '../geometry/source_polygon.dart';
import 'extrusion_entity.dart';
import 'flow.dart';
import 'source_arachne_extrusion_line_variable_width.dart';
import 'source_arachne_extrusion_order.dart';
import 'source_arachne_overhang.dart';
import 'source_arachne_overhang_speed.dart';
import 'source_fuzzy_skin_apply.dart';
import 'source_fuzzy_skin_geometry.dart';
import 'source_fuzzy_skin_policy.dart';
import 'source_loop_node.dart';
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
    this.loopNodes,
    this.outerWallLineWidthMm = 0,
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

  /// Result of source `is_enable_overhang_speed()` before its fuzzy-skin gate.
  final bool enableOverhangSpeed;
  final bool zDirectionOutwallSpeedContinuous;

  /// Mutable global source `loop_nodes` storage. Required only when the QIDI
  /// z-direction outer-wall continuity producer is enabled.
  final List<SourceLoopNode2>? loopNodes;

  /// Literal `config->outer_wall_line_width` value in millimeters.
  ///
  /// Pinned source passes `outer_wall_line_width / 2` directly to integer
  /// `BoundingBox::offset(coordf_t)`. The resulting `Point(coordf_t,coordf_t)`
  /// narrows to coord_t without `scale_()`, so common sub-2mm line widths
  /// intentionally produce a zero-unit bbox expansion.
  final double outerWallLineWidthMm;
}

/// Source-order slice of `PerimeterGenerator::traverse_extrusions()`.
///
/// This composes fuzzy skin, Arachne `to_thick_polyline()`, source
/// variable-width adapters, both active-overhang branches, the QIDI direct
/// external-wall LoopNode producer, loop/open entity construction, orientation
/// restoration and circle-compensation propagation.
class SourceArachneExtrusionTraversal2 {
  const SourceArachneExtrusionTraversal2._();

  static ExtrusionEntityCollection2 traverse({
    required List<SourceArachneOrderedExtrusion2> orderedExtrusions,
    required SourceArachneExtrusionTraversalSettings2 settings,
    required SourceFuzzyUnitRandom2 random,
  }) {
    final collection = ExtrusionEntityCollection2();
    final variableWidth = SourceVariableWidth2();
    final loopNodes = settings.loopNodes;

    if (settings.zDirectionOutwallSpeedContinuous) {
      if (loopNodes == null) {
        throw ArgumentError(
          'Pinned Arachne QIDI loop-node traversal requires global loopNodes',
        );
      }
      if (!settings.outerWallLineWidthMm.isFinite ||
          settings.outerWallLineWidthMm < 0) {
        throw ArgumentError.value(
          settings.outerWallLineWidthMm,
          'outerWallLineWidthMm',
          'Pinned outer-wall line width must be finite and nonnegative',
        );
      }
      collection.loopNodeRange = (loopNodes.length, loopNodes.length);
    }

    for (final ordered in orderedExtrusions) {
      final sourceExtrusion = ordered.extrusion;
      if (sourceExtrusion.isEmpty) continue;

      // QIDI source captures the raw Arachne line before fuzzy skin, overhang
      // clipping, orientation restoration or variable-width conversion.
      if (settings.zDirectionOutwallSpeedContinuous &&
          sourceExtrusion.insetIndex == 0) {
        final points = <SourcePoint2>[
          for (final junction in sourceExtrusion.junctions) junction.p,
        ];
        final contour = SourceNodeContour2(
          points: points,
          widths: [
            for (final junction in sourceExtrusion.junctions) junction.w,
          ],
          isLoop: sourceExtrusion.isClosed,
        );
        final sourceBboxOffset =
            (settings.outerWallLineWidthMm / 2.0).toInt();
        loopNodes!.add(
          SourceLoopNode2(
            nodeContour: contour,
            nodeId: loopNodes.length,
            loopId: collection.entities.length,
            bounds: SourceLoopNodeBounds2.fromPoints(
              points,
              offset: sourceBboxOffset,
            ),
          ),
        );
      }

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
        final overhangFlow = settings.overhangFlow;
        if (overhangFlow == null) {
          throw ArgumentError(
            'Pinned Arachne overhang traversal requires overhangFlow',
          );
        }
        final speedGrading = SourceFuzzySkinPolicy2.enablesOverhangSpeed(
          configuredOverhangSpeedEnabled: settings.enableOverhangSpeed,
          type: settings.fuzzyConfig.type,
          perimeterRegionsEmpty: settings.perimeterRegions.isEmpty,
        );
        if (speedGrading) {
          paths = SourceArachneOverhangSpeed2.splitWithSpeedGrading(
            extrusion: extrusion,
            lowerLayerPolygons: settings.lowerLayerPolygons,
            nozzleDiameterMm: settings.nozzleDiameterMm,
            supportedRole: role,
            supportedFlow: flow,
            overhangFlow: overhangFlow,
          );
        } else {
          paths = SourceArachneOverhang2.splitWithoutSpeedGrading(
            extrusion: extrusion,
            lowerLayerPolygons: settings.lowerLayerPolygons,
            nozzleDiameterMm: settings.nozzleDiameterMm,
            supportedRole: role,
            supportedFlow: flow,
            overhangFlow: overhangFlow,
          );
        }
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

    if (settings.zDirectionOutwallSpeedContinuous) {
      collection.loopNodeRange = (
        collection.loopNodeRange.$1,
        loopNodes!.length,
      );
    }
    return collection;
  }
}
