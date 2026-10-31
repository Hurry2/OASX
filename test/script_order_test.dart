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
}
