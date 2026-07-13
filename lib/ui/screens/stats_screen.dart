import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/task.dart';
import '../../data/task_completion_history.dart';
import '../../data/task_daily_log.dart';
import '../../theme/colors.dart';
import '../../viewmodel/task_provider.dart';
import 'task_list_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _statsTab = 0; // 0 = Overview, 1 = Task Analysis
  int _activeTab = 0; // 0 = Days, 1 = Weeks, 2 = Months

  int _dayLimit = 7;
  int _weekLimit = 8;
  int _monthLimit = 6;

  int? _selectedIndex;
  List<TaskDailyLog> _selectedDayLogs = [];
  bool _isLoadingLogs = false;

  // ── Date parsing & formatting utilities ──
  DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDateString(DateTime date, String format) {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final fullMonths = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];
    final weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    final shortWeekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

    if (format == "d MMM") {
      return "${date.day} ${months[date.month - 1]}";
    } else if (format == "E") {
      return shortWeekdays[date.weekday - 1];
    } else if (format == "d MMM yyyy") {
      return "${date.day} ${months[date.month - 1]} ${date.year}";
    } else if (format == "EEEE, d MMMM yyyy") {
      return "${weekdays[date.weekday - 1]}, ${date.day} ${fullMonths[date.month - 1]} ${date.year}";
    } else if (format == "MMM") {
      return months[date.month - 1];
    } else if (format == "MMMM yyyy") {
      return "${fullMonths[date.month - 1]} ${date.year}";
    }
    return date.toIso8601String().split('T')[0];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final history = provider.history;
    final currentTasks = provider.tasks;
    final dailyLogs = provider.dailyLogs;

    // 1. Compile history entries with today's live stats
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final combinedStats = List<TaskCompletionHistory>.from(history);
    
    if (combinedStats.indexWhere((h) => h.date == todayStr) == -1) {
      final total = currentTasks.length;
      if (total > 0) {
        final completed = currentTasks.where((t) => t.isCompleted).length;
        combinedStats.add(
          TaskCompletionHistory(
            date: todayStr,
            completedCount: completed,
            totalCount: total,
          ),
        );
      }
    }
    combinedStats.sort((a, b) => a.date.compareTo(b.date));

    // 2. Day-wise points calculation
    final dayPoints = combinedStats.map((entry) {
      final date = _parseDate(entry.date);
      final pct = entry.totalCount > 0 ? entry.completedCount / entry.totalCount : 0.0;
      return StatPoint(
        id: entry.date,
        label: _formatDateString(date, "d"),
        completedCount: entry.completedCount,
        totalCount: entry.totalCount,
        percentage: pct.toDouble(),
        rawDateDescription: _formatDateString(date, "EEEE, d MMMM yyyy"),
      );
    }).toList();

    // 3. Weekly points calculation
    final Map<String, List<TaskCompletionHistory>> weeklyGroup = {};
    for (final entry in combinedStats) {
      final date = _parseDate(entry.date);
      // Find start of week (Monday)
      final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
      final weekStr = startOfWeek.toIso8601String().split('T')[0];
      weeklyGroup.putIfAbsent(weekStr, () => []).add(entry);
    }
    final weekPoints = weeklyGroup.entries.map((group) {
      final monday = DateTime.parse(group.key);
      final sunday = monday.add(const Duration(days: 6));
      final completed = group.value.fold(0, (sum, item) => sum + item.completedCount);
      final total = group.value.fold(0, (sum, item) => sum + item.totalCount);
      final pct = total > 0 ? completed / total : 0.0;
      final rangeLabel = "${_formatDateString(monday, "d MMM")} - ${_formatDateString(sunday, "d MMM")}";
      return StatPoint(
        id: group.key,
        label: _formatDateString(monday, "d MMM"),
        completedCount: completed,
        totalCount: total,
        percentage: pct.toDouble(),
        rawDateDescription: "Week of $rangeLabel",
      );
    }).toList()..sort((a, b) => a.id.compareTo(b.id));

    // 4. Monthly points calculation
    final Map<String, List<TaskCompletionHistory>> monthlyGroup = {};
    for (final entry in combinedStats) {
      final date = _parseDate(entry.date);
      final monthStr = "${date.year}-${date.month.toString().padLeft(2, '0')}";
      monthlyGroup.putIfAbsent(monthStr, () => []).add(entry);
    }
    final monthPoints = monthlyGroup.entries.map((group) {
      final parts = group.key.split('-');
      final yearMonthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      final completed = group.value.fold(0, (sum, item) => sum + item.completedCount);
      final total = group.value.fold(0, (sum, item) => sum + item.totalCount);
      final pct = total > 0 ? completed / total : 0.0;
      return StatPoint(
        id: group.key,
        label: _formatDateString(yearMonthDate, "MMM"),
        completedCount: completed,
        totalCount: total,
        percentage: pct.toDouble(),
        rawDateDescription: _formatDateString(yearMonthDate, "MMMM yyyy"),
      );
    }).toList()..sort((a, b) => a.id.compareTo(b.id));

    // 5. Select target list based on tabs
    final displayPoints = _activeTab == 0
        ? dayPoints.reversed.take(_dayLimit).toList().reversed.toList()
        : _activeTab == 1
            ? weekPoints.reversed.take(_weekLimit).toList().reversed.toList()
            : monthPoints.reversed.take(_monthLimit).toList().reversed.toList();

    // 6. Selected indices bounds
    final activeSelectedIndex = _selectedIndex != null && _selectedIndex! < displayPoints.length
        ? _selectedIndex!
        : (displayPoints.length - 1).clamp(0, displayPoints.isNotEmpty ? displayPoints.length - 1 : 0);
    final activePoint = displayPoints.isNotEmpty ? displayPoints[activeSelectedIndex] : null;

    // Load logs for selected day
    if (activePoint != null && _activeTab == 0 && !_isLoadingLogs) {
      _isLoadingLogs = true;
      provider.getTaskLogsForDate(activePoint.id).then((logs) {
        if (mounted) {
          setState(() {
            if (logs.isEmpty) {
              // Fallback generator for old logs before version 3
              final entry = combinedStats.firstWhere((c) => c.date == activePoint.id);
              final List<TaskDailyLog> generated = [];
              for (int i = 1; i <= entry.totalCount; i++) {
                generated.add(
                  TaskDailyLog(
                    date: activePoint.id,
                    taskId: -i,
                    taskTitle: "Task $i",
                    isCompleted: i <= entry.completedCount,
                    colorHex: "#8B5CF6",
                  ),
                );
              }
              _selectedDayLogs = generated;
            } else {
              _selectedDayLogs = logs;
            }
            _isLoadingLogs = false;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Analytics Dashboard",
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Background Glow Blob
          Positioned(
            left: -80,
            bottom: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentVioletMuted.withOpacity(0.04),
                    Colors.transparent,
                  ],
                  radius: 0.6,
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // Top Tab Selector (Overview vs Task Analysis)
                _buildPrimaryTabRow(),
                const SizedBox(height: 18),

                Expanded(
                  child: _statsTab == 0
                      ? _buildOverviewTab(provider, displayPoints, activeSelectedIndex, activePoint, combinedStats)
                      : _buildTaskAnalysisTab(provider, combinedStats, dailyLogs, currentTasks),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Overview Tab Layout ──
  Widget _buildOverviewTab(
    TaskProvider provider,
    List<StatPoint> points,
    int selectedIndex,
    StatPoint? activePoint,
    List<TaskCompletionHistory> combinedStats,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // 1. Contribution Heatmap
        const Text(
          "CONSISTENCY HEATMAP",
          style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
        ),
        const SizedBox(height: 10),
        _buildContributionHeatmap(combinedStats, points),

        const SizedBox(height: 18),

        // 2. Granularity Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSegmentedTabController(),
            Row(
              children: [
                if (_activeTab == 0) ...[
                  _buildGranularityChip("7d", _dayLimit == 7, () => setState(() => _dayLimit = 7)),
                  const SizedBox(width: 6),
                  _buildGranularityChip("30d", _dayLimit == 30, () => setState(() => _dayLimit = 30)),
                ] else if (_activeTab == 1) ...[
                  _buildGranularityChip("4w", _weekLimit == 4, () => setState(() => _weekLimit = 4)),
                  const SizedBox(width: 6),
                  _buildGranularityChip("8w", _weekLimit == 8, () => setState(() => _weekLimit = 8)),
                ] else ...[
                  _buildGranularityChip("3m", _monthLimit == 3, () => setState(() => _monthLimit = 3)),
                  const SizedBox(width: 6),
                  _buildGranularityChip("6m", _monthLimit == 6, () => setState(() => _monthLimit = 6)),
                ]
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Canvas Line Graph
        _buildGraphCardContainer(points, selectedIndex),

        const SizedBox(height: 18),

        // 4. Details card
        if (activePoint != null) ...[
          _buildInteractiveDetailsCard(activePoint),
          const SizedBox(height: 18),
        ],

        // 5. Selected Day's Task List breakdown
        if (_activeTab == 0 && _selectedDayLogs.isNotEmpty) ...[
          const Text(
            "TASK BREAKDOWN",
            style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
          ),
          const SizedBox(height: 10),
          ..._selectedDayLogs.map((log) => _buildDayBreakdownTaskRow(log)).toList(),
          const SizedBox(height: 18),
        ],

        // 6. Metric summaries
        _buildInsightsGrid(combinedStats),
        const SizedBox(height: 18),

        // 7. Reset Analytics
        _buildResetHistoryButton(provider),
      ],
    );
  }

  // ── Task Analysis Tab Layout ──
  Widget _buildTaskAnalysisTab(
    TaskProvider provider,
    List<TaskCompletionHistory> combinedStats,
    List<TaskDailyLog> dailyLogs,
    List<Task> currentTasks,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        ...currentTasks.map((task) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: _buildTaskWiseAnalysisCard(task, combinedStats, dailyLogs),
            )).toList(),
        const SizedBox(height: 10),
        _buildResetHistoryButton(provider),
      ],
    );
  }

  // ── Primary Overview/Analysis Tab Row ──
  Widget _buildPrimaryTabRow() {
    return Row(
      children: [
        _buildPrimaryTabButton("Overview", _statsTab == 0, () => setState(() => _statsTab = 0)),
        _buildPrimaryTabButton("Task Analysis", _statsTab == 1, () => setState(() => _statsTab = 1)),
      ],
    );
  }

  Widget _buildPrimaryTabButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? accentViolet : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? accentVioletLight : textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // ── GitHub Contribution Heatmap ──
  Widget _buildContributionHeatmap(
    List<TaskCompletionHistory> combinedStats,
    List<StatPoint> points,
  ) {
    final today = DateTime.now();
    const weeksCount = 13;
    final startMonday = today.subtract(Duration(days: today.weekday - 1)).subtract(const Duration(days: 7 * (weeksCount - 1)));

    return Container(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: glassBorder, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Day labels
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text("M", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
              SizedBox(height: 14),
              Text("W", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
              SizedBox(height: 14),
              Text("F", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
              SizedBox(height: 14),
              Text("S", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 10),

          // Scrollable Grid of columns
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(weeksCount, (weekIdx) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 5.0),
                    child: Column(
                      children: List.generate(7, (dayIdx) {
                        final cellDate = startMonday.add(Duration(days: (weekIdx * 7) + dayIdx));
                        final isFuture = cellDate.isAfter(today);
                        final dateStr = cellDate.toIso8601String().split('T')[0];

                        // Find status matching this date
                        final stats = combinedStats.cast<TaskCompletionHistory?>().firstWhere(
                              (h) => h?.date == dateStr,
                              orElse: () => null,
                            );

                        final pct = stats != null && stats.totalCount > 0 ? stats.completedCount / stats.totalCount : 0.0;

                        Color cellColor;
                        if (isFuture) {
                          cellColor = Colors.transparent;
                        } else if (stats == null) {
                          cellColor = const Color(0x336B7280);
                        } else if (pct == 0) {
                          cellColor = darkSurfaceVariant;
                        } else if (pct <= 0.34) {
                          cellColor = accentViolet.withOpacity(0.2);
                        } else if (pct <= 0.67) {
                          cellColor = accentViolet.withOpacity(0.5);
                        } else if (pct < 1) {
                          cellColor = accentViolet.withOpacity(0.8);
                        } else {
                          cellColor = accentViolet;
                        }

                        return GestureDetector(
                          onTap: () {
                            if (!isFuture && stats != null) {
                              final idx = points.indexWhere((p) => p.id == dateStr);
                              if (idx != -1) {
                                setState(() {
                                  _activeTab = 0;
                                  _selectedIndex = idx;
                                });
                              }
                            }
                          },
                          child: Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(bottom: 5.0),
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Granularity selectors ──
  Widget _buildGranularityChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? accentViolet.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentViolet : glassBorder,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentVioletLight : textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Segmented Control tabs (D / W / M) ──
  Widget _buildSegmentedTabController() {
    final labels = ["D", "W", "M"];
    return Container(
      decoration: BoxDecoration(
        color: darkSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: glassBorder, width: 1),
      ),
      padding: const EdgeInsets.all(3),
      width: 150,
      child: Row(
        children: List.generate(3, (idx) {
          final active = _activeTab == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTab = idx;
                  _selectedIndex = null;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: active ? accentViolet : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 6),
                alignment: Alignment.center,
                child: Text(
                  labels[idx],
                  style: TextStyle(
                    color: active ? Colors.white : textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Canvas Graph Card ──
  Widget _buildGraphCardContainer(List<StatPoint> points, int selectedIndex) {
    return Container(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder, width: 1),
      ),
      padding: const EdgeInsets.only(top: 22, left: 16, right: 16, bottom: 12),
      child: points.isEmpty
          ? const SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  "Insufficient completion records.\nCheck back tomorrow!",
                  style: TextStyle(color: textSecondary, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final width = constraints.maxWidth;
                    const paddingLeft = 30.0;
                    const paddingRight = 12.0;
                    final graphWidth = width - paddingLeft - paddingRight;

                    if (points.length > 1 && details.localPosition.dx >= paddingLeft) {
                      final stepX = graphWidth / (points.length - 1);
                      final relativeX = details.localPosition.dx - paddingLeft;
                      final estimatedIndex = (relativeX / stepX).round().clamp(0, points.length - 1);
                      setState(() {
                        _selectedIndex = estimatedIndex;
                      });
                    }
                  },
                  child: CustomPaint(
                    size: const Size(double.infinity, 180),
                    painter: _StatsGraphPainter(
                      points: points,
                      selectedIndex: selectedIndex,
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ── Dynamic details card with Circular progress indicator ──
  Widget _buildInteractiveDetailsCard(StatPoint point) {
    final progressPct = (point.percentage * 100).toInt();

    return Container(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder, width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.rawDateDescription.toUpperCase(),
                  style: const TextStyle(
                    color: textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$progressPct% Completed",
                  style: const TextStyle(
                    color: accentVioletLight,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${point.completedCount} tasks done out of ${point.totalCount} total",
                  style: TextStyle(
                    color: textPrimary.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Custom circular loader widget
          SizedBox(
            width: 54,
            height: 54,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: point.percentage,
                completedCount: point.completedCount,
                totalCount: point.totalCount,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Task Card breakdown inside selected day list ──
  Widget _buildDayBreakdownTaskRow(TaskDailyLog log) {
    Color taskColor;
    try {
      taskColor = Color(int.parse(log.colorHex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      taskColor = accentViolet;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: glassBorder, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: log.isCompleted ? taskColor : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: log.isCompleted ? Colors.transparent : taskColor.withOpacity(0.4),
                width: log.isCompleted ? 0 : 1.5,
              ),
            ),
            child: log.isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              log.taskTitle,
              style: TextStyle(
                color: log.isCompleted ? textTertiary : textPrimary,
                fontSize: 15,
                fontWeight: log.isCompleted ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: log.isCompleted ? taskColor.withOpacity(0.15) : const Color(0x0CFFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              log.isCompleted ? "Completed" : "Incomplete",
              style: TextStyle(
                color: log.isCompleted ? taskColor : textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dynamic Insights grid calculation ──
  Widget _buildInsightsGrid(List<TaskCompletionHistory> combinedStats) {
    // 1. Most Productive Day of Week
    final dayOfWeekAverages = <int, List<double>>{};
    for (final stat in combinedStats) {
      final date = _parseDate(stat.date);
      final pct = stat.totalCount > 0 ? stat.completedCount / stat.totalCount : 0.0;
      dayOfWeekAverages.putIfAbsent(date.weekday, () => []).add(pct);
    }
    String bestDayText = "N/A";
    double bestDayAvg = 0;
    final weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    dayOfWeekAverages.forEach((weekday, list) {
      final avg = list.reduce((a, b) => a + b) / list.length;
      if (avg > bestDayAvg) {
        bestDayAvg = avg;
        bestDayText = "${weekdayNames[weekday - 1]} (${(avg * 100).toInt()}%)";
      }
    });

    // 2. Consistency Index
    int consistencyIndex = 0;
    if (combinedStats.isNotEmpty) {
      final perfectCount = combinedStats.where((h) => h.completedCount == h.totalCount && h.totalCount > 0).length;
      consistencyIndex = ((perfectCount / combinedStats.length) * 100).toInt();
    }

    // 3. Total Achievements
    final totalAchievements = combinedStats.fold(0, (sum, item) => sum + item.completedCount);

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: darkSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: glassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "BEST WORKDAY",
                  style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Text(
                  bestDayText,
                  style: const TextStyle(color: accentVioletLight, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Highest completion avg",
                  style: TextStyle(color: Color(0x996B7280), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: darkSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: glassBorder, width: 1),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "CONSISTENCY INDEX",
                  style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Text(
                  "$consistencyIndex%",
                  style: const TextStyle(color: greenAccent, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "$totalAchievements total tasks done",
                  style: const TextStyle(color: Color(0x996B7280), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Task Wise Analysis Card details calculations ──
  Widget _buildTaskWiseAnalysisCard(
    Task task,
    List<TaskCompletionHistory> combinedStats,
    List<TaskDailyLog> dailyLogs,
  ) {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    Color taskColor;
    try {
      taskColor = Color(int.parse(task.colorHex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      taskColor = accentViolet;
    }

    // Historical completion mapping
    final List<bool> completionList = combinedStats.map((entry) {
      if (entry.date == todayStr) {
        return task.isCompleted;
      } else {
        final log = dailyLogs.cast<TaskDailyLog?>().firstWhere(
              (l) => l?.date == entry.date && l?.taskTitle.toLowerCase() == task.title.toLowerCase(),
              orElse: () => null,
            );
        return log?.isCompleted ?? false;
      }
    }).toList();

    final totalLoggedDays = completionList.length;
    final totalCompletions = completionList.where((c) => c).length;
    final completionRate = totalLoggedDays > 0 ? ((totalCompletions / totalLoggedDays) * 100).toInt() : 0;

    // Current Streak
    int currentStreak = 0;
    for (int i = completionList.length - 1; i >= 0; i--) {
      if (completionList[i]) {
        currentStreak++;
      } else {
        if (i == completionList.length - 1 && combinedStats[i].date == todayStr) {
          continue; // Today incomplete, check starting from yesterday to keep active streak
        }
        break;
      }
    }

    // Max Streak
    int maxStreak = 0;
    int current = 0;
    for (final completed in completionList) {
      if (completed) {
        current++;
        if (current > maxStreak) maxStreak = current;
      } else {
        current = 0;
      }
    }

    // Consistent weekday
    final completedWeekdays = <int>[];
    for (int idx = 0; idx < completionList.length; idx++) {
      if (completionList[idx]) {
        completedWeekdays.add(_parseDate(combinedStats[idx].date).weekday);
      }
    }
    String preferredDayText = "N/A";
    if (completedWeekdays.isNotEmpty) {
      final groups = <int, int>{};
      for (final day in completedWeekdays) {
        groups[day] = (groups[day] ?? 0) + 1;
      }
      final sortedGroup = groups.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
      preferredDayText = weekdays[sortedGroup.first.key - 1];
    }

    // 7 days sparkline status
    final lastSevenList = completionList.reversed.take(7).toList().reversed.toList();

    return Container(
      decoration: BoxDecoration(
        color: darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glassBorder, width: 1),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: taskColor)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                "$completionRate% rate",
                style: const TextStyle(color: accentVioletLight, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Detail parameters
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOTAL LOGGED", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("$totalCompletions / $totalLoggedDays days", style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("STREAK", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("🔥 $currentStreak days", style: const TextStyle(color: accentVioletLight, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("BEST STREAK", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("🏆 $maxStreak days", style: const TextStyle(color: greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: glassBorder, height: 1),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("MOST CONSISTENT", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(preferredDayText, style: const TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),

              // 7 day circular sparkline tracker
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("LAST 7 DAYS", style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ...lastSevenList.map((completed) {
                        return Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(left: 5.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: completed ? taskColor : Colors.transparent,
                            border: Border.all(
                              color: completed ? Colors.transparent : taskColor.withOpacity(0.35),
                              width: completed ? 0 : 1.5,
                            ),
                          ),
                        );
                      }).toList(),
                      // padding circles
                      if (lastSevenList.length < 7)
                        ...List.generate(7 - lastSevenList.length, (index) {
                          return Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 5.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                              border: Border.all(color: glassBorder, width: 1),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Reset Database Analytics history button ──
  Widget _buildResetHistoryButton(TaskProvider provider) {
    return GestureDetector(
      onTap: () => _showResetAnalyticsDialog(context, provider),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: redAccent.withOpacity(0.35), width: 1),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_forever, color: redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              "Reset Analytics History",
              style: TextStyle(
                color: redAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetAnalyticsDialog(BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: darkSurface,
          shape: RoundedCornerShape(20),
          title: const Text(
            "Delete Past Analytics?",
            style: TextStyle(color: redAccent, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Are you sure you want to permanently clear all your past analytics data? This includes your completion trends, streak records, heatmap cells, and historical task-wise logs.\n\nWarning: Your current tasks will NOT be deleted, but your statistics will be completely reset. This action cannot be undone.",
            style: TextStyle(color: textSecondary, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: redAccent,
                shape: RoundedCornerShape(12),
              ),
              onPressed: () {
                provider.clearAllAnalytics();
                Navigator.pop(context);
              },
              child: const Text("Reset History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

// ── Graph Painter ──
class _StatsGraphPainter extends CustomPainter {
  final List<StatPoint> points;
  final int selectedIndex;

  _StatsGraphPainter({required this.points, required this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    const paddingLeft = 30.0;
    const paddingRight = 12.0;
    const paddingTop = 14.0;
    const paddingBottom = 26.0;

    final graphWidth = size.width - paddingLeft - paddingRight;
    final graphHeight = size.height - paddingTop - paddingBottom;

    // Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1.0;

    const gridLines = 4;
    for (int i = 0; i <= gridLines; i++) {
      final y = paddingTop + graphHeight * (1.0 - (i / gridLines));
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );
    }

    // Step calculations
    final stepX = points.length > 1 ? graphWidth / (points.length - 1) : graphWidth;

    final completedPoints = List.generate(points.length, (idx) {
      final x = paddingLeft + idx * stepX;
      final y = paddingTop + graphHeight * (1.0 - points[idx].percentage);
      return Offset(x, y);
    });

    // 1. Draw Area Fill Under Line
    if (completedPoints.isNotEmpty) {
      final areaPath = Path()
        ..moveTo(completedPoints.first.dx, paddingTop + graphHeight);
      for (final pt in completedPoints) {
        areaPath.lineTo(pt.dx, pt.dy);
      }
      areaPath.lineTo(completedPoints.last.dx, paddingTop + graphHeight);
      areaPath.close();

      final areaPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(completedPoints.first.dx, completedPoints.map((p) => p.dy).reduce(min)),
          Offset(completedPoints.first.dx, paddingTop + graphHeight),
          [accentViolet.withOpacity(0.22), Colors.transparent],
        );
      canvas.drawPath(areaPath, areaPaint);
    }

    // 2. Draw Vertical Dashed Line for Selected Point
    if (selectedIndex < completedPoints.length) {
      final selPt = completedPoints[selectedIndex];
      final dashedPaint = Paint()
        ..color = accentVioletLight.withOpacity(0.5)
        ..strokeWidth = 1.0;

      const dashHeight = 5.0;
      const dashSpace = 5.0;
      double startY = paddingTop;
      while (startY < paddingTop + graphHeight) {
        canvas.drawLine(
          Offset(selPt.dx, startY),
          Offset(selPt.dx, startY + dashHeight),
          dashedPaint,
        );
        startY += dashHeight + dashSpace;
      }
    }

    // 3. Draw Connecting Line
    if (completedPoints.length > 1) {
      final linePath = Path()..moveTo(completedPoints.first.dx, completedPoints.first.dy);
      for (int i = 1; i < completedPoints.length; i++) {
        linePath.lineTo(completedPoints[i].dx, completedPoints[i].dy);
      }

      final linePaint = Paint()
        ..color = accentViolet
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.0;

      canvas.drawPath(linePath, linePaint);
    }

    // 4. Draw Timeline labels (x-axis)
    if (points.isNotEmpty) {
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      final List<int> labelIndices;
      if (points.length <= 6) {
        labelIndices = List.generate(points.length, (i) => i);
      } else {
        labelIndices = [0, points.length ~/ 2, points.length - 1];
      }

      for (final idx in labelIndices) {
        final pt = completedPoints[idx];
        final label = points[idx].label;

        textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(pt.dx - textPainter.width / 2, size.height - 18.0),
        );
      }
    }

    // 5. Draw interactive bullet dots
    for (int idx = 0; idx < completedPoints.length; idx++) {
      final pt = completedPoints[idx];
      final isSelected = idx == selectedIndex;

      if (isSelected) {
        // outer glow
        canvas.drawCircle(
          pt,
          9.0,
          Paint()..color = accentViolet.withOpacity(0.25),
        );
        // white highlight ring
        canvas.drawCircle(
          pt,
          6.0,
          Paint()..color = Colors.white,
        );
      }

      // inner dot
      canvas.drawCircle(
        pt,
        4.5,
        Paint()..color = darkSurface,
      );
      canvas.drawCircle(
        pt,
        3.0,
        Paint()..color = isSelected ? accentViolet : accentVioletLight,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StatsGraphPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.selectedIndex != selectedIndex;
  }
}

// ── Circular Progress Gauge Painter ──
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final int completedCount;
  final int totalCount;

  _CircularProgressPainter({
    required this.progress,
    required this.completedCount,
    required this.totalCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - 2;

    // Track circle
    final trackPaint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(center, radius, trackPaint);

    // Active arc
    final arcPaint = Paint()
      ..color = progress == 1.0 ? greenAccent : accentViolet
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      arcPaint,
    );

    // Text in center
    final textPainter = TextPainter(
      text: TextSpan(
        text: "$completedCount/$totalCount",
        style: const TextStyle(
          color: textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.completedCount != completedCount ||
        oldDelegate.totalCount != totalCount;
  }
}

// ── StatPoint Data Model ──
class StatPoint {
  final String id;
  final String label;
  final int completedCount;
  final int totalCount;
  final double percentage;
  final String rawDateDescription;

  StatPoint({
    required this.id,
    required this.label,
    required this.completedCount,
    required this.totalCount,
    required this.percentage,
    required this.rawDateDescription,
  });
}
