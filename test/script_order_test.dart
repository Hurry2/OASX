import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/home/models/script_order.dart';

void main() {
  group('applyCustomScriptOrder', () {
    test('keeps the user order', () {
      expect(
        applyCustomScriptOrder(['A', 'B'], ['B', 'A']),
        ['B', 'A'],
      );
    });

    test('appends configs missing from the custom order', () {
      expect(
        applyCustomScriptOrder(['A', 'B', 'C'], ['B', 'A']),
        ['B', 'A', 'C'],
      );
    });

    test('drops names that no longer exist on the server', () {
      expect(
        applyCustomScriptOrder(['A', 'B'], ['X', 'B', 'A']),
        ['B', 'A'],
      );
    });

    test('falls back to server order when nothing matches', () {
      expect(
        applyCustomScriptOrder(['A', 'B'], ['X', 'Y']),
        ['A', 'B'],
      );
    });
  });

  group('isScriptOrderStale', () {
    test('true when the stored order shares no name with the server', () {
      expect(
        isScriptOrderStale(
          ['体验服', '模拟器2六道'],
          ['模拟器01大号', '模拟器02随区'],
        ),
        isTrue,
      );
    });

    test('false when at least one name matches', () {
      expect(
        isScriptOrderStale(
          ['体验服', '模拟器2六道'],
          ['模拟器2六道', '模拟器01大号'],
        ),
        isFalse,
      );
    });

    test('false when the stored order is empty (first run)', () {
      expect(isScriptOrderStale(['A'], []), isFalse);
    });

    test('false when the server list is empty (backend not ready)', () {
      // OAS 重启期间拿不到列表，此时不能判定顺序失效，否则会误清用户数据
      expect(isScriptOrderStale([], ['A', 'B']), isFalse);
    });

    test('ignores empty entries on both sides', () {
      expect(isScriptOrderStale(['A', ''], ['', 'B']), isTrue);
      expect(isScriptOrderStale(['A'], ['', 'A']), isFalse);
    });
  });

  group('reorderVisibleNames', () {
    test('moves an item inside an unfiltered list', () {
      expect(
        reorderVisibleNames(
          fullOrder: ['A', 'B', 'C'],
          visibleOrder: ['A', 'B', 'C'],
          oldIndex: 0,
          newIndex: 2,
        ),
        ['B', 'A', 'C'],
      );
    });

    test('keeps hidden items in place when filtered', () {
      // 可见 C、A；把 A 移到 C 前面，B 保持原位
      expect(
        reorderVisibleNames(
          fullOrder: ['A', 'B', 'C'],
          visibleOrder: ['A', 'C'],
          oldIndex: 0,
          newIndex: 1,
        ),
        ['B', 'A', 'C'],
      );
    });

    test('moves to the end when target is past the last visible item', () {
      expect(
        reorderVisibleNames(
          fullOrder: ['A', 'B', 'C'],
          visibleOrder: ['A', 'B'],
          oldIndex: 0,
          newIndex: 2,
        ),
        ['B', 'A', 'C'],
      );
    });

    test('returns the original order for out-of-range indexes', () {
      expect(
        reorderVisibleNames(
          fullOrder: ['A', 'B'],
          visibleOrder: ['A', 'B'],
          oldIndex: 5,
          newIndex: 0,
        ),
        ['A', 'B'],
      );
    });
  });

  group('per-backend script order', () {
    // 同一台设备切换局域网里的多台 OAS：各自的配置名不同，排序必须各存一份，
    // 否则切走再切回来时自定义顺序会被另一台的顺序覆盖掉（用户报告的 bug）。
    test('keeps one order per backend and never overwrites another', () {
      const backendA = 'http://192.168.1.9:22288';
      const backendB = 'http://192.168.1.10:22288';
      const backendC = 'http://192.168.1.11:22288';

      final stored = <String, List<String>>{
        backendA: ['模拟器01大号', '模拟器02随区'],
        backendB: ['设备A', '设备B'],
        backendC: ['机台一'],
      };
      final encoded = jsonEncode(stored);
      final parsed = parseScriptOrderStorage(
        encoded,
        currentBackend: backendA,
      );

      expect(parsed.length, 3, reason: '三台后端各有一份');
      expect(scriptOrderForBackend(parsed, backendA), ['模拟器01大号', '模拟器02随区']);
      expect(scriptOrderForBackend(parsed, backendB), ['设备A', '设备B']);
      expect(scriptOrderForBackend(parsed, backendC), ['机台一']);
    });

    test('returns an empty order for a backend that has none', () {
      final parsed = parseScriptOrderStorage(
        jsonEncode({
          'http://192.168.1.9:22288': ['A'],
        }),
        currentBackend: 'http://192.168.1.9:22288',
      );

      expect(
        scriptOrderForBackend(parsed, 'http://192.168.1.50:22288'),
        isEmpty,
      );
    });

    test('migrates the legacy flat list to the current backend', () {
      // 旧版只存了一个列表，没有任何后端信息 → 整份归到当前后端，不能丢。
      final parsed = parseScriptOrderStorage(
        ['A', 'B'],
        currentBackend: 'http://192.168.1.9:22288',
      );

      expect(parsed.length, 1);
      expect(
        scriptOrderForBackend(parsed, 'http://192.168.1.9:22288'),
        ['A', 'B'],
      );
    });

    test('migrates the legacy JSON-string list', () {
      final parsed = parseScriptOrderStorage(
        jsonEncode(['A', 'B']),
        currentBackend: 'http://192.168.1.9:22288',
      );

      expect(
        scriptOrderForBackend(parsed, 'http://192.168.1.9:22288'),
        ['A', 'B'],
      );
    });

    test('ignores garbage instead of throwing', () {
      for (final raw in <dynamic>[null, '', 'not json', 42, {'': ['A']}]) {
        expect(
          parseScriptOrderStorage(raw, currentBackend: 'b').values,
          isNot(contains(<String>['A'])),
          reason: '脏数据应被忽略（raw=$raw）',
        );
      }
    });
  });
}
