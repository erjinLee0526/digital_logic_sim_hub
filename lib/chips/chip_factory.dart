import '../models/chip_definition.dart';
import 'io_input.dart';
import 'io_led.dart';
import 'ls74ls00.dart';

/// Registry of all available chip types.
/// To add a new 74LS chip:
///   1. Create a class extending ChipDefinition
///   2. Add it to the _registry map below
///   3. Add it to the _all list below
class ChipFactory {
  static final Map<String, ChipDefinition Function()> _registry = {
    '74LS00': () => Chip74LS00(),
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
