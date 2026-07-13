import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/task.dart';
import '../data/task_completion_history.dart';
import '../data/task_daily_log.dart';
import '../data/task_repository.dart';

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

  List<Task> get tasks => _tasks;
  List<TaskCompletionHistory> get history => _history;
  List<TaskDailyLog> get dailyLogs => _dailyLogs;

  bool _isDragging = false;

  TaskProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
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

  Future<void> syncWidgetDataWithLocalDatabase() async {
    try {
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
      debugPrint("Error syncing widget data: $e");
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
    notifyListeners();
    _refreshWidget();
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

  Future<List<TaskDailyLog>> getTaskLogsForDate(String dateStr) async {
    return await _repository.getTaskLogsForDate(dateStr);
  }
}
