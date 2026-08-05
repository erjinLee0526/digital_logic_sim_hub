import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/simulation_engine.dart';

/// The singleton simulation engine instance.
/// Call rebuild(circuit) before running simulation to sync with latest circuit state.
final simulationEngineProvider = Provider<SimulationEngine>((ref) {
  return SimulationEngine();
});

/// Whether the simulation is currently running.
final simulationRunningProvider = StateProvider<bool>((ref) => false);

/// Number of steps per "run" tick.
final simulationSpeedProvider = StateProvider<int>((ref) => 1);
