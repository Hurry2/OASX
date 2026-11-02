import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';

void main() {
  test('localizedLogLabelFrom matches a raw upper case task name', () {
    const table = <String, String>{
      'DemonEncounter': '逢魔之时',
      'RichMan': '大富翁',
    };

    // 远端 OAS 会把横幅标题原样大写塞进 task 字段。
    expect(localizedLogLabelFrom('DEMONENCOUNTER', table), '逢魔之时');
    expect(localizedLogLabelFrom(' RichMan ', table), '大富翁');
  });

  test('localizedLogLabelFrom returns empty when nothing matches', () {
    const table = <String, String>{'RichMan': '大富翁'};

    // 已经本地化的中文标签不该被再次改写。
    expect(localizedLogLabelFrom('大富翁', table), isEmpty);
    expect(localizedLogLabelFrom('', table), isEmpty);
    expect(localizedLogLabelFrom('Unknown', table), isEmpty);
  });
}