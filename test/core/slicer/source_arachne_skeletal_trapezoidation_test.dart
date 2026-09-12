import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_beading_strategy_factory.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_skeletal_trapezoidation.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_beading_inputs.dart';

SourcePolygon2 _square() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(1000000, 0),
      SourcePoint2(1000000, 1000000),
      SourcePoint2(0, 1000000),
    ]);

SourceArachneWallToolPathsState2 _state() =>
    SourceArachneWallToolPathsState2(
      outline: [_square()],
      beadWidth0: 40000,
      beadWidthX: 40000,
      insetCount: 3,
      wall0Inset: 0,
      layerHeightMm: 0.2,
      params: SourceArachneWallToolPathsParams2(
        minBeadWidthMm: 0.2,
        minFeatureSizeMm: 0.1,
        wallTransitionLengthMm: 0.4,
        wallTransitionAngleDeg: 10.0,
        wallTransitionFilterDeviationMm: 0.05,
        wallDistributionCount: 3,
      ),
    );

void main() {
  test('real square composes Boost graph into variable-width Arachne lines', () {
    final state = _state();
    final inputs = SourceArachneWallToolPathsBeadingInputs2.fromState(state);
    final strategy = SourceArachneBeadingStrategyFactory2.makeStrategy(inputs);

    final result = SourceArachneSkeletalTrapezoidation2.generate(
      state.outline,
      strategy,
      transitioningAngle: strategy.transitioningAngle,
      discretizationStepSize: inputs.discretizationStepSize,
      transitionFilterDistance: inputs.transitionFilterDistance,
      allowedFilterDeviation: inputs.allowedFilterDeviation,
      beadingPropagationTransitionDistance: inputs.preferredTransitionLength,
      enableHoleCompensation: false,
    );

    expect(result.constructed.graph.nodes, isNotEmpty);
    expect(result.constructed.graph.edges, isNotEmpty);
    expect(result.toolpaths, isNotEmpty);
    expect(result.toolpaths.expand((group) => group), isNotEmpty);

    for (var insetIndex = 0;
        insetIndex < result.toolpaths.length;
        insetIndex++) {
      for (final line in result.toolpaths[insetIndex]) {
        expect(line.insetIndex, insetIndex);
        expect(line.junctions, isNotEmpty);
        for (final junction in line.junctions) {
          expect(junction.perimeterIndex, insetIndex);
          expect(junction.w, greaterThanOrEqualTo(0));
        }
      }
    }
  });

  test('source WallToolPaths scalar payload reaches skeletal wrapper unchanged', () {
    final state = _state();
    final inputs = SourceArachneWallToolPathsBeadingInputs2.fromState(state);
    final strategy = SourceArachneBeadingStrategyFactory2.makeStrategy(inputs);

    expect(inputs.discretizationStepSize,
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.8));
    expect(inputs.preferredTransitionLength,
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.4));

    final result = SourceArachneSkeletalTrapezoidation2.generate(
      state.outline,
      strategy,
      transitioningAngle: strategy.transitioningAngle,
      discretizationStepSize: inputs.discretizationStepSize,
      transitionFilterDistance: inputs.transitionFilterDistance,
      allowedFilterDeviation: inputs.allowedFilterDeviation,
      beadingPropagationTransitionDistance: inputs.preferredTransitionLength,
      enableHoleCompensation: false,
    );

    expect(result.toolpaths, isNotEmpty);
  });
}
