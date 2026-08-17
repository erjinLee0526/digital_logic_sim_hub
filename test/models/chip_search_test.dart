import 'package:flutter_test/flutter_test.dart';
import 'package:digital_logic_sim/chips/ls74ls10.dart';
import 'package:digital_logic_sim/chips/ls74ls32.dart';

void main() {
  group('ChipDefinition.matchesSearch', () {
    test('empty or blank query matches every chip', () {
      expect(Chip74LS10().matchesSearch(''), isTrue);
      expect(Chip74LS10().matchesSearch('   '), isTrue);
    });

    test('matches the model number, never the description', () {
      final tripleNand = Chip74LS10();
      expect(tripleNand.model, '74LS10');
      // 描述里有“3 输入”，但型号 74LS10 不含“3”，搜“3”不应命中。
      expect(tripleNand.description, contains('3'));
      expect(tripleNand.matchesSearch('3'), isFalse);

      final quadOr = Chip74LS32();
      expect(quadOr.model, '74LS32');
      expect(quadOr.matchesSearch('3'), isTrue);
    });

    test('matching is case-insensitive', () {
      expect(Chip74LS32().matchesSearch('ls32'), isTrue);
      expect(Chip74LS10().matchesSearch('LS10'), isTrue);
    });

    test('trims whitespace around the query', () {
      expect(Chip74LS32().matchesSearch(' 32 '), isTrue);
      expect(Chip74LS10().matchesSearch(' 10 '), isTrue);
    });
  });
}
