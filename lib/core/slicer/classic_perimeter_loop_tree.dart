import '../geometry/source_polygon.dart';

/// Source `PerimeterGeneratorLoop` value used by classic perimeter nesting and
/// `traverse_loops()`.
class SourcePerimeterLoop2 {
  SourcePerimeterLoop2({
    required this.polygon,
    required this.depth,
    required this.isContour,
    this.isSmallerWidthPerimeter = false,
    this.needCircleCompensation = false,
    Iterable<SourcePerimeterLoop2> children = const [],
  }) : children = List<SourcePerimeterLoop2>.of(children);

  final SourcePolygon2 polygon;
  final int depth;
  final bool isContour;
  final bool isSmallerWidthPerimeter;
  final bool needCircleCompensation;
  final List<SourcePerimeterLoop2> children;

  bool get isExternal => depth == 0;

  /// Exact source predicate: an internal contour is a contour containing no
  /// contour child. Hole children do not make it non-internal.
  bool get isInternalContour {
    if (!isContour) return false;
    for (final child in children) {
      if (child.isContour) return false;
    }
    return true;
  }
}

/// Literal port of the two classic `process_classic()` nesting passes.
class SourceClassicPerimeterLoopNester2 {
  const SourceClassicPerimeterLoopNester2._();

  static List<SourcePerimeterLoop2> nest({
    required List<List<SourcePerimeterLoop2>> contoursByDepth,
    required List<List<SourcePerimeterLoop2>> holesByDepth,
    required int loopNumber,
  }) {
    if (loopNumber < 0) return const [];
    if (contoursByDepth.length <= loopNumber ||
        holesByDepth.length <= loopNumber) {
      throw ArgumentError('loop containers must include 0..loopNumber');
    }

    // Source mutates its depth buckets while attaching value-copied loops.
    // Copy the bucket containers here while preserving node identity after a
    // node has a single owner in the resulting tree.
    final contours = <List<SourcePerimeterLoop2>>[
      for (final bucket in contoursByDepth) List.of(bucket),
    ];
    final holes = <List<SourcePerimeterLoop2>>[
      for (final bucket in holesByDepth) List.of(bucket),
    ];

    // Source: nest holes first, shallowest depth first. Prefer a containing
    // deeper hole; only if none exists search contours deepest-to-shallowest.
    for (var depth = 0; depth <= loopNumber; depth++) {
      final holesAtDepth = holes[depth];
      for (var i = 0; i < holesAtDepth.length; i++) {
        final loop = holesAtDepth[i];
        final probe = _firstPoint(loop);
        var attached = false;

        for (var parentDepth = depth + 1;
            parentDepth <= loopNumber && !attached;
            parentDepth++) {
          for (var j = 0; j < holes[parentDepth].length; j++) {
            final candidateParent = holes[parentDepth][j];
            if (candidateParent.polygon.contains(probe)) {
              candidateParent.children.add(loop);
              holesAtDepth.removeAt(i);
              i--;
              attached = true;
              break;
            }
          }
        }
        if (attached) continue;

        for (var parentDepth = loopNumber;
            parentDepth >= 0 && !attached;
            parentDepth--) {
          for (var j = 0; j < contours[parentDepth].length; j++) {
            final candidateParent = contours[parentDepth][j];
            if (candidateParent.polygon.contains(probe)) {
              candidateParent.children.add(loop);
              holesAtDepth.removeAt(i);
              i--;
              attached = true;
              break;
            }
          }
        }
        // If no parent is found the C++ source leaves this loop in its bucket;
        // it is not promoted to a root. Preserve that behavior.
      }
    }

    // Source: nest contours deepest-to-shallowest into the first containing
    // contour at any shallower depth, preferring the nearest depth first.
    for (var depth = loopNumber; depth >= 1; depth--) {
      final contoursAtDepth = contours[depth];
      for (var i = 0; i < contoursAtDepth.length; i++) {
        final loop = contoursAtDepth[i];
        final probe = _firstPoint(loop);
        var attached = false;

        for (var parentDepth = depth - 1;
            parentDepth >= 0 && !attached;
            parentDepth--) {
          for (var j = 0; j < contours[parentDepth].length; j++) {
            final candidateParent = contours[parentDepth][j];
            if (candidateParent.polygon.contains(probe)) {
              candidateParent.children.add(loop);
              contoursAtDepth.removeAt(i);
              i--;
              attached = true;
              break;
            }
          }
        }
        // As in source, an unparented deeper contour simply remains outside
        // contours[0] rather than being silently promoted.
      }
    }

    return List.unmodifiable(contours[0]);
  }

  static dynamic _firstPoint(SourcePerimeterLoop2 loop) {
    if (loop.polygon.points.isEmpty) {
      throw StateError('PerimeterGeneratorLoop polygon must not be empty');
    }
    return loop.polygon.points.first;
  }
}
