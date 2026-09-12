import 'source_geometry.dart';

/// Numeric constants from Boost.Polygon 1.83 `voronoi_geometry_type.hpp`.
class BoostGeometryCategory2 {
  const BoostGeometryCategory2._();
  static const int point = 0x0;
  static const int segment = 0x1;
}

class BoostSourceCategory2 {
  const BoostSourceCategory2._();

  static const int singlePoint = 0x0;
  static const int segmentStartPoint = 0x1;
  static const int segmentEndPoint = 0x2;
  static const int initialSegment = 0x8;
  static const int reverseSegment = 0x9;
  static const int geometryShift = 0x3;
  static const int bitmask = 0x1f;

  static bool belongs(int sourceCategory, int geometryCategory) =>
      (sourceCategory >> geometryShift) == geometryCategory;
}

/// Boost 1.83 `detail::site_event<int32>` using the QIDI `coord_t` domain.
/// Equality intentionally compares only the two site points and ignores all
/// indexes/flags, exactly like Boost; this is what `std::unique()` relies on.
class BoostSiteEvent2 {
  BoostSiteEvent2.point(SourcePoint2 point)
      : point0 = point,
        point1 = point;

  BoostSiteEvent2.segment(SourcePoint2 point0, SourcePoint2 point1)
      : point0 = point0,
        point1 = point1;

  SourcePoint2 point0;
  SourcePoint2 point1;
  int sortedIndex = 0;
  int initialIndex = 0;
  int _flags = 0;

  static const int isInverseBit = 0x20;

  int get x => point0.x;
  int get y => point0.y;
  int get x0 => point0.x;
  int get y0 => point0.y;
  int get x1 => point1.x;
  int get y1 => point1.y;

  bool get isInverse => (_flags & isInverseBit) != 0;
  int get sourceCategory => _flags & BoostSourceCategory2.bitmask;

  BoostSiteEvent2 setSortedIndex(int value) {
    sortedIndex = value;
    return this;
  }

  BoostSiteEvent2 setInitialIndex(int value) {
    initialIndex = value;
    return this;
  }

  /// Boost uses `flags_ |= source_category`, not replacement.
  BoostSiteEvent2 setSourceCategory(int value) {
    _flags |= value;
    return this;
  }

  BoostSiteEvent2 inverse() {
    final tmp = point0;
    point0 = point1;
    point1 = tmp;
    _flags ^= isInverseBit;
    return this;
  }

  bool get isPoint => point0 == point1;
  bool get isSegment => point0 != point1;

  BoostSiteEvent2 clone() {
    final out = isPoint
        ? BoostSiteEvent2.point(point0)
        : BoostSiteEvent2.segment(point0, point1);
    out
      ..sortedIndex = sortedIndex
      ..initialIndex = initialIndex
      .._flags = _flags;
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is BoostSiteEvent2 &&
      point0 == other.point0 &&
      point1 == other.point1;

  @override
  int get hashCode => Object.hash(point0, point1);

  @override
  String toString() =>
      'BoostSiteEvent2($point0->$point1, sorted=$sortedIndex, '
      'initial=$initialIndex, category=$sourceCategory, inverse=$isInverse)';
}

/// Boost 1.83 `detail::circle_event<fpt_type>` (`fpt_type` is double for the
/// int32 Voronoi ctype traits used by QIDI).
class BoostCircleEvent2 {
  BoostCircleEvent2({
    double centerX = 0,
    double centerY = 0,
    double lowerX = 0,
    bool active = true,
  })  : _centerX = centerX,
        _centerY = centerY,
        _lowerX = lowerX,
        _active = active;

  double _centerX;
  double _centerY;
  double _lowerX;
  bool _active;

  double get x => _centerX;
  double get y => _centerY;
  double get lowerX => _lowerX;
  double get lowerY => _centerY;
  bool get isActive => _active;

  BoostCircleEvent2 setX(double value) {
    _centerX = value;
    return this;
  }

  BoostCircleEvent2 setY(double value) {
    _centerY = value;
    return this;
  }

  BoostCircleEvent2 setLowerX(double value) {
    _lowerX = value;
    return this;
  }

  BoostCircleEvent2 deactivate() {
    _active = false;
    return this;
  }
}

/// Boost `detail::beach_line_node_key<site_event>`.
class BoostBeachLineNodeKey2 {
  BoostBeachLineNodeKey2.search(BoostSiteEvent2 newSite)
      : leftSite = newSite.clone(),
        rightSite = newSite.clone();

  BoostBeachLineNodeKey2(
    BoostSiteEvent2 leftSite,
    BoostSiteEvent2 rightSite,
  )   : leftSite = leftSite.clone(),
        rightSite = rightSite.clone();

  BoostSiteEvent2 leftSite;
  BoostSiteEvent2 rightSite;
}

/// Source-shaped value associated with a beach-line bisector. The future
/// Fortune builder supplies its draft edge type as [E]; keeping it generic
/// avoids prematurely coupling event semantics to the immutable final topology.
class BoostBeachLineNodeData2<E> {
  BoostBeachLineNodeData2(this.edge);

  BoostCircleEvent2? circleEvent;
  E edge;
}
