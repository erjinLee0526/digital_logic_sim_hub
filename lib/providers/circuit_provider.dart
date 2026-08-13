import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/chip_instance.dart';
import '../models/circuit_grid.dart';
import '../models/circuit.dart';
import '../models/signal_state.dart';
import '../models/wire.dart';
import '../chips/chip_factory.dart';

const _uuid = Uuid();

/// Notifier managing all circuit mutations.
class CircuitNotifier extends StateNotifier<Circuit> {
  CircuitNotifier() : super(const Circuit());

  // ---- Chip operations ----

  /// Adds a chip of the given model at the specified position.
  /// Returns the new chip's ID.
  String addChip(String model, Offset position) {
    final def = ChipFactory.create(model);
    final id = 'ic${_uuid.v4().substring(0, 8)}';
    final chip = ChipInstance(
      id: id,
      definition: def,
      position: snapOffsetToGrid(position),
    );
    state = state.addChip(chip);
    return id;
  }

  /// Removes a chip and all its connected wires.
  void removeChip(String chipId) {
    state = state.removeChip(chipId);
  }

  /// Moves a chip to a new position.
  void moveChip(String chipId, Offset newPosition) {
    state = state.moveChip(chipId, snapOffsetToGrid(newPosition));
  }

  // ---- Wire operations ----

  /// Adds a wire between two pins.
  /// Returns the new wire's ID, or null if invalid.
  String? addWire(String pinIdA, String pinIdB) {
    if (pinIdA == pinIdB) return null;

    // Check if already connected
    for (final w in state.wires) {
      if (w.connectsTo(pinIdA) && w.connectsTo(pinIdB)) return null;
    }

    final id = 'w${_uuid.v4().substring(0, 8)}';
    state = state.addWire(Wire(id: id, pinIdA: pinIdA, pinIdB: pinIdB));
    return id;
  }

  /// Removes a wire by ID.
  void removeWire(String wireId) {
    state = state.removeWire(wireId);
  }

  /// Removes all wires connected to a specific pin.
  void removeWiresForPin(String pinId) {
    var s = state;
    for (final w in s.wiresForPin(pinId)) {
      s = s.removeWire(w.id);
    }
    state = s;
  }

  /// Updates a pin's signal state.
  void updatePinState(String chipId, int pinNumber, SignalState value) {
    state = state.updatePinState(chipId, pinNumber, value);
  }

  // ---- Circuit-level operations ----

  /// Creates a new blank circuit.
  void newCircuit() {
    state = const Circuit();
  }

  /// Replaces the entire circuit state (for loading).
  void loadCircuit(Circuit circuit) {
    final snappedChips = circuit.chips
        .map((chip) => chip.copyWith(position: snapOffsetToGrid(chip.position)))
        .toList();
    state = circuit.copyWith(chips: snappedChips);
  }

  /// Triggers a state notification without changing circuit data.
  /// Use after the simulation engine mutates pin states in-place,
  /// so the UI repaints with updated signal values.
  void forceUpdate() {
    state = state.copyWith();
  }
}

/// The main circuit state provider.
final circuitProvider =
    StateNotifierProvider<CircuitNotifier, Circuit>((ref) {
  return CircuitNotifier();
});
