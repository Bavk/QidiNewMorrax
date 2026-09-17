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
      "retained_fixed",
      Path{IntPoint(0,0), IntPoint(162,-141), IntPoint(164,-8)},
      Path{IntPoint(-20,17), IntPoint(20,-17), IntPoint(70,-58)});
  run_case(
      "retained_owner_only_counter",
      Path{IntPoint(0,0), IntPoint(217,-158), IntPoint(63,-17)},
      Path{IntPoint(-25,18), IntPoint(25,-18), IntPoint(71,-51)});
  return 0;
}
