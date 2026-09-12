import 'dart:math' as math;

import '../geometry/source_geometry.dart';
import 'source_arachne_beading_strategy.dart';
import 'source_arachne_extrusion_line.dart';

/// Pinned `SkeletalTrapezoidationEdge::TransitionMiddle`.
class SourceArachneTransitionMiddle2 {
  const SourceArachneTransitionMiddle2({
    required this.pos,
    required this.lowerBeadCount,
    required this.featureRadius,
  });

  final int pos;
  final int lowerBeadCount;
  final int featureRadius;
}

/// Pinned `SkeletalTrapezoidationEdge::TransitionEnd`.
class SourceArachneTransitionEnd2 {
  const SourceArachneTransitionEnd2({
    required this.pos,
    required this.lowerBeadCount,
    required this.isLowerEnd,
  });

  final int pos;
  final int lowerBeadCount;
  final bool isLowerEnd;
}

enum SourceArachneSkeletalEdgeType2 {
  normal,
  extraVd,
  transitionEnd,
}

/// Direct represented data payload from `SkeletalTrapezoidationEdge`.
class SourceArachneSkeletalEdgeData2 {
  SourceArachneSkeletalEdgeData2({
    this.type = SourceArachneSkeletalEdgeType2.normal,
  });

  SourceArachneSkeletalEdgeType2 type;
  bool _centralIsSet = false;
  bool _isCentral = false;
  bool _applyHoleCompensation = false;
  List<SourceArachneTransitionMiddle2>? _transitions;
  List<SourceArachneTransitionEnd2>? _transitionEnds;
  List<SourceArachneExtrusionJunction2>? _extrusionJunctions;

  bool get isCentral {
    if (!_centralIsSet) {
      throw StateError('Pinned edge central state is still UNKNOWN');
    }
    return _isCentral;
  }

  void setIsCentral(bool value) {
    _centralIsSet = true;
    _isCentral = value;
  }

  bool get centralIsSet => _centralIsSet;

  bool hasTransitions({bool ignoreEmpty = false}) =>
      _transitions != null && (ignoreEmpty || _transitions!.isNotEmpty);

  void setTransitions(List<SourceArachneTransitionMiddle2> storage) {
    _transitions = storage;
  }

  List<SourceArachneTransitionMiddle2>? get transitions => _transitions;

  bool hasTransitionEnds({bool ignoreEmpty = false}) =>
      _transitionEnds != null && (ignoreEmpty || _transitionEnds!.isNotEmpty);

  void setTransitionEnds(List<SourceArachneTransitionEnd2> storage) {
    _transitionEnds = storage;
  }

  List<SourceArachneTransitionEnd2>? get transitionEnds => _transitionEnds;

  bool hasExtrusionJunctions({bool ignoreEmpty = false}) =>
      _extrusionJunctions != null &&
      (ignoreEmpty || _extrusionJunctions!.isNotEmpty);

  void setExtrusionJunctions(List<SourceArachneExtrusionJunction2> storage) {
    _extrusionJunctions = storage;
  }

  List<SourceArachneExtrusionJunction2>? get extrusionJunctions =>
      _extrusionJunctions;

  void setHoleCompensationFlag(bool enabled) {
    _applyHoleCompensation = enabled;
  }

  bool get holeCompensationFlag => _applyHoleCompensation;
}

class SourceArachneBeadingPropagation2 {
  SourceArachneBeadingPropagation2(this.beading);

  final SourceArachneBeading2 beading;
  int distToBottomSource = 0;
  int distFromTopSource = 0;
  bool isUpwardPropagatedOnly = false;
}

/// Direct represented data payload from `SkeletalTrapezoidationJoint`.
class SourceArachneSkeletalJoint2 {
  SourceArachneSkeletalJoint2({
    this.distanceToBoundary = -1,
    this.beadCount = -1,
    this.transitionRatio = 0,
  });

  int distanceToBoundary;
  int beadCount;
  double transitionRatio;
  SourceArachneBeadingPropagation2? _beading;

  bool get hasBeading => _beading != null;

  void setBeading(SourceArachneBeadingPropagation2 storage) {
    _beading = storage;
  }

  SourceArachneBeadingPropagation2? get beading => _beading;
}

/// Pointer-shaped port of `STHalfEdge` used before Voronoi construction is
/// integrated. Links are intentionally mutable, matching the source graph.
class SourceArachneSTHalfEdge2 {
  SourceArachneSTHalfEdge2([
    SourceArachneSkeletalEdgeData2? data,
  ]) : data = data ?? SourceArachneSkeletalEdgeData2();

  final SourceArachneSkeletalEdgeData2 data;
  SourceArachneSTHalfEdge2? twin;
  SourceArachneSTHalfEdge2? next;
  SourceArachneSTHalfEdge2? prev;
  SourceArachneSTHalfEdgeNode2? from;
  SourceArachneSTHalfEdgeNode2? to;

  bool canGoUp({bool strict = false}) {
    final fromNode = _requireFrom();
    final toNode = _requireTo();
    if (toNode.data.distanceToBoundary > fromNode.data.distanceToBoundary) {
      return true;
    }
    if (toNode.data.distanceToBoundary < fromNode.data.distanceToBoundary ||
        strict) {
      return false;
    }

    // Source recursion skips this edge's twin and rotates around the `to` node
    // by `outgoing = outgoing->twin->next`.
    var outgoing = next;
    while (!identical(outgoing, twin)) {
      if (outgoing == null) {
        throw StateError('Malformed pinned half-edge fan: next is null');
      }
      if (outgoing.canGoUp()) return true;
      final outgoingTwin = outgoing.twin;
      if (outgoingTwin == null) return false;
      final radialNext = outgoingTwin.next;
      if (radialNext == null) {
        // Literal source fallback: a boundary here "should never occur", but
        // `canGoUp()` returns true in release flow after the assert.
        return true;
      }
      outgoing = radialNext;
    }
    return false;
  }

  bool isUpward() {
    final fromNode = _requireFrom();
    final toNode = _requireTo();
    if (toNode.data.distanceToBoundary > fromNode.data.distanceToBoundary) {
      return true;
    }
    if (toNode.data.distanceToBoundary < fromNode.data.distanceToBoundary) {
      return false;
    }

    final forwardUpDistance = distToGoUp();
    final backwardUpDistance = twin?.distToGoUp();
    if (forwardUpDistance != null && backwardUpDistance != null) {
      return forwardUpDistance < backwardUpDistance;
    }
    if (forwardUpDistance != null) return true;
    if (backwardUpDistance != null) return false;

    // Pinned `Point::operator<`: x-major, then y. This arbitrary tie-break is
    // chosen specifically so the twin returns the opposite orientation.
    return _pointLess(toNode.p, fromNode.p);
  }

  int? distToGoUp() {
    final fromNode = _requireFrom();
    final toNode = _requireTo();
    if (toNode.data.distanceToBoundary > fromNode.data.distanceToBoundary) {
      return 0;
    }
    if (toNode.data.distanceToBoundary < fromNode.data.distanceToBoundary) {
      return null;
    }

    int? result;
    var outgoing = next;
    while (!identical(outgoing, twin)) {
      if (outgoing == null) {
        throw StateError('Malformed pinned half-edge fan: next is null');
      }
      final distanceToUp = outgoing.distToGoUp();
      if (distanceToUp != null) {
        result = result == null
            ? distanceToUp
            : math.min(result, distanceToUp);
      }
      final outgoingTwin = outgoing.twin;
      if (outgoingTwin == null) return null;
      final radialNext = outgoingTwin.next;
      if (radialNext == null) {
        // Literal source fallback after its failed boundary assert.
        return 0;
      }
      outgoing = radialNext;
    }
    if (result != null) {
      result += _coordNorm(toNode.p - fromNode.p);
    }
    return result;
  }

  SourceArachneSTHalfEdge2? getNextUnconnected() {
    var result = this;
    while (result.next != null) {
      result = result.next!;
      if (identical(result, this)) return null;
    }
    return result.twin;
  }

  SourceArachneSTHalfEdgeNode2 _requireFrom() =>
      from ?? (throw StateError('STHalfEdge.from is null'));

  SourceArachneSTHalfEdgeNode2 _requireTo() =>
      to ?? (throw StateError('STHalfEdge.to is null'));
}

class SourceArachneSTHalfEdgeNode2 {
  SourceArachneSTHalfEdgeNode2({
    required this.p,
    SourceArachneSkeletalJoint2? data,
  }) : data = data ?? SourceArachneSkeletalJoint2();

  final SourceArachneSkeletalJoint2 data;
  SourcePoint2 p;
  SourceArachneSTHalfEdge2? incidentEdge;

  bool isMultiIntersection() {
    var oddPathCount = 0;
    final first = incidentEdge;
    var outgoing = first;
    do {
      if (outgoing == null) return false;
      if (outgoing.data.isCentral) oddPathCount++;
      outgoing = outgoing.twin?.next;
    } while (!identical(outgoing, first));
    return oddPathCount > 2;
  }

  bool get isCentral {
    final first = incidentEdge;
    var edge = first;
    do {
      if (edge == null) return false;
      if (edge.data.isCentral) return true;
      final edgeTwin = edge.twin;
      if (edgeTwin == null) return false;
      edge = edgeTwin.next;
    } while (!identical(edge, first));
    return false;
  }

  bool isLocalMaximum({bool strict = false}) {
    if (data.distanceToBoundary == 0) return false;

    final first = incidentEdge;
    var edge = first;
    do {
      if (edge == null) return false;
      if (edge.canGoUp(strict: strict)) return false;
      final edgeTwin = edge.twin;
      if (edgeTwin == null) return false;
      if (edgeTwin.next == null) return false;
      edge = edgeTwin.next;
    } while (!identical(edge, first));
    return true;
  }
}

class SourceArachneSkeletalTrapezoidationGraph2 {
  final List<SourceArachneSTHalfEdge2> edges = [];
  final List<SourceArachneSTHalfEdgeNode2> nodes = [];
}

bool _pointLess(SourcePoint2 left, SourcePoint2 right) =>
    left.x < right.x || (left.x == right.x && left.y < right.y);

int _coordNorm(SourcePoint2 vector) =>
    math.sqrt(vector.squaredLength).truncate();
