#include "clipper/clipper.hpp"

#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using namespace ClipperLib;

static Path rotate3(const Path &p, int start) {
  Path out;
  for (int i = 0; i < 3; ++i) out.push_back(p[(start + i) % 3]);
  return out;
}

static std::string path_string(const Path &p) {
  std::ostringstream out;
  out << "[";
  for (size_t i = 0; i < p.size(); ++i) {
    if (i) out << ",";
    out << "(" << p[i].x() << "," << p[i].y() << ")";
  }
  out << "]";
  return out.str();
}

static bool source_union(const Path &a, const Path &b, Path &out) {
  Clipper clipper;
  if (!clipper.AddPath(a, ptSubject, true)) return false;
  if (!clipper.AddPath(b, ptSubject, true)) return false;
  Paths solution;
  if (!clipper.Execute(ctUnion, solution, pftNonZero, pftNonZero)) return false;
  if (solution.size() != 1) return false;
  out = solution[0];
  return true;
}

struct Fixture {
  const char *name;
  Path owner;
  Path other;
};

int main() {
  const std::vector<Fixture> fixtures = {
      {
          "retained_inner_vertex",
          {{0, 0}, {162, -141}, {164, -8}},
          {{-20, 17}, {20, -17}, {70, -58}},
      },
      {
          "retained_wedge",
          {{0, 0}, {-142, -178}, {27, -173}},
          {{-125, -167}, {125, 167}, {-6, -8}},
      },
  };

  int matched = 0;
  int total = 0;
  for (const Fixture &fixture : fixtures) {
    Path expected;
    if (!source_union(fixture.owner, fixture.other, expected)) {
      std::cerr << "BASE_EXEC_FAIL " << fixture.name << "\n";
      return 2;
    }
    std::cout << fixture.name << " raw=" << path_string(expected) << "\n";
    int fixture_matched = 0;
    for (int ro = 0; ro < 3; ++ro) {
      for (int rt = 0; rt < 3; ++rt) {
        const Path owner = rotate3(fixture.owner, ro);
        const Path other = rotate3(fixture.other, rt);
        for (int order = 0; order < 2; ++order) {
          ++total;
          Path actual;
          if (!source_union(order == 0 ? owner : other,
                            order == 0 ? other : owner,
                            actual)) {
            std::cerr << "EXEC_FAIL " << fixture.name << " ro=" << ro
                      << " rt=" << rt << " order=" << order << "\n";
            return 3;
          }
          if (actual != expected) {
            std::cerr << "MISMATCH " << fixture.name << " ro=" << ro
                      << " rt=" << rt << " order=" << order
                      << " expected=" << path_string(expected)
                      << " actual=" << path_string(actual) << "\n";
            return 4;
          }
          ++matched;
          ++fixture_matched;
        }
      }
    }
    std::cout << fixture.name << " " << fixture_matched
              << "/18 exact raw paths\n";
  }
  std::cout << "TOTAL " << matched << "/" << total << " exact raw paths\n";
  return matched == total ? 0 : 5;
}
