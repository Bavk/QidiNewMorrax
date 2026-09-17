#include "clipper/clipper.hpp"

#include <iostream>
#include <string>

using namespace ClipperLib;

// Fixed source-traced AEL-outside rounded-collapse fixtures.
static Path rotated(const Path &path, int start) {
  Path result;
  result.reserve(path.size());
  for (size_t i = 0; i < path.size(); ++i)
    result.push_back(path[(start + static_cast<int>(i)) % path.size()]);
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

static bool run_case(const char *name, const Path &owner, const Path &other,
                     const Path &expected) {
  int checked = 0;
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
          if (!solution.empty()) {
            std::cerr << "actual=[";
            for (size_t i = 0; i < solution.front().size(); ++i) {
              if (i) std::cerr << ",";
              std::cerr << "(" << solution.front()[i].x() << ","
                        << solution.front()[i].y() << ")";
            }
            std::cerr << "]\n";
          }
          return false;
        }
        ++checked;
      }
    }
  }
  std::cout << name << " exact=" << checked << "/18\n";
  return true;
}

int main() {
  bool ok = true;
  ok &= run_case(
      "retained_vertex",
      Path{IntPoint(0, 0), IntPoint(162, -141), IntPoint(164, -8)},
      Path{IntPoint(-20, 17), IntPoint(20, -17), IntPoint(70, -58)},
      Path{IntPoint(162, -141), IntPoint(164, -8), IntPoint(0, 0),
           IntPoint(20, -17)});
  ok &= run_case(
      "retained_wedge",
      Path{IntPoint(0, 0), IntPoint(-142, -178), IntPoint(27, -173)},
      Path{IntPoint(-125, -167), IntPoint(125, 167), IntPoint(-6, -8)},
      Path{IntPoint(27, -173), IntPoint(0, 0), IntPoint(125, 167),
           IntPoint(-6, -8), IntPoint(-142, -178)});
  return ok ? 0 : 1;
}
