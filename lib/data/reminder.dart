class Reminder {
  final int? id;
  final String title;
  final bool isCompleted;
  final String colorHex;

  Reminder({
    this.id,
    required this.title,
    this.isCompleted = false,
    this.colorHex = '#8B5CF6',
  });

  Reminder copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    String? colorHex,
  }) {
    return Reminder(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'colorHex': colorHex,
    };
  }

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      title: map['title'] as String,
      isCompleted: (map['isCompleted'] as int) == 1,
      colorHex: map['colorHex'] as String,
    );
  }
}
