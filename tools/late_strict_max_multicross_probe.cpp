#include "clipper/clipper.hpp"

#include <algorithm>
#include <cstdint>
#include <iostream>
#include <map>
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
  out << "]";
  return out.str();
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
  if (!(other[2].y() > std::min(owner[1].y(), owner[2].y()))) return false;

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

static IntPoint rebase_candidate(const Path &raw) {
  auto min_y = raw.front().y();
  for (const auto &p : raw) min_y = std::min(min_y, p.y());
  size_t anchor = raw.size();
  for (size_t i = 0; i < raw.size(); ++i) {
    if (raw[i].y() != min_y) continue;
    if (anchor == raw.size() || raw[i].x() > raw[anchor].x()) anchor = i;
  }
  return raw[(anchor + 1) % raw.size()];
}

static std::string classify_start(const IntPoint &p, const Path &owner, const Path &other) {
  if (same(p, owner[0])) return "touch";
  if (same(p, owner[1])) return "owner_next";
  if (same(p, owner[2])) return "owner_prev";
  if (same(p, other[0])) return "edge_0";
  if (same(p, other[1])) return "edge_1";
  if (same(p, other[2])) return "other_third";
  return "intersection";
}

int main() {
  Path fixed_owner{IntPoint(-606000, 279000), IntPoint(-905000, 166000), IntPoint(-354000, 79000)};
  Path fixed_other{IntPoint(-856000, 79000), IntPoint(-406000, 439000), IntPoint(-870000, 163000)};
  int fixed_pc = 0;
  std::cout << "FIXED_STATE ok=" << state_ok(fixed_owner, fixed_other, fixed_pc)
            << " pc=" << fixed_pc << " owner=" << path_string(fixed_owner)
            << " other=" << path_string(fixed_other) << "\n";
  for (int ro = 0; ro < 3; ++ro) {
    for (int rt = 0; rt < 3; ++rt) {
      for (int swap = 0; swap < 2; ++swap) {
        Path o = rotate_path(fixed_owner, ro), t = rotate_path(fixed_other, rt), raw;
        bool ok = swap ? run_union(t, o, raw) : run_union(o, t, raw);
        std::cout << "FIXED ro=" << ro << " rt=" << rt << " swap=" << swap << " ok=" << ok;
        if (ok) {
          const auto candidate = rebase_candidate(raw);
          std::cout << " raw=" << path_string(raw)
                    << " candidate=" << key(candidate)
                    << " match=" << same(raw.front(), candidate)
                    << " class=" << classify_start(raw.front(), fixed_owner, fixed_other);
        }
        std::cout << "\n";
      }
    }
  }

  std::mt19937_64 rng(0xBADC0FFEE1234ULL);
  auto ri = [&](long long lo, long long hi) {
    std::uniform_int_distribution<long long> dist(lo, hi);
    return dist(rng);
  };

  long long bases = 0, total = 0, candidate_matches = 0;
  std::map<int, long long> base_pc, total_pc, match_pc;
  std::map<std::string, long long> start_class;
  long long min1 = 0, min2adj = 0, min2sep = 0, min3plus = 0;
  int mismatch_printed = 0;
  int match_printed = 0;

  for (long long attempt = 0; attempt < 5000000 && bases < 6000; ++attempt) {
    const long long tx = ri(-900000, 900000);
    const long long ty = ri(-300000, 900000);
    const IntPoint touch(tx, ty);

    IntPoint a(tx + ri(-800000, 800000), ty - ri(50000, 900000));
    IntPoint b(tx + ri(-800000, 800000), ty - ri(50000, 900000));
    Path owner{touch, a, b};
    if (Area(owner) == 0) continue;
    if (Area(owner) < 0) std::swap(owner[1], owner[2]);

    long long vx = ri(-600000, 600000);
    long long vy = ri(-600000, 600000);
    if (vx == 0 || vy == 0) continue;
    const long long k1 = ri(1, 4), k2 = ri(1, 4);
    IntPoint c(tx + k1 * vx, ty + k1 * vy);
    IntPoint d(tx - k2 * vx, ty - k2 * vy);
    const long long min_neighbor_y = std::min(owner[1].y(), owner[2].y());
    IntPoint third(tx + ri(-1000000, 1000000), ri(min_neighbor_y + 1, ty + 900000));
    Path other{c, d, third};
    if (Area(other) == 0) continue;
    if (Area(other) < 0) std::swap(other[0], other[1]);

    int pc = 0;
    if (!state_ok(owner, other, pc)) continue;
    ++bases;
    ++base_pc[pc];

    for (int ro = 0; ro < 3; ++ro) {
      for (int rt = 0; rt < 3; ++rt) {
        for (int swap = 0; swap < 2; ++swap) {
          Path o = rotate_path(owner, ro), t = rotate_path(other, rt), raw;
          if (!(swap ? run_union(t, o, raw) : run_union(o, t, raw))) continue;
          ++total;
          ++total_pc[pc];
          const IntPoint cand = rebase_candidate(raw);
          const bool match = same(raw.front(), cand);
          if (match) {
            ++candidate_matches;
            ++match_pc[pc];
          }
          ++start_class[classify_start(raw.front(), owner, other)];

          auto min_y = raw.front().y();
          for (const auto &p : raw) min_y = std::min(min_y, p.y());
          std::vector<int> minima;
          for (int i = 0; i < (int)raw.size(); ++i) if (raw[i].y() == min_y) minima.push_back(i);
          if (minima.size() == 1) ++min1;
          else if (minima.size() == 2) {
            bool adj = (minima[0] + 1) % raw.size() == (size_t)minima[1] ||
                       (minima[1] + 1) % raw.size() == (size_t)minima[0];
            if (adj) ++min2adj; else ++min2sep;
          } else ++min3plus;

          if (!match && mismatch_printed < 40) {
            ++mismatch_printed;
            std::cout << "MISMATCH pc=" << pc << " swap=" << swap
                      << " owner=" << path_string(owner)
                      << " other=" << path_string(other)
                      << " raw=" << path_string(raw)
                      << " cand=" << key(cand)
                      << " start_class=" << classify_start(raw.front(), owner, other)
                      << " owner_min_neighbor_y=" << min_neighbor_y
                      << " third_y=" << other[2].y() << "\n";
          } else if (match && match_printed < 8) {
            ++match_printed;
            std::cout << "MATCH_SAMPLE pc=" << pc
                      << " owner=" << path_string(owner)
                      << " other=" << path_string(other)
                      << " raw=" << path_string(raw) << "\n";
          }
        }
      }
    }
  }

  std::cout << "SUMMARY bases=" << bases << " total=" << total
            << " candidate_matches=" << candidate_matches
            << " mismatches=" << (total - candidate_matches)
            << " min1=" << min1 << " min2adj=" << min2adj
            << " min2sep=" << min2sep << " min3plus=" << min3plus << "\n";
  std::cout << "BASE_PC";
  for (const auto &[pc, count] : base_pc) std::cout << " pc" << pc << "=" << count;
  std::cout << "\nTOTAL_PC";
  for (const auto &[pc, count] : total_pc)
    std::cout << " pc" << pc << "=" << count << "/" << match_pc[pc];
  std::cout << "\nSTART_CLASS";
  for (const auto &[name, count] : start_class) std::cout << " " << name << "=" << count;
  std::cout << "\n";

  return bases < 1000 ? 2 : 0;
}
