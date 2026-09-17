from pathlib import Path
p = Path('lib/core/slicer/source_clipper1_two_convex_mixed_point_union.dart')
s = p.read_text()
old = '''      if (!actual.points.contains(SourcePoint2(\n        origin.x + point.x,\n        origin.y + point.y,\n      ))) return false;\n'''
new = '''      if (!actual.points.contains(SourcePoint2(\n        origin.x + point.x,\n        origin.y + point.y,\n      ))) {\n        return false;\n      }\n'''
if old not in s:
    raise SystemExit('target not found')
p.write_text(s.replace(old, new, 1))
