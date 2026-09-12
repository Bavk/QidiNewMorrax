import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';
import 'package:qidi_flow_flutter/core/geometry/source_polygon.dart';

SourcePolygon2 square() => SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
      SourcePoint2(100, 100),
      SourcePoint2(0, 100),
    ]);

void main() {
  test('PointInPolygon returns source 0/1/-1 contract', () {
    final polygon = square();
    expect(polygon.pointInPolygon(const SourcePoint2(50, 50)), 1);
    expect(polygon.pointInPolygon(const SourcePoint2(150, 50)), 0);
    expect(polygon.pointInPolygon(const SourcePoint2(0, 50)), -1);
    expect(polygon.pointInPolygon(const SourcePoint2(100, 100)), -1);
  });

  test('Polygon contains treats boundary as inside by source default', () {
    final polygon = square();
    expect(polygon.contains(const SourcePoint2(0, 50)), true);
    expect(
      polygon.contains(const SourcePoint2(0, 50), borderResult: false),
      false,
    );
  });

  test('containment is orientation independent', () {
    final reversed = square().reversed();
    expect(reversed.contains(const SourcePoint2(50, 50)), true);
    expect(reversed.contains(const SourcePoint2(150, 50)), false);
    expect(reversed.contains(const SourcePoint2(50, 0)), true);
  });

  test('concave crossing parity matches source odd-even behavior', () {
    final polygon = SourcePolygon2(const [
      SourcePoint2(0, 0),
      SourcePoint2(100, 0),
      SourcePoint2(100, 40),
      SourcePoint2(40, 40),
      SourcePoint2(40, 100),
      SourcePoint2(0, 100),
    ]);
    expect(polygon.contains(const SourcePoint2(20, 80)), true);
    expect(polygon.contains(const SourcePoint2(80, 80)), false);
  });
}
