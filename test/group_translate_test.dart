import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/utils/group_translate.dart';

void main() {
  /// GetX 的翻译表是进程级的, appendTranslations 只能累加,
  /// 所以每个用例用独立的基础名, 避免互相污染。
  void useTranslations(Map<String, String> cn) {
    Get.updateLocale(const Locale('zh', 'CN'));
    Get.appendTranslations(<String, Map<String, String>>{
      'zh_CN': cn,
    });
  }

  test('trGroup keeps exact match', () {
    useTranslations(<String, String>{
      'scheduler': '调度器',
      'assist_battle_config': '协战配置',
    });

    expect('scheduler'.trGroup, '调度器');
    expect('assist_battle_config'.trGroup, '协战配置');
  });

  test('trGroup falls back to base name for numbered groups', () {
    useTranslations(<String, String>{'fallback_base': '基础名'});

    expect('fallback_base_1'.trGroup, '基础名');
    expect('fallback_base_108'.trGroup, '基础名');
  });

  test('trGroup prefers exact match over base name', () {
    useTranslations(<String, String>{
      'exact_base': '基础名',
      'exact_base_1': '精确名',
    });

    expect('exact_base_1'.trGroup, '精确名');
  });

  test('trGroup expands pattern entry', () {
    useTranslations(<String, String>{'pattern_list_%s': '队伍%s'});

    expect('pattern_list_7'.trGroup, '队伍7');
  });

  test('trGroup prefers pattern entry over base name', () {
    useTranslations(<String, String>{
      'ordered_base': '基础名',
      'ordered_base_%s': '账号%s',
    });

    expect('ordered_base_1'.trGroup, '账号1');
    expect('ordered_base_108'.trGroup, '账号108');
  });

  test('trGroup returns key when nothing matches', () {
    useTranslations(<String, String>{});

    expect('nomatch_group_3'.trGroup, 'nomatch_group_3');
    expect('nomatch_group'.trGroup, 'nomatch_group');
  });
}
