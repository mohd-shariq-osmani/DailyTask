class Task {
  final int? id;
  final String title;
  final bool isCompleted;
  final int displayOrder;
  final String colorHex;

  Task({
    this.id,
    required this.title,
    this.isCompleted = false,
    this.displayOrder = 0,
    this.colorHex = '#8B5CF6',
  });

  Task copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    int? displayOrder,
    String? colorHex,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      displayOrder: displayOrder ?? this.displayOrder,
      colorHex: colorHex ?? this.colorHex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'displayOrder': displayOrder,
      'colorHex': colorHex,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      isCompleted: (map['isCompleted'] as int) == 1,
      displayOrder: map['displayOrder'] as int,
      colorHex: map['colorHex'] as String,
    );
  }
}
