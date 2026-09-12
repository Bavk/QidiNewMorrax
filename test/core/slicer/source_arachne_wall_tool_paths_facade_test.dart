import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths.dart';
import 'package:qidi_flow_flutter/core/slicer/source_arachne_wall_tool_paths_facade.dart';

SourceArachneWallToolPathsParams2 _params() =>
    SourceArachneWallToolPathsParams2(
      minBeadWidthMm: 0.2,
      minFeatureSizeMm: 0.1,
      wallTransitionLengthMm: 0.4,
      wallTransitionAngleDeg: 10,
      wallTransitionFilterDeviationMm: 0.05,
      wallDistributionCount: 3,
    );

SourcePolygon2 _square() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(1000000, 0),
      SourcePoint2(1000000, 1000000),
      SourcePoint2(0, 1000000),
    ]);

SourceArachneWallToolPathsState2 _state({
  int insetCount = 1,
  List<SourcePolygon2>? outline,
}) =>
    SourceArachneWallToolPathsState2(
      outline: outline ?? [_square()],
      beadWidth0: 40000,
      beadWidthX: 40000,
      insetCount: insetCount,
      wall0Inset: 0,
      layerHeightMm: 0.2,
      params: _params(),
    );

void main() {
  test('zero inset inner contour returns original outline without generation', () {
    final state = _state(insetCount: 0);
    final facade = SourceArachneWallToolPathsFacade2(state);

    final inner = facade.getInnerContour();

    expect(identical(inner, state.outline), isTrue);
    expect(facade.latest, isNull);
    expect(facade.toolpathsGenerated, isFalse);
  });

  test('zero inset first-wall contour is source global empty', () {
    final facade = SourceArachneWallToolPathsFacade2(_state(insetCount: 0));

    expect(facade.getFirstWallContour(), isEmpty);
    expect(facade.latest, isNull);
  });

  test('zero inset getToolPaths calls generate but keeps generated flag false', () {
    final state = _state(insetCount: 0);
    final facade = SourceArachneWallToolPathsFacade2(state);

    expect(facade.getToolPaths(), isEmpty);
    expect(facade.latest, isNotNull);
    expect(facade.toolpathsGenerated, isFalse);
    expect(identical(facade.getInnerContour(), state.outline), isTrue);
  });

  test('failed early generation is retried by the next getter', () {
    final facade = SourceArachneWallToolPathsFacade2(
      _state(outline: const <SourcePolygon2>[]),
    );

    facade.getToolPaths();
    final firstAttempt = facade.latest;
    expect(firstAttempt, isNotNull);
    expect(firstAttempt!.toolpathsGenerated, isFalse);

    facade.getInnerContour();
    final secondAttempt = facade.latest;
    expect(secondAttempt, isNotNull);
    expect(identical(secondAttempt, firstAttempt), isFalse);
    expect(secondAttempt!.toolpathsGenerated, isFalse);
  });

  test('positive inset inner getter lazily generates and then caches', () {
    final facade = SourceArachneWallToolPathsFacade2(_state());

    final inner = facade.getInnerContour();
    final generated = facade.latest;

    expect(generated, isNotNull);
    expect(generated!.toolpathsGenerated, isTrue);
    expect(facade.toolpathsGenerated, isTrue);
    expect(identical(inner, generated.innerContour), isTrue);

    facade.getToolPaths();
    expect(identical(facade.latest, generated), isTrue);
  });

  test('hole compensation assignment is consumed by first generation', () {
    final facade = SourceArachneWallToolPathsFacade2(_state())
      ..enableHoleCompensation(true, const <int>[]);

    facade.getToolPaths();

    expect(facade.latest!.prepared!.applyHoleCompensation, isTrue);
  });

  test('EnableHoleCompensation after successful generation does not rerun', () {
    final facade = SourceArachneWallToolPathsFacade2(_state());
    facade.getToolPaths();
    final generated = facade.latest;
    expect(generated!.prepared!.applyHoleCompensation, isFalse);

    facade.enableHoleCompensation(true, const <int>[]);
    facade.getFirstWallContour();

    expect(identical(facade.latest, generated), isTrue);
    expect(facade.latest!.prepared!.applyHoleCompensation, isFalse);
  });
}
