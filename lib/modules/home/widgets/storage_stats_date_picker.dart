import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/widgets/statistics_formatters.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Pill radius matching the Material 3 segmented control used by the log tab.
const _kDateButtonRadius = 999.0;

/// Edge length of one day cell in the calendar.
const _kCalendarCell = 36.0;

/// Days rendered per week.
const _kCalendarColumns = 7;

/// Horizontal padding inside the calendar card.
const _kCalendarPadding = 12.0;

/// Width of the calendar card: 7 cells plus the padding.
const _kCalendarWidth =
    _kCalendarCell * _kCalendarColumns + _kCalendarPadding * 2;

/// Vertical gap between the date button and the popup.
const _kCalendarGap = 6.0;

/// Minimum distance the popup keeps from the window edges.
const _kCalendarMargin = 8.0;

/// Conservative height estimate used to decide whether to flip the popup up.
const _kCalendarMaxHeight = 320.0;

/// Date selector of the `纳物库` toolbar.
///
/// Only dates that actually carry a snapshot are selectable, so the calendar
/// doubles as a coverage map of what the backend has collected. The popup is
/// anchored to this button rather than centred, so it opens right next to the
/// date the user is looking at.
class StorageStatsDateButton extends StatefulWidget {
  /// Creates the storage date selector.
  const StorageStatsDateButton({
    super.key,
    required this.selected,
    required this.dates,
    required this.onSelected,
  });

  /// Date currently rendered, `YYYY-MM-DD`.
  final String selected;

  /// Every date that has a snapshot, newest first.
  final List<String> dates;

  /// Called with the picked `YYYY-MM-DD`.
  final ValueChanged<String> onSelected;

  @override
  State<StorageStatsDateButton> createState() => _StorageStatsDateButtonState();
}

class _StorageStatsDateButtonState extends State<StorageStatsDateButton> {
  /// Popup currently mounted in the overlay, or `null` when closed.
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: I18n.storageStatsDate.tr,
      child: InkWell(
        onTap: widget.dates.isEmpty ? null : _toggle,
        borderRadius: BorderRadius.circular(_kDateButtonRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kDateButtonRadius),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _buttonLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_drop_down_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Label rendered inside the button, falling back to the newest date.
  String _buttonLabel() {
    if (widget.dates.isEmpty) {
      return '--';
    }
    return formatStatisticsDayLabel(
      widget.selected.isNotEmpty ? widget.selected : widget.dates.first,
    );
  }

  /// Opens the popup, or closes it when it is already open.
  void _toggle() {
    if (_entry != null) {
      _removeEntry();
      return;
    }
    _show();
  }

  /// Unmounts the popup, if any.
  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  /// Inserts the calendar just below the button, clamped to the window.
  void _show() {
    final buttonBox = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) {
      return;
    }
    final origin = buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = MediaQuery.sizeOf(context);
    final maxLeft = math.max(
      _kCalendarMargin,
      size.width - _kCalendarWidth - _kCalendarMargin,
    );
    final left = origin.dx.clamp(_kCalendarMargin, maxLeft).toDouble();
    final below = origin.dy + buttonBox.size.height + _kCalendarGap;
    // The toolbar sits at the top of the panel, so opening downwards is the
    // normal case; flipping up only happens when the panel is pinned to the
    // bottom of a short window.
    final openUpwards =
        below + _kCalendarMaxHeight > size.height &&
        origin.dy - _kCalendarGap - _kCalendarMaxHeight > 0;
    _entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _removeEntry,
            ),
          ),
          Positioned(
            left: left,
            top: openUpwards ? null : below,
            bottom: openUpwards
                ? size.height - origin.dy + _kCalendarGap
                : null,
            width: _kCalendarWidth,
            child: _buildCard(overlayContext),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
  }

  /// Builds the calendar surface with its elevation and border.
  Widget _buildCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 8,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: _StorageCalendarCard(
        dates: widget.dates,
        selected: widget.selected,
        onSelected: (value) {
          _removeEntry();
          if (value != widget.selected) {
            widget.onSelected(value);
          }
        },
      ),
    );
  }
}

/// Compact month grid rendered inside the anchored popup.
///
/// Navigation is clamped to the months that actually hold snapshots, so the
/// arrows never lead into an empty month.
class _StorageCalendarCard extends StatefulWidget {
  const _StorageCalendarCard({
    required this.dates,
    required this.selected,
    required this.onSelected,
  });

  final List<String> dates;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<_StorageCalendarCard> createState() => _StorageCalendarCardState();
}

class _StorageCalendarCardState extends State<_StorageCalendarCard> {
  /// `日期(仅年月日) -> 后端原始 YYYY-MM-DD`，只含有快照的日期。
  final Map<DateTime, String> _byDay = <DateTime, String>{};

  /// 含有快照的月份，由旧到新。
  List<DateTime> _months = const <DateTime>[];

  /// 当前展示的月份在 [_months] 中的下标。
  int _monthIndex = 0;

  @override
  void initState() {
    super.initState();
    for (final date in widget.dates) {
      final parsed = DateTime.tryParse(date);
      if (parsed != null) {
        _byDay[DateUtils.dateOnly(parsed)] = date;
      }
    }
    if (_byDay.isEmpty) {
      return;
    }
    _months = <DateTime>{
      for (final day in _byDay.keys) DateTime(day.year, day.month),
    }.toList()..sort();
    final anchor = DateTime.tryParse(widget.selected) ?? _byDay.keys.first;
    final index = _months.indexOf(DateTime(anchor.year, anchor.month));
    _monthIndex = index < 0 ? _months.length - 1 : index;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_months.isEmpty) {
      return const SizedBox.shrink();
    }
    final month = _months[_monthIndex];
    return SizedBox(
      width: _kCalendarWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _kCalendarPadding,
          _kCalendarPadding - 4,
          _kCalendarPadding,
          _kCalendarPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme, month),
            const SizedBox(height: 4),
            _buildWeekdayRow(theme),
            const SizedBox(height: 2),
            _buildGrid(theme, month),
          ],
        ),
      ),
    );
  }

  /// Month title with the two navigation arrows.
  Widget _buildHeader(ThemeData theme, DateTime month) {
    return Row(
      children: [
        IconButton(
          onPressed: _monthIndex > 0
              ? () => setState(() => _monthIndex -= 1)
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: I18n.storageStatsDatePrevMonth.tr,
        ),
        Expanded(
          child: Text(
            I18n.storageStatsDateMonth.trParams({
              'year': '${month.year}',
              'month': '${month.month}',
            }),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
        IconButton(
          onPressed: _monthIndex + 1 < _months.length
              ? () => setState(() => _monthIndex += 1)
              : null,
          icon: const Icon(Icons.chevron_right_rounded),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
          tooltip: I18n.storageStatsDateNextMonth.tr,
        ),
      ],
    );
  }

  /// Weekday captions, Monday first to match the grid.
  Widget _buildWeekdayRow(ThemeData theme) {
    final labels = I18n.storageStatsDateWeekdays.tr.split(',');
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var column = 0; column < _kCalendarColumns; column++)
          SizedBox(
            width: _kCalendarCell,
            height: 22,
            child: Center(
              child: Text(
                column < labels.length ? labels[column] : '',
                style: style,
              ),
            ),
          ),
      ],
    );
  }

  /// The month grid, padded so the 1st lands on its real weekday.
  Widget _buildGrid(ThemeData theme, DateTime month) {
    final leading = DateTime(month.year, month.month).weekday - DateTime.monday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((leading + daysInMonth) / _kCalendarColumns).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var column = 0; column < _kCalendarColumns; column++)
                _buildCell(
                  theme,
                  _cellDate(month, leading, daysInMonth, row, column),
                ),
            ],
          ),
      ],
    );
  }

  /// Resolves the date of one grid cell, or `null` for the padding slots.
  DateTime? _cellDate(
    DateTime month,
    int leading,
    int daysInMonth,
    int row,
    int column,
  ) {
    final dayNumber = row * _kCalendarColumns + column - leading + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return null;
    }
    return DateTime(month.year, month.month, dayNumber);
  }

  /// One day cell: filled when selected, dimmed when the backend has no data.
  Widget _buildCell(ThemeData theme, DateTime? day) {
    if (day == null) {
      return const SizedBox(width: _kCalendarCell, height: _kCalendarCell);
    }
    return _buildDay(theme, day, _byDay[day]);
  }

  /// One day circle; [date] is `null` when the backend has no snapshot.
  Widget _buildDay(ThemeData theme, DateTime day, String? date) {
    final scheme = theme.colorScheme;
    final isSelected = date != null && date == widget.selected;
    final VoidCallback? onTap;
    if (date == null) {
      onTap = null;
    } else {
      // 提前取出非空值，避免闭包里依赖类型提升。
      final value = date;
      onTap = () => widget.onSelected(value);
    }
    final Color foreground;
    if (isSelected) {
      foreground = scheme.onPrimary;
    } else if (date != null) {
      foreground = scheme.onSurface;
    } else {
      foreground = scheme.onSurfaceVariant.withValues(alpha: 0.38);
    }
    return SizedBox(
      width: _kCalendarCell,
      height: _kCalendarCell,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: Container(
            width: _kCalendarCell - 6,
            height: _kCalendarCell - 6,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? scheme.primary : null,
              border: !isSelected && DateUtils.isSameDay(day, DateTime.now())
                  ? Border.all(color: scheme.primary.withValues(alpha: 0.6))
                  : null,
            ),
            child: Text(
              '${day.day}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: date != null ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
