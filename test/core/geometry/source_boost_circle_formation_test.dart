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

  test('PPS index=3 matches Boost oracle for two points then segment', () {
    final p1 = BoostSiteEvent2.point(const SourcePoint2(0, 0))
      ..setSortedIndex(0);
    final p2 = BoostSiteEvent2.point(const SourcePoint2(0, 10))
      ..setSortedIndex(1);
    final segment = BoostSiteEvent2.segment(
      const SourcePoint2(10, -10),
      const SourcePoint2(10, 20),
    )..setSortedIndex(2);
    final circle = BoostCircleEvent2();

    expect(formation.tryForm(p1, p2, segment, circle), true);
    expect(circle.x, closeTo(3.75, 1e-12));
    expect(circle.y, closeTo(5, 1e-12));
    expect(circle.lowerX, closeTo(10, 1e-12));
  });

  test('PPS dispatch preserves same geometry for segment index=1', () {
    final segment = BoostSiteEvent2.segment(
      const SourcePoint2(10, -10),
      const SourcePoint2(10, 20),
    )..setSortedIndex(0);
    final p1 = BoostSiteEvent2.point(const SourcePoint2(0, 0))
      ..setSortedIndex(1);
    final p2 = BoostSiteEvent2.point(const SourcePoint2(0, 10))
      ..setSortedIndex(2);
    final circle = BoostCircleEvent2();

    expect(formation.tryForm(segment, p1, p2, circle), true);
    expect(circle.x, closeTo(3.75, 1e-12));
    expect(circle.y, closeTo(5, 1e-12));
    expect(circle.lowerX, closeTo(10, 1e-12));
  });

  test('PPS index=2 normalized reorder matches Boost nonvertical oracle', () {
    final p1 = BoostSiteEvent2.point(const SourcePoint2(-5, 2))
      ..setSortedIndex(0);
    final segment = BoostSiteEvent2.segment(
      const SourcePoint2(20, -3),
      const SourcePoint2(30, 19),
    )..setSortedIndex(1);
    final p2 = BoostSiteEvent2.point(const SourcePoint2(7, 11))
      ..setSortedIndex(2);
    final circle = BoostCircleEvent2();

    expect(formation.tryForm(p1, segment, p2, circle), true);
    expect(circle.x, closeTo(-101.97217573169743, 1e-10));
    expect(circle.y, closeTo(143.79623430892991, 1e-10));
    expect(circle.lowerX, closeTo(-273.75626967037431, 1e-10));
  });

  test('PPS inverse segment retains center but changes Boost lower_x side', () {
    final p1 = BoostSiteEvent2.point(const SourcePoint2(-5, 2))
      ..setSortedIndex(0);
    final p2 = BoostSiteEvent2.point(const SourcePoint2(7, 11))
      ..setSortedIndex(1);
    final segment = BoostSiteEvent2.segment(
      const SourcePoint2(20, -3),
      const SourcePoint2(30, 19),
    )
      ..setSortedIndex(2)
      ..inverse();
    final circle = BoostCircleEvent2();

    expect(formation.tryForm(p1, p2, segment, circle), true);
    expect(circle.x, closeTo(6.9840663381183559, 1e-12));
    expect(circle.y, closeTo(-1.4787551174911417, 1e-12));
    expect(circle.lowerX, closeTo(19.462831628157762, 1e-12));
  });

  test('vertical segment post-filter rejects circle outside source y-range', () {
    final p1 = BoostSiteEvent2.point(const SourcePoint2(0, 0))
      ..setSortedIndex(0);
    final p2 = BoostSiteEvent2.point(const SourcePoint2(10, 0))
      ..setSortedIndex(1);
    final segment = BoostSiteEvent2.segment(
      const SourcePoint2(5, -10),
      const SourcePoint2(5, 10),
    )..setSortedIndex(2);
    expect(formation.tryForm(p1, p2, segment, BoostCircleEvent2()), false);
  });

  test('PSS and SSS stay explicit until their exact source formulas exist', () {
    final point = BoostSiteEvent2.point(const SourcePoint2(0, 0));
    final segment1 = BoostSiteEvent2.segment(
      const SourcePoint2(10, 0),
      const SourcePoint2(10, 10),
    );
    final segment2 = BoostSiteEvent2.segment(
      const SourcePoint2(20, 0),
      const SourcePoint2(20, 10),
    );
    expect(
      () => formation.tryForm(point, segment1, segment2, BoostCircleEvent2()),
      throwsUnsupportedError,
    );
    expect(
      () => formation.tryForm(segment1, segment2, segment1, BoostCircleEvent2()),
      throwsUnsupportedError,
    );
  });
}
