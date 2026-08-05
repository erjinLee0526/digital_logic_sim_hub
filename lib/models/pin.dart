import 'signal_state.dart';

/// Direction / role of a pin on a chip.
enum PinDirection {
  input,
  output,
  power,
  ground,
}

/// Immutable definition of a pin on a chip type (template).
class PinDefinition {
  final int number; // 1–14 for 74LS DIP packages
  final String label; // e.g. "1A", "1Y", "VCC", "GND"
  final PinDirection direction;

  const PinDefinition({
    required this.number,
    required this.label,
    required this.direction,
  });
}

/// Runtime state of a specific pin on a specific chip instance.
class PinState {
  final int number;
  final String label;
  final PinDirection direction;
  SignalState value;

  PinState({
    required this.number,
    required this.label,
    required this.direction,
    this.value = SignalState.unknown,
  });

  /// Whether this pin can be connected by the user.
  bool get isConnectable =>
      direction == PinDirection.input || direction == PinDirection.output;

  PinState copyWith({SignalState? value}) {
    return PinState(
      number: number,
      label: label,
      direction: direction,
      value: value ?? this.value,
    );
  }
}
