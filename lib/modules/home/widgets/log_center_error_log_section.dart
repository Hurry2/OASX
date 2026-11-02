part of 'log_center_panel.dart';

extension _LogCenterErrorDetailLogSectionX on LogCenterErrorDetailView {
  /// 单行最多渲染这么多字符：文本布局对超长行极其昂贵（一行几百万字符会直接冻住界面）。
  /// 完整内容仍然可以通过长按复制 / 保存报告拿到。
  static const int _maxRenderedLineChars = 8192;

  /// Builds the log slivers with progressive state feedback.
  List<Widget> _buildLogSlivers(BuildContext context) {
    final lines = controller.selectedErrorLogLines;
    final preparing = controller.errorLogPreparing.value;
    if (lines.isEmpty) {
      if (controller.errorMessage.value.isNotEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(controller.errorMessage.value)),
          ),
        ];
      }
      if (preparing) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }
      return const [SliverToBoxAdapter(child: SizedBox.shrink())];
    }
    final wrapLines = controller.wrapLines.value;
    return [
      if (preparing || controller.errorLogAppending.value)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        ),
      // 必须虚拟化: 报错日志可能有几万行（见过 19k 行 / 3MB 的），
      // 用 Column 一次性构建会直接把界面卡死。
      SliverList.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final rendered = line.length > _maxRenderedLineChars
              ? '${line.substring(0, _maxRenderedLineChars)} …'
              : line;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _openCopyDialog(context),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: LogCenterLogText(
                line: rendered,
                maxLines: wrapLines ? null : 1,
                overflow: wrapLines
                    ? TextOverflow.clip
                    : TextOverflow.visible,
                softWrap: wrapLines,
              ),
            ),
          );
        },
      ),
    ];
  }

  /// Opens the dedicated copy dialog with the current error-detail log body.
  void _openCopyDialog(BuildContext context) {
    showLogCenterCopyDialog(
      context,
      text: controller.selectedErrorLogText,
      onCopy: controller.copyText,
    );
  }

  /// Resolves one best-effort monospace width for horizontal scrolling.
  double _resolveContentWidth(
    BuildContext context,
    double viewportWidth,
    int widthScore,
  ) {
    final fontSize = Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14;
    final estimatedWidth = widthScore * fontSize * 0.64 + 48;
    return estimatedWidth < viewportWidth ? viewportWidth : estimatedWidth;
  }
}
