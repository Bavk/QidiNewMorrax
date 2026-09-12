import 'source_boost_circle_formation.dart';
import 'source_boost_voronoi_output.dart';
import 'source_boost_voronoi_predicates.dart';
import 'source_boost_voronoi_structures.dart';
import 'source_geometry.dart';

class _BeachNode2 {
  _BeachNode2(
    this.key,
    this.data,
  );

  final BoostBeachLineNodeKey2 key;
  final BoostBeachLineNodeData2<BoostRawVoronoiEdge2?> data;
}

class _CircleQueueEntry2 {
  _CircleQueueEntry2(this.circle, this.node);

  final BoostCircleEvent2 circle;
  final _BeachNode2 node;
}

class _EndPointEntry2 {
  _EndPointEntry2(this.point, this.node);

  final SourcePoint2 point;
  final _BeachNode2 node;
}

/// Direct Dart port of Boost.Polygon 1.83 `voronoi_builder<int32>` used by
/// QIDI. The input/site stage, beach-line Fortune sweep, circle-event queue and
/// mutable `voronoi_diagram<double>` output wiring intentionally follow the
/// source control flow instead of substituting another Voronoi implementation.
///
/// The beach line is represented by a sorted Dart list rather than `std::map`.
/// This does not change the source ordering contract: all searches/insertions
/// use the exact Boost `node_comparison_predicate`, and existing nodes are never
/// re-sorted after the source's deliberate in-place circle-event key mutation.
class SourceBoostVoronoiBuilder2 {
  int _index = 0;
  final List<BoostSiteEvent2> _siteEvents = [];

  List<BoostSiteEvent2> _sites = const [];
  int _siteEventIndex = 0;
  final List<_BeachNode2> _beachLine = [];
  final List<_CircleQueueEntry2> _circleHeap = [];
  final List<_EndPointEntry2> _endPoints = [];
  final BoostCircleFormation2 _circleFormation = const BoostCircleFormation2();

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

  /// Equivalent of Boost `construct(OUTPUT*)`, specialized to the directly
  /// ported mutable raw diagram. The returned diagram has already executed the
  /// source `_build()` finalization pass.
  BoostRawVoronoiDiagram2 construct() {
    final output = BoostRawVoronoiDiagram2();
    _constructInto(output);
    return output;
  }

  BoostVoronoiSnapshot2 constructSnapshot() => construct().snapshot();

  void clear() {
    _index = 0;
    _siteEvents.clear();
    _resetSweepState();
  }

  void _constructInto(BoostRawVoronoiDiagram2 output) {
    _resetSweepState();
    _sites = prepareSites();
    output.reserve(_sites.length);
    _initBeachLine(output);

    while (_circleHeap.isNotEmpty || _siteEventIndex < _sites.length) {
      if (_circleHeap.isEmpty) {
        _processSiteEvent(output);
      } else if (_siteEventIndex >= _sites.length) {
        _processCircleEvent(output);
      } else {
        final circle = _circleTop.circle;
        if (BoostVoronoiPredicates2.siteCircleLess(
          _sites[_siteEventIndex],
          circle,
        )) {
          _processSiteEvent(output);
        } else {
          _processCircleEvent(output);
        }
      }

      while (_circleHeap.isNotEmpty && !_circleTop.circle.isActive) {
        _circlePop();
      }
    }

    _beachLine.clear();
    _endPoints.clear();
    output.build();
  }

  void _resetSweepState() {
    _sites = const [];
    _siteEventIndex = 0;
    _beachLine.clear();
    _circleHeap.clear();
    _endPoints.clear();
  }

  void _initBeachLine(BoostRawVoronoiDiagram2 output) {
    if (_sites.isEmpty) return;
    if (_sites.length == 1) {
      output.processSingleSite(_sites[0]);
      _siteEventIndex++;
      return;
    }

    var skip = 0;
    while (_siteEventIndex < _sites.length &&
        BoostVoronoiPredicates2.isVerticalPoints(
          _sites[_siteEventIndex].point0,
          _sites.first.point0,
        ) &&
        BoostVoronoiPredicates2.isVertical(_sites[_siteEventIndex])) {
      _siteEventIndex++;
      skip++;
    }

    if (skip == 1) {
      _initBeachLineDefault(output);
    } else {
      _initBeachLineCollinearSites(output);
    }
  }

  void _initBeachLineDefault(BoostRawVoronoiDiagram2 output) {
    final first = _sites[0];
    final second = _sites[1];
    _insertNewArc(first, first, second, output);
    _siteEventIndex++;
  }

  void _initBeachLineCollinearSites(BoostRawVoronoiDiagram2 output) {
    var firstIndex = 0;
    var secondIndex = 1;
    while (secondIndex != _siteEventIndex) {
      final first = _sites[firstIndex];
      final second = _sites[secondIndex];
      final edge = output.insertNewEdge(first, second).first;
      _insertBeachNode(
        BoostBeachLineNodeKey2(first, second),
        BoostBeachLineNodeData2<BoostRawVoronoiEdge2?>(edge),
      );
      firstIndex++;
      secondIndex++;
    }
  }

  void _deactivateCircleEvent(
    BoostBeachLineNodeData2<BoostRawVoronoiEdge2?> data,
  ) {
    final circle = data.circleEvent;
    if (circle == null) return;
    circle.deactivate();
    data.circleEvent = null;
  }

  void _processSiteEvent(BoostRawVoronoiDiagram2 output) {
    final currentSite = _sites[_siteEventIndex];
    var last = _siteEventIndex + 1;

    if (!currentSite.isSegment) {
      while (_endPoints.isNotEmpty &&
          _endPointTop.point == currentSite.point0) {
        final entry = _endPointPop();
        _beachLine.remove(entry.node);
      }
    } else {
      while (last < _sites.length &&
          _sites[last].isSegment &&
          _sites[last].point0 == currentSite.point0) {
        last++;
      }
    }

    final searchKey = BoostBeachLineNodeKey2.search(currentSite);
    _BeachNode2? rightNode = _lowerBoundNode(searchKey);

    while (_siteEventIndex != last) {
      var siteEvent = _sites[_siteEventIndex].clone();
      final rightIndex = rightNode == null ? -1 : _beachLine.indexOf(rightNode);

      if (rightNode == null) {
        if (_beachLine.isEmpty) {
          throw StateError('Boost beach line unexpectedly empty at right end');
        }
        final leftNode = _beachLine.last;
        final siteArc = leftNode.key.rightSite.clone();
        rightNode = _insertNewArc(
          siteArc,
          siteArc,
          siteEvent,
          output,
        );
        _activateCircleEvent(
          leftNode.key.leftSite,
          leftNode.key.rightSite,
          siteEvent,
          rightNode,
        );
      } else if (rightIndex == 0) {
        final siteArc = rightNode.key.leftSite.clone();
        final leftNode = _insertNewArc(
          siteArc,
          siteArc,
          siteEvent,
          output,
        );

        if (siteEvent.isSegment) {
          siteEvent.inverse();
        }
        _activateCircleEvent(
          siteEvent,
          rightNode.key.leftSite,
          rightNode.key.rightSite,
          rightNode,
        );
        rightNode = leftNode;
      } else {
        final siteArc2 = rightNode.key.leftSite.clone();
        final site3 = rightNode.key.rightSite.clone();

        _deactivateCircleEvent(rightNode.data);
        final leftNode = _beachLine[rightIndex - 1];
        final siteArc1 = leftNode.key.rightSite.clone();
        final site1 = leftNode.key.leftSite.clone();

        final newNode = _insertNewArc(
          siteArc1,
          siteArc2,
          siteEvent,
          output,
        );
        _activateCircleEvent(site1, siteArc1, siteEvent, newNode);

        if (siteEvent.isSegment) {
          siteEvent.inverse();
        }
        _activateCircleEvent(
          siteEvent,
          siteArc2,
          site3,
          rightNode,
        );
        rightNode = newNode;
      }

      _siteEventIndex++;
    }
  }

  void _processCircleEvent(BoostRawVoronoiDiagram2 output) {
    final queueEvent = _circleTop;
    final circleEvent = queueEvent.circle;
    final secondNode = queueEvent.node;
    final secondIndex = _beachLine.indexOf(secondNode);
    if (secondIndex <= 0) {
      throw StateError('Boost circle event has invalid beach-line predecessor');
    }

    var site3 = secondNode.key.rightSite.clone();
    final bisector2 = secondNode.data.edge;
    final firstNode = _beachLine[secondIndex - 1];
    final bisector1 = firstNode.data.edge;
    final site1 = firstNode.key.leftSite.clone();

    if (bisector1 == null || bisector2 == null) {
      throw StateError('Boost circle event requires two materialized bisectors');
    }

    if (!site1.isSegment &&
        site3.isSegment &&
        site3.point1 == site1.point0) {
      site3.inverse();
    }

    firstNode.key.rightSite = site3.clone();
    firstNode.data.edge = output
        .insertNewEdgeAtCircle(
          site1,
          site3,
          circleEvent,
          bisector1,
          bisector2,
        )
        .first;

    _beachLine.remove(secondNode);
    _circlePop();

    var firstIndex = _beachLine.indexOf(firstNode);
    if (firstIndex > 0) {
      _deactivateCircleEvent(firstNode.data);
      final leftNeighbor = _beachLine[firstIndex - 1];
      final siteL1 = leftNeighbor.key.leftSite.clone();
      _activateCircleEvent(siteL1, site1, site3, firstNode);
    }

    firstIndex = _beachLine.indexOf(firstNode);
    final nextIndex = firstIndex + 1;
    if (nextIndex < _beachLine.length) {
      final rightNeighbor = _beachLine[nextIndex];
      _deactivateCircleEvent(rightNeighbor.data);
      final siteR1 = rightNeighbor.key.rightSite.clone();
      _activateCircleEvent(site1, site3, siteR1, rightNeighbor);
    }
  }

  _BeachNode2 _insertNewArc(
    BoostSiteEvent2 siteArc1,
    BoostSiteEvent2 siteArc2,
    BoostSiteEvent2 siteEvent,
    BoostRawVoronoiDiagram2 output,
  ) {
    final newLeftKey = BoostBeachLineNodeKey2(siteArc1, siteEvent);
    final newRightKey = BoostBeachLineNodeKey2(siteEvent, siteArc2);

    if (siteEvent.isSegment) {
      newRightKey.leftSite.inverse();
    }

    final edges = output.insertNewEdge(siteArc2, siteEvent);
    _insertBeachNode(
      newRightKey,
      BoostBeachLineNodeData2<BoostRawVoronoiEdge2?>(edges.second),
    );

    if (siteEvent.isSegment) {
      final temporaryKey = BoostBeachLineNodeKey2(siteEvent, siteEvent);
      temporaryKey.rightSite.inverse();
      final temporaryNode = _insertBeachNode(
        temporaryKey,
        BoostBeachLineNodeData2<BoostRawVoronoiEdge2?>(null),
      );
      _endPointPush(_EndPointEntry2(siteEvent.point1, temporaryNode));
    }

    return _insertBeachNode(
      newLeftKey,
      BoostBeachLineNodeData2<BoostRawVoronoiEdge2?>(edges.first),
    );
  }

  void _activateCircleEvent(
    BoostSiteEvent2 site1,
    BoostSiteEvent2 site2,
    BoostSiteEvent2 site3,
    _BeachNode2 bisectorNode,
  ) {
    final circle = BoostCircleEvent2();
    if (!_circleFormation.tryForm(site1, site2, site3, circle)) return;
    _circlePush(_CircleQueueEntry2(circle, bisectorNode));
    bisectorNode.data.circleEvent = circle;
  }

  _BeachNode2? _lowerBoundNode(BoostBeachLineNodeKey2 key) {
    final index = _lowerBoundIndex(key);
    return index == _beachLine.length ? null : _beachLine[index];
  }

  int _lowerBoundIndex(BoostBeachLineNodeKey2 key) {
    var low = 0;
    var high = _beachLine.length;
    while (low < high) {
      final middle = low + ((high - low) >> 1);
      if (BoostVoronoiPredicates2.nodeLess(_beachLine[middle].key, key)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  _BeachNode2 _insertBeachNode(
    BoostBeachLineNodeKey2 key,
    BoostBeachLineNodeData2<BoostRawVoronoiEdge2?> data,
  ) {
    final index = _lowerBoundIndex(key);
    if (index < _beachLine.length) {
      final existing = _beachLine[index];
      if (!BoostVoronoiPredicates2.nodeLess(key, existing.key) &&
          !BoostVoronoiPredicates2.nodeLess(existing.key, key)) {
        // `std::map::insert` keeps the existing value for an equivalent key.
        return existing;
      }
    }

    final node = _BeachNode2(key, data);
    _beachLine.insert(index, node);
    return node;
  }

  _CircleQueueEntry2 get _circleTop {
    if (_circleHeap.isEmpty) {
      throw StateError('Circle queue is empty');
    }
    return _circleHeap.first;
  }

  void _circlePush(_CircleQueueEntry2 value) {
    _circleHeap.add(value);
    _pushHeap(_circleHeap, _circleHeapLess);
  }

  _CircleQueueEntry2 _circlePop() {
    if (_circleHeap.isEmpty) {
      throw StateError('Circle queue is empty');
    }
    return _popHeap(_circleHeap, _circleHeapLess);
  }

  bool _circleHeapLess(_CircleQueueEntry2 lhs, _CircleQueueEntry2 rhs) =>
      BoostVoronoiPredicates2.circleLess(rhs.circle, lhs.circle);

  _EndPointEntry2 get _endPointTop {
    if (_endPoints.isEmpty) {
      throw StateError('Endpoint queue is empty');
    }
    return _endPoints.first;
  }

  void _endPointPush(_EndPointEntry2 value) {
    _endPoints.add(value);
    _pushHeap(_endPoints, _endPointHeapLess);
  }

  _EndPointEntry2 _endPointPop() {
    if (_endPoints.isEmpty) {
      throw StateError('Endpoint queue is empty');
    }
    return _popHeap(_endPoints, _endPointHeapLess);
  }

  bool _endPointHeapLess(_EndPointEntry2 lhs, _EndPointEntry2 rhs) =>
      BoostVoronoiPredicates2.pointLess(rhs.point, lhs.point);

  /// libstdc++/libc++ style binary heap operations used by `std::priority_queue`.
  /// The tie behavior matters for symmetric Voronoi inputs, so equal values are
  /// not replaced by an arbitrary sort of the whole queue.
  static void _pushHeap<T>(List<T> heap, bool Function(T, T) less) {
    if (heap.length < 2) return;
    var hole = heap.length - 1;
    final value = heap[hole];
    while (hole > 0) {
      final parent = (hole - 1) >> 1;
      if (!less(heap[parent], value)) break;
      heap[hole] = heap[parent];
      hole = parent;
    }
    heap[hole] = value;
  }

  static T _popHeap<T>(List<T> heap, bool Function(T, T) less) {
    final top = heap.first;
    if (heap.length == 1) {
      heap.removeLast();
      return top;
    }

    final value = heap.removeLast();
    final length = heap.length;
    var hole = 0;
    final topIndex = 0;
    var secondChild = 2;

    while (secondChild < length) {
      if (less(heap[secondChild], heap[secondChild - 1])) {
        secondChild--;
      }
      heap[hole] = heap[secondChild];
      hole = secondChild;
      secondChild = 2 * (hole + 1);
    }

    if (secondChild == length) {
      heap[hole] = heap[secondChild - 1];
      hole = secondChild - 1;
    }

    while (hole > topIndex) {
      final parent = (hole - 1) >> 1;
      if (!less(heap[parent], value)) break;
      heap[hole] = heap[parent];
      hole = parent;
    }
    heap[hole] = value;
    return top;
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
