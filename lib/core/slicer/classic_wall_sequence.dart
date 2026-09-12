import 'extrusion_entity.dart';

enum SourceWallSequence2 {
  innerOuter,
  outerInner,
  innerOuterInner,
}

/// Literal classic `process_classic()` wall-order adjustment after
/// `traverse_loops()`.
class SourceClassicWallSequence2 {
  const SourceClassicWallSequence2._();

  static void adjust(
    ExtrusionEntityCollection2 entities, {
    required SourceWallSequence2 wallSequence,
    required int layerId,
    required bool brimOuterOnly,
    required double brimWidth,
  }) {
    final isOuterWallFirst = wallSequence == SourceWallSequence2.outerInner;
    if (isOuterWallFirst ||
        (layerId == 0 && brimOuterOnly && brimWidth > 0)) {
      // Source `ExtrusionEntityCollection::reverse()` reverses entity order and
      // reverses only non-loop children, preserving loop winding.
      entities.reverse();
      return;
    }

    if (wallSequence != SourceWallSequence2.innerOuterInner ||
        entities.entities.length <= 1) {
      return;
    }

    final reordered = <ExtrusionEntity2>[];
    final secondWall = <ExtrusionEntity2>[];
    for (final entity in entities.entities) {
      // The C++ source uses static_cast<ExtrusionLoop*> here. Its classic
      // caller expects structural wall loops for this sequence branch.
      if (entity is! ExtrusionLoop2) {
        throw StateError(
          'InnerOuterInner source branch expects ExtrusionLoop entities',
        );
      }

      if ((entity.loopRole & ExtrusionLoopRoles.secondPerimeter) != 0) {
        secondWall.add(entity);
      } else {
        reordered.add(entity);
        if (entity.role == ExtrusionRole.externalPerimeter &&
            secondWall.isNotEmpty) {
          reordered.addAll(secondWall);
          secondWall.clear();
        }
      }
    }

    // Preserve source behavior exactly: there is intentionally no append of
    // any trailing `secondWall` entries after the scan.
    entities.entities
      ..clear()
      ..addAll(reordered);
  }
}
