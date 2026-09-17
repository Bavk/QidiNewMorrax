#include "clipper/clipper.hpp"

#include <iostream>
#include <string>

using namespace ClipperLib;

static Path rotated(const Path &path, int start) {
  Path result;
  result.reserve(path.size());
  for (size_t i = 0; i < path.size(); ++i)
    result.push_back(path[(start + static_cast<int>(i)) % path.size()]);
  return result;
}

static Path translated(const Path &path, long long tx, long long ty) {
  Path result;
  result.reserve(path.size());
  for (const IntPoint &point : path)
    result.push_back(IntPoint(point.x() + tx, point.y() + ty));
  return result;
}

static bool same_path(const Path &actual, const Path &expected) {
  if (actual.size() != expected.size()) return false;
  for (size_t i = 0; i < actual.size(); ++i) {
    if (actual[i].x() != expected[i].x() || actual[i].y() != expected[i].y())
      return false;
  }
  return true;
}

static bool run_case(const std::string &name, const Path &owner,
                     const Path &other, const Path &expected) {
  for (int owner_rotation = 0; owner_rotation < 3; ++owner_rotation) {
    for (int other_rotation = 0; other_rotation < 3; ++other_rotation) {
      const Path a = rotated(owner, owner_rotation);
      const Path b = rotated(other, other_rotation);
      for (int order = 0; order < 2; ++order) {
        Clipper clipper;
        if (order == 0) {
          clipper.AddPath(a, ptSubject, true);
          clipper.AddPath(b, ptSubject, true);
        } else {
          clipper.AddPath(b, ptSubject, true);
          clipper.AddPath(a, ptSubject, true);
        }
        Paths solution;
        if (!clipper.Execute(ctUnion, solution, pftNonZero, pftNonZero) ||
            solution.size() != 1 || !same_path(solution.front(), expected)) {
          std::cerr << name << " mismatch owner_rotation=" << owner_rotation
                    << " other_rotation=" << other_rotation
                    << " order=" << order << "\n";
          return false;
        }
      }
    }
  }
  return true;
}

static bool run_family(const char *name, const Path &owner, const Path &other,
                       const Path &expected) {
  const int target = 1000;
  long long checked = 0;
  for (int i = 0; i < target; ++i) {
    const long long tx = (static_cast<long long>(i) * 7919 - 3000000) * 1000000LL;
    const long long ty = (static_cast<long long>(i) * -3571 + 1800000) * 1000000LL;
    const Path a = translated(owner, tx, ty);
    const Path b = translated(other, tx, ty);
    const Path e = translated(expected, tx, ty);
    if (!run_case(std::string(name) + "_" + std::to_string(i), a, b, e))
      return false;
    checked += 18;
  }
  std::cout << name << " translated_bases=" << target
            << " exact_full_paths=" << checked << "/" << checked << "\n";
  return true;
}

int main() {
  const Path retained_vertex_owner{
      IntPoint(0, 0), IntPoint(162, -141), IntPoint(164, -8)};
  const Path retained_vertex_other{
      IntPoint(-20, 17), IntPoint(20, -17), IntPoint(70, -58)};
  const Path retained_vertex_expected{
      IntPoint(162, -141), IntPoint(164, -8), IntPoint(0, 0),
      IntPoint(20, -17)};

  const Path retained_wedge_owner{
      IntPoint(0, 0), IntPoint(-142, -178), IntPoint(27, -173)};
  const Path retained_wedge_other{
      IntPoint(-125, -167), IntPoint(125, 167), IntPoint(-6, -8)};
  const Path retained_wedge_expected{
      IntPoint(27, -173), IntPoint(0, 0), IntPoint(125, 167),
      IntPoint(-6, -8), IntPoint(-142, -178)};

  bool ok = true;
  ok &= run_family("retained_vertex", retained_vertex_owner,
                   retained_vertex_other, retained_vertex_expected);
  ok &= run_family("retained_wedge", retained_wedge_owner,
                   retained_wedge_other, retained_wedge_expected);
  return ok ? 0 : 1;
}
