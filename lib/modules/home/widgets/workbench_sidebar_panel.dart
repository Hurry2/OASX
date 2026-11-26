import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/click_statistics/click_statistics_controller.dart';
import 'package:oasx/modules/click_statistics/click_statistics_view.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/widgets/last_screenshot_panel.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/home/widgets/statistics_panel.dart';
import 'package:oasx/modules/home/widgets/statistics_pie_card.dart';
import 'package:oasx/modules/home/widgets/storage_stats_panel.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Hosts the desktop right sidebar for statistics, logs, monitoring and clicks.
class WorkbenchSidebarPanel extends StatelessWidget {
  /// Creates the right workbench sidebar.
  const WorkbenchSidebarPanel({
    super.key,
    required this.controller,
    required this.scriptName,
    required this.onCollapse,
  });

  /// Dashboard controller that owns sidebar tab state.
  final HomeDashboardController controller;

  /// Active script rendered by the sidebar.
  final String scriptName;

  /// Collapses this sidebar so the workbench pane gets the full width.
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 600) {
          return _buildBentoCockpit(context);
        }
        return _buildNarrowBento(context, constraints.maxWidth);
      },
    );
  }

  /// Narrow fallback when the user drags the divider to shrink the right pane:
  /// keeps the Bento layout and exposes Monitor + Heatmap as a floating pill.
  Widget _buildNarrowBento(BuildContext context, double maxWidth) {
    final showBottomSplit = maxWidth >= 460;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              LogCenterPanel(scriptName: scriptName),
              Positioned(
                right: 14,
                bottom: 14,
                child: Material(
                  elevation: 3,
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => _openStorageStatsDialog(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 15,
                                  color: scheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  I18n.storageStatsTab.tr,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 14,
                          color: scheme.onPrimaryContainer.withValues(
                            alpha: 0.2,
                          ),
                        ),
                        IconButton(
                          tooltip: I18n.homeClickStatsTab.tr,
                          onPressed: () => _openClickStatsDialog(context),
                          iconSize: 16,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 28,
                            height: 26,
                          ),
                          icon: _HeatmapMouseIcon(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 204,
          child: showBottomSplit
              ? Row(
                  children: [
                    Expanded(
                      flex: 9,
                      child: LastScreenshotPanel(
                        scriptName: scriptName,
                        compact: true,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: 11,
                      child: StatisticsPieCard(
                        onOpenFullStats: () => _openStatsDialog(context),
                      ),
                    ),
                  ],
                )
              : StatisticsPieCard(
                  onOpenFullStats: () => _openStatsDialog(context),
                ),
        ),
      ],
    );
  }

  /// Desktop cockpit: top row has [LogCenter | 2-col Resource Monitor],
  /// bottom row spans both columns with [Live Screenshot | Statistics Pie].
  Widget _buildBentoCockpit(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: LogCenterPanel(scriptName: scriptName)),
              const SizedBox(width: 4),
              SizedBox(
                width: 300,
                child: StorageStatsPanel(
                  scriptName: scriptName,
                  showScreenshot: false,
                  forcedColumns: 2,
                  headerTrailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: I18n.homeClickStatsTab.tr,
                        onPressed: () => _openClickStatsDialog(context),
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        icon: _HeatmapMouseIcon(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      IconButton(
                        key: const ValueKey<String>(
                          'home-workbench-collapse-right-sidebar',
                        ),
                        tooltip: I18n.homeCollapseSidebar.tr,
                        onPressed: onCollapse,
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.keyboard_double_arrow_right_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 204,
          child: Row(
            children: [
              Expanded(
                flex: 9,
                child: LastScreenshotPanel(
                  scriptName: scriptName,
                  compact: true,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 11,
                child: StatisticsPieCard(
                  onOpenFullStats: () => _openStatsDialog(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openStorageStatsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1020, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      I18n.storageStatsTab.tr,
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 12),
                Expanded(
                  child: StorageStatsPanel(
                    scriptName: scriptName,
                    showScreenshot: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStatsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1020, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 18,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      I18n.homeStatsTab.tr,
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 12),
                const Expanded(child: ScriptStatisticsPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openClickStatsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 850),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    _HeatmapMouseIcon(
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      I18n.homeClickStatsTab.tr,
                      style: Theme.of(dialogContext).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 12),
                Expanded(
                  child: WorkbenchClickStatisticsPanel(scriptName: scriptName),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Click statistics hosted inside a workbench panel instead of its own route.
///
/// The instance follows the panel's script, so this panel has no instance dropdown.
class WorkbenchClickStatisticsPanel extends StatefulWidget {
  /// Creates the embedded click statistics panel.
  const WorkbenchClickStatisticsPanel({super.key, required this.scriptName});

  /// Config/instance currently selected on the left.
  final String scriptName;

  @override
  State<WorkbenchClickStatisticsPanel> createState() =>
      _WorkbenchClickStatisticsPanelState();
}

class _WorkbenchClickStatisticsPanelState
    extends State<WorkbenchClickStatisticsPanel> {
  @override
  void initState() {
    super.initState();
    _ensureController();
    unawaited(_controller.useFixedConfig(widget.scriptName));
  }

  @override
  void didUpdateWidget(covariant WorkbenchClickStatisticsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptName != widget.scriptName) {
      unawaited(_controller.useFixedConfig(widget.scriptName));
    }
  }

  ClickStatisticsController get _controller =>
      Get.find<ClickStatisticsController>();

  /// Registers the controller on first use (the route binding may never have run).
  void _ensureController() {
    if (!Get.isRegistered<ClickStatisticsController>()) {
      Get.lazyPut<ClickStatisticsController>(() => ClickStatisticsController());
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureController();
    return ClickStatisticsView(embedded: true);
  }
}

/// 鼠标 + 火焰组合图标，用于热力图入口。
class _HeatmapMouseIcon extends StatelessWidget {
  const _HeatmapMouseIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: Icon(Icons.mouse_outlined, size: 16, color: color),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 11,
              color: Colors.deepOrange.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
