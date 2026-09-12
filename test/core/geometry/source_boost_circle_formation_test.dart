import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_circle_formation.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_voronoi_structures.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';

void main() {
  const formation = BoostCircleFormation2();

  test('PPP circle matches Boost 1.83 C++ oracle for a right triangle', () {
    final a = BoostSiteEvent2.point(const SourcePoint2(0, 0));
    final b = BoostSiteEvent2.point(const SourcePoint2(0, 10));
    final c = BoostSiteEvent2.point(const SourcePoint2(10, 0));
    final circle = BoostCircleEvent2();

    expect(formation.tryForm(a, b, c, circle), true);
    expect(circle.x, closeTo(5, 1e-12));
    expect(circle.y, closeTo(5, 1e-12));
    expect(circle.lowerX, closeTo(12.071067811865476, 1e-12));
  });

  test('PPP extreme int32 coordinates match Boost robust C++ oracle', () {
    final a = BoostSiteEvent2.point(
      const SourcePoint2(-2147483000, -2147482000),
    );
    final b = BoostSiteEvent2.point(
      const SourcePoint2(-100, 2147480000),
    );
    final c = BoostSiteEvent2.point(
      const SourcePoint2(2147480000, -200),
    );
    final circle = BoostCircleEvent2();

    expect(formation.tryForm(a, b, c, circle), true);
    expect(circle.x, closeTo(-357914738.88887125, 1e-6));
    expect(circle.y, closeTo(-357914722.22214752, 1e-6));
    expect(circle.lowerX, closeTo(2172916271.4453912, 1e-5));
  });

  test('PPP rejects non-clockwise/collinear triples through existence predicate', () {
    final a = BoostSiteEvent2.point(const SourcePoint2(0, 0));
    final b = BoostSiteEvent2.point(const SourcePoint2(10, 0));
    final c = BoostSiteEvent2.point(const SourcePoint2(20, 0));
    expect(formation.tryForm(a, b, c, BoostCircleEvent2()), false);
  });

  test('segment combinations stay explicit until their exact source formulas exist', () {
    final p1 = BoostSiteEvent2.point(const SourcePoint2(0, 0));
    final p2 = BoostSiteEvent2.point(const SourcePoint2(0, 10));
    final segment = BoostSiteEvent2.segment(
      const SourcePoint2(10, 0),
      const SourcePoint2(10, 10),
    );
    expect(
      () => formation.tryForm(p1, p2, segment, BoostCircleEvent2()),
      throwsUnsupportedError,
    );
  });
}
