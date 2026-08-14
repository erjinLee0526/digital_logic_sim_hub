import 'package:collection/collection.dart';
import '../models/chip_instance.dart';
import '../models/circuit.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';
import '../models/wire.dart';
import '../chips/chip_factory.dart';
import 'simulation_event.dart';

/// Discrete-event simulation engine for digital logic circuits.
///
/// Principles:
/// - Events are signal changes at pins, scheduled at specific times.
/// - When an input pin changes, the owning chip's outputs are re-evaluated
///   and scheduled after the chip's propagation delay.
/// - Wires propagate signals instantly (or with a tiny delay).
/// - Multiple drivers on the same net → conflict → SignalState.unknown.
/// - High-Z outputs don't drive the net.
class SimulationEngine {
  final HeapPriorityQueue<SimulationEvent> _eventQueue =
      HeapPriorityQueue<SimulationEvent>();

  int _currentTimePs = 0;
  bool _running = false;

  // Internal state built from the circuit
  final Map<String, ChipInstance> _chips = {};
  final Map<String, Wire> _wires = {};
  final Map<String, List<String>> _pinToWireIds = {}; // pinId → wire IDs
  final Map<String, String> _pinToChipId = {}; // pinId → chipId

  int get currentTimePs => _currentTimePs;
  bool get isRunning => _running;
  bool get hasPendingEvents => _eventQueue.isNotEmpty;
  int get pendingEventCount => _eventQueue.length;

  /// Rebuilds internal lookup tables from a circuit snapshot.
  void rebuild(Circuit circuit) {
    _chips.clear();
    _wires.clear();
    _pinToWireIds.clear();
    _pinToChipId.clear();
    _eventQueue.clear();
    _currentTimePs = 0;

    for (final chip in circuit.chips) {
      _chips[chip.id] = chip;
      for (final pin in chip.pinStates.values) {
        final pid = chip.pinId(pin.number);
        _pinToChipId[pid] = chip.id;
      }
    }

    for (final wire in circuit.wires) {
      _wires[wire.id] = wire;
      _pinToWireIds.putIfAbsent(wire.pinIdA, () => []).add(wire.id);
      _pinToWireIds.putIfAbsent(wire.pinIdB, () => []).add(wire.id);
    }
  }

  /// Injects an input change from outside (e.g., user toggling a switch).
  void injectSignal(String pinId, SignalState newValue) {
    _eventQueue.add(SimulationEvent(
      timePs: _currentTimePs,
      pinId: pinId,
      newValue: newValue,
      priority: 0,
    ));
  }

  /// Processes a single event from the queue.
  /// Returns the list of pin IDs that changed (for UI repaint).
  List<String> step() {
    if (!_eventQueue.isNotEmpty) return [];
    final event = _eventQueue.removeFirst();
    _currentTimePs = event.timePs;
    return _applyEvent(event);
  }

  /// Runs until the event queue is empty or maxSteps is reached.
  /// Returns all pin IDs that changed.
  List<String> runUntilStable({int maxSteps = 10000}) {
    final changed = <String>{};
    int steps = 0;
    while (_eventQueue.isNotEmpty && steps < maxSteps) {
      changed.addAll(step());
      steps++;
    }
    return changed.toList();
  }

  /// Runs a single "epoch": processes all events at the current time.
  List<String> stepEpoch() {
    if (!_eventQueue.isNotEmpty) return [];
    final changed = <String>{};
    final currentTime = _eventQueue.first.timePs;

    while (_eventQueue.isNotEmpty && _eventQueue.first.timePs == currentTime) {
      changed.addAll(step());
    }
    return changed.toList();
  }

  List<String> _applyEvent(SimulationEvent event) {
    final changed = <String>[];

    // Parse pinId: "chipId_pinNumber"
    final parts = event.pinId.split('_');
    if (parts.length < 2) return changed;
    final chipId = parts.sublist(0, parts.length - 1).join('_');
    final pinNum = int.tryParse(parts.last);
    if (pinNum == null) return changed;

    final chip = _chips[chipId];
    if (chip == null) return changed;

    final pinState = chip.pinStates[pinNum];
    if (pinState == null) return changed;

    // No change → nothing to do
    if (pinState.value == event.newValue) return changed;

    // Apply the new value
    pinState.value = event.newValue;
    changed.add(event.pinId);

    // Propagate through wires
    _propagateThroughWires(event);

    // Re-evaluate the chip if this was an input pin
    if (pinState.direction == PinDirection.input) {
      _evaluateChip(chip, event.timePs, changed);
    }

    return changed;
  }

  void _propagateThroughWires(SimulationEvent event) {
    final wireIds = _pinToWireIds[event.pinId];
    if (wireIds == null) return;

    for (final wireId in wireIds) {
      final wire = _wires[wireId];
      if (wire == null) continue;

      final otherEnd = wire.otherEnd(event.pinId);
      if (otherEnd == null) continue;

      _eventQueue.add(SimulationEvent(
        timePs: event.timePs + wire.propagationDelayPs,
        pinId: otherEnd,
        newValue: event.newValue,
        priority: event.priority + 1,
      ));
    }
  }

  void _evaluateChip(ChipInstance chip, int baseTimePs, List<String> changed) {
    // Collect current input states
    final inputStates = <int, SignalState>{};
    for (final pin in chip.pinStates.values) {
      inputStates[pin.number] = pin.value;
    }

    // Evaluate
    final outputs = chip.definition.evaluate(
      inputStates,
      internalState: chip.internalState,
    );

    // Schedule output changes
    for (final entry in outputs.entries) {
      final outPinNum = entry.key;
      final newVal = entry.value;
      final currentPin = chip.pinStates[outPinNum];
      if (currentPin == null) continue;
      if (currentPin.value == newVal) continue;

      _eventQueue.add(SimulationEvent(
        timePs: baseTimePs + chip.definition.propagationDelayPs,
        pinId: chip.pinId(outPinNum),
        newValue: newVal,
        priority: 2,
      ));
    }
  }

  /// Resets all non-power, non-ground pins to unknown.
  void resetSignals() {
    _eventQueue.clear();
    _currentTimePs = 0;
    for (final chip in _chips.values) {
      chip.resetInternalState();
      for (final pin in chip.pinStates.values) {
        if (pin.direction == PinDirection.power) {
          pin.value = SignalState.high;
        } else if (pin.direction == PinDirection.ground) {
          pin.value = SignalState.low;
        } else {
          pin.value = SignalState.unknown;
        }
      }
    }
  }
}
