import 'source_boost_voronoi_predicates.dart';
import 'source_boost_voronoi_structures.dart';
import 'source_geometry.dart';

/// Port-in-progress of Boost.Polygon 1.83 `voronoi_builder<int32>` used by the
/// QIDI source. This unit currently covers the exact input/site-event stage:
/// insert_point, insert_segment and init_sites_queue.
///
/// Beach-line, circle-event predicates and half-edge output construction are
/// separate source units being ported next. [construct] deliberately refuses to
/// substitute another Voronoi implementation.
class SourceBoostVoronoiBuilder2 {
  int _index = 0;
  final List<BoostSiteEvent2> _siteEvents = [];

  int get inputGeometryCount => _index;
  List<BoostSiteEvent2> get insertedSiteEvents =>
      List.unmodifiable(_siteEvents.map((event) => event.clone()));

  int insertPoint(int x, int y) {
    _requireInt32(x, 'x');
    _requireInt32(y, 'y');
    final inputIndex = _index++;
    _siteEvents.add(
      BoostSiteEvent2.point(SourcePoint2(x, y))
        ..setInitialIndex(inputIndex)
        ..setSourceCategory(BoostSourceCategory2.singlePoint),
    );
    return inputIndex;
  }

  /// Boost creates three site events for one segment: start point, end point,
  /// and the segment itself. All share the same initial input index.
  int insertSegment(int x1, int y1, int x2, int y2) {
    _requireInt32(x1, 'x1');
    _requireInt32(y1, 'y1');
    _requireInt32(x2, 'x2');
    _requireInt32(y2, 'y2');

    final inputIndex = _index++;
    final p1 = SourcePoint2(x1, y1);
    final p2 = SourcePoint2(x2, y2);

    _siteEvents
      ..add(
        BoostSiteEvent2.point(p1)
          ..setInitialIndex(inputIndex)
          ..setSourceCategory(BoostSourceCategory2.segmentStartPoint),
      )
      ..add(
        BoostSiteEvent2.point(p2)
          ..setInitialIndex(inputIndex)
          ..setSourceCategory(BoostSourceCategory2.segmentEndPoint),
      );

    final segment = BoostVoronoiPredicates2.pointLess(p1, p2)
        ? (BoostSiteEvent2.segment(p1, p2)
          ..setSourceCategory(BoostSourceCategory2.initialSegment))
        : (BoostSiteEvent2.segment(p2, p1)
          ..setSourceCategory(BoostSourceCategory2.reverseSegment));
    segment.setInitialIndex(inputIndex);
    _siteEvents.add(segment);
    return inputIndex;
  }

  /// Boost `init_sites_queue()`: event sort, equality-based adjacent unique,
  /// then sequential `sorted_index` assignment.
  List<BoostSiteEvent2> prepareSites() {
    final sites = _siteEvents.map((event) => event.clone()).toList();
    sites.sort(_compareSites);

    final unique = <BoostSiteEvent2>[];
    for (final site in sites) {
      if (unique.isEmpty || unique.last != site) unique.add(site);
    }
    for (var index = 0; index < unique.length; index++) {
      unique[index].setSortedIndex(index);
    }
    return unique;
  }

  Never construct() => throw UnsupportedError(
        'Boost.Polygon Fortune beach-line/circle-event/output construction is '
        'still being ported. Using a different Voronoi implementation would '
        'violate the strict 1:1 migration contract.',
      );

  void clear() {
    _index = 0;
    _siteEvents.clear();
  }

  static int _compareSites(BoostSiteEvent2 a, BoostSiteEvent2 b) {
    if (BoostVoronoiPredicates2.siteLess(a, b)) return -1;
    if (BoostVoronoiPredicates2.siteLess(b, a)) return 1;
    return 0;
  }

  static void _requireInt32(int value, String name) {
    if (value < -0x80000000 || value > 0x7fffffff) {
      throw RangeError.range(value, -0x80000000, 0x7fffffff, name);
    }
  }
}
