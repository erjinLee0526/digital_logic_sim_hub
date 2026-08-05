/// Four-state logic used throughout the simulator.
/// Models real digital signals: driven values, high-impedance, and unknown.
enum SignalState {
  /// Logic 0 (low voltage, driven)
  low,

  /// Logic 1 (high voltage, driven)
  high,

  /// High-impedance (tri-state output disabled, effectively disconnected)
  highZ,

  /// Unknown state (uninitialized, conflict, or invalid input)
  unknown;

  /// Whether this state represents a driven logic level.
  bool get isDriven => this == low || this == high;

  /// Converts to a boolean, treating high as true.
  /// Returns null for highZ or unknown.
  bool? toBoolOrNull() {
    switch (this) {
      case low:
        return false;
      case high:
        return true;
      default:
        return null;
    }
  }

  /// Creates a SignalState from a boolean.
  factory SignalState.fromBool(bool value) => value ? high : low;

  /// Returns a short display string.
  String get displayName {
    switch (this) {
      case low:
        return '0';
      case high:
        return '1';
      case highZ:
        return 'Z';
      case unknown:
        return 'X';
    }
  }

  /// logical NOT
  SignalState not() {
    switch (this) {
      case low:
        return high;
      case high:
        return low;
      default:
        return unknown;
    }
  }

  /// NAND gate: NOT (A AND B)
  static SignalState nand(SignalState a, SignalState b) {
    // 0 NAND anything = 1
    if (a == low || b == low) return high;
    // 1 NAND 1 = 0
    if (a == high && b == high) return low;
    // highZ on either input → unknown
    if (a == highZ || b == highZ) return unknown;
    // remaining cases involve unknown → unknown
    return unknown;
  }

  /// AND gate
  static SignalState and(SignalState a, SignalState b) {
    return nand(a, b).not();
  }

  /// NOR gate: NOT (A OR B)
  static SignalState nor(SignalState a, SignalState b) {
    // 1 NOR anything = 0
    if (a == high || b == high) return low;
    // 0 NOR 0 = 1
    if (a == low && b == low) return high;
    // highZ on either input → unknown
    if (a == highZ || b == highZ) return unknown;
    return unknown;
  }

  /// OR gate
  static SignalState or(SignalState a, SignalState b) {
    return nor(a, b).not();
  }

  /// XOR gate
  static SignalState xor(SignalState a, SignalState b) {
    if (!a.isDriven || !b.isDriven) return unknown;
    return SignalState.fromBool(a != b);
  }

  /// NOT (inverter)
  static SignalState invert(SignalState a) {
    return a.not();
  }
}
