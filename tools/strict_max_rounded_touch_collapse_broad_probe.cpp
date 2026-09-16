#define main narrow_probe_main
#include "strict_max_rounded_touch_collapse_probe.cpp"
#undef main

static IntPoint shifted(const IntPoint &origin, long long x, long long y) {
  return IntPoint(origin.x() + x, origin.y() + y);
}

int main() {
  std::mt19937_64 rng(0x6150608BULL);
  std::uniform_int_distribution<int> translate(-2000, 2000);
  std::uniform_int_distribution<int> coord(-220, 220);
  std::uniform_int_distribution<int> neg_y(-220, -1);
  std::uniform_int_distribution<int> multiplier(1, 7);
  std::uniform_int_distribution<int> scale_pick(0, 3);
  const long long scales[] = {1, 17, 1000, 100000};
  const int target = 5000;
  int tested = 0;
  int collapse_edge_0 = 0;
  int collapse_edge_2 = 0;
  int asymmetric_touch = 0;
  int translated = 0;
  long long attempts = 0;

  while (attempts < 450000000 && tested < target) {
    ++attempts;
    const long long scale = scales[scale_pick(rng)];
    const IntPoint touch(
        (long long)translate(rng) * 1000000LL,
        (long long)translate(rng) * 1000000LL);

    IntPoint p = shifted(touch, (long long)coord(rng) * scale,
                        (long long)neg_y(rng) * scale);
    IntPoint q = shifted(touch, (long long)coord(rng) * scale,
                        (long long)neg_y(rng) * scale);
    if (same(p, q) || cross(touch, p, q) == 0 || p.y() == q.y()) continue;
    Path owner{touch, p, q};
    make_positive(owner);
    if (!strict_positive_triangle(owner)) continue;

    int ex = coord(rng);
    int ey = coord(rng);
    if ((ex == 0 && ey == 0) || ey == 0) continue;
    const int before = multiplier(rng);
    int after = multiplier(rng);
    if (after == before) after = after == 7 ? 1 : after + 1;
    IntPoint u = shifted(touch,
        -(long long)ex * before * scale,
        -(long long)ey * before * scale);
    IntPoint v = shifted(touch,
        (long long)ex * after * scale,
        (long long)ey * after * scale);
    IntPoint w = shifted(touch, (long long)coord(rng) * scale,
                         (long long)coord(rng) * scale);
    if (same(w, u) || same(w, v) || cross(u, v, w) == 0) continue;
    Path other{u, v, w};
    make_positive(other);
    if (!strict_positive_triangle(other)) continue;

    const long long owner_min_y = std::min(owner[1].y(), owner[2].y());
    const int touch_edge = strict_touch_edge(other, touch);
    if (touch_edge < 0) continue;
    const IntPoint touch_start = other[touch_edge];
    const IntPoint touch_end = other[(touch_edge + 1) % 3];
    const IntPoint other_third = other[(touch_edge + 2) % 3];
    if (other_third.y() <= owner_min_y) continue;
    if (touch_start.y() == owner_min_y || touch_end.y() == owner_min_y) continue;

    int proper_count = 0;
    IntPoint found_touch;
    if (!one_unique_touch_no_overlap(owner, other, proper_count, found_touch)) continue;
    if (!same(found_touch, touch) || proper_count != 1) continue;

    const CollapsePair collapse = touch_collapse_pair(owner, other, touch);
    if (collapse.owner_edge < 0 || collapse.other_edge < 0) continue;

    int inside_count = 0;
    for (const IntPoint &point : other) {
      if (strictly_inside(owner, point)) ++inside_count;
    }
    if (inside_count != 2) continue;

    if (!owner_bounds_surround_active_other_edges(
            owner, other, touch, touch_edge, collapse)) continue;

    const Path expected = rotate_path(owner, 2);
    if (!exact_all_variants(owner, other, expected)) {
      Path actual;
      source_union(owner, other, actual);
      std::cerr << "COUNTER edge=" << collapse.owner_edge
                << " before=" << before << " after=" << after
                << " scale=" << scale
                << " owner=" << path_string(owner)
                << " other=" << path_string(other)
                << " expected=" << path_string(expected)
                << " actual=" << path_string(actual) << "\n";
      return 3;
    }

    if (collapse.owner_edge == 0) ++collapse_edge_0;
    else if (collapse.owner_edge == 2) ++collapse_edge_2;
    if (before != after) ++asymmetric_touch;
    if (touch.x() != 0 || touch.y() != 0) ++translated;
    ++tested;

    if (tested <= 8) {
      std::cout << "CASE " << tested << " edge=" << collapse.owner_edge
                << " fraction=" << before << ":" << after
                << " scale=" << scale
                << " owner=" << path_string(owner)
                << " other=" << path_string(other)
                << " raw=" << path_string(expected) << "\n";
    }
  }

  std::cout << "tested_bases=" << tested
            << " exact_full_paths=" << (long long)tested * 18
            << " collapse_edges=" << collapse_edge_0 << "," << collapse_edge_2
            << " asymmetric_touch=" << asymmetric_touch
            << " translated=" << translated
            << " attempts=" << attempts << "\n";
  return tested == target ? 0 : 2;
}
