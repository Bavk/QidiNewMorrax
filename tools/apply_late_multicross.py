from pathlib import Path

source_path = Path('lib/core/slicer/source_clipper1_two_convex_mixed_point_union.dart')
source = source_path.read_text()

old = """/// 4. the strict maximum-Y vertex, with exactly one proper crossing, a
///    non-horizontal touched edge and the other triangle's third vertex
///    strictly later than the earlier owner neighbor
///    (`third.y > min(neighbor.y)`).
"""
new = """/// 4. the strict maximum-Y vertex, with a non-horizontal touched edge and the
///    other triangle's third vertex strictly later than the earlier owner
///    neighbor (`third.y > min(neighbor.y)`).
"""
assert old in source
source = source.replace(old, new, 1)

old = """/// direct raw-ELF matrices matched 39600/39600 full raw paths for the
/// strict-minimum class, 72000/72000 for the ordered strict-maximum class and
/// 64800/64800 for the late single-crossing strict-maximum class. A separate
/// exact pinned-source Clipper1 probe matched the proper-only raw start rule in
/// 54000/54000 equal-Y cases across 3000 bases, all 3x3 cyclic source rotations
/// and both input orders; the committed equal-Y fixture locks the full raw path.
/// Side/horizontal, late multi-crossing and rounded-degenerate mixed touch
/// states remain explicit compatibility seams because broader audits contain
/// raw-start counterexamples.
"""
new = """/// direct raw-ELF matrices matched 39600/39600 full raw paths for the
/// strict-minimum class, 72000/72000 for the ordered strict-maximum class and
/// 64800/64800 for the late single-crossing strict-maximum class. Independent
/// pinned-source late multi-crossing probes add 216000/216000 exact raw starts
/// across proper-count 2-4, including targeted vertical, positive-slope and
/// negative-slope touched edges. A separate exact pinned-source Clipper1 probe
/// matched the proper-only raw start rule in 54000/54000 equal-Y cases across
/// 3000 bases, all 3x3 cyclic source rotations and both input orders; the
/// committed equal-Y fixture locks the full raw path. Side/horizontal and
/// rounded-degenerate mixed touch states remain explicit compatibility seams.
"""
assert old in source
source = source.replace(old, new, 1)

old = '    return properCount == 1;\n'
assert source.count(old) == 1
source = source.replace(old, '    return properCount >= 1;\n', 1)
source_path.write_text(source)

test_path = Path('test/core/slicer/source_clipper1_two_convex_mixed_point_union_test.dart')
tests = test_path.read_text()
old = """  test('late strict-maximum multi-crossing state remains fallback', () {
    final values = [
      _poly([(-606000, 279000), (-905000, 166000), (-354000, 79000)]),
      _poly([(-856000, 79000), (-406000, 439000), (-870000, 163000)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexUnion2.supports(values), isFalse);
  });
"""
new = """  test('late strict-maximum multi-crossing touch is exact', () {
    _expectExactAllRotations(
      _poly([(-606000, 279000), (-905000, 166000), (-354000, 79000)]),
      _poly([(-856000, 79000), (-406000, 439000), (-870000, 163000)]),
      const [
        SourcePoint2(-606000, 279000),
        SourcePoint2(-406000, 439000),
        SourcePoint2(-795185, 207502),
        SourcePoint2(-905000, 166000),
        SourcePoint2(-869568, 160405),
        SourcePoint2(-856000, 79000),
        SourcePoint2(-773253, 145198),
        SourcePoint2(-354000, 79000),
      ],
    );
  });
"""
assert old in tests
tests = tests.replace(old, new, 1)

marker = "  test('side touching vertex remains on mixed compatibility seam', () {\n"
addition = """  test('Arachne zero offset routes late multi-crossing strict-maximum state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(-606000, 279000), (-905000, 166000), (-354000, 79000)]),
        _poly([(-856000, 79000), (-406000, 439000), (-870000, 163000)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(-606000, 279000),
      SourcePoint2(-406000, 439000),
      SourcePoint2(-795185, 207502),
      SourcePoint2(-905000, 166000),
      SourcePoint2(-869568, 160405),
      SourcePoint2(-856000, 79000),
      SourcePoint2(-773253, 145198),
      SourcePoint2(-354000, 79000),
    ]);
  });

"""
assert marker in tests
tests = tests.replace(marker, addition + marker, 1)
test_path.write_text(tests)
