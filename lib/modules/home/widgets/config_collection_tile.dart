import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/widgets/config_collection_script_label.dart';
import 'package:oasx/modules/home/widgets/config_collection_task_preview.dart';
import 'package:oasx/translation/i18n_content.dart';

class ConfigCollectionTile extends StatefulWidget {
  const ConfigCollectionTile({
    super.key,
    required this.controller,
    required this.script,
    required this.onTap,
    required this.onTogglePower,
    required this.onRename,
    required this.onExport,
    required this.onDelete,
    this.horizontal = false,
    this.dragHandle,
  });

  static const _actionSpacing = 8.0;
  static const _compactLayoutThreshold = 200.0;
  final HomeDashboardController controller;
  final ScriptModel script;
  final VoidCallback onTap;
  final VoidCallback onTogglePower;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final bool horizontal;

  /// 拖动排序手柄，由列表注入。
  ///
  /// 为空时不占位：只有一条配置时排序没有意义，列表会直接不传。
  final Widget? dragHandle;

  @override
  State<ConfigCollectionTile> createState() => _ConfigCollectionTileState();
}

class _ConfigCollectionTileState extends State<ConfigCollectionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Obx(() {
          final isActive =
              widget.controller.activeScriptName.value == widget.script.name;
          final showLinkCheckbox = widget.controller.isLinkModeEnabled.value;
          final isLinked = widget.controller.isScriptLinked(widget.script.name);
          final isDragCopyLoading = widget.controller.isDragCopyPendingFor(
            widget.script.name,
          );
          // 排序手柄会占掉左侧一条，窄窗下要提前切到紧凑布局。
          final compactThreshold =
              ConfigCollectionTile._compactLayoutThreshold +
              (showLinkCheckbox ? 64 : 0) +
              (widget.dragHandle != null ? 28 : 0);
          final isCompact = constraints.maxWidth < compactThreshold;
          final rowColor = isActive
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.28)
              : (widget.horizontal
                    ? theme.colorScheme.surfaceContainerLowest
                    : theme.cardColor);
          final accentColor = _accentColor(
            context,
            widget.controller.scriptCollectionStateFor(widget.script),
          );
          // 悬浮时才显示操作按钮；横向模式下改为右上角悬浮胶囊，不挤占文字宽度
          final showActions = widget.horizontal
              ? _isHovered
              : (_isHovered || isActive);
          final powerButton = _PowerButton(
            onTogglePower: widget.onTogglePower,
            compact: widget.horizontal,
          );
          final popupButton = _ActionMenuButton(
            onRename: widget.onRename,
            onExport: widget.onExport,
            onDelete: widget.onDelete,
            compact: widget.horizontal,
          );
          final bodyRow = Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.horizontal ? 8 : 10,
              vertical: widget.horizontal ? 6 : (isCompact ? 8 : 10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (showLinkCheckbox) ...[
                  SizedBox(
                    width: widget.horizontal ? 28 : 36,
                    height: widget.horizontal ? 28 : 36,
                    child: Checkbox(
                      value: isLinked,
                      onChanged: (value) =>
                          widget.controller.setScriptLinked(
                        widget.script.name,
                        value ?? false,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
                Expanded(
                  child: Stack(
                    children: [
                      AbsorbPointer(
                        absorbing: isDragCopyLoading,
                        child: _ScriptMeta(
                          script: widget.script,
                          compact: !widget.horizontal && isCompact,
                          horizontal: widget.horizontal,
                          accentColor: accentColor,
                          dragHandle: widget.dragHandle,
                          showActions: showActions,
                          powerButton: powerButton,
                          popupButton: popupButton,
                        ),
                      ),
                      if (isDragCopyLoading)
                        const Positioned.fill(
                          child: _DragCopyLoadingMask(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
          final tileContent = MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: rowColor,
                borderRadius: widget.horizontal
                    ? BorderRadius.circular(10)
                    : null,
                border: widget.horizontal
                    ? Border.all(
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.45)
                            : theme.colorScheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                      )
                    : null,
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: InkWell(
                borderRadius: widget.horizontal
                    ? BorderRadius.circular(10)
                    : null,
                onTap: isDragCopyLoading ? null : widget.onTap,
                child: widget.horizontal
                    ? Stack(
                        children: [
                          bodyRow,
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IgnorePointer(
                              ignoring: !showActions || isDragCopyLoading,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 140),
                                opacity: showActions && !isDragCopyLoading
                                    ? 1.0
                                    : 0.0,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.94),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.colorScheme.shadow
                                            .withValues(alpha: 0.10),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 1,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [powerButton, popupButton],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : bodyRow,
              ),
            ),
          );
          if (widget.horizontal) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: showLinkCheckbox ? 236 : 210,
                maxWidth: showLinkCheckbox ? 304 : 276,
              ),
              child: SizedBox(
                height: 62,
                child: IntrinsicWidth(child: tileContent),
              ),
            );
          }
          return tileContent;
        });
      },
    );
  }

  Color _accentColor(BuildContext context, HomeScriptStateFilter value) {
    final scheme = Theme.of(context).colorScheme;
    return switch (value) {
      HomeScriptStateFilter.running => Colors.green.shade600,
      HomeScriptStateFilter.stopped => scheme.outline,
      HomeScriptStateFilter.abnormal => Colors.orange.shade700,
      HomeScriptStateFilter.offline => Colors.orange.shade700,
      HomeScriptStateFilter.all => scheme.outline,
    };
  }
}

class _ScriptMeta extends StatelessWidget {
  const _ScriptMeta({
    required this.script,
    required this.compact,
    required this.horizontal,
    required this.accentColor,
    required this.dragHandle,
    required this.showActions,
    required this.powerButton,
    required this.popupButton,
  });

  final ScriptModel script;
  final bool compact;
  final bool horizontal;
  final Color accentColor;
  final Widget? dragHandle;
  final bool showActions;
  final Widget powerButton;
  final Widget popupButton;

  @override
  Widget build(BuildContext context) {
    final actions = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: showActions ? 1.0 : 0.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [powerButton, popupButton],
      ),
    );
    if (compact) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (dragHandle != null) ...[dragHandle!, const SizedBox(width: 2)],
            _RegularAccentBar(
              key: ValueKey<String>('config-accent-bar-${script.name}'),
              color: accentColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  actions,
                  const SizedBox(height: 4),
                  ConfigCollectionScriptLabel(script: script, centered: true),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dragHandle != null) ...[dragHandle!, const SizedBox(width: 2)],
          _RegularAccentBar(
            key: ValueKey<String>('config-accent-bar-${script.name}'),
            color: accentColor,
          ),
          SizedBox(width: horizontal ? 8 : 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Tooltip(
                  message: script.name,
                  waitDuration: const Duration(milliseconds: 500),
                  child: ConfigCollectionScriptLabel(
                    script: script,
                    centered: false,
                  ),
                ),
                SizedBox(height: horizontal ? 3 : 6),
                ConfigCollectionTaskPreview(script: script),
              ],
            ),
          ),
          if (!horizontal) ...[
            const SizedBox(width: ConfigCollectionTile._actionSpacing),
            actions,
          ],
        ],
      ),
    );
  }
}

class _DragCopyLoadingMask extends StatelessWidget {
  const _DragCopyLoadingMask();

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    );
  }
}

class _RegularAccentBar extends StatelessWidget {
  const _RegularAccentBar({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 6,
      height: double.infinity,
      child: Center(
        child: FractionallySizedBox(
          heightFactor: 0.8,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.onTogglePower, this.compact = false});

  final VoidCallback onTogglePower;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dimension = compact ? 26.0 : 32.0;
    return IconButton(
      onPressed: onTogglePower,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: dimension, height: dimension),
      padding: EdgeInsets.zero,
      iconSize: compact ? 18 : 23,
      icon: const Icon(Icons.power_settings_new_rounded),
    );
  }
}

class _ActionMenuButton extends StatelessWidget {
  const _ActionMenuButton({
    required this.onRename,
    required this.onExport,
    required this.onDelete,
    this.compact = false,
  });

  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: compact ? 26 : 32,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        tooltip: '',
        icon: Icon(Icons.more_vert_rounded, size: compact ? 16 : 18),
        onSelected: (value) async {
          if (value == 'rename') {
            onRename();
            return;
          }
          if (value == 'export') {
            onExport();
            return;
          }
          onDelete();
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'rename', child: Text(I18n.rename.tr)),
          PopupMenuItem(value: 'export', child: Text(I18n.configExport.tr)),
          PopupMenuItem(value: 'delete', child: Text(I18n.delete.tr)),
        ],
      ),
    );
  }
}
