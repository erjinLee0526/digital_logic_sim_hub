import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current editing tool/mode.
enum EditorTool {
  /// Click pins to connect them with wires.
  wiring,

  /// Click and drag chips to move them.
  dragging,

  /// Click chips or wires to delete them.
  deleting,
}

/// Currently selected editor tool.
final editorToolProvider = StateProvider<EditorTool>((ref) => EditorTool.wiring);

/// The currently selected pin ID (for wiring mode).
/// When non-null, the next pin click will create a wire.
final selectedPinProvider = StateProvider<String?>((ref) => null);

/// The currently selected chip ID.
final selectedChipProvider = StateProvider<String?>((ref) => null);

/// The currently selected wire ID.
final selectedWireProvider = StateProvider<String?>((ref) => null);

/// The current mouse/hover position in circuit coordinates.
final mouseCircuitPositionProvider = StateProvider<Offset?>((ref) => null);
