import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
import 'package:oasx/modules/home/widgets/config_state_indicator.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/home/widgets/statistics_panel.dart';
import 'package:oasx/modules/home/widgets/storage_stats_panel.dart';
import 'package:oasx/modules/home/widgets/task_catalog_panel.dart';
import 'package:oasx/modules/home/widgets/task_status_panel.dart';
import 'package:oasx/modules/home/widgets/workbench_sidebar_panel.dart';
import 'package:oasx/translation/i18n_content.dart';

class ActiveConfigPanel extends StatelessWidget {
  const ActiveConfigPanel({
    super.key,
    required this.controller,
    required this.layoutMode,
    required this.onChangeTab,
    required this.onOpenTask,
    required this.onTogglePower,
    required this.onRenameScript,
    required this.onDeleteScript,
    required this.onSetNextRun,
    required this.onQuickRun,
    required this.onQuickWait,
    required this.onBulkQuickRun,
    required this.onBulkQuickWait,
    this.onExpandRightSidebar,
    this.onBackToScripts,
  });

  final HomeDashboardController controller;
  final HomeWorkbenchLayoutMode layoutMode;
  final Future<void> Function(HomeWorkbenchTab tab) onChangeTab;
  final Future<void> Function(
    String taskName,
    HomeTaskParameterEntrySource source,
  )
  onOpenTask;
  final Future<void> Function(String scriptName, bool enable) onTogglePower;
  final Future<void> Function(String scriptName) onRenameScript;
  final Future<void> Function(String scriptName) onDeleteScript;
  final Future<void> Function(String taskName, String nextRun) onSetNextRun;
  final Future<void> Function(String taskName) onQuickRun;
  final Future<void> Function(String taskName) onQuickWait;
  final Future<void> Function() onBulkQuickRun;
  final Future<void> Function() onBulkQuickWait;
  final VoidCallback? onExpandRightSidebar;
  final VoidCallback? onBackToScripts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Obx(() {
          final script = controller.activeScriptModel;
          final currentTab = controller.displayedWorkbenchTabFor(layoutMode);
          final tabs = controller.workbenchTabsFor(layoutMode);
          if (script == null) {
            return Center(child: Text(I18n.homeNoScriptSelected.tr));
          }
          final isRunning = script.state.value == ScriptState.running;
          final bulkMode = controller.bulkQuickScheduleMode.value;
          final hasBulkTasks = controller
              .quickSchedulableTaskNamesFor(script)
              .isNotEmpty;
          final isBulkIdle = bulkMode == HomeBulkQuickScheduleMode.none;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onBackToScripts != null)
                    IconButton(
                      tooltip: I18n.scriptList.tr,
                      onPressed: onBackToScripts,
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ConfigStateIndicator(
                    state: controller.scriptStateFor(script),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      script.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _BulkQuickScheduleButton(
                    icon: Icons.flash_on_rounded,
                    tooltip: I18n.homeQuickRunAll.tr,
                    loading: bulkMode == HomeBulkQuickScheduleMode.runNow,
                    onPressed: isBulkIdle && hasBulkTasks
                        ? onBulkQuickRun
                        : null,
                  ),
                  _BulkQuickScheduleButton(
                    icon: Icons.schedule_rounded,
                    tooltip: I18n.homeQuickWaitAll.tr,
                    loading: bulkMode == HomeBulkQuickScheduleMode.waitNow,
                    onPressed: isBulkIdle && hasBulkTasks
                        ? onBulkQuickWait
                        : null,
                  ),
                  IconButton(
                    tooltip: isRunning ? I18n.stop.tr : I18n.run.tr,
                    onPressed: () => onTogglePower(script.name, !isRunning),
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      Icons.power_settings_new_rounded,
                      color: isRunning
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (onExpandRightSidebar != null) const SizedBox(width: 4),
                  if (onExpandRightSidebar != null)
                    IconButton.filledTonal(
                      key: const ValueKey<String>(
                        'home-workbench-expand-right-sidebar',
                      ),
                      tooltip: I18n.homeRestoreSidebar.tr,
                      onPressed: onExpandRightSidebar,
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: const Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _PillTabSwitch<HomeWorkbenchTab>(
                tabs: tabs,
                currentTab: currentTab,
                labelOf: _tabLabel,
                onTap: onChangeTab,
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildTabContent(script, currentTab)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(ScriptModel script, HomeWorkbenchTab currentTab) {
    return switch (currentTab) {
      HomeWorkbenchTab.status => TaskStatusPanel(
        controller: controller,
        scriptModel: script,
        canQuickScheduleTask: (taskName) =>
            controller.canQuickScheduleTask(script, taskName),
        onSetNextRun: onSetNextRun,
        onQuickRun: onQuickRun,
        onQuickWait: onQuickWait,
        onEditTask: (taskName) =>
            onOpenTask(taskName, HomeTaskParameterEntrySource.overview),
      ),
      HomeWorkbenchTab.tasks => TaskCatalogPanel(
        controller: controller,
        scriptModel: script,
        onOpenTask: (taskName) =>
            onOpenTask(taskName, HomeTaskParameterEntrySource.tasks),
        onQuickRun: onQuickRun,
        onQuickWait: onQuickWait,
      ),
      HomeWorkbenchTab.stats => const ScriptStatisticsPanel(),
      HomeWorkbenchTab.logs => LogCenterPanel(scriptName: script.name),
      HomeWorkbenchTab.storageStats => StorageStatsPanel(
        scriptName: script.name,
      ),
      HomeWorkbenchTab.clickStats => WorkbenchClickStatisticsPanel(
        scriptName: script.name,
      ),
    };
  }

  String _tabLabel(HomeWorkbenchTab value) {
    return switch (value) {
      HomeWorkbenchTab.status => I18n.overview.tr,
      HomeWorkbenchTab.tasks => I18n.homeTasksTab.tr,
      HomeWorkbenchTab.stats => I18n.homeStatsTab.tr,
      HomeWorkbenchTab.logs => I18n.log.tr,
      HomeWorkbenchTab.storageStats => I18n.storageStatsTab.tr,
      HomeWorkbenchTab.clickStats => I18n.homeClickStatsTab.tr,
    };
  }
}

class _BulkQuickScheduleButton extends StatelessWidget {
  const _BulkQuickScheduleButton({
    required this.icon,
    required this.tooltip,
    required this.loading,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: loading ? null : onPressed,
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: loading
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            )
          : Icon(icon, color: scheme.onSurfaceVariant),
    );
  }
}

/// 胶囊风格 Tab 切换条，与日志/统计面板保持一致。
class _PillTabSwitch<T> extends StatelessWidget {
  const _PillTabSwitch({
    required this.tabs,
    required this.currentTab,
    required this.labelOf,
    required this.onTap,
  });

  final List<T> tabs;
  final T currentTab;
  final String Function(T) labelOf;
  final void Function(T) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((tab) {
            final isSelected = tab == currentTab;
            return InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onTap(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  labelOf(tab),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
