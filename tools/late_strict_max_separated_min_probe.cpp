#include "clipper/clipper.hpp"

#include <algorithm>
#include <cstdint>
#include <iostream>
#include <random>
#include <set>
#include <string>
#include <vector>

using namespace ClipperLib;

static long long cross(const IntPoint &a, const IntPoint &b, const IntPoint &c) {
  return (long long)(b.x() - a.x()) * (c.y() - a.y()) -
         (long long)(b.y() - a.y()) * (c.x() - a.x());
}

static bool same(const IntPoint &a, const IntPoint &b) {
  return a.x() == b.x() && a.y() == b.y();
}

static bool on_segment(const IntPoint &a, const IntPoint &b, const IntPoint &p) {
  if (cross(a, b, p) != 0) return false;
  return std::min(a.x(), b.x()) <= p.x() && p.x() <= std::max(a.x(), b.x()) &&
         std::min(a.y(), b.y()) <= p.y() && p.y() <= std::max(a.y(), b.y());
}

static bool proper(const IntPoint &a, const IntPoint &b, const IntPoint &c, const IntPoint &d) {
  const long long o1 = cross(a, b, c);
  const long long o2 = cross(a, b, d);
  const long long o3 = cross(c, d, a);
  const long long o4 = cross(c, d, b);
  return ((o1 > 0 && o2 < 0) || (o1 < 0 && o2 > 0)) &&
         ((o3 > 0 && o4 < 0) || (o3 < 0 && o4 > 0));
}

static std::string key(const IntPoint &p) {
  return std::to_string(p.x()) + "," + std::to_string(p.y());
}

static Path rotate_path(const Path &path, int start) {
  Path out;
  for (size_t i = 0; i < path.size(); ++i) out.push_back(path[(start + (int)i) % path.size()]);
  return out;
}

static bool run_union(const Path &first, const Path &second, Path &raw) {
  Clipper clipper;
  if (!clipper.AddPath(first, ptSubject, true)) return false;
  if (!clipper.AddPath(second, ptSubject, true)) return false;
  Paths solution;
  if (!clipper.Execute(ctUnion, solution, pftNonZero, pftNonZero)) return false;
  if (solution.size() != 1) return false;
  raw = solution.front();
  return raw.size() >= 3;
}

static IntPoint candidate(const Path &raw) {
  long long min_y = raw.front().y();
  for (const auto &p : raw) min_y = std::min(min_y, p.y());
  size_t anchor = raw.size();
  for (size_t i = 0; i < raw.size(); ++i) {
    if (raw[i].y() != min_y) continue;
    if (anchor == raw.size() || raw[i].x() > raw[anchor].x()) anchor = i;
  }
  return raw[(anchor + 1) % raw.size()];
}

static bool exactly_two_separated_minima(const Path &raw) {
  long long min_y = raw.front().y();
  for (const auto &p : raw) min_y = std::min(min_y, p.y());
  std::vector<int> ids;
  for (int i = 0; i < (int)raw.size(); ++i) if (raw[i].y() == min_y) ids.push_back(i);
  if (ids.size() != 2) return false;
  return (ids[0] + 1) % raw.size() != (size_t)ids[1] &&
         (ids[1] + 1) % raw.size() != (size_t)ids[0];
}

static bool state_ok(const Path &owner, const Path &other, int &proper_count) {
  if (owner.size() != 3 || other.size() != 3 || Area(owner) <= 0 || Area(other) <= 0) return false;
  const IntPoint touch = owner[0];
  if (!(owner[1].y() < touch.y() && owner[2].y() < touch.y())) return false;

  int edge = -1;
  for (int i = 0; i < 3; ++i) {
    const IntPoint a = other[i], b = other[(i + 1) % 3];
    if (!same(touch, a) && !same(touch, b) && on_segment(a, b, touch)) {
      if (edge >= 0) return false;
      edge = i;
    }
  }
  if (edge < 0) return false;
  const IntPoint es = other[edge], ee = other[(edge + 1) % 3];
  if (es.y() == ee.y()) return false;
  const IntPoint third = other[(edge + 2) % 3];
  const long long min_neighbor_y = std::min(owner[1].y(), owner[2].y());
  if (!(third.y() > min_neighbor_y)) return false;
  if (!(es.y() == min_neighbor_y || ee.y() == min_neighbor_y)) return false;

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
  return proper_count >= 2 && touches.size() == 1 && *touches.begin() == key(touch);
}

int main() {
  std::mt19937_64 rng(0x5E9A12B00DULL);
  auto ri = [&](long long lo, long long hi) {
    std::uniform_int_distribution<long long> dist(lo, hi);
    return dist(rng);
  };

  const char *names[] = {"vertical", "positive", "negative"};
  long long grand_bases = 0, grand_total = 0, grand_matches = 0;

  for (int mode = 0; mode < 3; ++mode) {
    long long bases = 0, total = 0, matches = 0, full_same = 0;
    long long pc2 = 0, pc3 = 0, pc4 = 0;
    for (long long attempt = 0; attempt < 12000000 && bases < 1200; ++attempt) {
      const long long tx = ri(-900000, 900000);
      const long long ty = ri(100000, 1000000);
      const IntPoint touch(tx, ty);

      const long long y1 = ty - ri(80000, 850000);
      const long long y2 = ty - ri(80000, 850000);
      IntPoint a(tx + ri(-850000, 850000), y1);
      IntPoint b(tx + ri(-850000, 850000), y2);
      Path owner{touch, a, b};
      if (Area(owner) == 0) continue;
      if (Area(owner) < 0) std::swap(owner[1], owner[2]);
      const long long min_y = std::min(owner[1].y(), owner[2].y());
      const long long dy = ty - min_y;
      if (dy <= 0) continue;

      long long cx = tx;
      if (mode == 1) cx = tx - ri(50000, 750000);
      if (mode == 2) cx = tx + ri(50000, 750000);
      const IntPoint c(cx, min_y);
      const long long factor = ri(1, 3);
      const IntPoint d(tx + factor * (tx - cx), ty + factor * dy);
      const IntPoint third(tx + ri(-950000, 950000), ri(min_y + 1, ty + 850000));
      Path other{c, d, third};
      if (Area(other) == 0) continue;
      if (Area(other) < 0) std::swap(other[0], other[1]);

      int pc = 0;
      if (!state_ok(owner, other, pc)) continue;
      Path base_raw;
      if (!run_union(owner, other, base_raw)) continue;
      if (!exactly_two_separated_minima(base_raw)) continue;
      ++bases;
      if (pc == 2) ++pc2; else if (pc == 3) ++pc3; else if (pc == 4) ++pc4;

      for (int ro = 0; ro < 3; ++ro) {
        for (int rt = 0; rt < 3; ++rt) {
          for (int swap = 0; swap < 2; ++swap) {
            Path o = rotate_path(owner, ro), t = rotate_path(other, rt), raw;
            const bool ok = swap ? run_union(t, o, raw) : run_union(o, t, raw);
            if (!ok) continue;
            ++total;
            if (same(raw.front(), candidate(raw))) ++matches;
            if (raw == base_raw) ++full_same;
          }
        }
      }
    }

    std::cout << "BOUNDARY mode=" << names[mode]
              << " bases=" << bases
              << " total=" << total
              << " start_matches=" << matches
              << " full_same=" << full_same
              << " pc2=" << pc2 << " pc3=" << pc3 << " pc4=" << pc4 << "\n";
    if (bases < 800 || total != bases * 18 || matches != total || full_same != total) return 2;
    grand_bases += bases;
    grand_total += total;
    grand_matches += matches;
  }

  std::cout << "BOUNDARY_GRAND bases=" << grand_bases
            << " total=" << grand_total
            << " start_matches=" << grand_matches << "\n";
  return 0;
}
