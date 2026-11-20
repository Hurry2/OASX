import 'package:get/get.dart';

/// 分组名的翻译兜底。
///
/// OAS 的分组名可能是带序号的平铺键（account_list_1 / account_list_108），
/// GetX 的 `.tr` 是精确查表，词典里不可能逐个铺 100 多条。
/// 这里按三级顺序回退：
///   1. 原样查表（account_list_1 -> 有词条就用）
///   2. 剥掉数字后缀查表（account_list_1 -> account_list）
///   3. 模式词条展开（account_list_1 -> 'account_list_%s' -> '账号%s'）
extension GroupTranslate on String {
  String get trGroup {
    final direct = tr;
    if (direct != this) {
      return direct;
    }

    final numbered = RegExp(r'^(.*)_(\d+)$').firstMatch(this);
    if (numbered == null) {
      return direct;
    }

    final base = numbered.group(1)!;
    final index = numbered.group(2)!;

    // 模式词条优先(account_list_%s -> '账号%s'), 比基础名更具体
    final pattern = '${base}_%s';
    final patternText = pattern.tr;
    if (patternText != pattern) {
      return patternText.replaceAll('%s', index);
    }

    // 再用剥掉序号的基础名兜底(词典里 account_list -> '账号列表')
    final baseText = base.tr;
    if (baseText != base) {
      return baseText;
    }

    return direct;
  }
}
