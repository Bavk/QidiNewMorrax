#include "clipper/clipper.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <random>
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
static long long extended_gcd(long long a, long long b,
                              long long &x, long long &y) {
  if (b == 0) {
    x = a >= 0 ? 1 : -1;
    y = 0;
    return std::llabs(a);
  }
  long long x1 = 0, y1 = 0;
  const long long g = extended_gcd(b, a % b, x1, y1);
  x = y1;
  y = x1 - (a / b) * y1;
  return g;
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
static void make_positive(Path &p) {
  if (area2(p) < 0) std::swap(p[1], p[2]);
}
static bool strict_positive_triangle(const Path &p) {
  if (p.size() != 3 || area2(p) <= 0) return false;
  for (int i = 0; i < 3; ++i)
    if (orient(p[i], p[(i + 1) % 3], p[(i + 2) % 3]) <= 0) return false;
  return true;
}
static bool strictly_inside(const Path &triangle, const IntPoint &p) {
  for (int i = 0; i < 3; ++i)
    if (orient(triangle[i], triangle[(i + 1) % 3], p) <= 0) return false;
  return true;
}
static bool proper(const IntPoint &a, const IntPoint &b,
                   const IntPoint &c, const IntPoint &d) {
  const int ab_c = orient(a, b, c), ab_d = orient(a, b, d);
  const int cd_a = orient(c, d, a), cd_b = orient(c, d, b);
  return ab_c != 0 && ab_d != 0 && cd_a != 0 && cd_b != 0 &&
         ab_c != ab_d && cd_a != cd_b;
}
static long long clipper_round(double v) {
  return v < 0 ? (long long)std::ceil(v - 0.5) : (long long)std::floor(v + 0.5);
}
struct Edge {
  IntPoint bot, top;
  long long delta_x;
  double dx;
  bool horizontal;
};
static Edge edge_from(const IntPoint &a, const IntPoint &b) {
  Edge e;
  if (a.y() >= b.y()) { e.bot = a; e.top = b; }
  else { e.bot = b; e.top = a; }
  e.delta_x = e.top.x() - e.bot.x();
  const long long dy = e.top.y() - e.bot.y();
  e.horizontal = dy == 0;
  e.dx = e.horizontal ? -1.0e40 : (double)e.delta_x / (double)dy;
  return e;
}
static long long top_x(const Edge &e, long long y) {
  return y == e.top.y() ? e.top.x()
      : e.bot.x() + clipper_round(e.dx * (double)(y - e.bot.y()));
}
static bool e2_before(const Edge &first, const Edge &second, long long y) {
  const long long first_x = top_x(first, y), second_x = top_x(second, y);
  if (second_x == first_x) {
    if (second.top.y() > first.top.y())
      return second.top.x() < top_x(first, second.top.y());
    return first.top.x() > top_x(second, first.top.y());
  }
  return second_x < first_x;
}
static bool rounded_intersection(const IntPoint &a, const IntPoint &b,
                                 const IntPoint &c, const IntPoint &d,
                                 IntPoint &out) {
  const Edge first = edge_from(a, b), second = edge_from(c, d);
  long long x = 0, y = 0;
  if (first.horizontal) { y = first.bot.y(); x = top_x(second, y); }
  else if (second.horizontal) { y = second.bot.y(); x = top_x(first, y); }
  else if (first.dx == second.dx) return false;
  else if (first.delta_x == 0) {
    x = first.bot.x();
    const double intercept = second.bot.y() - second.bot.x() / second.dx;
    y = clipper_round(x / second.dx + intercept);
  } else if (second.delta_x == 0) {
    x = second.bot.x();
    const double intercept = first.bot.y() - first.bot.x() / first.dx;
    y = clipper_round(x / first.dx + intercept);
  } else {
    const double i1 = first.bot.x() - first.bot.y() * first.dx;
    const double i2 = second.bot.x() - second.bot.y() * second.dx;
    const double q = (i2 - i1) / (first.dx - second.dx);
    y = clipper_round(q);
    x = std::fabs(first.dx) < std::fabs(second.dx)
        ? clipper_round(first.dx * q + i1)
        : clipper_round(second.dx * q + i2);
  }
  if (y < first.top.y() || y < second.top.y()) {
    y = std::max(first.top.y(), second.top.y());
    x = std::fabs(first.dx) < std::fabs(second.dx) ? top_x(first, y) : top_x(second, y);
  }
  if (y > first.bot.y() || y > second.bot.y()) return false;
  out = IntPoint(x, y);
  return true;
}
static std::string path_string(const Path &p) {
  std::ostringstream out; out << "[";
  for (size_t i = 0; i < p.size(); ++i) {
    if (i) out << ",";
    out << "(" << p[i].x() << "," << p[i].y() << ")";
  }
  out << "]"; return out.str();
}
static Path rotate3(const Path &p, int start) {
  return {p[start], p[(start + 1) % 3], p[(start + 2) % 3]};
}
static bool source_union(const Path &a, const Path &b, Path &out) {
  Clipper clipper;
  if (!clipper.AddPath(a, ptSubject, true) || !clipper.AddPath(b, ptSubject, true)) return false;
  Paths solution;
  if (!clipper.Execute(ctUnion, solution, pftNonZero, pftNonZero) || solution.size() != 1) return false;
  out = solution[0]; return true;
}
static Path rebase_rightmost_min_successor(const Path &cycle) {
  long long min_y = cycle[0].y();
  for (const auto &p : cycle) min_y = std::min(min_y, (long long)p.y());
  int anchor = -1;
  for (int i = 0; i < (int)cycle.size(); ++i) {
    if (cycle[i].y() != min_y) continue;
    if (anchor < 0 || cycle[i].x() > cycle[anchor].x()) anchor = i;
  }
  Path out;
  out.reserve(cycle.size());
  const int start = (anchor + 1) % cycle.size();
  for (int i = 0; i < (int)cycle.size(); ++i)
    out.push_back(cycle[(start + i) % cycle.size()]);
  return out;
}

static bool exact_all_variants(const Path &owner, const Path &other, const Path &expected) {
  for (int ro = 0; ro < 3; ++ro) for (int rt = 0; rt < 3; ++rt) {
    const Path a = rotate3(owner, ro), b = rotate3(other, rt);
    for (int order = 0; order < 2; ++order) {
      Path actual;
      if (!source_union(order ? b : a, order ? a : b, actual) || actual != expected) return false;
    }
  }
  return true;
}
static int strict_touch_edge(const Path &other, const IntPoint &touch) {
  for (int i = 0; i < 3; ++i) {
    const IntPoint &a = other[i], &b = other[(i + 1) % 3];
    if (orient(a, b, touch) == 0 &&
        std::min(a.x(), b.x()) < touch.x() && touch.x() < std::max(a.x(), b.x()) &&
        std::min(a.y(), b.y()) < touch.y() && touch.y() < std::max(a.y(), b.y())) return i;
  }
  return -1;
}


int main() {
  const Path fixed_owner{
    IntPoint(0,0), IntPoint(217,-158), IntPoint(63,-17)
  };
  const Path fixed_other{
    IntPoint(-25,18), IntPoint(25,-18), IntPoint(71,-51)
  };
  const Path fixed_expected{
    IntPoint(63,-17), IntPoint(0,0), IntPoint(217,-158)
  };
  if (!exact_all_variants(fixed_owner, fixed_other, fixed_expected)) {
    Path actual;
    source_union(fixed_owner, fixed_other, actual);
    std::cerr << "FIXED_MISMATCH actual=" << path_string(actual) << "\n";
    return 2;
  }
  std::cout << "early_touch_owner_only 18/18 exact raw paths\n";

  std::mt19937_64 rng(0xEA8170C4ULL);
  std::uniform_int_distribution<int> coord(-220, 220), neg_y(-220, -1);
  const IntPoint touch(0, 0);
  const int target = 1200;
  int accepted = 0;
  long long attempts = 0;
  while (attempts++ < 240000000LL && accepted < target) {
    // Generate the traced source-event shape directly: the outgoing owner
    // bound stays active far below touch while the positive-order predecessor
    // is the first shallow scanbeam. The classifier below remains unchanged.
    const IntPoint p(
        std::uniform_int_distribution<int>(80, 240)(rng),
        -std::uniform_int_distribution<int>(80, 220)(rng));
    const IntPoint q(
        std::uniform_int_distribution<int>(20, 180)(rng),
        -std::uniform_int_distribution<int>(5, 45)(rng));
    if (cross(touch,p,q) <= 0 || p.y()==q.y()) continue;
    Path owner{touch,p,q};
    if (!strict_positive_triangle(owner)) continue;

    // The rounded-to-touch family is numerically skinny. Construct a
    // primitive touch-line vector and a nearby third point with determinant
    // 1..4 so an independent proper crossing can round onto touch.
    int ex = std::uniform_int_distribution<int>(8, 90)(rng);
    int ey = -std::uniform_int_distribution<int>(8, 90)(rng);
    long long bezout_x = 0, bezout_y = 0;
    if (extended_gcd(ex, ey, bezout_x, bezout_y) != 1) continue;
    const int before = std::uniform_int_distribution<int>(1, 3)(rng);
    const int after = std::uniform_int_distribution<int>(1, 3)(rng);
    const int determinant = std::uniform_int_distribution<int>(1, 4)(rng);
    const int along = after + std::uniform_int_distribution<int>(1, 4)(rng);
    const long long wx0 = -bezout_y * determinant;
    const long long wy0 = bezout_x * determinant;
    const IntPoint third((long long)along * ex + wx0,
                         (long long)along * ey + wy0);
    Path other{
      IntPoint(-(long long)before * ex, -(long long)before * ey),
      IntPoint((long long)after * ex, (long long)after * ey),
      third,
    };
    if (same(other[2],other[0]) || same(other[2],other[1]) ||
        cross(other[0],other[1],other[2])==0) continue;
    make_positive(other);
    if (!strict_positive_triangle(other)) continue;

    const int touch_edge = strict_touch_edge(other, touch);
    if (touch_edge < 0) continue;

    int proper_count = 0, owner_edge = -1, crossing_edge = -1;
    bool rounded_to_touch = false;
    for (int i=0;i<3;++i) for (int j=0;j<3;++j) {
      if (!proper(owner[i],owner[(i+1)%3],
                  other[j],other[(j+1)%3])) continue;
      ++proper_count;
      IntPoint rounded;
      if (rounded_intersection(owner[i],owner[(i+1)%3],
                               other[j],other[(j+1)%3],rounded) &&
          same(rounded,touch)) {
        rounded_to_touch = true;
        owner_edge = i;
        crossing_edge = j;
      }
    }
    if (proper_count != 1 || !rounded_to_touch ||
        crossing_edge == touch_edge) continue;
    if (owner_edge != 0 && owner_edge != 2) continue;

    const long long min_owner_y = std::min(owner[1].y(), owner[2].y());
    const IntPoint other_third = other[(touch_edge + 2) % 3];
    if (other_third.y() <= min_owner_y) continue;
    if (other[touch_edge].y() == min_owner_y ||
        other[(touch_edge+1)%3].y() == min_owner_y) continue;
    int inside_count = 0;
    for (const auto &point : other)
      if (strictly_inside(owner, point)) ++inside_count;
    if (inside_count != 2) continue;

    const Edge outgoing = edge_from(touch, owner[1]);
    const Edge incoming = edge_from(owner[2], touch);
    const Edge left = outgoing.dx > incoming.dx ? outgoing : incoming;
    const Edge right = outgoing.dx > incoming.dx ? incoming : outgoing;
    const Edge touched = edge_from(
        other[touch_edge], other[(touch_edge+1)%3]);
    const Edge crossing = edge_from(
        other[crossing_edge], other[(crossing_edge+1)%3]);
    auto position = [&](const Edge &e) {
      if (!(e.top.y() < 0 && e.bot.y() > 0) || top_x(e,0) != 0) return -1;
      const bool before_left = e2_before(e,left,0);
      const bool before_right = e2_before(e,right,0);
      if (!before_left && !before_right) return 0;
      if (before_left && !before_right) return 1;
      if (before_left && before_right) return 2;
      return -1;
    };
    const int touched_position = position(touched);
    const int crossing_position = position(crossing);
    const IntPoint touch_end = other[(touch_edge+1)%3];
    const bool touch_end_inside = strictly_inside(owner, touch_end);

    if (!(touched_position == 0 &&
          crossing_position == 1 &&
          touch_end_inside &&
          touch_end.y() < owner[2].y() &&
          other_third.y() < touch_end.y() &&
          top_x(touched, owner[2].y()) >
              top_x(outgoing, owner[2].y()))) {
      continue;
    }

    const Path expected{owner[2], touch, owner[1]};
    if (!exact_all_variants(owner, other, expected)) {
      Path actual;
      source_union(owner,other,actual);
      std::cerr << "COUNTER"
                << " owner=" << path_string(owner)
                << " other=" << path_string(other)
                << " prev_y=" << owner[2].y()
                << " touched_topx=" << top_x(touched,owner[2].y())
                << " outgoing_topx=" << top_x(outgoing,owner[2].y())
                << " expected=" << path_string(expected)
                << " actual=" << path_string(actual) << "\n";
      return 3;
    }
    ++accepted;
  }

  std::cout << "generated early_touch=" << accepted << "/" << target
            << " bases attempts=" << attempts << "\n";
  std::cout << "generated raw paths=" << accepted*18 << "/"
            << target*18 << " exact\n";
  return accepted == target ? 0 : 4;
}
