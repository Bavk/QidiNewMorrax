import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';
import 'package:qidi_flow_flutter/core/slicer/surface.dart';

SourceExPolygon2 box() => SourceExPolygon2(
      contour: SourcePolygon2(const [
        SourcePoint2(0, 0),
        SourcePoint2(100000, 0),
        SourcePoint2(100000, 100000),
        SourcePoint2(0, 100000),
      ]),
    );

void main() {
  test('default Surface fields match source constructor defaults', () {
    final surface = Surface2();
    expect(surface.surfaceType, SurfaceType.internal);
    expect(surface.thickness, -1);
    expect(surface.thicknessLayers, 1);
    expect(surface.bridgeAngle, -1);
    expect(surface.extraPerimeters, 0);
    expect(surface.counterCircleCompensation, false);
    expect(surface.holesCircleCompensation, isEmpty);
  });

  test('surface classification preserves source stPerimeter behavior', () {
    final perimeter = Surface2(surfaceType: SurfaceType.perimeter);
    expect(perimeter.isTop, false);
    expect(perimeter.isBottom, false);
    expect(perimeter.isExternal, false);
    expect(perimeter.isInternal, true);
    expect(perimeter.isSolid, false);
  });

  test('bottom bridge is both bottom, bridge, external and solid', () {
    final surface = Surface2(surfaceType: SurfaceType.bottomBridge);
    expect(surface.isBottom, true);
    expect(surface.isBridge, true);
    expect(surface.isExternal, true);
    expect(surface.isSolid, true);
  });

  test('source copy constructor resets omitted QIDI compensation members', () {
    final source = Surface2(
      surfaceType: SurfaceType.top,
      expolygon: box(),
      thickness: 0.2,
      thicknessLayers: 2,
      bridgeAngle: 1.25,
      extraPerimeters: 3,
      counterCircleCompensation: true,
      holesCircleCompensation: const [0, 2],
    );

    final copy = Surface2.sourceCopy(source);
    expect(copy.surfaceType, source.surfaceType);
    expect(copy.extraPerimeters, 3);
    expect(copy.counterCircleCompensation, false);
    expect(copy.holesCircleCompensation, isEmpty);
  });

  test('source assignment leaves destination compensation state untouched', () {
    final source = Surface2(
      surfaceType: SurfaceType.internalSolid,
      expolygon: box(),
      extraPerimeters: 4,
      counterCircleCompensation: false,
    );
    final destination = Surface2(
      counterCircleCompensation: true,
      holesCircleCompensation: const [1],
    );

    destination.sourceAssignFrom(source);
    expect(destination.surfaceType, SurfaceType.internalSolid);
    expect(destination.extraPerimeters, 4);
    expect(destination.counterCircleCompensation, true);
    expect(destination.holesCircleCompensation, [1]);
  });

  test('surfaces_could_merge intentionally ignores extra_perimeters', () {
    final a = Surface2(
      surfaceType: SurfaceType.internalSolid,
      thickness: 0.2,
      thicknessLayers: 2,
      bridgeAngle: 0.5,
      extraPerimeters: 0,
    );
    final b = Surface2(
      surfaceType: SurfaceType.internalSolid,
      thickness: 0.2,
      thicknessLayers: 2,
      bridgeAngle: 0.5,
      extraPerimeters: 7,
    );
    expect(surfacesCouldMerge(a, b), true);
  });

  test('surface type colors match Surface.cpp', () {
    expect(surfaceTypeToColorName(SurfaceType.top), 'rgb(255,0,0)');
    expect(surfaceTypeToColorName(SurfaceType.bottom), 'rgb(0,255,0)');
    expect(surfaceTypeToColorName(SurfaceType.internalBridge), 'rgb(0,255,255)');
    expect(surfaceTypeToColorName(null), 'rgb(64,64,64)');
  });
}
