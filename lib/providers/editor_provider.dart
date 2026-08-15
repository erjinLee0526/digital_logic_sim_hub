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

/// Visual style used for rendering chips on the canvas.
enum ChipStyle {
  /// Current utilitarian look.
  industrial,

  /// Refined glass look: soft shadows, whiter/gray body, hidden pins by
  /// default.
  refined,
}

/// Currently selected editor tool.
final editorToolProvider = StateProvider<EditorTool>((ref) => EditorTool.wiring);

/// Currently selected chip rendering style.
final chipStyleProvider =
    StateProvider<ChipStyle>((ref) => ChipStyle.industrial);

/// Whether the clickable pin dots are rendered on chips.
final showPinsProvider = StateProvider<bool>((ref) => true);

/// The currently selected pin ID (for wiring mode).
/// When non-null, the next pin click will create a wire.
final selectedPinProvider = StateProvider<String?>((ref) => null);

/// The currently selected chip ID.
final selectedChipProvider = StateProvider<String?>((ref) => null);

/// The currently selected wire ID.
final selectedWireProvider = StateProvider<String?>((ref) => null);

/// The current mouse/hover position in circuit coordinates.
final mouseCircuitPositionProvider = StateProvider<Offset?>((ref) => null);
