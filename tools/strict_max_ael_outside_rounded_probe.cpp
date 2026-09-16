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
  Path expected;
};

int main() {
  const std::vector<Fixture> fixtures = {
      {
          "retained_all_vertices",
          {{9, -82}, {122, 60}, {-18, 77}},
          {{-10, 67}, {6, 3}, {-34, 73}},
          {{6, 3}, {-34, 73}, {-13, 69}, {-18, 77}, {9, -82}, {122, 60}, {0, 75}, {-10, 67}},
      },
      {
          "widened_wedge",
          {{-120, -220}, {80, 80}, {210, -220}},
          {{240, -160}, {-65, -99}, {-67, -101}},
          {{-67, -101}, {-65, -99}, {-66, -100}, {-31, -86}, {-120, -220}, {210, -220}, {95, -28}, {80, 80}},
      },
      {
          "retained_nearby_vertex",
          {{-120, -220}, {80, 80}, {210, -220}},
          {{220, -107}, {-70, -46}, {-66, -47}},
          {{-66, -47}, {-70, -46}, {-69, -46}, {-26, -79}, {-120, -220}, {210, -220}, {195, -186}, {80, 80}},
      },
  };

  int matched = 0;
  int total = 0;
  for (const Fixture &fixture : fixtures) {
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
            return 2;
          }
          if (actual != fixture.expected) {
            std::cerr << "MISMATCH " << fixture.name << " ro=" << ro
                      << " rt=" << rt << " order=" << order
                      << " expected=" << path_string(fixture.expected)
                      << " actual=" << path_string(actual) << "\n";
            return 3;
          }
          ++matched;
          ++fixture_matched;
        }
      }
    }
    std::cout << fixture.name << " " << fixture_matched << "/18 exact raw paths\n";
  }
  std::cout << "TOTAL " << matched << "/" << total << " exact raw paths\n";
  return matched == total ? 0 : 4;
}
