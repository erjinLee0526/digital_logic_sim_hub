import 'dart:ui';
import 'chip_instance.dart';
import 'pin.dart';
import 'signal_state.dart';
import 'wire.dart';

/// The complete circuit state: all chips and wires on the canvas.
class Circuit {
  final String name;
  final List<ChipInstance> chips;
  final List<Wire> wires;

  const Circuit({
    this.name = 'Untitled',
    this.chips = const [],
    this.wires = const [],
  });

  /// Builds a lookup map: pinId → absolute canvas position.
  Map<String, Offset> get allPinPositions {
    final map = <String, Offset>{};
    for (final chip in chips) {
      final positions = chip.pinAbsolutePositions;
      for (final entry in positions.entries) {
        map[chip.pinId(entry.key)] = entry.value;
      }
    }
    return map;
  }

  /// Finds a chip by its ID.
  ChipInstance? chipById(String id) {
    try {
      return chips.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Finds all wires connected to a specific pin.
  List<Wire> wiresForPin(String pinId) {
    return wires.where((w) => w.connectsTo(pinId)).toList();
  }

  /// Finds all wires connected to a specific chip (any pin).
  List<Wire> wiresForChip(String chipId) {
    return wires.where((w) {
      return w.pinIdA.startsWith('${chipId}_') ||
          w.pinIdB.startsWith('${chipId}_');
    }).toList();
  }

  Circuit copyWith({
    String? name,
    List<ChipInstance>? chips,
    List<Wire>? wires,
  }) {
    return Circuit(
      name: name ?? this.name,
      chips: chips ?? List<ChipInstance>.from(this.chips),
      wires: wires ?? List<Wire>.from(this.wires),
    );
  }

  Circuit addChip(ChipInstance chip) {
    return copyWith(chips: [...chips, chip]);
  }

  Circuit removeChip(String chipId) {
    return copyWith(
      chips: chips.where((c) => c.id != chipId).toList(),
      wires: wires
          .where((w) =>
              !w.pinIdA.startsWith('${chipId}_') &&
              !w.pinIdB.startsWith('${chipId}_'))
          .toList(),
    );
  }

  Circuit addWire(Wire wire) {
    return copyWith(wires: [...wires, wire]);
  }

  Circuit removeWire(String wireId) {
    return copyWith(wires: wires.where((w) => w.id != wireId).toList());
  }

  Circuit moveChip(String chipId, Offset newPosition) {
    return copyWith(
      chips: chips.map((c) {
        if (c.id == chipId) {
          return c.copyWith(position: newPosition);
        }
        return c;
      }).toList(),
    );
  }

  Circuit updatePinState(String chipId, int pinNumber, SignalState value) {
    return copyWith(
      chips: chips.map((c) {
        if (c.id == chipId) {
          final newStates = Map<int, PinState>.from(c.pinStates);
          newStates[pinNumber] =
              (newStates[pinNumber] ?? c.pinStates[pinNumber]!)
                  .copyWith(value: value);
          return c.copyWith(pinStates: newStates);
        }
        return c;
      }).toList(),
    );
  }
}
