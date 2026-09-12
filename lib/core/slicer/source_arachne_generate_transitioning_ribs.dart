import 'source_arachne_beading_strategy.dart';
import 'source_arachne_skeletal_apply_transitions.dart';
import 'source_arachne_skeletal_graph.dart';
import 'source_arachne_skeletal_transition_ends.dart';
import 'source_arachne_skeletal_transition_filters.dart';
import 'source_arachne_skeletal_transition_mids.dart';

/// Direct composition of pinned
/// `SkeletalTrapezoidation::generateTransitioningRibs()`.
extension SourceArachneGenerateTransitioningRibs2
    on SourceArachneSkeletalTrapezoidationGraph2 {
  void generateTransitioningRibs(
    SourceArachneBeadingStrategy2 beadingStrategy, {
    required int transitionFilterDistance,
    required int allowedFilterDeviation,
    required int snapDistance,
  }) {
    generateTransitionMids(beadingStrategy);
    filterTransitionMids(
      beadingStrategy,
      transitionFilterDistance: transitionFilterDistance,
      allowedFilterDeviation: allowedFilterDeviation,
    );
    final edgeTransitionEnds = generateAllTransitionEnds(beadingStrategy);
    applyTransitions(edgeTransitionEnds, snapDistance: snapDistance);
  }
}
