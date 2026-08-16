import '../models/chip_definition.dart';
import 'io_input.dart';
import 'io_led.dart';
import 'ls74ls00.dart';
import 'ls74ls02.dart';
import 'ls74ls04.dart';
import 'ls74ls08.dart';
import 'ls74ls10.dart';
import 'ls74ls11.dart';
import 'ls74ls112.dart';
import 'ls74ls125.dart';
import 'ls74ls20.dart';
import 'ls74ls21.dart';
import 'ls74ls27.dart';
import 'ls74ls32.dart';
import 'ls74ls42.dart';
import 'ls74ls74.dart';
import 'ls74ls75.dart';
import 'ls74ls76.dart';
import 'ls74ls85.dart';
import 'ls74ls86.dart';
import 'ls74ls136.dart';
import 'ls74ls138.dart';
import 'ls74ls139.dart';
import 'ls74ls148.dart';
import 'ls74ls151.dart';
import 'ls74ls153.dart';
import 'ls74ls154.dart';
import 'ls74ls157.dart';
import 'ls74ls160.dart';
import 'ls74ls161.dart';
import 'ls74ls163.dart';
import 'ls74ls164.dart';
import 'ls74ls165.dart';
import 'ls74ls166.dart';
import 'ls74ls174.dart';
import 'ls74ls266.dart';
import 'ls74ls175.dart';
import 'ls74ls190.dart';
import 'ls74ls191.dart';
import 'ls74ls192.dart';
import 'ls74ls193.dart';
import 'ls74ls194.dart';
import 'ls74ls195.dart';
import 'ls74ls244.dart';
import 'ls74ls245.dart';
import 'ls74ls273.dart';
import 'ls74ls283.dart';
import 'ls74ls373.dart';
import 'ls74ls374.dart';
import 'ls74ls393.dart';
import 'ls74ls90.dart';
import 'ls74ls93.dart';
import 'ls74ls95.dart';

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
    '74LS10': () => Chip74LS10(),
    '74LS11': () => Chip74LS11(),
    '74LS112': () => Chip74LS112(),
    '74LS125': () => Chip74LS125(),
    '74LS20': () => Chip74LS20(),
    '74LS21': () => Chip74LS21(),
    '74LS27': () => Chip74LS27(),
    '74LS32': () => Chip74LS32(),
    '74LS42': () => Chip74LS42(),
    '74LS74': () => Chip74LS74(),
    '74LS75': () => Chip74LS75(),
    '74LS76': () => Chip74LS76(),
    '74LS85': () => Chip74LS85(),
    '74LS86': () => Chip74LS86(),
    '74LS136': () => Chip74LS136(),
    '74LS138': () => Chip74LS138(),
    '74LS139': () => Chip74LS139(),
    '74LS148': () => Chip74LS148(),
    '74LS151': () => Chip74LS151(),
    '74LS153': () => Chip74LS153(),
    '74LS154': () => Chip74LS154(),
    '74LS157': () => Chip74LS157(),
    '74LS160': () => Chip74LS160(),
    '74LS161': () => Chip74LS161(),
    '74LS163': () => Chip74LS163(),
    '74LS164': () => Chip74LS164(),
    '74LS165': () => Chip74LS165(),
    '74LS166': () => Chip74LS166(),
    '74LS174': () => Chip74LS174(),
    '74LS266': () => Chip74LS266(),
    '74LS175': () => Chip74LS175(),
    '74LS190': () => Chip74LS190(),
    '74LS191': () => Chip74LS191(),
    '74LS192': () => Chip74LS192(),
    '74LS193': () => Chip74LS193(),
    '74LS194': () => Chip74LS194(),
    '74LS195': () => Chip74LS195(),
    '74LS244': () => Chip74LS244(),
    '74LS245': () => Chip74LS245(),
    '74LS273': () => Chip74LS273(),
    '74LS283': () => Chip74LS283(),
    '74LS373': () => Chip74LS373(),
    '74LS374': () => Chip74LS374(),
    '74LS393': () => Chip74LS393(),
    '74LS90': () => Chip74LS90(),
    '74LS93': () => Chip74LS93(),
    '74LS95': () => Chip74LS95(),
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
