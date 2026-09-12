import '../geometry/expolygon.dart';
import 'classic_perimeter.dart';
import 'classic_perimeter_fill_boundary.dart';
import 'classic_top_one_wall_context.dart';

class SourceClassicPerimeterFillProcessSettings2 {
  const SourceClassicPerimeterFillProcessSettings2({
    required this.perimeter,
    required this.solidInfillSpacingMm,
    required this.infillWallOverlap,
    this.fillSurfaceSimplifyResolutionMm = 0,
  });

  final ClassicPerimeterSettings perimeter;

  /// Source `solid_infill_spacing` consumed by the final post-perimeter
  /// boundary block. It remains explicit here because classic gap-fill may be
  /// disabled, in which case the narrower shell helper does not otherwise need
  /// a `solid_infill_flow` object.
  final double solidInfillSpacingMm;

  final SourceFloatOrPercent2 infillWallOverlap;

  /// Source `m_scaled_resolution` converted back to millimeters at this API
  /// boundary. This is intentionally distinct from the shell's gap-region
  /// simplification setting.
  final double fillSurfaceSimplifyResolutionMm;
}

class SourceClassicPerimeterFillProcessResult2 {
  const SourceClassicPerimeterFillProcessResult2({
    required this.perimeter,
    required this.fillBoundary,
  });

  /// Shell / thin-wall / gap-fill result after the exact represented source
  /// ordering, including carried `top_fills` and `fill_clip`.
  final ClassicPerimeterResult perimeter;

  /// Final represented `fill_surfaces` / `fill_no_overlap` output.
  final SourceClassicFillBoundaryResult2 fillBoundary;
}

/// Composes the currently represented `PerimeterGenerator::process_classic()`
/// stages in their pinned source order:
///
/// 1. requested/alternate perimeter count and pre-shell one-wall gate;
/// 2. onion-shell generation;
/// 3. in-loop `TopOneWallType::Alltop` mutation after the first `last=offsets`;
/// 4. source final-wall stop / optional extra gap-discovery iteration;
/// 5. thin-wall + gap-fill mutation of `last`;
/// 6. final `not_filled_exp` -> `fill_surfaces` / `fill_no_overlap` block.
///
/// This is still a scoped process helper. It does not claim the surrounding
/// loop traversal, overhang/fuzzy extrusion conversion, loop-node metadata or
/// later fill generation that live elsewhere in the source pipeline.
class SourceClassicPerimeterFillProcess2 {
  const SourceClassicPerimeterFillProcess2({
    this.shell = const ClassicPerimeterShellGenerator(),
    this.fillBoundary = const SourceClassicFillBoundary2(),
  });

  final ClassicPerimeterShellGenerator shell;
  final SourceClassicFillBoundary2 fillBoundary;

  SourceClassicPerimeterFillProcessResult2 generate(
    List<ExPolygon2> surfaces,
    SourceClassicPerimeterFillProcessSettings2 settings, {
    required int layerIndex,
    SourceClassicTopOneWallContext2? topOneWall,
  }) {
    if (!settings.solidInfillSpacingMm.isFinite ||
        settings.solidInfillSpacingMm <= 0 ||
        !settings.fillSurfaceSimplifyResolutionMm.isFinite ||
        settings.fillSurfaceSimplifyResolutionMm < 0) {
      throw ArgumentError(
        'solidInfillSpacingMm must be finite and > 0; '
        'fillSurfaceSimplifyResolutionMm must be finite and >= 0',
      );
    }

    final perimeter = shell.generate(
      surfaces,
      settings.perimeter,
      layerIndex: layerIndex,
      topOneWall: topOneWall,
    );

    // Pinned source runs this after gap-fill has potentially subtracted actual
    // covered extrusion geometry from `last`. The shell result's innerRegion is
    // therefore the correct input; do not reconstruct it from perimeter loops.
    final boundary = fillBoundary.build(
      last: perimeter.innerRegion,
      effectiveLoopCount: perimeter.effectiveLoopCount,
      settings: SourceClassicFillBoundarySettings2(
        externalPerimeterSpacingMm:
            settings.perimeter.externalPerimeterSpacing,
        perimeterSpacingMm: settings.perimeter.perimeterSpacing,
        solidInfillSpacingMm: settings.solidInfillSpacingMm,
        infillWallOverlap: settings.infillWallOverlap,
        surfaceSimplifyResolutionMm:
            settings.fillSurfaceSimplifyResolutionMm,
      ),
      topFills: perimeter.topFills,
      fillClip: perimeter.fillClip,
    );

    return SourceClassicPerimeterFillProcessResult2(
      perimeter: perimeter,
      fillBoundary: boundary,
    );
  }
}
