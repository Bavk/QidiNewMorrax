from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if text.count(old) != 1:
        raise RuntimeError(f"expected one replacement in {path}, found {text.count(old)}")
    p.write_text(text.replace(old, new, 1))

replace_once(
    "lib/core/slicer/source_clipper1_two_convex_mixed_point_union.dart",
    """/// negative-slope touched edges. A separate late multi-crossing boundary matrix
/// adds 64800/64800 exact full raw paths where the touched-edge endpoint and
/// earlier owner neighbor share the separated global minimum Y. A separate
/// exact pinned-source Clipper1 probe
""",
    """/// negative-slope touched edges. Separate late separated-minimum boundary
/// matrices add 64800/64800 exact full raw paths for multi-crossing states and
/// 64800/64800 exact full raw paths for single-crossing states where the
/// touched-edge endpoint and earlier owner neighbor share the global minimum Y.
/// A separate exact pinned-source Clipper1 probe
""",
)
replace_once(
    "lib/core/slicer/source_clipper1_two_convex_mixed_point_union.dart",
    """/// committed equal-Y fixture locks the full raw path. Side/horizontal and
/// rounded-degenerate mixed touch states remain explicit compatibility seams.
""",
    """/// committed equal-Y fixture locks the full raw path. Side/horizontal and
/// other rounded-degenerate mixed touch states remain explicit compatibility
/// seams.
""",
)
replace_once(
    "lib/core/slicer/source_clipper1_two_convex_mixed_point_union.dart",
    """  ) {
    if (properCount < 2) return false;
    final ownerIndex = owner.points.indexOf(touch);
""",
    """  ) {
    if (properCount < 1) return false;
    final ownerIndex = owner.points.indexOf(touch);
""",
)

replace_once(
    "test/core/slicer/source_clipper1_two_convex_mixed_point_union_test.dart",
    """  test('rounded old strict-maximum fixture remains fallback', () {
    final values = [
      _poly([(-420000, -80000), (-620000, -260000), (-390000, -160000)]),
      _poly([(-420000, -30000), (-420000, -260000), (-340000, -180000)]),
    ];
    expect(SourceClipper1TwoConvexMixedPointUnion2.supports(values), isFalse);
    expect(SourceClipper1TwoConvexUnion2.supports(values), isFalse);
  });
""",
    """  test('late strict-maximum single-cross separated-minimum state is exact', () {
    _expectExactAllRotations(
      _poly([(-420000, -80000), (-620000, -260000), (-390000, -160000)]),
      _poly([(-420000, -30000), (-420000, -260000), (-340000, -180000)]),
      const [
        SourcePoint2(-340000, -180000),
        SourcePoint2(-420000, -30000),
        SourcePoint2(-420000, -80000),
        SourcePoint2(-620000, -260000),
        SourcePoint2(-420000, -173043),
        SourcePoint2(-420000, -260000),
      ],
    );
  });
""",
)

needle = """  test('side touching vertex remains on mixed compatibility seam', () {
"""
insert = """  test('Arachne zero offset routes single-cross separated-minimum state exactly', () {
    final result = SourceArachneWallToolPathsPrepareExact2.offsetPolygons(
      [
        _poly([(-420000, -80000), (-620000, -260000), (-390000, -160000)]),
        _poly([(-420000, -30000), (-420000, -260000), (-340000, -180000)]),
      ],
      0,
    );
    expect(result, hasLength(1));
    expect(result.single.points, const [
      SourcePoint2(-340000, -180000),
      SourcePoint2(-420000, -30000),
      SourcePoint2(-420000, -80000),
      SourcePoint2(-620000, -260000),
      SourcePoint2(-420000, -173043),
      SourcePoint2(-420000, -260000),
    ]);
  });

"""
p = Path("test/core/slicer/source_clipper1_two_convex_mixed_point_union_test.dart")
text = p.read_text()
if text.count(needle) != 1:
    raise RuntimeError("side-touch insertion point not unique")
p.write_text(text.replace(needle, insert + needle, 1))
