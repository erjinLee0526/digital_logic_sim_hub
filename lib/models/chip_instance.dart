import 'dart:ui';
import 'chip_definition.dart';
import 'pin.dart';
import 'signal_state.dart';

/// A concrete chip placed on the circuit canvas.
class ChipInstance {
  final String id;
  final ChipDefinition definition;
  Offset position; // center position in circuit coordinates
  final Map<int, PinState> pinStates; // pin number → state
  final Map<String, SignalState> internalState;

  ChipInstance({
    required this.id,
    required this.definition,
    required this.position,
    Map<int, PinState>? pinStates,
    Map<String, SignalState>? internalState,
  })  : pinStates = pinStates ?? _createPinStates(definition),
        internalState = internalState ?? _createInternalState(definition);

  static Map<int, PinState> _createPinStates(ChipDefinition def) {
    final map = <int, PinState>{};
    for (final pin in def.pinDefinitions) {
      map[pin.number] = PinState(
        number: pin.number,
        label: pin.label,
        direction: pin.direction,
        value: _initialValue(pin.direction),
      );
    }
    return map;
  }

  static SignalState _initialValue(PinDirection dir) {
    switch (dir) {
      case PinDirection.power:
        return SignalState.high;
      case PinDirection.ground:
        return SignalState.low;
      default:
        return SignalState.unknown;
    }
  }

  static Map<String, SignalState> _createInternalState(ChipDefinition def) {
    return Map<String, SignalState>.of(def.initialState);
  }

  /// Restores the chip's internal state to its definition defaults.
  void resetInternalState() {
    internalState
      ..clear()
      ..addAll(definition.initialState);
  }

  /// The bounding rectangle of the chip in circuit coordinates.
  Rect get rect => Rect.fromCenter(
        center: position,
        width: definition.width,
        height: definition.height,
      );

  /// Absolute position of each pin on the canvas.
  Map<int, Offset> get pinAbsolutePositions {
    final map = <int, Offset>{};
    final relatives = definition.pinRelativePositions;
    for (final entry in relatives.entries) {
      map[entry.key] = position + entry.value;
    }
    return map;
  }

  /// Absolute position of a specific pin.
  Offset pinPosition(int pinNumber) {
    final rel = definition.pinRelativePositions[pinNumber];
    if (rel == null) return position;
    return position + rel;
  }

  /// Returns a unique string ID for a pin (used for wire endpoints).
  String pinId(int pinNumber) => '${id}_$pinNumber';

  ChipInstance copyWith({
    Offset? position,
    Map<int, PinState>? pinStates,
    Map<String, SignalState>? internalState,
  }) {
    return ChipInstance(
      id: id,
      definition: definition,
      position: position ?? this.position,
      pinStates: pinStates ?? this.pinStates,
      internalState: internalState ?? this.internalState,
    );
  }
}
