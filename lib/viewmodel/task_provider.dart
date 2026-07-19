import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/task.dart';
import '../data/task_completion_history.dart';
import '../data/task_daily_log.dart';
import '../data/task_repository.dart';
import '../data/reminder.dart';

class TaskProvider extends ChangeNotifier with WidgetsBindingObserver {
  final TaskRepository _repository = TaskRepository();
  static const _channel = MethodChannel('com.dailytask/widget');

  Future<void> _refreshWidget() async {
    try {
      final total = _tasks.length;
      final completed = _tasks.where((t) => t.isCompleted).length;
      
      final tasksListMap = _tasks.map((t) => {
        'id': t.id ?? 0,
        'title': t.title,
        'isCompleted': t.isCompleted,
        'colorHex': t.colorHex,
      }).toList();

      final widgetData = {
        'tasks': tasksListMap,
        'completedCount': completed,
        'totalCount': total,
      };
      
      final jsonString = jsonEncode(widgetData);
      await _channel.invokeMethod('refreshWidget', jsonString);
    } catch (e) {
      debugPrint("Error refreshing widget: $e");
    }
  }

  List<Task> _tasks = [];
  List<TaskCompletionHistory> _history = [];
  List<TaskDailyLog> _dailyLogs = [];
  List<Reminder> _reminders = [];
  List<String> _suggestions = [];

  List<Task> get tasks => _tasks;
  List<TaskCompletionHistory> get history => _history;
  List<TaskDailyLog> get dailyLogs => _dailyLogs;
  List<Reminder> get reminders => _reminders;
  List<String> get suggestions => _suggestions;

  bool _isDragging = false;

  TaskProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetUpdated') {
        debugPrint("Widget updated, reloading data in app...");
        await loadAllData();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      syncWidgetDataWithLocalDatabase();
    }
  }

  Future<void> _refreshRemindersWidget() async {
    try {
      final remindersListMap = _reminders.map((r) => {
        'id': r.id ?? 0,
        'title': r.title,
        'isCompleted': r.isCompleted,
        'colorHex': r.colorHex,
      }).toList();

      final widgetData = {
        'reminders': remindersListMap,
        'totalCount': _reminders.length,
      };
      
      final jsonString = jsonEncode(widgetData);
      await _channel.invokeMethod('refreshRemindersWidget', jsonString);
    } catch (e) {
      debugPrint("Error refreshing reminders widget: $e");
    }
  }

  Future<void> syncWidgetDataWithLocalDatabase() async {
    try {
      // 1. Sync Tasks
      final String? jsonString = await _channel.invokeMethod('getWidgetData');
      if (jsonString != null && jsonString.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(jsonString);
        if (decoded.containsKey('tasks')) {
          final List<dynamic> widgetTasks = decoded['tasks'];
          bool dbUpdated = false;
          for (var wt in widgetTasks) {
            final int id = wt['id'];
            final bool isCompleted = wt['isCompleted'];
            
            final localTaskIndex = _tasks.indexWhere((t) => t.id == id);
            if (localTaskIndex != -1) {
              final localTask = _tasks[localTaskIndex];
              if (localTask.isCompleted != isCompleted) {
                final updatedTask = localTask.copyWith(isCompleted: isCompleted);
                await _repository.updateTask(updatedTask);
                dbUpdated = true;
              }
            }
          }
          if (dbUpdated) {
            await loadAllData();
          }
        }
      }
    } catch (e) {
      debugPrint("Error syncing task widget data: $e");
    }

    try {
      // 2. Sync Reminders
      final String? remindersJson = await _channel.invokeMethod('getRemindersData');
      if (remindersJson != null && remindersJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(remindersJson);
        if (decoded.containsKey('reminders')) {
          final List<dynamic> widgetReminders = decoded['reminders'];
          bool dbUpdated = false;
          
          for (var localReminder in _reminders) {
            final int id = localReminder.id ?? 0;
            final inWidget = widgetReminders.any((wr) => wr['id'] == id);
            if (!inWidget) {
              // Toggled completed and removed in widget!
              final updated = localReminder.copyWith(isCompleted: true);
              await _repository.updateReminder(updated);
              dbUpdated = true;
            }
          }
          if (dbUpdated) {
            await loadAllData();
          }
        }
      }
    } catch (e) {
      debugPrint("Error syncing reminders widget data: $e");
    }
  }

  Future<void> _init() async {
    await _repository.checkAndResetDailyTasks();
    await loadAllData();
  }

  Future<void> loadAllData() async {
    if (!_isDragging) {
      _tasks = await _repository.getTasks();
    }
    _history = await _repository.getHistory();
    _dailyLogs = await _repository.getDailyLogs();
    
    // Load reminders and suggestions
    _reminders = await _repository.getActiveReminders();
    _suggestions = await _repository.getReminderSuggestions();

    notifyListeners();
    _refreshWidget();
    _refreshRemindersWidget();
  }

  Future<void> addTask(String title, String colorHex) async {
    final newTask = Task(title: title, colorHex: colorHex);
    await _repository.insertTask(newTask);
    await loadAllData();
  }

  Future<void> toggleTask(Task task) async {
    final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
    await _repository.updateTask(updatedTask);
    await loadAllData();
  }

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
    await loadAllData();
  }

  // Local drag and drop swap for instant responsive animation
  void swapTasksLocal(int fromIndex, int toIndex) {
    _isDragging = true;
    if (fromIndex < _tasks.length && toIndex < _tasks.length) {
      final temp = _tasks[fromIndex];
      _tasks[fromIndex] = _tasks[toIndex];
      _tasks[toIndex] = temp;
      notifyListeners();
    }
  }

  // Persist order on drag end
  Future<void> saveTaskOrder() async {
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.displayOrder != i) {
        await _repository.updateTask(task.copyWith(displayOrder: i));
      }
    }
    _isDragging = false;
    await loadAllData();
  }

  Future<void> resetDay() async {
    await _repository.resetCompletionStates();
    await loadAllData();
  }

  Future<void> clearAllAnalytics() async {
    await _repository.clearAllAnalyticsData();
    await loadAllData();
  }

  // ── Reminders CRUD ──
  Future<void> addReminder(String title, String colorHex) async {
    final newReminder = Reminder(title: title, colorHex: colorHex);
    await _repository.insertReminder(newReminder);
    await loadAllData();
  }

  Future<void> toggleReminder(Reminder reminder) async {
    final updated = reminder.copyWith(isCompleted: !reminder.isCompleted);
    await _repository.updateReminder(updated);
    await loadAllData();
  }

  Future<void> deleteReminder(int id) async {
    await _repository.deleteReminder(id);
    await loadAllData();
  }

  Future<List<TaskDailyLog>> getTaskLogsForDate(String dateStr) async {
    return await _repository.getTaskLogsForDate(dateStr);
  }
}
