import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chips/chip_factory.dart';
import '../models/chip_definition.dart';
import '../providers/circuit_provider.dart';
import '../theme/dark_theme.dart';

/// Side panel for searching and adding chips to the canvas.
class ChipLibraryPanel extends ConsumerStatefulWidget {
  const ChipLibraryPanel({super.key});

  @override
  ConsumerState<ChipLibraryPanel> createState() => _ChipLibraryPanelState();
}

class _ChipLibraryPanelState extends ConsumerState<ChipLibraryPanel> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ChipDefinition> get _filteredChips {
    final all = ChipFactory.allDefinitions;
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((c) {
      return c.model.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chips = _filteredChips;

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.chipBorder, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppTheme.chipBorder, width: 1),
              ),
            ),
            child: const Text(
              'Chip Library',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search chips...',
                hintStyle: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppTheme.textSecondary),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Chip list
          Expanded(
            child: chips.isEmpty
                ? const Center(
                    child: Text(
                      'No chips found',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: chips.length,
                    itemBuilder: (context, index) {
                      return _ChipLibraryTile(definition: chips[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChipLibraryTile extends ConsumerWidget {
  final ChipDefinition definition;

  const _ChipLibraryTile({required this.definition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: AppTheme.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppTheme.chipBorder, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          // Add the chip to the canvas at a random position near center
          final random = Random();
          final x = 400.0 + random.nextDouble() * 200 - 100;
          final y = 300.0 + random.nextDouble() * 200 - 100;
          ref
              .read(circuitProvider.notifier)
              .addChip(definition.model, Offset(x, y));
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Chip icon
              Container(
                width: 36,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.chipBody,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.chipBorder, width: 1),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.memory,
                    size: 20, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.model,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      definition.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${definition.pinDefinitions.length} pins  |  Delay: ${definition.propagationDelayPs ~/ 1000}ns',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline,
                  size: 20, color: AppTheme.accentGreen),
            ],
          ),
        ),
      ),
    );
  }
}
