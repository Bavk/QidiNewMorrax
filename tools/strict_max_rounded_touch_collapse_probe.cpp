#include "clipper/clipper.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <random>
#include <set>
#include <sstream>
#include <string>
#include <vector>

using namespace ClipperLib;

static long long cross(const IntPoint &a, const IntPoint &b, const IntPoint &c) {
  return (long long)(b.x() - a.x()) * (c.y() - a.y()) -
         (long long)(b.y() - a.y()) * (c.x() - a.x());
}

static int orient(const IntPoint &a, const IntPoint &b, const IntPoint &c) {
  const long long v = cross(a, b, c);
  return (v > 0) - (v < 0);
}

static bool same(const IntPoint &a, const IntPoint &b) {
  return a.x() == b.x() && a.y() == b.y();
}

static bool on_segment(const IntPoint &a, const IntPoint &b, const IntPoint &p) {
  if (orient(a, b, p) != 0) return false;
  return std::min(a.x(), b.x()) <= p.x() && p.x() <= std::max(a.x(), b.x()) &&
         std::min(a.y(), b.y()) <= p.y() && p.y() <= std::max(a.y(), b.y());
}

static bool proper(const IntPoint &a, const IntPoint &b,
                   const IntPoint &c, const IntPoint &d) {
  const int ab_c = orient(a, b, c);
  const int ab_d = orient(a, b, d);
  const int cd_a = orient(c, d, a);
  const int cd_b = orient(c, d, b);
  return ab_c != 0 && ab_d != 0 && cd_a != 0 && cd_b != 0 &&
         ab_c != ab_d && cd_a != cd_b;
}

static long long area2(const Path &p) {
  long long result = 0;
  for (size_t i = 0; i < p.size(); ++i) {
    const IntPoint &a = p[i];
    const IntPoint &b = p[(i + 1) % p.size()];
    result += (long long)a.x() * b.y() - (long long)a.y() * b.x();
  }
  return result;
}

static bool strict_positive_triangle(const Path &p) {
  if (p.size() != 3 || area2(p) <= 0) return false;
  for (int i = 0; i < 3; ++i) {
    if (orient(p[(i + 2) % 3], p[i], p[(i + 1) % 3]) <= 0) return false;
  }
  return true;
}

static void make_positive(Path &p) {
  if (area2(p) < 0) std::swap(p[1], p[2]);
}

static bool strictly_inside(const Path &positive_triangle, const IntPoint &p) {
  for (int i = 0; i < 3; ++i) {
    if (orient(positive_triangle[i], positive_triangle[(i + 1) % 3], p) <= 0)
      return false;
  }
  return true;
}

static long long round_clipper(double v) {
  return v < 0 ? (long long)std::ceil(v - 0.5) : (long long)std::floor(v + 0.5);
}

struct Edge {
  IntPoint bot;
  IntPoint top;
  long long delta_x;
  double dx;
  bool horizontal;
};

static Edge edge_from(const IntPoint &a, const IntPoint &b) {
  Edge e;
  if (a.y() >= b.y()) {
    e.bot = a;
    e.top = b;
  } else {
    e.bot = b;
    e.top = a;
  }
  e.delta_x = e.top.x() - e.bot.x();
  const long long delta_y = e.top.y() - e.bot.y();
  e.horizontal = delta_y == 0;
  e.dx = e.horizontal ? -1.0e40 : (double)e.delta_x / (double)delta_y;
  return e;
}

static long long top_x(const Edge &e, long long y) {
  return y == e.top.y() ? e.top.x()
                        : e.bot.x() + round_clipper(e.dx * (double)(y - e.bot.y()));
}

static bool rounded_intersection(const IntPoint &a, const IntPoint &b,
                                 const IntPoint &c, const IntPoint &d,
                                 IntPoint &out) {
  const Edge first = edge_from(a, b);
  const Edge second = edge_from(c, d);
  long long x = 0;
  long long y = 0;
  if (first.horizontal) {
    y = first.bot.y();
    x = top_x(second, y);
  } else if (second.horizontal) {
    y = second.bot.y();
    x = top_x(first, y);
  } else if (first.dx == second.dx) {
    return false;
  } else if (first.delta_x == 0) {
    x = first.bot.x();
    const double intercept = second.bot.y() - second.bot.x() / second.dx;
    y = round_clipper(x / second.dx + intercept);
  } else if (second.delta_x == 0) {
    x = second.bot.x();
    const double intercept = first.bot.y() - first.bot.x() / first.dx;
    y = round_clipper(x / first.dx + intercept);
  } else {
    const double intercept_first = first.bot.x() - first.bot.y() * first.dx;
    const double intercept_second = second.bot.x() - second.bot.y() * second.dx;
    const double q = (intercept_second - intercept_first) / (first.dx - second.dx);
    y = round_clipper(q);
    x = std::fabs(first.dx) < std::fabs(second.dx)
            ? round_clipper(first.dx * q + intercept_first)
            : round_clipper(second.dx * q + intercept_second);
  }
  if (y < first.top.y() || y < second.top.y()) {
    y = first.top.y() > second.top.y() ? first.top.y() : second.top.y();
    x = std::fabs(first.dx) < std::fabs(second.dx) ? top_x(first, y) : top_x(second, y);
  }
  if (y > first.bot.y() || y > second.bot.y()) return false;
  out = IntPoint(x, y);
  return true;
}

static bool e2_insert_tie(const Edge &e1, const Edge &e2) {
  // Exact equality branch inside pinned E2InsertsBeforeE1() when Curr.x is tied.
  if (e2.top.y() > e1.top.y())
    return e2.top.x() == top_x(e1, e2.top.y());
  return e1.top.x() == top_x(e2, e1.top.y());
}

static std::string point_key(const IntPoint &p) {
  return std::to_string(p.x()) + "," + std::to_string(p.y());
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

static Path rotate_path(const Path &p, int start) {
  Path out;
  for (int i = 0; i < 3; ++i) out.push_back(p[(start + i) % 3]);
  return out;
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

static bool one_unique_touch_no_overlap(const Path &first, const Path &second,
                                        int &proper_count, IntPoint &touch) {
  proper_count = 0;
  std::set<std::string> touches;
  IntPoint one_touch;
  for (int i = 0; i < 3; ++i) {
    const IntPoint &a = first[i];
    const IntPoint &b = first[(i + 1) % 3];
    for (int j = 0; j < 3; ++j) {
      const IntPoint &c = second[j];
      const IntPoint &d = second[(j + 1) % 3];
      if (proper(a, b, c, d)) {
        ++proper_count;
        continue;
      }
      if (orient(a, b, c) == 0 && orient(a, b, d) == 0) {
        std::set<std::string> common;
        for (const IntPoint *p : {&a, &b, &c, &d}) {
          if (on_segment(a, b, *p) && on_segment(c, d, *p)) common.insert(point_key(*p));
        }
        if (common.size() >= 2) return false;
      }
      for (const IntPoint *p : {&c, &d}) {
        if (on_segment(a, b, *p)) {
          touches.insert(point_key(*p));
          one_touch = *p;
        }
      }
      for (const IntPoint *p : {&a, &b}) {
        if (on_segment(c, d, *p)) {
          touches.insert(point_key(*p));
          one_touch = *p;
        }
      }
    }
  }
  if (proper_count < 1 || touches.size() != 1) return false;
  touch = one_touch;
  return true;
}

static int strict_touch_edge(const Path &other, const IntPoint &touch) {
  for (int i = 0; i < 3; ++i) {
    const IntPoint &a = other[i];
    const IntPoint &b = other[(i + 1) % 3];
    if (!same(a, touch) && !same(b, touch) && on_segment(a, b, touch)) return i;
  }
  return -1;
}

static int touch_collapse_owner_edge(const Path &first, const Path &second,
                                     const IntPoint &touch) {
  int found = -1;
  for (int i = 0; i < 3; ++i) {
    const IntPoint &a = first[i];
    const IntPoint &b = first[(i + 1) % 3];
    for (int j = 0; j < 3; ++j) {
      const IntPoint &c = second[j];
      const IntPoint &d = second[(j + 1) % 3];
      if (!proper(a, b, c, d)) continue;
      IntPoint rounded;
      if (!rounded_intersection(a, b, c, d, rounded) || !same(rounded, touch)) continue;
      if (found != -1) return -2;
      found = i;
    }
  }
  return found;
}

static bool exact_all_variants(const Path &owner, const Path &other,
                               const Path &expected) {
  for (int ro = 0; ro < 3; ++ro) {
    for (int rt = 0; rt < 3; ++rt) {
      const Path a = rotate_path(owner, ro);
      const Path b = rotate_path(other, rt);
      for (int order = 0; order < 2; ++order) {
        Path result;
        if (!source_union(order == 0 ? a : b, order == 0 ? b : a, result)) return false;
        if (result != expected) return false;
      }
    }
  }
  return true;
}

int main() {
  std::mt19937_64 rng(0x6150608ULL);
  std::uniform_int_distribution<int> coord(-180, 180);
  std::uniform_int_distribution<int> neg_y(-180, -1);
  const IntPoint touch(0, 0);
  const int target = 5000;
  int tested = 0;
  int rejected_ael_tie = 0;
  int collapse_edge_0 = 0;
  int collapse_edge_2 = 0;
  long long attempts = 0;

  while (attempts < 220000000 && tested < target) {
    ++attempts;
    IntPoint p(coord(rng), neg_y(rng));
    IntPoint q(coord(rng), neg_y(rng));
    if (same(p, q) || cross(touch, p, q) == 0 || p.y() == q.y()) continue;
    Path owner{touch, p, q};
    make_positive(owner);
    if (!strict_positive_triangle(owner)) continue;

    int ex = coord(rng);
    int ey = coord(rng);
    if ((ex == 0 && ey == 0) || ey == 0) continue;
    IntPoint u(-ex, -ey);
    IntPoint v(ex, ey);
    IntPoint w(coord(rng), coord(rng));
    if (same(w, u) || same(w, v) || cross(u, v, w) == 0) continue;
    Path other{u, v, w};
    make_positive(other);
    if (!strict_positive_triangle(other)) continue;

    const long long owner_min_y = std::min(owner[1].y(), owner[2].y());
    if (w.y() <= owner_min_y) continue;
    if (u.y() == owner_min_y || v.y() == owner_min_y) continue;

    int proper_count = 0;
    IntPoint found_touch;
    if (!one_unique_touch_no_overlap(owner, other, proper_count, found_touch)) continue;
    if (!same(found_touch, touch) || proper_count != 1) continue;

    const int collapse_owner_edge = touch_collapse_owner_edge(owner, other, touch);
    if (collapse_owner_edge != 0 && collapse_owner_edge != 2) continue;

    int inside_count = 0;
    for (const IntPoint &point : other) {
      if (strictly_inside(owner, point)) ++inside_count;
    }
    if (inside_count != 2) continue;

    const int touch_edge = strict_touch_edge(other, touch);
    if (touch_edge < 0) continue;
    const Edge active_touch = edge_from(other[touch_edge], other[(touch_edge + 1) % 3]);
    const int other_owner_edge = collapse_owner_edge == 0 ? 2 : 0;
    const Edge noncollapsed_owner =
        edge_from(owner[other_owner_edge], owner[(other_owner_edge + 1) % 3]);
    if (e2_insert_tie(noncollapsed_owner, active_touch)) {
      ++rejected_ael_tie;
      continue;
    }

    // This exact subset follows the source local-minimum insertion order:
    // the rounded crossing collapses onto the strict-max touch, the opposite
    // owner bound does not hit the E2InsertsBeforeE1 integer TopX tie, and the
    // rounded-away sliver leaves the owner contour anchored at its predecessor.
    const Path expected = rotate_path(owner, 2);
    if (!exact_all_variants(owner, other, expected)) {
      Path actual;
      source_union(owner, other, actual);
      std::cerr << "COUNTER edge=" << collapse_owner_edge
                << " owner=" << path_string(owner)
                << " other=" << path_string(other)
                << " expected=" << path_string(expected)
                << " actual=" << path_string(actual) << "\n";
      return 3;
    }

    if (collapse_owner_edge == 0) ++collapse_edge_0;
    else ++collapse_edge_2;
    ++tested;

    if (tested <= 8) {
      std::cout << "CASE " << tested << " edge=" << collapse_owner_edge
                << " owner=" << path_string(owner)
                << " other=" << path_string(other)
                << " raw=" << path_string(expected) << "\n";
    }
  }

  std::cout << "tested_bases=" << tested
            << " exact_full_paths=" << (long long)tested * 18
            << " collapse_edges=" << collapse_edge_0 << "," << collapse_edge_2
            << " rejected_ael_tie=" << rejected_ael_tie
            << " attempts=" << attempts << "\n";
  return tested == target ? 0 : 2;
}
