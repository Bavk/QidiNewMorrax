import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_voronoi_builder.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_voronoi_predicates.dart';
import 'package:qidi_flow_flutter/core/geometry/source_boost_voronoi_structures.dart';
import 'package:qidi_flow_flutter/core/geometry/source_geometry.dart';

void main() {
  test('Boost source categories retain exact numeric geometry bits', () {
    expect(BoostSourceCategory2.singlePoint, 0x0);
    expect(BoostSourceCategory2.segmentStartPoint, 0x1);
    expect(BoostSourceCategory2.segmentEndPoint, 0x2);
    expect(BoostSourceCategory2.initialSegment, 0x8);
    expect(BoostSourceCategory2.reverseSegment, 0x9);
    expect(
      BoostSourceCategory2.belongs(
        BoostSourceCategory2.initialSegment,
        BoostGeometryCategory2.segment,
      ),
      true,
    );
    expect(
      BoostSourceCategory2.belongs(
        BoostSourceCategory2.segmentStartPoint,
        BoostGeometryCategory2.point,
      ),
      true,
    );
  });

  test('site_event equality ignores flags and indexes like Boost std::unique', () {
    final a = BoostSiteEvent2.point(const SourcePoint2(1, 2))
      ..setInitialIndex(5)
      ..setSortedIndex(9)
      ..setSourceCategory(BoostSourceCategory2.segmentStartPoint);
    final b = BoostSiteEvent2.point(const SourcePoint2(1, 2))
      ..setInitialIndex(99)
      ..setSourceCategory(BoostSourceCategory2.segmentEndPoint);
    expect(a, b);
  });

  test('site_event inverse swaps segment endpoints and toggles 0x20 only', () {
    final site = BoostSiteEvent2.segment(
      const SourcePoint2(1, 2),
      const SourcePoint2(3, 4),
    )
      ..setSourceCategory(BoostSourceCategory2.initialSegment)
      ..setInitialIndex(7);

    site.inverse();
    expect(site.point0, const SourcePoint2(3, 4));
    expect(site.point1, const SourcePoint2(1, 2));
    expect(site.isInverse, true);
    expect(site.sourceCategory, BoostSourceCategory2.initialSegment);
    expect(site.initialIndex, 7);

    site.inverse();
    expect(site.point0, const SourcePoint2(1, 2));
    expect(site.isInverse, false);
  });

  test('circle_event lower_y is always center_y and deactivate is sticky', () {
    final event = BoostCircleEvent2(centerX: 3, centerY: 4, lowerX: 5);
    expect(event.lowerY, 4);
    expect(event.isActive, true);
    event
      ..setY(7)
      ..deactivate();
    expect(event.lowerY, 7);
    expect(event.isActive, false);
  });

  test('point comparator is x-major then y like Boost', () {
    expect(
      BoostVoronoiPredicates2.pointLess(
        const SourcePoint2(0, 9),
        const SourcePoint2(1, -100),
      ),
      true,
    );
    expect(
      BoostVoronoiPredicates2.pointLess(
        const SourcePoint2(1, 2),
        const SourcePoint2(1, 3),
      ),
      true,
    );
  });

  test('event comparator keeps point before nonvertical segment at same x', () {
    final point = BoostSiteEvent2.point(const SourcePoint2(0, 100));
    final segment = BoostSiteEvent2.segment(
      const SourcePoint2(0, 0),
      const SourcePoint2(10, 0),
    );
    expect(BoostVoronoiPredicates2.siteLess(point, segment), true);
    expect(BoostVoronoiPredicates2.siteLess(segment, point), false);
  });

  test('event comparator vertical-site branch uses <= for point vs segment', () {
    final point = BoostSiteEvent2.point(const SourcePoint2(0, 5));
    final vertical = BoostSiteEvent2.segment(
      const SourcePoint2(0, 5),
      const SourcePoint2(0, 10),
    );
    expect(BoostVoronoiPredicates2.siteLess(point, vertical), true);
  });

  test('Boost ULP comparator treats adjacent doubles equal within 64 ULP', () {
    final one = 1.0;
    final onePlusOneUlp = _doubleFromBits(_bits(one) + 1);
    expect(
      BoostVoronoiPredicates2.ulpCompare(one, onePlusOneUlp, 64),
      BoostUlpResult2.equal,
    );
  });

  test('insertSegment creates endpoint + endpoint + directed segment sites', () {
    final builder = SourceBoostVoronoiBuilder2();
    final inputIndex = builder.insertSegment(10, 0, 0, 0);
    expect(inputIndex, 0);
    expect(builder.insertedSiteEvents, hasLength(3));

    final sites = builder.insertedSiteEvents;
    expect(sites[0].sourceCategory, BoostSourceCategory2.segmentStartPoint);
    expect(sites[0].point0, const SourcePoint2(10, 0));
    expect(sites[1].sourceCategory, BoostSourceCategory2.segmentEndPoint);
    expect(sites[1].point0, const SourcePoint2(0, 0));
    expect(sites[2].sourceCategory, BoostSourceCategory2.reverseSegment);
    expect(sites[2].point0, const SourcePoint2(0, 0));
    expect(sites[2].point1, const SourcePoint2(10, 0));
    expect(sites.every((site) => site.initialIndex == 0), true);
  });

  test('prepareSites sorts, uniques by geometry and assigns sorted indexes', () {
    final builder = SourceBoostVoronoiBuilder2();
    builder
      ..insertPoint(10, 0)
      ..insertPoint(0, 5)
      ..insertPoint(0, 5);

    final sites = builder.prepareSites();
    expect(sites, hasLength(2));
    expect(sites[0].point0, const SourcePoint2(0, 5));
    expect(sites[1].point0, const SourcePoint2(10, 0));
    expect(sites[0].sortedIndex, 0);
    expect(sites[1].sortedIndex, 1);
  });

  test('builder enforces QIDI int32 coord_t contract at insertion', () {
    final builder = SourceBoostVoronoiBuilder2();
    expect(() => builder.insertPoint(0x80000000, 0), throwsRangeError);
    expect(() => builder.insertPoint(-0x80000001, 0), throwsRangeError);
  });

  test('construct refuses non-source Voronoi substitution while port is partial', () {
    final builder = SourceBoostVoronoiBuilder2();
    expect(builder.construct, throwsUnsupportedError);
  });
}

int _bits(double value) {
  final data = ByteData(8)..setFloat64(0, value, Endian.host);
  return data.getUint64(0, Endian.host);
}

double _doubleFromBits(int value) {
  final data = ByteData(8)..setUint64(0, value, Endian.host);
  return data.getFloat64(0, Endian.host);
}
