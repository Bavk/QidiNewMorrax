import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_extrusion_line.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_wall_tool_paths.dart';

/// Fourth source-order slice of pinned
/// `SkeletalTrapezoidation::generateSegments()`: connect per-edge junctions
/// into variable-width extrusion lines.
extension SourceArachneGenerateSegmentsConnect2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  SourceArachneSTHalfEdge2 getQuadMaxRedgeTo(
    SourceArachneSTHalfEdge2 quadStartEdge,
  ) {
    assert(quadStartEdge.prev == null);
    final startFrom = quadStartEdge.from ??
        (throw StateError('Quad start has no from node'));
    assert(startFrom.data.distanceToBoundary == 0);

    var maxRadius = -1;
    SourceArachneSTHalfEdge2? result;
    SourceArachneSTHalfEdge2? edge = quadStartEdge;
    while (edge != null) {
      final to = edge.to ??
          (throw StateError('Quad edge has no to node'));
      final radius = to.data.distanceToBoundary;
      if (radius > maxRadius) {
        maxRadius = radius;
        result = edge;
      }
      edge = edge.next;
    }

    if (result == null) {
      throw StateError('Pinned quad contains no edge');
    }
    final epsilon =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.005);
    final resultFrom = result.from ??
        (throw StateError('Quad max edge has no from node'));
    final resultTo = result.to ??
        (throw StateError('Quad max edge has no to node'));
    if (result.next == null &&
        resultTo.data.distanceToBoundary - epsilon <
            resultFrom.data.distanceToBoundary) {
      result = result.prev;
    }
    assert(result != null);
    assert(result!.next != null);
    return result!;
  }

  void addToolpathSegment(
    List<List<SourceArachneExtrusionLine2>> generatedToolpaths,
    SourceArachneExtrusionJunction2 from,
    SourceArachneExtrusionJunction2 to, {
    required bool isOdd,
    required bool forceNewPath,
    required bool fromIs3Way,
    required bool toIs3Way,
  }) {
    if (from == to) return;

    final insetIndex = from.perimeterIndex;
    while (generatedToolpaths.length <= insetIndex) {
      generatedToolpaths.add(<SourceArachneExtrusionLine2>[]);
    }
    final insetLines = generatedToolpaths[insetIndex];
    assert(insetLines.isEmpty || insetLines.last.junctions.isNotEmpty);

    if (insetLines.isEmpty ||
        insetLines.last.isOdd != isOdd ||
        insetLines.last.junctions.last.perimeterIndex != insetIndex) {
      forceNewPath = true;
    }

    final joinDistance =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.010);
    if (!forceNewPath &&
        _sourceShorterThen(
          insetLines.last.junctions.last.p - from.p,
          joinDistance,
        ) &&
        (insetLines.last.junctions.last.w - from.w).abs() < joinDistance &&
        !fromIs3Way) {
      insetLines.last.junctions.add(to.copy());
    } else if (!forceNewPath &&
        _sourceShorterThen(
          insetLines.last.junctions.last.p - to.p,
          joinDistance,
        ) &&
        (insetLines.last.junctions.last.w - to.w).abs() < joinDistance &&
        !toIs3Way) {
      // Source logs if this reverses an even wall, but still appends `from`.
      insetLines.last.junctions.add(from.copy());
    } else {
      insetLines.add(
        SourceArachneExtrusionLine2(
          insetIndex: insetIndex,
          isOdd: isOdd,
          junctions: [from, to],
        ),
      );
    }
  }

  void connectJunctions(
    List<List<SourceArachneExtrusionJunction2>> edgeJunctions,
    List<List<SourceArachneExtrusionLine2>> generatedToolpaths,
  ) {
    // Source uses an identity set of edge pointers. Dart half-edge objects keep
    // identity equality, while insertion order gives a stable representation
    // of the graph list used to populate that set.
    final unprocessedQuadStarts = <SourceArachneSTHalfEdge2>{};
    for (final edge in edges) {
      if (edge.prev == null) {
        unprocessedQuadStarts.add(edge);
      }
    }
    final passedOddEdges = <SourceArachneSTHalfEdge2>{};
    final oddEpsilon =
        SourceArachneWallToolPathsPreprocess2.scaleDouble(0.005);

    while (unprocessedQuadStarts.isNotEmpty) {
      final polyDomainStart = unprocessedQuadStarts.first;
      var quadStart = polyDomainStart;
      var newDomainStart = true;

      do {
        var quadEnd = quadStart;
        while (quadEnd.next != null) {
          quadEnd = quadEnd.next!;
        }

        final edgeToPeak = getQuadMaxRedgeTo(quadStart);
        final edgeFromPeak = edgeToPeak.next ??
            (throw StateError('Pinned peak edge has no descending edge'));
        unprocessedQuadStarts.remove(quadStart);

        if (!edgeToPeak.data.hasExtrusionJunctions()) {
          final storage = <SourceArachneExtrusionJunction2>[];
          edgeJunctions.add(storage);
          edgeToPeak.data.setExtrusionJunctions(storage);
        }
        final fromStorage = edgeToPeak.data.extrusionJunctions ??
            (throw StateError('Peak edge junction storage disappeared'));
        final fromJunctions = <SourceArachneExtrusionJunction2>[
          for (final junction in fromStorage) junction.copy(),
        ];

        final descendingTwin = edgeFromPeak.twin ??
            (throw StateError('Descending peak edge has no twin'));
        if (!descendingTwin.data.hasExtrusionJunctions()) {
          final storage = <SourceArachneExtrusionJunction2>[];
          edgeJunctions.add(storage);
          descendingTwin.data.setExtrusionJunctions(storage);
        }
        final toStorage = descendingTwin.data.extrusionJunctions ??
            (throw StateError('Descending twin junction storage disappeared'));
        final toJunctions = <SourceArachneExtrusionJunction2>[
          for (final junction in toStorage) junction.copy(),
        ];

        final beforePeak = edgeToPeak.prev;
        if (beforePeak != null) {
          final previousStorage = beforePeak.data.extrusionJunctions ??
              (throw StateError('Previous peak edge has no junction storage'));
          final previous = <SourceArachneExtrusionJunction2>[
            for (final junction in previousStorage) junction.copy(),
          ];
          while (fromJunctions.isNotEmpty &&
              previous.isNotEmpty &&
              fromJunctions.last.perimeterIndex <=
                  previous.first.perimeterIndex) {
            fromJunctions.removeLast();
          }
          fromJunctions.addAll(previous);
          assert(beforePeak.prev == null);
        }

        final afterPeak = edgeFromPeak.next;
        if (afterPeak != null) {
          final afterTwin = afterPeak.twin ??
              (throw StateError('Post-peak edge has no twin'));
          final nextStorage = afterTwin.data.extrusionJunctions ??
              (throw StateError('Post-peak twin has no junction storage'));
          final next = <SourceArachneExtrusionJunction2>[
            for (final junction in nextStorage) junction.copy(),
          ];
          while (toJunctions.isNotEmpty &&
              next.isNotEmpty &&
              toJunctions.last.perimeterIndex <= next.first.perimeterIndex) {
            toJunctions.removeLast();
          }
          toJunctions.addAll(next);
          assert(afterPeak.next == null);
        }

        assert((fromJunctions.length - toJunctions.length).abs() <= 1);
        final segmentCount = math.min(fromJunctions.length, toJunctions.length);
        for (var reverseIndex = 0;
            reverseIndex < segmentCount;
            reverseIndex++) {
          final from = fromJunctions[fromJunctions.length - 1 - reverseIndex];
          final to = toJunctions[toJunctions.length - 1 - reverseIndex];
          assert(from.perimeterIndex == to.perimeterIndex);

          final quadStartTo = quadStart.to ??
              (throw StateError('Quad start has no to node'));
          final quadEndFrom = quadEnd.from ??
              (throw StateError('Quad end has no from node'));
          final fromIsOdd = quadStartTo.data.beadCount > 0 &&
              quadStartTo.data.beadCount.isOdd &&
              quadStartTo.data.transitionRatio == 0 &&
              reverseIndex == segmentCount - 1 &&
              _sourceShorterThen(from.p - quadStartTo.p, oddEpsilon);
          final toIsOdd = quadEndFrom.data.beadCount > 0 &&
              quadEndFrom.data.beadCount.isOdd &&
              quadEndFrom.data.transitionRatio == 0 &&
              reverseIndex == segmentCount - 1 &&
              _sourceShorterThen(to.p - quadEndFrom.p, oddEpsilon);
          final isOddSegment = fromIsOdd && toIsOdd;

          final quadStartNext = quadStart.next ??
              (throw StateError('Quad start has no next edge'));
          final nextTwin = quadStartNext.twin ??
              (throw StateError('Quad start next edge has no twin'));
          if (isOddSegment && passedOddEdges.contains(nextTwin)) {
            continue;
          }
          final fromIs3Way = fromIsOdd && quadStartTo.isMultiIntersection();
          final toIs3Way = toIsOdd && quadEndFrom.isMultiIntersection();
          passedOddEdges.add(quadStartNext);

          addToolpathSegment(
            generatedToolpaths,
            from,
            to,
            isOdd: isOddSegment,
            forceNewPath: newDomainStart,
            fromIs3Way: fromIs3Way,
            toIs3Way: toIs3Way,
          );
        }
        newDomainStart = false;

        final nextQuad = quadStart.getNextUnconnected();
        if (nextQuad == null) {
          throw StateError('Pinned poly-domain traversal reached no next quad');
        }
        quadStart = nextQuad;
      } while (!identical(quadStart, polyDomainStart));
    }
  }
}

bool _sourceShorterThen(SourcePoint2 vector, int length) {
  if (vector.x > length || vector.x < -length) return false;
  if (vector.y > length || vector.y < -length) return false;
  return vector.squaredLength <= length * length;
}
