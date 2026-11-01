library args;

import 'dart:async';
import 'dart:convert';

import 'package:expansion_tile_group/expansion_tile_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pickers/pickers.dart';
import 'package:flutter_pickers/style/default_style.dart';
import 'package:flutter_pickers/time_picker/model/date_mode.dart';
import 'package:flutter_pickers/time_picker/model/pduration.dart';
import 'package:flutter_pickers/time_picker/model/suffix.dart';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/common/models/config_drag_payload.dart';
import 'package:oasx/modules/common/widgets/drag_copy_feedback.dart';
import 'package:oasx/service/websocket_service.dart';
import 'package:oasx/utils/platform_utils.dart';
import 'package:styled_widget/styled_widget.dart';

import '../../translation/i18n_content.dart';

part 'widgets/group_view.dart';
part 'widgets/date_time_picker.dart';
part 'widgets/time_delta_picker.dart';
part 'widgets/time_picker.dart';
part 'widgets/argument_view.dart';
part 'widgets/argument_view_actions.dart';
part 'controllers/args_controller.dart';

typedef SetArgumentCallback = void Function(
  String? config,
  String? task,
  String group,
  String argument,
  String type,
  dynamic value,
);

typedef SaveArgumentCallback = Future<bool> Function(
  String config,
  String task,
  String group,
  String argument,
  String type,
  dynamic value,
);

class Args extends StatefulWidget {
  const Args({
    Key? key,
    this.scriptName,
    this.taskName,
    this.groupDraggable = true,
    this.stagingMode = false,
    this.lockImmediateScheduling = false,
    this.activeDragPayload,
    this.groupDragPayloadBuilder,
    this.onGroupDragStarted,
    this.onGroupDragEnded,
    this.setArgumentOverride,
    this.onCancel,
  }) : super(key: key);

  final String? scriptName;
  final String? taskName;
  final bool groupDraggable;
  final bool stagingMode;
  final bool lockImmediateScheduling;
  final ConfigDragPayload? activeDragPayload;
  final ConfigDragPayload Function(String groupName)? groupDragPayloadBuilder;
  final ValueChanged<ConfigDragPayload>? onGroupDragStarted;
  final VoidCallback? onGroupDragEnded;
  final SetArgumentCallback? setArgumentOverride;
  final Future<void> Function()? onCancel;

  @override
  State<Args> createState() => _ArgsState();
}

/// 任务配置表单：顶部分组卡片栏 + 下方只显示选中的那一个分组。
class _ArgsState extends State<Args> {
  /// 分组卡片的最小宽度（约两三个汉字）与卡片间隙。
  static const double _groupCardMinWidth = 62;
  static const double _groupCardSpacing = 6;

  /// 当前选中的分组（'' = 还没点过，按第一个算）。
  ///
  /// 用 ValueNotifier 而不是 setState：换分组只重建卡片栏和分组内容这两块，
  /// 不会重刷整页；也不再需要滚动定位，原来"点一下滑过去"的卡顿一并消失。
  final ValueNotifier<String> _currentGroup = ValueNotifier<String>('');

  @override
  void dispose() {
    _currentGroup.dispose();
    super.dispose();
  }

  /// 当前要显示的分组。
  String _activeGroupOf(List<String> groupNames) {
    final current = _currentGroup.value;

    if (current.isNotEmpty && groupNames.contains(current)) {
      return current;
    }

    return groupNames.isEmpty ? '' : groupNames.first;
  }

  /// 切到某个分组（纯切换，不滚动）。
  void _selectGroup(String name) {
    _currentGroup.value = name;
  }

  /// 一个分组的表单内容（标题 + 可选拖拽手柄 + 参数列表）。
  ExpansionTileItem _buildGroupItem(
    BuildContext context,
    String name,
    String selectedScript,
    String selectedTask,
  ) {
    return ExpansionTileItem(
      key: ValueKey<String>('args-group-$selectedScript-$selectedTask-$name'),
      initiallyExpanded: true,
      isHasTopBorder: false,
      isHasBottomBorder: false,
      backgroundColor: _groupBackgroundColor(
        context,
        selectedScript,
        selectedTask,
        name,
      ),
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      title: <Widget>[
        if (widget.groupDraggable)
          _buildGroupDragHandle(context, selectedScript, selectedTask, name),
        Text(name.tr),
      ].toRow(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
      ),
      children: _children(
        groupName: name,
        selectedScript: selectedScript,
        selectedTask: selectedTask,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetX<ArgsController>(builder: (controller) {
      final selectedScript =
          (widget.scriptName ?? Get.parameters['script'] ?? '').trim();
      final selectedTask =
          (widget.taskName ?? Get.parameters['task'] ?? '').trim();
      final groupNames = controller.groupsName.value;

      final content = Column(
        children: [
          _buildGroupTabBar(context, groupNames),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _currentGroup,
              builder: (context, _, _) {
                final group = _activeGroupOf(groupNames);

                if (group.isEmpty) {
                  return const SizedBox.shrink();
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      // 换分组时从顶部重新开始; 内容高于视口时这层滚动是兜底。
                      key: ValueKey<String>('args-group-body-$group'),
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: ExpansionTileGroup(
                          spaceBetweenItem: 10,
                          children: [
                            _buildGroupItem(
                              context,
                              group,
                              selectedScript,
                              selectedTask,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
      if (!widget.stagingMode) {
        return content;
      }
      return Column(
        children: [
          Expanded(child: content),
          ArgsDraftBar(
            scriptName: selectedScript,
            taskName: selectedTask,
            onCancel: widget.onCancel,
          ),
        ],
      );
    });
  }

  /// 顶部分组卡片栏：卡片窄（约两三个字），按可用宽度均分铺满整行，放不下换行。
  Widget _buildGroupTabBar(BuildContext context, List<String> groupNames) {
    if (groupNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<String>(
      valueListenable: _currentGroup,
      builder: (context, _, _) {
        final active = _activeGroupOf(groupNames);

        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = _groupColumnsFor(constraints.maxWidth);
              final cardWidth = _groupCardWidthFor(
                constraints.maxWidth,
                columns,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var start = 0;
                    start < groupNames.length;
                    start += columns
                  )
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: start + columns < groupNames.length
                            ? _groupCardSpacing
                            : 0,
                      ),
                      child: _buildGroupCardRow(
                        context,
                        groupNames.sublist(
                          start,
                          start + columns < groupNames.length
                              ? start + columns
                              : groupNames.length,
                        ),
                        active,
                        cardWidth,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// 一行放几张：按"两三个字"的最小宽度算。
  int _groupColumnsFor(double available) {
    final columns =
        ((available + _groupCardSpacing) /
                (_groupCardMinWidth + _groupCardSpacing))
            .floor();

    return columns < 1 ? 1 : columns;
  }

  /// 卡片宽度：一行放几张就按几张均分，满行正好铺满、且各行宽度一致。
  double _groupCardWidthFor(double available, int columns) =>
      (available - _groupCardSpacing * (columns - 1)) / columns;

  /// 一行分组卡片：靠左排（与页面其余内容对齐），同一行高度取这一行最高的那张。
  Widget _buildGroupCardRow(
    BuildContext context,
    List<String> names,
    String active,
    double cardWidth,
  ) {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < names.length; index++) ...[
            if (index > 0) const SizedBox(width: _groupCardSpacing),
            SizedBox(
              width: cardWidth,
              child: _buildGroupCard(
                context,
                names[index],
                names[index] == active,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 一张分组卡片：点击切换分组，也可以直接拖到别的配置上复制这一组参数。
  Widget _buildGroupCard(BuildContext context, String name, bool active) {
    final scheme = Theme.of(context).colorScheme;

    return _buildGroupCardDraggable(
      name,
      Material(
        color: active ? scheme.primary : scheme.surfaceContainerHighest,
        elevation: active ? 1 : 0,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _selectGroup(name),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Center(
              child: Text(
                name.tr,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 让卡片本身可拖动复制（与分组标题上的手柄共用同一套 payload）。
  Widget _buildGroupCardDraggable(String name, Widget child) {
    final payload = widget.groupDragPayloadBuilder?.call(name);

    if (payload == null) {
      return child;
    }

    return Draggable<ConfigDragPayload>(
      data: payload,
      feedback: DragCopyFeedback(label: payload.displayLabel),
      onDragStarted: () => widget.onGroupDragStarted?.call(payload),
      onDragCompleted: () => widget.onGroupDragEnded?.call(),
      onDraggableCanceled: (_, __) => widget.onGroupDragEnded?.call(),
      onDragEnd: (_) => widget.onGroupDragEnded?.call(),
      child: child,
    );
  }

  List<Widget> _children({
    required String groupName,
    required String selectedScript,
    required String selectedTask,
  }) {
    final controller = Get.find<ArgsController>();
    final setArgument = widget.setArgumentOverride ?? controller.setArgument;
    final groupsModel = controller.groupsData.value[groupName]!;
    final result = <Widget>[const Divider()];
    for (int i = 0; i < groupsModel.members.length; i++) {
      final member = groupsModel.members[i] as ArgumentModel;
      result.add(
        ArgumentView(
          key: ValueKey<String>(
            'args-$selectedScript-$selectedTask-$groupName-${member.title}',
          ),
          scriptName: widget.scriptName,
          taskName: widget.taskName,
          setArgument: setArgument,
          getGroupName: groupsModel.getGroupName,
          lockImmediateScheduling: widget.lockImmediateScheduling,
          index: i,
        ),
      );
    }
    return result;
  }

  Color _groupBackgroundColor(
    BuildContext context,
    String selectedScript,
    String selectedTask,
    String groupName,
  ) {
    return Theme.of(context)
        .colorScheme
        .secondaryContainer
        .withValues(alpha: 0.24);
  }

  Widget _buildGroupDragHandle(
    BuildContext context,
    String selectedScript,
    String selectedTask,
    String groupName,
  ) {
    final payload = widget.groupDragPayloadBuilder?.call(groupName);
    if (payload == null) {
      return const Icon(Icons.drag_indicator_outlined);
    }
    return Draggable<ConfigDragPayload>(
      data: payload,
      feedback: DragCopyFeedback(label: payload.displayLabel),
      onDragStarted: () => widget.onGroupDragStarted?.call(payload),
      onDragCompleted: () => widget.onGroupDragEnded?.call(),
      onDraggableCanceled: (_, __) => widget.onGroupDragEnded?.call(),
      onDragEnd: (_) => widget.onGroupDragEnded?.call(),
      child: const Icon(Icons.drag_indicator_outlined),
    );
  }
}

class ArgsDraftBar extends StatelessWidget {
  const ArgsDraftBar({
    super.key,
    required this.scriptName,
    required this.taskName,
    this.onCancel,
  });

  final String scriptName;
  final String taskName;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final controller = Get.find<ArgsController>();
      final dirtyCount = controller.dirtyFieldKeys.length;
      final scopeCount = controller.scopeScriptCount.value;
      final pendingCount = dirtyCount * scopeCount;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${I18n.argsDraftDirty.tr}: $pendingCount',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () async {
                await controller.discardDraftChanges();
                await onCancel?.call();
              },
              child: Text(I18n.cancel.tr),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: controller.isSavingDraft.value || dirtyCount == 0
                  ? null
                  : () async {
                      final ret = await controller.saveDraftChanges();
                      if (ret) {
                        final localizedTaskName = taskName.tr;
                        final contextText = scriptName.isEmpty
                            ? localizedTaskName
                            : '$scriptName / $localizedTaskName';
                        Get.snackbar(
                          I18n.settingSaved.tr,
                          contextText,
                        );
                        return;
                      }
                      Get.snackbar(
                        I18n.error.tr,
                        I18n.argsValidationFailed.tr,
                      );
                    },
              icon: controller.isSavingDraft.value
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(I18n.argsSaveChanges.tr),
            ),
          ],
        ).paddingAll(12),
      );
    });
  }
}
