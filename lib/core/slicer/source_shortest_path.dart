import '../geometry/source_geometry.dart';
import 'extrusion_entity.dart';

/// Result entry returned by source `chain_extrusion_entities()`.
class SourceEntityChainEntry2 {
  const SourceEntityChainEntry2(this.index, this.reversed);

  final int index;
  final bool reversed;

  @override
  bool operator ==(Object other) =>
      other is SourceEntityChainEntry2 &&
      other.index == index &&
      other.reversed == reversed;

  @override
  int get hashCode => Object.hash(index, reversed);

  @override
  String toString() => 'SourceEntityChainEntry2($index, $reversed)';
}

class _ChainEndPoint2 {
  _ChainEndPoint2(this.position);

  final SourcePoint2 position;
  int chainId = 0;
  int? edgeOut;
  double distanceOut = double.maxFinite;
  bool inQueue = false;
}

class _EquivalentChains2 {
  _EquivalentChains2(int reserveHint) {
    // Source reserves but always starts with invalid class zero.
    equivalentWith.add(0);
  }

  final List<int> equivalentWith = <int>[];
  int lastChainId = 0;

  int next() {
    lastChainId++;
    equivalentWith.add(lastChainId);
    return lastChainId;
  }

  int equivalent(int chainId) {
    if (chainId == 0) return 0;
    var last = chainId;
    while (true) {
      final lower = equivalentWith[last];
      if (lower == last) {
        equivalentWith[chainId] = lower;
        return lower;
      }
      last = lower;
    }
  }

  int merge(int chainId1, int chainId2) {
    final result = equivalent(chainId1) < equivalent(chainId2)
        ? equivalent(chainId1)
        : equivalent(chainId2);
    equivalentWith[chainId1] = result;
    equivalentWith[chainId2] = result;
    return result;
  }
}

/// Direct behavioral port of the source
/// `chain_segments_greedy_constrained_reversals_()` path used by
/// `chain_extrusion_entities()`.
///
/// The C++ implementation accelerates nearest-endpoint queries with a KD tree
/// and maintains a mutable heap. This Dart port evaluates the same admissible
/// candidates linearly and recomputes the queue minimum. That preserves the
/// multi-fragment graph, chain-equivalence, cycle and reversal semantics while
/// deliberately trading asymptotic performance for a smaller parity surface.
class SourceShortestPath2 {
  const SourceShortestPath2._();

  static List<SourceEntityChainEntry2> chainExtrusionEntities(
    List<ExtrusionEntity2> entities, {
    SourcePoint2? startNear,
  }) {
    final chain = _chainSegments(
      entities.length,
      (index, firstPoint) =>
          firstPoint ? entities[index].firstPoint : entities[index].lastPoint,
      (index) => entities[index].isLoop || entities[index].canReverse,
      startNear,
    );

    return List.unmodifiable([
      for (final entry in chain)
        SourceEntityChainEntry2(
          entry.index,
          entities[entry.index].isLoop ? false : entry.reversed,
        ),
    ]);
  }

  static void reorderExtrusionEntities(
    List<ExtrusionEntity2> entities,
    List<SourceEntityChainEntry2> chain,
  ) {
    if (entities.length != chain.length) {
      throw ArgumentError('entity count must match source chain length');
    }
    final output = <ExtrusionEntity2>[];
    for (final entry in chain) {
      final entity = entities[entry.index];
      if (entry.reversed) entity.reverse();
      output.add(entity);
    }
    entities
      ..clear()
      ..addAll(output);
  }

  static void chainAndReorderExtrusionEntities(
    List<ExtrusionEntity2> entities, {
    SourcePoint2? startNear,
  }) {
    final chain = chainExtrusionEntities(entities, startNear: startNear);
    reorderExtrusionEntities(entities, chain);
  }

  static List<SourceEntityChainEntry2> _chainSegments(
    int count,
    SourcePoint2 Function(int index, bool firstPoint) endpoint,
    bool Function(int index) couldReverse,
    SourcePoint2? startNear,
  ) {
    if (count == 0) return const [];
    if (count == 1) {
      final reversed = couldReverse(0) &&
          startNear != null &&
          _squaredDistance(endpoint(0, false), startNear) <
              _squaredDistance(endpoint(0, true), startNear);
      return [SourceEntityChainEntry2(0, reversed)];
    }

    final endPoints = <_ChainEndPoint2>[];
    for (var i = 0; i < count; i++) {
      endPoints
        ..add(_ChainEndPoint2(endpoint(i, true)))
        ..add(_ChainEndPoint2(endpoint(i, false)));
    }
    final equivalent = _EquivalentChains2(count);

    int? firstPointIndex;
    if (startNear != null) {
      firstPointIndex = _findClosest(
        endPoints,
        startNear,
        (index) => index.isEven || couldReverse(index >> 1),
      );
      final first = endPoints[firstPointIndex];
      first
        ..distanceOut = 0
        ..chainId = equivalent.next();
    }
    final initialPointIndex = firstPointIndex;
    int? lastPointIndex;

    for (var i = 0; i < endPoints.length; i++) {
      if (i == firstPointIndex) continue;
      final candidate = _findClosest(
        endPoints,
        endPoints[i].position,
        (index) => index != firstPointIndex && (index ^ i) > 1,
      );
      endPoints[i]
        ..edgeOut = candidate
        ..distanceOut = _squaredDistance(
          endPoints[i].position,
          endPoints[candidate].position,
        )
        ..inQueue = true;
    }

    var iteration = count - 2;
    while (true) {
      final firstIndex = _queueTop(endPoints);
      final first = endPoints[firstIndex];
      final secondIndex = first.edgeOut!;
      final second = endPoints[secondIndex];

      var valid = true;
      var firstOtherChain = 0;
      var secondOtherChain = 0;
      if (second.chainId > 0) {
        valid = false;
      } else {
        firstOtherChain = equivalent.equivalent(
          endPoints[firstIndex ^ 1].chainId,
        );
        secondOtherChain = equivalent.equivalent(
          endPoints[secondIndex ^ 1].chainId,
        );
        if (firstOtherChain == secondOtherChain && firstOtherChain != 0) {
          valid = false;
        }
      }

      if (valid) {
        first.inQueue = false;
        second.inQueue = false;
        second
          ..edgeOut = firstIndex
          ..distanceOut = first.distanceOut;

        final chainId = firstOtherChain == 0
            ? (secondOtherChain == 0
                ? equivalent.next()
                : secondOtherChain)
            : (secondOtherChain == 0
                ? firstOtherChain
                : (firstOtherChain == secondOtherChain
                    ? firstOtherChain
                    : equivalent.merge(firstOtherChain, secondOtherChain)));
        first.chainId = chainId;
        second.chainId = chainId;

        if (iteration == 0) {
          final queue = _queueIndexes(endPoints);
          if (firstPointIndex == null) {
            if (queue.length != 2) {
              throw StateError('source chain expected two free endpoints');
            }
            firstPointIndex = _queueTop(endPoints);
            endPoints[firstPointIndex]
              ..inQueue = false
              ..edgeOut = null;
          }
          final remaining = _queueIndexes(endPoints);
          if (remaining.length != 1) {
            throw StateError('source chain expected one final endpoint');
          }
          lastPointIndex = remaining.single;
          endPoints[lastPointIndex]
            ..inQueue = false
            ..edgeOut = null;
          break;
        }
        iteration--;
      } else {
        final thisIndex = firstIndex;
        final next = _findClosest(
          endPoints,
          first.position,
          (index) {
            if ((index ^ thisIndex) <= 1 || endPoints[index].chainId != 0) {
              return false;
            }
            final chain1 = equivalent.equivalent(
              endPoints[thisIndex ^ 1].chainId,
            );
            final chain2 = equivalent.equivalent(
              endPoints[index ^ 1].chainId,
            );
            return chain1 != chain2 || chain1 == 0;
          },
        );
        first
          ..edgeOut = next
          ..distanceOut = _squaredDistance(
            first.position,
            endPoints[next].position,
          );
        // C++ increments the for-loop counter here to cancel its decrement.
      }
    }

    final direct = _walkGraph(
      endPoints,
      firstPointIndex,
      count,
      couldReverse,
    );
    if (direct != null) return direct;

    if (startNear == null) {
      final reverseDirection = _walkGraph(
        endPoints,
        lastPointIndex,
        count,
        couldReverse,
      );
      if (reverseDirection != null) return reverseDirection;
    }

    return _closestPointFallback(
      endPoints,
      couldReverse,
      initialPointIndex ?? 0,
      count,
    );
  }

  static List<SourceEntityChainEntry2>? _walkGraph(
    List<_ChainEndPoint2> endPoints,
    int firstPointIndex,
    int count,
    bool Function(int index) couldReverse,
  ) {
    final output = <SourceEntityChainEntry2>[];
    int? current = firstPointIndex;
    while (current != null) {
      if (output.length >= count) {
        throw StateError('source chain graph unexpectedly contains a cycle');
      }
      final segment = current >> 1;
      final reversed = current.isOdd;
      if (reversed && !couldReverse(segment)) return null;
      output.add(SourceEntityChainEntry2(segment, reversed));
      current = endPoints[current ^ 1].edgeOut;
    }
    return output.length == count ? output : null;
  }

  static List<SourceEntityChainEntry2> _closestPointFallback(
    List<_ChainEndPoint2> endPoints,
    bool Function(int index) couldReverse,
    int firstPointIndex,
    int count,
  ) {
    for (final point in endPoints) {
      point.chainId = 0;
    }

    final output = <SourceEntityChainEntry2>[];
    output.add(SourceEntityChainEntry2(
      firstPointIndex >> 1,
      firstPointIndex.isOdd,
    ));
    endPoints[firstPointIndex].chainId = 1;
    var current = firstPointIndex ^ 1;

    for (var iter = count - 2; iter >= 0; iter--) {
      endPoints[current].chainId = 1;
      final next = _findClosest(
        endPoints,
        endPoints[current].position,
        (index) =>
            (index ^ current) > 1 &&
            endPoints[index].chainId == 0 &&
            (index.isEven || couldReverse(index >> 1)),
      );
      endPoints[next].chainId = 1;
      output.add(SourceEntityChainEntry2(next >> 1, next.isOdd));
      current = next ^ 1;
    }
    return output;
  }

  static int _findClosest(
    List<_ChainEndPoint2> points,
    SourcePoint2 target,
    bool Function(int index) allowed,
  ) {
    var best = -1;
    var bestDistance = double.maxFinite;
    for (var i = 0; i < points.length; i++) {
      if (!allowed(i)) continue;
      final distance = _squaredDistance(points[i].position, target);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    if (best < 0) throw StateError('source chain has no admissible endpoint');
    return best;
  }

  static int _queueTop(List<_ChainEndPoint2> points) {
    var best = -1;
    var bestDistance = double.maxFinite;
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (!point.inQueue) continue;
      if (point.distanceOut < bestDistance) {
        bestDistance = point.distanceOut;
        best = i;
      }
    }
    if (best < 0) throw StateError('source chain queue unexpectedly empty');
    return best;
  }

  static List<int> _queueIndexes(List<_ChainEndPoint2> points) => [
        for (var i = 0; i < points.length; i++)
          if (points[i].inQueue) i,
      ];

  static double _squaredDistance(SourcePoint2 a, SourcePoint2 b) {
    final dx = a.x.toDouble() - b.x.toDouble();
    final dy = a.y.toDouble() - b.y.toDouble();
    return dx * dx + dy * dy;
  }
}
