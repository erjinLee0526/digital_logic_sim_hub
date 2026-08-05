import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import '../models/chip_instance.dart';
import '../models/circuit.dart';
import '../models/wire.dart';
import '../chips/chip_factory.dart';

/// Service for saving and loading circuit files as JSON.
class FileService {
  static Future<String> get _directory async {
    final dir = await getApplicationDocumentsDirectory();
    final circuitDir = Directory('${dir.path}/circuits');
    if (!await circuitDir.exists()) {
      await circuitDir.create(recursive: true);
    }
    return circuitDir.path;
  }

  /// Serializes a circuit to a JSON string.
  static String toJson(Circuit circuit) {
    final map = <String, dynamic>{
      'version': '1.0',
      'name': circuit.name,
      'chips': circuit.chips.map(_chipToMap).toList(),
      'wires': circuit.wires.map(_wireToMap).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Deserializes a circuit from a JSON string.
  static Circuit fromJson(String jsonString) {
    final map = json.decode(jsonString) as Map<String, dynamic>;
    final name = map['name'] as String? ?? 'Untitled';

    final chips = (map['chips'] as List<dynamic>?)?.map((c) {
          final cm = c as Map<String, dynamic>;
          final def = ChipFactory.create(cm['model'] as String);
          return ChipInstance(
            id: cm['id'] as String,
            definition: def,
            position: Offset(
              (cm['x'] as num).toDouble(),
              (cm['y'] as num).toDouble(),
            ),
          );
        }).toList() ??
        [];

    final wires = (map['wires'] as List<dynamic>?)?.map((w) {
          final wm = w as Map<String, dynamic>;
          return Wire(
            id: wm['id'] as String,
            pinIdA: wm['pinIdA'] as String,
            pinIdB: wm['pinIdB'] as String,
          );
        }).toList() ??
        [];

    return Circuit(name: name, chips: chips, wires: wires);
  }

  static Map<String, dynamic> _chipToMap(ChipInstance chip) {
    return {
      'id': chip.id,
      'model': chip.definition.model,
      'x': chip.position.dx,
      'y': chip.position.dy,
    };
  }

  static Map<String, dynamic> _wireToMap(Wire wire) {
    return {
      'id': wire.id,
      'pinIdA': wire.pinIdA,
      'pinIdB': wire.pinIdB,
    };
  }

  /// Saves a circuit to a file.
  static Future<void> save(Circuit circuit, String filename) async {
    final path = '${await _directory}/$filename.json';
    final file = File(path);
    await file.writeAsString(toJson(circuit));
  }

  /// Loads a circuit from a file.
  static Future<Circuit> load(String filename) async {
    final path = '${await _directory}/$filename.json';
    final file = File(path);
    final jsonString = await file.readAsString();
    return fromJson(jsonString);
  }

  /// Lists all saved circuit files.
  static Future<List<String>> listSavedCircuits() async {
    final dir = Directory(await _directory);
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.path.split('/').last.replaceAll('.json', ''))
        .toList();
    return files;
  }

  /// Deletes a saved circuit file.
  static Future<void> delete(String filename) async {
    final path = '${await _directory}/$filename.json';
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
