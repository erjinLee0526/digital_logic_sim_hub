import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/chip_definition.dart';
import '../models/pin.dart';
import '../models/signal_state.dart';
import '../models/truth_table.dart';
import '../theme/app_theme.dart';

/// Opens the graphical datasheet for [definition] as a dialog.
Future<void> showChipManual(
  BuildContext context,
  ChipDefinition definition,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChipManualDialog(definition: definition),
  );
}

/// Graphical chip datasheet: pinout diagram, pin table, truth tables, and
/// notes. All content is derived from the chip definition so it always
/// matches what the simulator does.
class ChipManualDialog extends StatelessWidget {
  final ChipDefinition definition;

  const ChipManualDialog({super.key, required this.definition});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final groups = definition.truthTableGroups;
    final notes = definition.datasheetNotes;
    final isStateful = definition.initialState.isNotEmpty;

    return Dialog(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: p.chipBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ManualHeader(definition: definition, isStateful: isStateful),
            Divider(height: 1, color: p.chipBorder),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionTitle('功能概述'),
                    const SizedBox(height: 8),
                    Text(
                      definition.functionSummary,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _PinoutDiagram(definition: definition),
                    const SizedBox(height: 8),
                    const _DirectionLegend(),
                    const SizedBox(height: 20),
                    const _SectionTitle('引脚表'),
                    const SizedBox(height: 8),
                    _PinTable(definition: definition),
                    if (groups.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionTitle('真值表'),
                      const SizedBox(height: 8),
                      if (groups.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '各组逻辑行为一致，以下以 ${groups.first.name} 为例。',
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      _TruthTableSection(
                        chip: definition,
                        group: groups.first,
                      ),
                    ],
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const _SectionTitle('说明'),
                      const SizedBox(height: 8),
                      for (final note in notes)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '\u2022 $note',
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualHeader extends StatelessWidget {
  final ChipDefinition definition;
  final bool isStateful;

  const _ManualHeader({required this.definition, required this.isStateful});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.model,
                  style: TextStyle(
                    color: p.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  definition.description,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MetaChip('${definition.pinDefinitions.length} 引脚'),
                    _MetaChip('延迟 ${_formatDelay(definition.propagationDelayPs)}'),
                    _MetaChip(isStateful ? '时序逻辑' : '组合逻辑'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: p.textSecondary),
          ),
        ],
      ),
    );
  }

  static String _formatDelay(int ps) {
    final ns = ps / 1000;
    final text = ns == ns.roundToDouble()
        ? ns.toStringAsFixed(0)
        : ns.toStringAsFixed(1);
    return '${text}ns';
  }
}

class _MetaChip extends StatelessWidget {
  final String text;

  const _MetaChip(this.text);

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.chipBorder, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(color: p.textSecondary, fontSize: 10),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Text(
      text,
      style: TextStyle(
        color: p.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

/// Scaled-down rendering of the chip body and its pins, using the same
/// colors as the circuit canvas.
class _PinoutDiagram extends StatelessWidget {
  final ChipDefinition definition;

  const _PinoutDiagram({required this.definition});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: p.canvasBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.chipBorder, width: 0.5),
      ),
      child: CustomPaint(
        size: Size.infinite,
        painter: _PinoutPainter(definition, p),
      ),
    );
  }
}

class _PinoutPainter extends CustomPainter {
  final ChipDefinition definition;
  final ThemePalette palette;

  _PinoutPainter(this.definition, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    // Reserve space on both sides for pin labels.
    const labelSpace = 76.0;
    final availableWidth = math.max(40.0, size.width - labelSpace * 2);
    final availableHeight = math.max(60.0, size.height - 24);
    final scale = math.min(
      availableWidth / definition.width,
      availableHeight / definition.height,
    );
    final bodySize = Size(
      definition.width * scale,
      definition.height * scale,
    );
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: bodySize.width,
      height: bodySize.height,
    );

    // Body.
    final bodyPaint = Paint()
      ..color = palette.chipBody
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = palette.chipBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
    canvas.drawRRect(rrect, bodyPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Notch indicator at the top center.
    final notchPaint = Paint()
      ..color = palette.chipBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final notchRect = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.top + 2),
      width: 16,
      height: 6,
    );
    canvas.drawArc(notchRect, math.pi, math.pi, false, notchPaint);

    // Model number near the top of the body.
    final modelPainter = TextPainter(
      text: TextSpan(
        text: definition.model,
        style: TextStyle(
          color: palette.accent,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    modelPainter.paint(
      canvas,
      Offset(rect.center.dx - modelPainter.width / 2, rect.top + 14),
    );

    // Pins with number + label outside the body.
    final positions = definition.pinRelativePositions;
    for (final pin in definition.pinDefinitions) {
      final rel = positions[pin.number];
      if (rel == null) continue;
      final pos = center + Offset(rel.dx * scale, rel.dy * scale);
      final isLeft = rel.dx < 0;
      final color = _directionColor(pin.direction);

      canvas.drawCircle(
        pos,
        4.0,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pos,
        4.0,
        Paint()
          ..color = palette.textPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      final labelPainter = TextPainter(
        text: TextSpan(children: [
          TextSpan(
            text: '${pin.number}',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '  ${pin.label}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelX = isLeft
          ? pos.dx - 8 - labelPainter.width
          : pos.dx + 8;
      labelPainter.paint(
        canvas,
        Offset(labelX, pos.dy - labelPainter.height / 2),
      );
    }
  }

  Color _directionColor(PinDirection direction) {
    switch (direction) {
      case PinDirection.input:
        return palette.pinInput;
      case PinDirection.output:
        return palette.pinOutput;
      case PinDirection.power:
        return palette.pinPower;
      case PinDirection.ground:
        return palette.pinGround;
    }
  }

  @override
  bool shouldRepaint(covariant _PinoutPainter oldDelegate) =>
      oldDelegate.definition != definition || oldDelegate.palette != palette;
}

class _DirectionLegend extends StatelessWidget {
  const _DirectionLegend();

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final items = [
      (p.pinInput, '输入'),
      (p.pinOutput, '输出'),
      (p.pinPower, '电源'),
      (p.pinGround, '接地'),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.$1,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.$2,
                style: TextStyle(
                  color: p.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _PinTable extends StatelessWidget {
  final ChipDefinition definition;

  const _PinTable({required this.definition});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final groupByPin = <int, String>{};
    for (final group in definition.truthTableGroups) {
      for (final pin in [...group.inputPins, ...group.outputPins]) {
        groupByPin.putIfAbsent(pin, () => group.name);
      }
    }
    final pins = [...definition.pinDefinitions]
      ..sort((a, b) => a.number.compareTo(b.number));

    final cellStyle = TextStyle(color: p.textPrimary, fontSize: 11);
    final headerStyle = TextStyle(
      color: p.textSecondary,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    Widget cell(String text, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(text, style: style ?? cellStyle),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Table(
        border: TableBorder.all(
          color: p.chipBorder.withValues(alpha: 0.35),
          width: 0.5,
        ),
        columnWidths: const {
          0: FixedColumnWidth(44),
          1: FixedColumnWidth(68),
          2: FixedColumnWidth(96),
          3: FlexColumnWidth(),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: p.surfaceLight),
            children: [
              cell('引脚', style: headerStyle),
              cell('名称', style: headerStyle),
              cell('类型', style: headerStyle),
              cell('功能', style: headerStyle),
            ],
          ),
          for (final pin in pins)
            TableRow(
              children: [
                cell('${pin.number}'),
                cell(pin.label),
                cell(_directionName(pin.direction)),
                cell(groupByPin[pin.number] ?? _directionRole(pin.direction)),
              ],
            ),
        ],
      ),
    );
  }

  static String _directionName(PinDirection direction) {
    switch (direction) {
      case PinDirection.input:
        return '输入';
      case PinDirection.output:
        return '输出';
      case PinDirection.power:
        return '电源';
      case PinDirection.ground:
        return '接地';
    }
  }

  static String _directionRole(PinDirection direction) {
    switch (direction) {
      case PinDirection.input:
        return '输入';
      case PinDirection.output:
        return '输出';
      case PinDirection.power:
        return '电源 +5V';
      case PinDirection.ground:
        return '接地 0V';
    }
  }
}

class _TruthTableSection extends StatelessWidget {
  final ChipDefinition chip;
  final TruthTableGroup group;

  const _TruthTableSection({required this.chip, required this.group});

  @override
  Widget build(BuildContext context) {
    final p = AppTheme.of(context);
    final rows = generateTruthTable(chip, group);
    final headers = [
      ...group.inputPins.map(_labelOf),
      ...group.outputPins.map(_labelOf),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            group.name,
            style: TextStyle(
              color: p.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: p.chipBorder.withValues(alpha: 0.35),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              border: TableBorder.all(
                color: p.chipBorder.withValues(alpha: 0.35),
                width: 0.5,
              ),
              defaultColumnWidth: const FixedColumnWidth(52),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: p.surfaceLight),
                  children: [
                    for (final header in headers)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 5),
                        child: Text(
                          header,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final row in rows)
                  TableRow(
                    children: [
                      ...row.inputs.map((s) => _valueCell(s, p)),
                      ...row.outputs.map((s) => _valueCell(s, p)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _labelOf(int pinNumber) {
    for (final pin in chip.pinDefinitions) {
      if (pin.number == pinNumber) return pin.label;
    }
    return '$pinNumber';
  }

  Widget _valueCell(SignalState state, ThemePalette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        state.displayName,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: p.colorForSignal(state),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
