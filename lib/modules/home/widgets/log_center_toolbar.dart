part of 'log_center_panel.dart';

/// Header controls for the log center.
class LogCenterToolbar extends StatelessWidget {
  /// Creates toolbar controls.
  const LogCenterToolbar({
    super.key,
    required this.controller,
    required this.onToggleLineWrap,
  });

  /// Log browser controller.
  final ScriptLogBrowserController controller;

  /// Toggles wrapping with panel-level scroll handling.
  final VoidCallback onToggleLineWrap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _leadingControls(context)),
        const SizedBox(width: 8),
        _trailingControls(),
      ],
    );
  }

  /// Builds title and tab switch on the left.
  Widget _leadingControls(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Icons.article_outlined, size: 16, color: scheme.primary),
        const SizedBox(width: 6),
        Text(
          I18n.log.tr,
          style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        _tabSwitch(context),
      ],
    );
  }

  /// Builds action buttons aligned to the right.
  Widget _trailingControls() {
    return Obx(() {
      if (!_shouldShowLogActions()) {
        return const SizedBox.shrink();
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_shouldShowWrapAction()) _wrapButton(),
          if (controller.activeTab.value == ScriptLogBrowserTab.info)
            _autoScrollButton(),
          _copyButton(),
          _clearButton(),
        ],
      );
    });
  }

  /// Returns whether the current view owns log text actions.
  bool _shouldShowLogActions() {
    if (controller.activeTab.value == ScriptLogBrowserTab.info) {
      return true;
    }
    return controller.errorDetailVisible.value;
  }

  /// Returns whether wrapping can affect the current log text.
  bool _shouldShowWrapAction() {
    if (controller.activeTab.value == ScriptLogBrowserTab.info) {
      return true;
    }
    return controller.errorDetailVisible.value;
  }

  /// Builds the info/error tab selector matching the compact pill switch style.
  Widget _tabSwitch(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final active = controller.activeTab.value;
      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogTabPill(
              label: I18n.homeLogInfoTab.tr,
              selected: active == ScriptLogBrowserTab.info,
              onTap: () => controller.selectTab(ScriptLogBrowserTab.info),
            ),
            _LogTabPill(
              label: I18n.homeLogErrorTab.tr,
              selected: active == ScriptLogBrowserTab.error,
              onTap: () => controller.selectTab(ScriptLogBrowserTab.error),
            ),
          ],
        ),
      );
    });
  }

  Widget _autoScrollButton() {
    final enabled = controller.autoScroll.value;
    return _CompactToolbarIcon(
      tooltip: I18n.homeLogAutoScroll.tr,
      onPressed: controller.toggleAutoScroll,
      icon: enabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
      active: enabled,
    );
  }

  /// Builds the long-line wrapping action.
  Widget _wrapButton() {
    final enabled = controller.wrapLines.value;
    return _CompactToolbarIcon(
      tooltip: I18n.homeLogWrapLines.tr,
      onPressed: onToggleLineWrap,
      icon: enabled ? Icons.wrap_text_rounded : Icons.short_text_rounded,
      active: enabled,
    );
  }

  /// Builds the copy action.
  Widget _copyButton() {
    return _CompactToolbarIcon(
      tooltip: I18n.copy.tr,
      onPressed: _copyCurrent,
      icon: Icons.copy_rounded,
    );
  }

  /// Builds the clear action.
  Widget _clearButton() {
    return _CompactToolbarIcon(
      tooltip: I18n.clearLog.tr,
      onPressed: controller.clearCurrentView,
      icon: Icons.delete_outlined,
    );
  }

  void _copyCurrent() {
    controller.copyCurrentView();
  }
}

class _LogTabPill extends StatelessWidget {
  const _LogTabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _CompactToolbarIcon extends StatelessWidget {
  const _CompactToolbarIcon({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.active = false,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 28, height: 28),
      icon: Icon(
        icon,
        color: active ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}
