import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chips/chip_factory.dart';
import '../models/chip_definition.dart';
import '../providers/circuit_provider.dart';
import '../theme/app_theme.dart';
import 'chip_manual.dart';

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
    // 搜索只匹配型号名（model），不匹配功能描述（description）。
    return all.where((c) => c.matchesSearch(_query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chips = _filteredChips;
    final p = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: p.chipBorder, width: 1),
              ),
            ),
            child: Text(
              '芯片库',
              style: TextStyle(
                color: p.textPrimary,
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
              style: TextStyle(color: p.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: '搜索芯片…',
                hintStyle:
                    TextStyle(color: p.textSecondary, fontSize: 12),
                prefixIcon:
                    Icon(Icons.search, size: 18, color: p.textSecondary),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                filled: true,
                fillColor: p.surfaceLight,
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
                ? Center(
                    child: Text(
                      '未找到芯片',
                      style: TextStyle(
                          color: p.textSecondary, fontSize: 12),
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
    );
  }
}

class _ChipLibraryTile extends ConsumerWidget {
  final ChipDefinition definition;

  const _ChipLibraryTile({required this.definition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppTheme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: p.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: p.chipBorder, width: 0.5),
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
                  color: p.chipBody,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: p.chipBorder, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.memory, size: 20, color: p.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.model,
                      style: TextStyle(
                        color: p.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      definition.description,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 10,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${definition.pinDefinitions.length} 引脚  |  '
                      '延迟 ${definition.propagationDelayPs ~/ 1000}ns',
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: '查看数据手册',
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => showChipManual(context, definition),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child:
                        Icon(Icons.info_outline, size: 18, color: p.accent),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.add_circle_outline,
                  size: 20, color: p.accentGreen),
            ],
          ),
        ),
      ),
    );
  }
}
