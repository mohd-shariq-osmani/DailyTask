import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';
import 'task.dart';
import 'task_completion_history.dart';
import 'task_daily_log.dart';
import 'reminder.dart';

class TaskRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const String _keyLastActiveDate = "last_active_date";

  // ── Database Delegations ──
  Future<List<Task>> getTasks() => _dbHelper.getAllTasks();
  Future<int> insertTask(Task task) => _dbHelper.insertTask(task);
  Future<int> updateTask(Task task) => _dbHelper.updateTask(task);
  Future<int> deleteTask(int id) => _dbHelper.deleteTask(id);
  Future<List<TaskCompletionHistory>> getHistory() => _dbHelper.getAllHistory();
  Future<List<TaskDailyLog>> getDailyLogs() => _dbHelper.getAllDailyLogs();

  // ── Reminders Delegations ──
  Future<List<Reminder>> getActiveReminders() => _dbHelper.getActiveReminders();
  Future<List<String>> getReminderSuggestions() => _dbHelper.getReminderSuggestions();
  Future<int> insertReminder(Reminder reminder) => _dbHelper.insertReminder(reminder);
  Future<int> updateReminder(Reminder reminder) => _dbHelper.updateReminder(reminder);
  Future<int> deleteReminder(int id) => _dbHelper.deleteReminder(id);

  // ── custom date logs lookup ──
  Future<List<TaskDailyLog>> getTaskLogsForDate(String dateStr) async {
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    if (dateStr == todayStr) {
      final activeTasks = await getTasks();
      return activeTasks.map((task) {
        return TaskDailyLog(
          date: todayStr,
          taskId: task.id ?? 0,
          taskTitle: task.title,
          isCompleted: task.isCompleted,
          colorHex: task.colorHex,
        );
      }).toList();
    } else {
      return await _dbHelper.getDailyLogsForDate(dateStr);
    }
  }

  // ── Reset history ──
  Future<void> clearAllAnalyticsData() async {
    await _dbHelper.deleteAllHistory();
    await _dbHelper.deleteAllDailyLogs();
    
    // Reset date preference to today so fresh tracking starts now
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    await prefs.setString(_keyLastActiveDate, todayStr);
  }

  Future<void> resetCompletionStates() async {
    await _dbHelper.resetAllTasksCompletion();
  }

  // ── Midnight check and reset backfill logic ──
  Future<void> checkAndResetDailyTasks() async {
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];

    final prefs = await SharedPreferences.getInstance();
    final lastActiveStr = prefs.getString(_keyLastActiveDate);

    if (lastActiveStr == null) {
      // First time launch: save today's date
      await prefs.setString(_keyLastActiveDate, todayStr);
      return;
    }

    if (lastActiveStr != todayStr) {
      log("Date change detected! Last active: $lastActiveStr, Today: $todayStr");
      try {
        final lastActiveDate = DateTime.parse(lastActiveStr);
        // Calculate days between
        final daysBetween = today.difference(lastActiveDate).inDays;

        if (daysBetween > 0) {
          final currentTasks = await getTasks();
          final totalTasksCount = currentTasks.length;

          if (totalTasksCount > 0) {
            // 1. Log stats for the last active date
            final completedCount = currentTasks.where((t) => t.isCompleted).length;
            await _dbHelper.insertHistory(
              TaskCompletionHistory(
                date: lastActiveStr,
                completedCount: completedCount,
                totalCount: totalTasksCount,
              ),
            );

            // Log task logs for the last active date
            final dailyLogs = currentTasks.map((task) {
              return TaskDailyLog(
                date: lastActiveStr,
                taskId: task.id ?? 0,
                taskTitle: task.title,
                isCompleted: task.isCompleted,
                colorHex: task.colorHex,
              );
            }).toList();
            await _dbHelper.insertDailyLogs(dailyLogs);

            // 2. Backfill intermediate missed days
            for (int i = 1; i < daysBetween; i++) {
              final missedDate = lastActiveDate.add(Duration(days: i));
              final missedDateStr = missedDate.toIso8601String().split('T')[0];

              await _dbHelper.insertHistory(
                TaskCompletionHistory(
                  date: missedDateStr,
                  completedCount: 0,
                  totalCount: totalTasksCount,
                ),
              );

              // Log missed daily logs as incomplete
              final missedLogs = currentTasks.map((task) {
                return TaskDailyLog(
                  date: missedDateStr,
                  taskId: task.id ?? 0,
                  taskTitle: task.title,
                  isCompleted: false,
                  colorHex: task.colorHex,
                );
              }).toList();
              await _dbHelper.insertDailyLogs(missedLogs);
            }
          }

          // 3. Reset task completions in database
          await _dbHelper.resetAllTasksCompletion();
        }
      } catch (e) {
        log("Error performing daily task reset: $e");
      }

      // 4. Update the saved active date
      await prefs.setString(_keyLastActiveDate, todayStr);
    }
  }
}
