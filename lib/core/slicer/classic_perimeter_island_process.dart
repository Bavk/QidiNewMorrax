import '../geometry/expolygon.dart';
import '../geometry/source_polygon.dart';
import 'classic_perimeter.dart';
import 'classic_perimeter_fill_process.dart';
import 'classic_perimeter_no_bridge.dart';
import 'classic_perimeter_surface_prepare.dart';
import 'classic_top_one_wall_context.dart';
import 'source_fuzzy_skin_policy.dart';
import 'surface.dart';

class SourceClassicPerimeterIslandProcessSettings2 {
  const SourceClassicPerimeterIslandProcessSettings2({
    required this.fillProcess,
    required this.resolutionMm,
    required this.enableArcFitting,
    required this.fuzzySkinType,
    this.counterboreHoleBridging = SourceCounterboreHoleBridging2.none,
    this.bridgeAngleDegrees = 0,
  });

  final SourceClassicPerimeterFillProcessSettings2 fillProcess;
  final double resolutionMm;
  final bool enableArcFitting;
  final SourceFuzzySkinType2 fuzzySkinType;
  final SourceCounterboreHoleBridging2 counterboreHoleBridging;
  final double bridgeAngleDegrees;
}

class SourceClassicProcessedIsland2 {
  const SourceClassicProcessedIsland2({
    required this.prepared,
    required this.process,
  });

  final SourceClassicPreparedSurface2 prepared;
  final SourceClassicPerimeterFillProcessResult2 process;
}

class SourceClassicPerimeterIslandProcessResult2 {
  const SourceClassicPerimeterIslandProcessResult2({
    required this.noBridge,
    required this.preparation,
    required this.islands,
    required this.fillSurfaces,
    required this.fillNoOverlap,
  });

  final SourceClassicNoBridgeResult2 noBridge;
  final SourceClassicSurfacePrepareResult2 preparation;
  final List<SourceClassicProcessedIsland2> islands;

  /// Source-global `fill_surfaces`: counterbore extraction first, followed by
  /// each prepared island's final classic fill surfaces in `chain_expolygons`
  /// order.
  final List<Surface2> fillSurfaces;

  /// Source-global `fill_no_overlap` accumulated from prepared islands.
  final List<SourceExPolygon2> fillNoOverlap;
}

/// Composes the pinned classic path from the source surface vector through the
/// already parity-scoped per-island fill process:
///
/// 1. `Surfaces all_surfaces = slices->surfaces` and `process_no_bridge()`;
/// 2. source resolution selection and `chain_expolygons()` ordering;
/// 3. per-surface `extra_perimeters` / alternate-wall accounting and
///    `simplify_p()` + union;
/// 4. the represented per-island classic shell / Alltop / gap-fill / final
///    fill-boundary pipeline.
///
/// Circle-compensation centers are retained by [preparation] for the later
/// loop/traversal consumer. This helper deliberately does not pretend that the
/// current shell already consumes that metadata.
class SourceClassicPerimeterIslandProcess2 {
  const SourceClassicPerimeterIslandProcess2({
    this.noBridge = const SourceClassicNoBridge2(),
    this.surfacePrepare = const SourceClassicSurfacePrepare2(),
    this.fillProcess = const SourceClassicPerimeterFillProcess2(),
  });

  final SourceClassicNoBridge2 noBridge;
  final SourceClassicSurfacePrepare2 surfacePrepare;
  final SourceClassicPerimeterFillProcess2 fillProcess;

  SourceClassicPerimeterIslandProcessResult2 generate({
    required List<Surface2> surfaces,
    required SourceClassicPerimeterIslandProcessSettings2 settings,
    required int layerIndex,
    List<ExPolygon2>? lowerSlices,
    SourceClassicTopOneWallContext2? topOneWall,
  }) {
    final basePerimeter = settings.fillProcess.perimeter;

    final noBridgeResult = noBridge.process(
      surfaces: surfaces,
      lowerSlices: lowerSlices,
      settings: SourceClassicNoBridgeSettings2(
        mode: settings.counterboreHoleBridging,
        perimeterSpacingMm: basePerimeter.perimeterSpacing,
        externalPerimeterWidthMm: basePerimeter.externalPerimeterWidth,
        bridgeAngleDegrees: settings.bridgeAngleDegrees,
      ),
    );

    final preparation = surfacePrepare.prepare(
      noBridgeResult.surfaces,
      SourceClassicSurfacePrepareSettings2(
        resolutionMm: settings.resolutionMm,
        enableArcFitting: settings.enableArcFitting,
        fuzzySkinType: settings.fuzzySkinType,
        wallLoops: basePerimeter.wallLoops,
        alternateExtraWall: basePerimeter.alternateExtraWall,
        spiralVase: basePerimeter.spiralVase,
      ),
      layerIndex: layerIndex,
    );

    final islands = <SourceClassicProcessedIsland2>[];
    final fillSurfaces = <Surface2>[...noBridgeResult.fillSurfaces];
    final fillNoOverlap = <SourceExPolygon2>[];

    for (final prepared in preparation.prepared) {
      final perSurfacePerimeter = _copyPerimeter(
        basePerimeter,
        extraPerimeters: prepared.surface.extraPerimeters,
        surfaceSimplifyResolution: preparation.surfaceSimplifyResolutionMm,
      );

      final process = fillProcess.generate(
        prepared.simplified,
        SourceClassicPerimeterFillProcessSettings2(
          perimeter: perSurfacePerimeter,
          solidInfillSpacingMm: settings.fillProcess.solidInfillSpacingMm,
          infillWallOverlap: settings.fillProcess.infillWallOverlap,
          // Pinned final `not_filled_exp` uses m_scaled_resolution, not the
          // conditional 0.2 * resolution used inside the island shell.
          fillSurfaceSimplifyResolutionMm: preparation.baseResolutionMm,
        ),
        layerIndex: layerIndex,
        topOneWall: topOneWall,
      );

      islands.add(
        SourceClassicProcessedIsland2(
          prepared: prepared,
          process: process,
        ),
      );
      fillSurfaces.addAll(process.fillBoundary.fillSurfaces);
      fillNoOverlap.addAll(process.fillBoundary.fillNoOverlap);
    }

    return SourceClassicPerimeterIslandProcessResult2(
      noBridge: noBridgeResult,
      preparation: preparation,
      islands: List.unmodifiable(islands),
      fillSurfaces: List.unmodifiable(fillSurfaces),
      fillNoOverlap: List.unmodifiable(fillNoOverlap),
    );
  }

  ClassicPerimeterSettings _copyPerimeter(
    ClassicPerimeterSettings source, {
    required int extraPerimeters,
    required double surfaceSimplifyResolution,
  }) =>
      ClassicPerimeterSettings(
        wallLoops: source.wallLoops,
        externalPerimeterWidth: source.externalPerimeterWidth,
        externalPerimeterSpacing: source.externalPerimeterSpacing,
        perimeterWidth: source.perimeterWidth,
        perimeterSpacing: source.perimeterSpacing,
        externalPerimeterFlow: source.externalPerimeterFlow,
        solidInfillFlow: source.solidInfillFlow,
        hasGapFill: source.hasGapFill,
        sparseInfillDensityPercent: source.sparseInfillDensityPercent,
        filterOutGapFill: source.filterOutGapFill,
        surfaceSimplifyResolution: surfaceSimplifyResolution,
        extraPerimeters: extraPerimeters,
        alternateExtraWall: source.alternateExtraWall,
        preciseOuterWall: source.preciseOuterWall,
        innerOuterWallSequence: source.innerOuterWallSequence,
        detectThinWall: source.detectThinWall,
        spiralVase: source.spiralVase,
      );
}
