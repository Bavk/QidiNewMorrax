#include "clipper/clipper.hpp"

#include <iostream>

using namespace ClipperLib;

static void print_path(const char *label, const Path &path) {
  std::cout << label << "=[";
  for (size_t i = 0; i < path.size(); ++i) {
    if (i) std::cout << ",";
    std::cout << "(" << path[i].x() << "," << path[i].y() << ")";
  }
  std::cout << "]\n";
}

static void run_case(const char *name, const Path &owner, const Path &other) {
  std::cerr << "===== " << name << " =====\n";
  Clipper clipper;
  clipper.AddPath(owner, ptSubject, true);
  clipper.AddPath(other, ptSubject, true);
  Paths solution;
  clipper.Execute(ctUnion, solution, pftNonZero, pftNonZero);
  std::cout << name << " count=" << solution.size() << "\n";
  if (!solution.empty()) print_path(name, solution[0]);
}

int main() {
  run_case(
      "owner_only",
      Path{IntPoint(0, 0), IntPoint(-129, -164), IntPoint(149, -16)},
      Path{IntPoint(-21, 56), IntPoint(21, -56), IntPoint(28, -74)});
  run_case(
      "retained_vertex",
      Path{IntPoint(0, 0), IntPoint(162, -141), IntPoint(164, -8)},
      Path{IntPoint(-20, 17), IntPoint(20, -17), IntPoint(70, -58)});
  run_case(
      "retained_wedge",
      Path{IntPoint(0, 0), IntPoint(-142, -178), IntPoint(27, -173)},
      Path{IntPoint(-125, -167), IntPoint(125, 167), IntPoint(-6, -8)});
  return 0;
}
