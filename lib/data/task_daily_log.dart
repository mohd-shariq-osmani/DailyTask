class TaskDailyLog {
  final String date; // "yyyy-MM-dd"
  final int taskId;
  final String taskTitle;
  final bool isCompleted;
  final String colorHex;

  TaskDailyLog({
    required this.date,
    required this.taskId,
    required this.taskTitle,
    required this.isCompleted,
    required this.colorHex,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'isCompleted': isCompleted ? 1 : 0,
      'colorHex': colorHex,
    };
  }

  factory TaskDailyLog.fromMap(Map<String, dynamic> map) {
    return TaskDailyLog(
      date: map['date'] as String,
      taskId: map['taskId'] as int,
      taskTitle: map['taskTitle'] as String,
      isCompleted: (map['isCompleted'] as int) == 1,
      colorHex: map['colorHex'] as String,
    );
  }
}
