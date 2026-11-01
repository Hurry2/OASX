import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/click_statistics/click_statistics_controller.dart';
import 'package:oasx/modules/click_statistics/click_statistics_view.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/home/widgets/statistics_panel.dart';
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
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tabs
                          .map(
                            (tab) => ChoiceChip(
                              label: Text(_tabLabel(tab)),
                              showCheckmark: false,
                              selected: currentTab == tab,
                              onSelected: (_) => controller
                                  .setActiveWorkbenchSidebarTabValue(tab),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const ValueKey<String>(
                      'home-workbench-collapse-right-sidebar',
                    ),
                    tooltip: I18n.homeCollapseSidebar.tr,
                    onPressed: onCollapse,
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
            ],
          );
        }),
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
