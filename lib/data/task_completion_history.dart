class TaskCompletionHistory {
  final int? id;
  final String date; // "yyyy-MM-dd"
  final int completedCount;
  final int totalCount;

  TaskCompletionHistory({
    this.id,
    required this.date,
    required this.completedCount,
    required this.totalCount,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'completedCount': completedCount,
      'totalCount': totalCount,
    };
  }

  factory TaskCompletionHistory.fromMap(Map<String, dynamic> map) {
    return TaskCompletionHistory(
      id: map['id'] as int?,
      date: map['date'] as String,
      completedCount: map['completedCount'] as int,
      totalCount: map['totalCount'] as int,
    );
  }
}
