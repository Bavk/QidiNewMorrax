#include "clipper/clipper.hpp"
#include <algorithm>
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

static bool on_segment(const IntPoint &a, const IntPoint &b, const IntPoint &p) {
  return cross(a, b, p) == 0 &&
         std::min(a.x(), b.x()) <= p.x() && p.x() <= std::max(a.x(), b.x()) &&
         std::min(a.y(), b.y()) <= p.y() && p.y() <= std::max(a.y(), b.y());
}

static bool proper(const IntPoint &a, const IntPoint &b, const IntPoint &c, const IntPoint &d) {
  const long long o1 = cross(a, b, c), o2 = cross(a, b, d);
  const long long o3 = cross(c, d, a), o4 = cross(c, d, b);
  return ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
         ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0));
}

static bool same(const IntPoint &a, const IntPoint &b) {
  return a.x() == b.x() && a.y() == b.y();
}

static std::string key(const IntPoint &p) {
  return std::to_string(p.x()) + "," + std::to_string(p.y());
}

static std::string path_string(const Path &path) {
  std::ostringstream out;
  out << "[";
  for (size_t i = 0; i < path.size(); ++i) {
    if (i) out << ",";
    out << "(" << path[i].x() << "," << path[i].y() << ")";
  }
  return out.str() + "]";
}

static Path rotate_path(const Path &path, int start) {
  Path out;
  for (size_t i = 0; i < path.size(); ++i)
    out.push_back(path[(start + (int)i) % path.size()]);
  return out;
}

static bool state_ok(const Path &owner, const Path &other, int &proper_count) {
  if (owner.size() != 3 || other.size() != 3 || Area(owner) <= 0 || Area(other) <= 0)
    return false;
  const IntPoint touch = owner[0];
  if (!(owner[1].y() < touch.y() && owner[2].y() < touch.y())) return false;
  if (other[0].y() == other[1].y()) return false;
  if (!on_segment(other[0], other[1], touch) || same(touch, other[0]) || same(touch, other[1]))
    return false;
  if (other[2].y() != std::min(owner[1].y(), owner[2].y())) return false;

  std::set<std::string> touches;
  proper_count = 0;
  for (int i = 0; i < 3; ++i) {
    const IntPoint a = owner[i], b = owner[(i + 1) % 3];
    for (int j = 0; j < 3; ++j) {
      const IntPoint c = other[j], d = other[(j + 1) % 3];
      if (proper(a, b, c, d)) {
        ++proper_count;
        continue;
      }
      if (cross(a, b, c) == 0 && cross(a, b, d) == 0) {
        std::set<std::string> common;
        for (const auto &p : std::vector<IntPoint>{a, b, c, d})
          if (on_segment(a, b, p) && on_segment(c, d, p)) common.insert(key(p));
        if (common.size() >= 2) return false;
      }
      if (on_segment(a, b, c)) touches.insert(key(c));
      if (on_segment(a, b, d)) touches.insert(key(d));
      if (on_segment(c, d, a)) touches.insert(key(a));
      if (on_segment(c, d, b)) touches.insert(key(b));
    }
  }
  return proper_count >= 1 && touches.size() == 1 && *touches.begin() == key(touch);
}

static bool run_union(const Path &first, const Path &second, Path &raw) {
  Clipper clipper;
  if (!clipper.AddPath(first, ptSubject, true) || !clipper.AddPath(second, ptSubject, true))
    return false;
  Paths solution;
  if (!clipper.Execute(ctUnion, solution, pftNonZero, pftNonZero) || solution.size() != 1)
    return false;
  raw = solution.front();
  return raw.size() >= 3;
}

static IntPoint proper_rebase_start(const Path &raw) {
  auto min_y = raw.front().y();
  for (const auto &p : raw) min_y = std::min(min_y, p.y());
  size_t anchor = raw.size();
  for (size_t i = 0; i < raw.size(); ++i) {
    if (raw[i].y() == min_y && (anchor == raw.size() || raw[i].x() > raw[anchor].x())) anchor = i;
  }
  return raw[(anchor + 1) % raw.size()];
}

int main() {
  Path fixed_owner{IntPoint(-126000, 102000), IntPoint(-455000, -127000), IntPoint(65000, -185000)};
  Path fixed_other{IntPoint(24000, 312000), IntPoint(-176000, 32000), IntPoint(91000, -185000)};
  for (int ro = 0; ro < 3; ++ro) for (int rt = 0; rt < 3; ++rt) for (int swap = 0; swap < 2; ++swap) {
    Path o = rotate_path(fixed_owner, ro), t = rotate_path(fixed_other, rt), raw;
    bool ok = swap ? run_union(t, o, raw) : run_union(o, t, raw);
    std::cout << "FIXED ro=" << ro << " rt=" << rt << " swap=" << swap << " ok=" << ok;
    if (ok) std::cout << " raw=" << path_string(raw) << " proper_start=" << key(proper_rebase_start(raw));
    std::cout << "\n";
  }

  std::mt19937_64 rng(0x5eedE9ULL);
  auto ri = [&](long long lo, long long hi) {
    std::uniform_int_distribution<long long> dist(lo, hi);
    return dist(rng);
  };

  long long bases = 0, total = 0, proper_matches = 0, one_cross = 0, multi_cross = 0;
  long long first_touch = 0, first_owner1 = 0, first_owner2 = 0, first_third = 0;
  int mismatch_printed = 0;
  for (long long attempt = 0; attempt < 3000000 && bases < 3000; ++attempt) {
    const long long tx = ri(-900000, 900000), ty = ri(-300000, 900000);
    const IntPoint touch(tx, ty);
    Path owner{touch,
      IntPoint(tx + ri(-700000, 700000), ty - ri(60000, 800000)),
      IntPoint(tx + ri(-700000, 700000), ty - ri(60000, 800000))};
    if (Area(owner) == 0) continue;
    if (Area(owner) < 0) std::swap(owner[1], owner[2]);

    long long vx = ri(-500000, 500000), vy = ri(-500000, 500000);
    if (vx == 0 || vy == 0) continue;
    const long long k1 = ri(1, 4), k2 = ri(1, 4);
    Path other{IntPoint(tx + k1 * vx, ty + k1 * vy),
               IntPoint(tx - k2 * vx, ty - k2 * vy),
               IntPoint(tx + ri(-900000, 900000), std::min(owner[1].y(), owner[2].y()))};
    if (Area(other) == 0) continue;
    if (Area(other) < 0) std::swap(other[0], other[1]);

    int pc = 0;
    if (!state_ok(owner, other, pc)) continue;
    ++bases;
    if (pc == 1) ++one_cross; else ++multi_cross;

    for (int ro = 0; ro < 3; ++ro) for (int rt = 0; rt < 3; ++rt) for (int swap = 0; swap < 2; ++swap) {
      Path o = rotate_path(owner, ro), t = rotate_path(other, rt), raw;
      if (!(swap ? run_union(t, o, raw) : run_union(o, t, raw))) continue;
      ++total;
      const IntPoint candidate = proper_rebase_start(raw);
      if (same(raw.front(), candidate)) ++proper_matches;
      if (same(raw.front(), touch)) ++first_touch;
      if (same(raw.front(), owner[1])) ++first_owner1;
      if (same(raw.front(), owner[2])) ++first_owner2;
      if (same(raw.front(), other[2])) ++first_third;
      if (!same(raw.front(), candidate) && mismatch_printed < 12) {
        ++mismatch_printed;
        std::cout << "MISMATCH pc=" << pc << " swap=" << swap
                  << " owner=" << path_string(owner) << " other=" << path_string(other)
                  << " raw=" << path_string(raw) << " proper_start=" << key(candidate) << "\n";
      }
    }
  }
  std::cout << "SUMMARY bases=" << bases << " total=" << total
            << " one_cross_bases=" << one_cross << " multi_cross_bases=" << multi_cross
            << " proper_matches=" << proper_matches
            << " first_touch=" << first_touch << " first_owner1=" << first_owner1
            << " first_owner2=" << first_owner2 << " first_third=" << first_third << "\n";
  return bases < 1000 ? 2 : 0;
}
