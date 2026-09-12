import '../geometry/source_geometry.dart';
import 'source_arachne_skeletal_graph.dart';

/// Direct port of pinned `SkeletalTrapezoidationGraph::collapseSmallEdges()`.
///
/// The source stores edges/nodes in `std::list` and locator maps point to stable
/// list iterators. Dart object references are identity-stable while List indexes
/// are not, so this port deliberately tracks the current edge and all removals
/// by object identity instead of translating source iterators into indexes.
extension SourceArachneSkeletalGraphCollapse2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void collapseSmallEdges([int snapDistance = 5]) {
    SourceArachneSTHalfEdge2? cursor = edges.isEmpty ? null : edges.first;

    while (cursor != null) {
      // `cursor` is reassigned by `safelyRemoveEdge`, so Dart deliberately does
      // not promote it for the whole loop body. Source `edge_it` itself is the
      // stable iterator for this iteration; freeze the equivalent object now.
      final current = cursor!;
      if (!_containsIdentical(edges, current)) {
        throw StateError('collapseSmallEdges cursor is no longer in graph');
      }

      if (current.prev != null) {
        cursor = _successorOf(edges, current);
        continue;
      }

      final quadStart = current;
      var quadEnd = quadStart;
      while (quadEnd.next != null) {
        quadEnd = quadEnd.next!;
      }
      final quadMid = identical(quadStart.next, quadEnd)
          ? null
          : quadStart.next;

      var cursorUpdated = false;

      void safelyRemoveEdge(SourceArachneSTHalfEdge2 edge) {
        if (identical(edge, cursor)) {
          cursor = _successorOf(edges, edge);
          cursorUpdated = true;
        }
        _removeIdentical(edges, edge, kind: 'edge');
      }

      if (quadMid != null &&
          _shouldCollapse(quadMid.from, quadMid.to, snapDistance)) {
        final quadMidTwin = quadMid.twin;
        if (quadMidTwin == null) {
          // Pinned source asserts here. Its release continuation would keep the
          // same list iterator and loop forever, so fail explicitly rather than
          // inventing a recoverable topology.
          throw StateError('collapseSmallEdges middle edge has no twin');
        }
        final collapsedNode = quadMid.from ??
            (throw StateError('collapseSmallEdges middle edge has no from'));

        var count = 0;
        SourceArachneSTHalfEdge2? edgeFrom3 = quadEnd;
        while (edgeFrom3 != null && !identical(edgeFrom3, quadMidTwin)) {
          edgeFrom3.from = collapsedNode;
          final radialTwin = edgeFrom3.twin ??
              (throw StateError(
                  'collapseSmallEdges radial edge has no twin'));
          radialTwin.to = collapsedNode;
          count++;
          if (count > 1000) break;
          edgeFrom3 = radialTwin.next;
        }

        if (identical(collapsedNode.incidentEdge, quadMid)) {
          if (quadMidTwin.next != null) {
            collapsedNode.incidentEdge = quadMidTwin.next;
          } else {
            final previous = quadMid.prev ??
                (throw StateError(
                    'collapseSmallEdges middle edge has no prev'));
            collapsedNode.incidentEdge = previous.twin;
          }
        }

        final removedNode = quadMid.to ??
            (throw StateError('collapseSmallEdges middle edge has no to'));
        _removeIdentical(nodes, removedNode, kind: 'node');

        final middlePrev = quadMid.prev ??
            (throw StateError('collapseSmallEdges middle edge has no prev'));
        final middleNext = quadMid.next ??
            (throw StateError('collapseSmallEdges middle edge has no next'));
        final twinNext = quadMidTwin.next ??
            (throw StateError(
                'collapseSmallEdges middle twin has no next'));
        final twinPrev = quadMidTwin.prev ??
            (throw StateError(
                'collapseSmallEdges middle twin has no prev'));

        middlePrev.next = middleNext;
        middleNext.prev = middlePrev;
        twinNext.prev = twinPrev;
        twinPrev.next = twinNext;

        safelyRemoveEdge(quadMidTwin);
        safelyRemoveEdge(quadMid);
      }

      if (_shouldCollapse(quadStart.from, quadEnd.to, snapDistance) &&
          _shouldCollapse(quadStart.to, quadEnd.from, snapDistance)) {
        final startTwin = quadStart.twin ??
            (throw StateError('collapseSmallEdges start edge has no twin'));
        final endTwin = quadEnd.twin ??
            (throw StateError('collapseSmallEdges end edge has no twin'));
        final endTo = quadEnd.to ??
            (throw StateError('collapseSmallEdges end edge has no to'));
        final endFrom = quadEnd.from ??
            (throw StateError('collapseSmallEdges end edge has no from'));
        final startFrom = quadStart.from ??
            (throw StateError('collapseSmallEdges start edge has no from'));

        startTwin.to = endTo;
        endTo.incidentEdge = endTwin;

        if (identical(endFrom.incidentEdge, quadEnd)) {
          if (endTwin.next != null) {
            endFrom.incidentEdge = endTwin.next;
          } else {
            final endPrev = quadEnd.prev ??
                (throw StateError(
                    'collapseSmallEdges end edge has no prev'));
            endFrom.incidentEdge = endPrev.twin;
          }
        }

        _removeIdentical(nodes, startFrom, kind: 'node');

        startTwin.twin = endTwin;
        endTwin.twin = startTwin;

        safelyRemoveEdge(quadStart);
        safelyRemoveEdge(quadEnd);
      }

      if (!cursorUpdated) {
        cursor = _successorOf(edges, current);
      }
    }
  }
}

bool _shouldCollapse(
  SourceArachneSTHalfEdgeNode2? first,
  SourceArachneSTHalfEdgeNode2? second,
  int snapDistance,
) {
  if (first == null || second == null) {
    throw StateError('collapseSmallEdges encountered a null endpoint');
  }
  return _sourceShorterThen(first.p - second.p, snapDistance);
}

/// Literal source `shorter_then(Point, coord_t)` comparison.
///
/// Boundary length is inclusive: the final source comparison is
/// `squaredNorm() <= sqr(len)`.
bool _sourceShorterThen(SourcePoint2 vector, int length) {
  if (vector.x > length || vector.x < -length) return false;
  if (vector.y > length || vector.y < -length) return false;
  return vector.x * vector.x + vector.y * vector.y <= length * length;
}

T? _successorOf<T>(List<T> values, T value) {
  final index = _indexOfIdentical(values, value);
  if (index < 0) {
    throw StateError('Source list cursor target is missing');
  }
  return index + 1 < values.length ? values[index + 1] : null;
}

bool _containsIdentical<T>(List<T> values, T value) =>
    _indexOfIdentical(values, value) >= 0;

void _removeIdentical<T>(
  List<T> values,
  T value, {
  required String kind,
}) {
  final index = _indexOfIdentical(values, value);
  if (index < 0) {
    throw StateError('Pinned collapse tried to erase a missing $kind');
  }
  values.removeAt(index);
}

int _indexOfIdentical<T>(List<T> values, T value) {
  for (var index = 0; index < values.length; index++) {
    if (identical(values[index], value)) return index;
  }
  return -1;
}
