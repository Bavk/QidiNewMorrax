from pathlib import Path

path = Path('lib/core/slicer/source_clipper1_two_convex_mixed_point_union.dart')
text = path.read_text()

old = """/// pinned-source late multi-crossing probes add 216000/216000 exact raw starts
/// across proper-count 2-4, including targeted vertical, positive-slope and
/// negative-slope touched edges. A separate exact pinned-source Clipper1 probe
"""
new = """/// pinned-source late multi-crossing probes add 216000/216000 exact raw starts
/// across proper-count 2-4, including targeted vertical, positive-slope and
/// negative-slope touched edges. A separate late multi-crossing boundary matrix
/// adds 64800/64800 exact full raw paths where the touched-edge endpoint and
/// earlier owner neighbor share the separated global minimum Y. A separate
/// exact pinned-source Clipper1 probe
"""
assert old in text
text = text.replace(old, new, 1)

old = """    final equalYStrictMaximum =
        _isEqualYStrictMaximumTouchState(owner, other, touch);

    final boundary = <_DirectedMixedEdge2>[];
"""
new = """    final equalYStrictMaximum =
        _isEqualYStrictMaximumTouchState(owner, other, touch);
    final lateSeparatedMinimumBoundary =
        _isLateStrictMaximumSeparatedMinimumBoundary(
      owner,
      other,
      touch,
      properCount,
    );

    final boundary = <_DirectedMixedEdge2>[];
"""
assert old in text
text = text.replace(old, new, 1)

old = """    final rebased = _rebaseBuildResult(
      simplified,
      allowSeparatedEqualMinimumY: equalYStrictMaximum,
    );
"""
new = """    final rebased = _rebaseBuildResult(
      simplified,
      allowSeparatedEqualMinimumY:
          equalYStrictMaximum || lateSeparatedMinimumBoundary,
    );
"""
assert old in text
text = text.replace(old, new, 1)

marker = """  static int? _strictContainingEdgeIndex(
"""
helper = """  static bool _isLateStrictMaximumSeparatedMinimumBoundary(
    SourcePolygon2 owner,
    SourcePolygon2 other,
    SourcePoint2 touch,
    int properCount,
  ) {
    if (properCount < 2) return false;
    final ownerIndex = owner.points.indexOf(touch);
    if (ownerIndex < 0) return false;
    final previous = owner.points[(ownerIndex + 2) % 3];
    final next = owner.points[(ownerIndex + 1) % 3];
    if (!(previous.y < touch.y && next.y < touch.y)) return false;

    final edgeIndex = _strictContainingEdgeIndex(other, touch);
    if (edgeIndex == null) return false;
    final edgeStart = other.points[edgeIndex];
    final edgeEnd = other.points[(edgeIndex + 1) % 3];
    if (edgeStart.y == edgeEnd.y) return false;

    final otherThird = other.points[(edgeIndex + 2) % 3];
    final minimumOwnerNeighborY =
        previous.y < next.y ? previous.y : next.y;
    if (otherThird.y <= minimumOwnerNeighborY) return false;
    return edgeStart.y == minimumOwnerNeighborY ||
        edgeEnd.y == minimumOwnerNeighborY;
  }

"""
assert marker in text
text = text.replace(marker, helper + marker, 1)

path.write_text(text)
