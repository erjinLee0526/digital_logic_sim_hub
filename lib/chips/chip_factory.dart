import '../models/chip_definition.dart';
import 'io_input.dart';
import 'io_led.dart';
import 'ls74ls00.dart';
import 'ls74ls02.dart';
import 'ls74ls04.dart';
import 'ls74ls08.dart';
import 'ls74ls32.dart';
import 'ls74ls74.dart';
import 'ls74ls86.dart';
import 'ls74ls136.dart';
import 'ls74ls266.dart';
import 'ls74ls175.dart';
import 'ls74ls273.dart';
import 'ls74ls373.dart';

/// Registry of all available chip types.
/// To add a new 74LS chip:
///   1. Create a class extending ChipDefinition
///   2. Add it to the _registry map below
///   3. Add it to the _all list below
class ChipFactory {
  static final Map<String, ChipDefinition Function()> _registry = {
    '74LS00': () => Chip74LS00(),
    '74LS02': () => Chip74LS02(),
    '74LS04': () => Chip74LS04(),
    '74LS08': () => Chip74LS08(),
    '74LS32': () => Chip74LS32(),
    '74LS74': () => Chip74LS74(),
    '74LS86': () => Chip74LS86(),
    '74LS136': () => Chip74LS136(),
    '74LS266': () => Chip74LS266(),
    '74LS175': () => Chip74LS175(),
    '74LS273': () => Chip74LS273(),
    '74LS373': () => Chip74LS373(),
    'INPUT': () => ChipInput(),
    'LED': () => ChipLED(),
  };

  /// All available chip type definitions.
  static List<ChipDefinition> get allDefinitions =>
      _registry.values.map((f) => f()).toList();

  /// All available chip model numbers.
  static List<String> get allModels => _registry.keys.toList();

  /// Creates a new chip definition instance by model number.
  static ChipDefinition create(String model) {
    final factory = _registry[model];
    if (factory == null) {
      throw ArgumentError('Unknown chip model: $model');
    }
    return factory();
  }

  /// Checks if a chip model is supported.
  static bool supports(String model) => _registry.containsKey(model);
}
