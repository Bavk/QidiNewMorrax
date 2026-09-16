#define main random_probe_main
#include "late_strict_max_multicross_probe.cpp"
#undef main

int main() {
  std::mt19937_64 rng(0x51A0BEEFA55ULL);
  auto ri = [&](long long lo, long long hi) {
    std::uniform_int_distribution<long long> dist(lo, hi);
    return dist(rng);
  };

  const char *names[] = {"vertical", "positive", "negative"};
  long long grand_bases = 0, grand_total = 0, grand_matches = 0;

  for (int mode = 0; mode < 3; ++mode) {
    long long bases = 0, total = 0, matches = 0;
    std::map<int, long long> base_pc, total_pc, match_pc;
    int mismatch_printed = 0;

    for (long long attempt = 0; attempt < 6000000 && bases < 2000; ++attempt) {
      const long long tx = ri(-1000000, 1000000);
      const long long ty = ri(-400000, 1000000);
      const IntPoint touch(tx, ty);

      IntPoint a(tx + ri(-900000, 900000), ty - ri(50000, 1000000));
      IntPoint b(tx + ri(-900000, 900000), ty - ri(50000, 1000000));
      Path owner{touch, a, b};
      if (Area(owner) == 0) continue;
      if (Area(owner) < 0) std::swap(owner[1], owner[2]);

      long long vx, vy;
      if (mode == 0) {
        vx = 0;
        vy = ri(50000, 700000) * (ri(0, 1) ? 1 : -1);
      } else {
        const long long ax = ri(50000, 700000);
        const long long ay = ri(50000, 700000);
        const long long sign = ri(0, 1) ? 1 : -1;
        vx = ax;
        vy = mode == 1 ? sign * ay : -sign * ay;
        vx *= sign;
      }

      const long long k1 = ri(1, 4), k2 = ri(1, 4);
      IntPoint c(tx + k1 * vx, ty + k1 * vy);
      IntPoint d(tx - k2 * vx, ty - k2 * vy);
      const long long min_neighbor_y = std::min(owner[1].y(), owner[2].y());
      IntPoint third(tx + ri(-1100000, 1100000), ri(min_neighbor_y + 1, ty + 1000000));
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
            if (same(raw.front(), cand)) {
              ++matches;
              ++match_pc[pc];
            } else if (mismatch_printed < 20) {
              ++mismatch_printed;
              std::cout << "TARGET_MISMATCH mode=" << names[mode] << " pc=" << pc
                        << " owner=" << path_string(owner)
                        << " other=" << path_string(other)
                        << " raw=" << path_string(raw)
                        << " cand=" << key(cand) << "\n";
            }
          }
        }
      }
    }

    grand_bases += bases;
    grand_total += total;
    grand_matches += matches;
    std::cout << "TARGET_SUMMARY mode=" << names[mode]
              << " bases=" << bases << " total=" << total
              << " matches=" << matches << " mismatches=" << (total - matches);
    for (const auto &[pc, count] : total_pc)
      std::cout << " pc" << pc << "=" << count << "/" << match_pc[pc];
    std::cout << "\n";
    if (bases < 1500) return 2;
  }

  std::cout << "TARGET_GRAND bases=" << grand_bases << " total=" << grand_total
            << " matches=" << grand_matches
            << " mismatches=" << (grand_total - grand_matches) << "\n";
  return 0;
}
