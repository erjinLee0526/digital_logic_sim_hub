import '../models/signal_state.dart';

/// A scheduled signal change at a specific pin at a specific time.
class SimulationEvent implements Comparable<SimulationEvent> {
  /// Time in picoseconds when this event occurs.
  final int timePs;

  /// The pin ID (format: "chipId_pinNumber") that will change.
  final String pinId;

  /// The new signal value for the pin.
  final SignalState newValue;

  /// Tie-breaker for events at the same time (lower = processed first).
  final int priority;

  const SimulationEvent({
    required this.timePs,
    required this.pinId,
    required this.newValue,
    this.priority = 0,
  });

  @override
  int compareTo(SimulationEvent other) {
    final cmp = timePs.compareTo(other.timePs);
    if (cmp != 0) return cmp;
    return priority.compareTo(other.priority);
  }

  @override
  String toString() =>
      'Event(t=${timePs}ps, pin=$pinId, val=${newValue.displayName})';
}
