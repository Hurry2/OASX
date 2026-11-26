import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/click_statistics/click_statistics_controller.dart';
import 'package:oasx/modules/click_statistics/click_statistics_view.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
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
        return _buildCompactTabbedSidebar(context);
      },
    );
  }

  /// Desktop cockpit: top row has [LogCenter | 2-col Resource Monitor],
  /// bottom row spans both columns with [Live Screenshot | Statistics Pie].
  Widget _buildBentoCockpit(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: LogCenterPanel(scriptName: scriptName)),
              const SizedBox(width: 4),
              SizedBox(
                width: 284,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 15,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            I18n.storageStatsTab.tr,
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: I18n.homeClickStatsTab.tr,
                            onPressed: () => _openClickStatsDialog(context),
                            iconSize: 17,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 28,
                              height: 28,
                            ),
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.grid_view_rounded,
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
                    Expanded(
                      child: StorageStatsPanel(
                        scriptName: scriptName,
                        showScreenshot: false,
                        forcedColumns: 2,
                      ),
                    ),
                  ],
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

  Widget _buildCompactTabbedSidebar(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Obx(() {
          final tabs = controller.workbenchSidebarTabsFor(
            HomeWorkbenchLayoutMode.threePane,
          );
          final currentTab = controller.displayedWorkbenchSidebarTabFor(
            HomeWorkbenchLayoutMode.threePane,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    // --- 细线 Tab 行替换 ChoiceChip ---
                    child: _SidebarTabBar(
                      tabs: tabs,
                      currentTab: currentTab,
                      labelOf: _tabLabel,
                      onTap: controller.setActiveWorkbenchSidebarTabValue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey<String>(
                      'home-workbench-collapse-right-sidebar',
                    ),
                    tooltip: I18n.homeCollapseSidebar.tr,
                    onPressed: onCollapse,
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.keyboard_double_arrow_right_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: switch (currentTab) {
                  HomeWorkbenchTab.stats => const ScriptStatisticsPanel(),
                  HomeWorkbenchTab.logs => LogCenterPanel(
                    scriptName: scriptName,
                  ),
                  HomeWorkbenchTab.storageStats => StorageStatsPanel(
                    scriptName: scriptName,
                  ),
                  HomeWorkbenchTab.clickStats => WorkbenchClickStatisticsPanel(
                    scriptName: scriptName,
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
              if (currentTab != HomeWorkbenchTab.stats) ...[
                const SizedBox(height: 10),
                StatisticsPieCard(
                  onOpenFullStats: () =>
                      controller.setActiveWorkbenchSidebarTabValue(
                        HomeWorkbenchTab.stats,
                      ),
                ),
              ],
            ],
          );
        }),
      ),
    );
  }

  Future<void> _openStatsDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
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
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 640),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: 18,
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

  /// Resolves a localized label for one sidebar tab.
  String _tabLabel(HomeWorkbenchTab value) {
    return switch (value) {
      HomeWorkbenchTab.stats => I18n.homeStatsTab.tr,
      HomeWorkbenchTab.logs => I18n.log.tr,
      HomeWorkbenchTab.storageStats => I18n.storageStatsTab.tr,
      HomeWorkbenchTab.clickStats => I18n.homeClickStatsTab.tr,
      _ => '',
    };
  }
}

/// 右侧面板轻量细线 Tab 行。
class _SidebarTabBar extends StatelessWidget {
  const _SidebarTabBar({
    required this.tabs,
    required this.currentTab,
    required this.labelOf,
    required this.onTap,
  });

  final List<HomeWorkbenchTab> tabs;
  final HomeWorkbenchTab currentTab;
  final String Function(HomeWorkbenchTab) labelOf;
  final void Function(HomeWorkbenchTab) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelMedium = Theme.of(context).textTheme.labelMedium;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((tab) {
          final isSelected = tab == currentTab;
          return InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => onTap(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? scheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                labelOf(tab),
                style: labelMedium?.copyWith(
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
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
