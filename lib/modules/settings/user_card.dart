import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:oasx/modules/settings/controllers/settings_controller.dart';
import 'package:oasx/modules/settings/widgets/setting_card.dart';
import 'package:oasx/modules/settings/widgets/setting_item.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/utils/platform_utils.dart';

class UserSettingsCard extends StatelessWidget {
  const UserSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingCard(
      title: I18n.userSetting.tr,
      items: [
        SettingItem(
          left: Text(I18n.loginAddress.tr),
          right: const _LoginInputField(type: _LoginFieldType.address),
        ),
        SettingItem(
          left: Text(I18n.username.tr),
          right: const _LoginInputField(type: _LoginFieldType.username),
        ),
        SettingItem(
          left: Text(I18n.password.tr),
          right: const _LoginInputField(type: _LoginFieldType.password),
        ),
      ],
    );
  }
}

enum _LoginFieldType { address, username, password }

class _LoginInputField extends StatefulWidget {
  const _LoginInputField({required this.type});

  final _LoginFieldType type;

  @override
  State<_LoginInputField> createState() => _LoginInputFieldState();
}

class _LoginInputFieldState extends State<_LoginInputField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _settingsController = Get.find<SettingsController>();
    _controller = TextEditingController(text: _currentValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _LoginInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTextController();
  }

  String get _currentValue {
    return switch (widget.type) {
      _LoginFieldType.address => _settingsController.address.value,
      _LoginFieldType.username => _settingsController.username.value,
      _LoginFieldType.password => _settingsController.password.value,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _isAddress => widget.type == _LoginFieldType.address;

  /// 后缀槽位的尺寸。地址字段放历史入口，用户名/密码放等宽占位。
  static const double _suffixSlot = 32;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Obx(() {
      _syncTextController();
      return SizedBox(
        width: 220,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          obscureText: widget.type == _LoginFieldType.password,
          keyboardType: _isAddress ? TextInputType.url : TextInputType.text,
          decoration: InputDecoration(
            // 三个字段显式共用同一套下划线。只依赖默认边框的话，实测只有挂了
            // suffixIcon 的地址字段画得出来，用户名/密码是空白的（看不出输入框
            // 边界）。显式给 enabledBorder / focusedBorder 就绕过了默认边框的
            // 解析分支，颜色和 M3 默认值一致（enabled = outline，focused =
            // primary 加粗）。
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            // 用户名/密码塞一个等宽的空占位，让三个字段的节点结构、行高、文本区
            // 宽度完全一致 —— 否则只有地址那一行会被 suffix 撑高，且上面那条
            // 边框差异又只在带 suffix 的字段上出现。
            suffixIcon: _isAddress
                ? _AddressHistoryMenu(
                    history: _settingsController.addressHistory,
                    current: _settingsController.address.value,
                    onSelected: _applyAddress,
                    onClear: _settingsController.clearAddressHistory,
                  )
                : const SizedBox.square(dimension: _suffixSlot),
            suffixIconConstraints: const BoxConstraints(
              minWidth: _suffixSlot,
              minHeight: _suffixSlot,
            ),
          ),
          scrollPadding: EdgeInsets.only(
            left: 12,
            top: 12,
            right: 12,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          textInputAction: TextInputAction.done,
          onTapOutside: PlatformUtils.isWeb ? null : (_) => _finishEditing(),
          onEditingComplete: PlatformUtils.isWeb ? null : _finishEditing,
          onChanged: (text) {
            switch (widget.type) {
              case _LoginFieldType.address:
                _settingsController.updateAddress(text);
                break;
              case _LoginFieldType.username:
                _settingsController.updateUsername(text);
                break;
              case _LoginFieldType.password:
                _settingsController.updatePassword(text);
                break;
            }
          },
        ),
      );
    });
  }

  /// 回填历史地址。程序改 controller 不会触发 onChanged，必须显式提交一次，
  /// 否则界面变了但 [SettingsController.address] 还是旧值。
  void _applyAddress(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _settingsController.updateAddress(value);
  }

  /// 输入框的「提交」时机：失焦或按下回车。地址字段只在这里落一条历史，
  /// 避免把 `192`、`192.1` 这种输入过程中的半成品也记进去。
  void _finishEditing() {
    if (_isAddress) {
      _settingsController.rememberAddress(_settingsController.address.value);
    }
    _focusNode.unfocus();
  }

  void _syncTextController() {
    if (_focusNode.hasFocus) {
      return;
    }
    final current = _currentValue;
    if (_controller.text == current) {
      return;
    }
    _controller.value = TextEditingValue(
      text: current,
      selection: TextSelection.collapsed(offset: current.length),
    );
  }
}

/// 登录地址输入框右侧的历史入口，点开直接选中一条历史地址。
class _AddressHistoryMenu extends StatelessWidget {
  const _AddressHistoryMenu({
    required this.history,
    required this.current,
    required this.onSelected,
    required this.onClear,
  });

  /// 「清空历史」的哨兵值，用不可见字符开头，不会和真实地址冲突。
  static const String _clearValue = '\u0000clear-address-history';

  static const double _maxEntryWidth = 220;
  static const double _itemHeight = 36;

  final List<String> history;
  final String current;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<String>(
      tooltip: I18n.loginAddressHistory.tr,
      padding: const EdgeInsets.all(6),
      iconSize: 18,
      icon: const Icon(Icons.history_rounded),
      onSelected: (value) {
        if (value == _clearValue) {
          onClear();
          return;
        }
        onSelected(value);
      },
      itemBuilder: (context) {
        if (history.isEmpty) {
          return [
            PopupMenuItem<String>(
              enabled: false,
              height: _itemHeight,
              child: Text(
                I18n.addressHistoryEmpty.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ];
        }
        return [
          for (final item in history)
            PopupMenuItem<String>(
              value: item,
              height: _itemHeight,
              child: _AddressHistoryEntry(
                text: item,
                selected: item == current,
              ),
            ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: _clearValue,
            height: _itemHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(I18n.clearAddressHistory.tr),
              ],
            ),
          ),
        ];
      },
    );
  }
}

class _AddressHistoryEntry extends StatelessWidget {
  const _AddressHistoryEntry({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? Icons.check_rounded : Icons.history_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: _AddressHistoryMenu._maxEntryWidth,
          ),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
