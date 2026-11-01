part of 'dashboard_controller.dart';

extension HomeDashboardLayoutX on HomeDashboardController {
  /// Returns the persisted collection width after sanitizing the stored value.
  void _loadWorkbenchCollectionWidth() {
    final storedWidth =
        _storage.read(StorageKey.homeWorkbenchCollectionWidth.name);
    workbenchCollectionWidth.value =
        sanitizeHomeWorkbenchCollectionWidth(storedWidth);
  }

  /// Persists the latest valid collection width.
  void setWorkbenchCollectionWidth(double value) {
    final normalized = sanitizeHomeWorkbenchCollectionWidth(value);
    if ((workbenchCollectionWidth.value - normalized).abs() < 0.0001) {
      return;
    }
    workbenchCollectionWidth.value = normalized;
    _storage.write(StorageKey.homeWorkbenchCollectionWidth.name, normalized);
  }

  /// Returns the persisted split ratio after sanitizing the stored value.
  void _loadWorkbenchSplitRatio() {
    final storedRatio = _storage.read(StorageKey.homeWorkbenchSplitRatio.name);
    workbenchSplitRatio.value = sanitizeHomeWorkbenchSplitRatio(storedRatio);
  }

  /// Persists the latest valid three-pane split ratio.
  void setWorkbenchSplitRatio(double value) {
    final normalized = sanitizeHomeWorkbenchSplitRatio(value);
    if ((workbenchSplitRatio.value - normalized).abs() < 0.0001) {
      return;
    }
    workbenchSplitRatio.value = normalized;
    _storage.write(StorageKey.homeWorkbenchSplitRatio.name, normalized);
  }

  /// Returns the persisted right sidebar collapse state.
  void _loadWorkbenchSidebarCollapsed() {
    workbenchSidebarCollapsed.value =
        _storage.read(StorageKey.homeWorkbenchSidebarCollapsed.name) == true;
  }

  /// Persists whether the desktop right sidebar is collapsed.
  void setWorkbenchSidebarCollapsed(bool value) {
    if (workbenchSidebarCollapsed.value == value) {
      return;
    }
    workbenchSidebarCollapsed.value = value;
    _storage.write(StorageKey.homeWorkbenchSidebarCollapsed.name, value);
  }
}
