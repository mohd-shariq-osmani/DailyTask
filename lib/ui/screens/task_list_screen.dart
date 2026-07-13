import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/task.dart';
import '../../theme/colors.dart';
import '../../viewmodel/task_provider.dart';
import 'stats_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _taskController = TextEditingController();

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  String _getCurrentDateStr() {
    final now = DateTime.now();
    final weekdays = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    final months = [
      "JAN", "FEB", "MAR", "APR", "MAY", "JUN",
      "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"
    ];
    return "${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}";
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.tasks;

    final total = tasks.length;
    final completed = tasks.where((t) => t.isCompleted).length;
    final left = total - completed;
    final progress = total > 0 ? completed / total : 0.0;

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Container(
          decoration: BoxDecoration(
            color: darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: glassBorder, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            _getCurrentDateStr().toUpperCase(),
            style: const TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ),
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Icon(
            Icons.check_circle,
            color: accentViolet,
            size: 28,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: textSecondary, size: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // ── Ambient Glow Blobs ──
          Positioned(
            left: -80,
            top: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accentViolet.withOpacity(0.06),
                    Colors.transparent,
                  ],
                  radius: 0.6,
                ),
              ),
            ),
          ),
          Positioned(
            right: -80,
            bottom: -60,
            child: Container(
              width: 260,
              height: 260,
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

          // ── Main Content Column ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                
                // Title
                Row(
                  children: const [
                    Text(
                      "Daily",
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      "Task",
                      style: TextStyle(
                        color: accentViolet,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  "Stay consistent. Build habits.",
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Progress Bar ──
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "PROGRESS",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          "$completed / $total",
                          style: const TextStyle(
                            color: accentVioletLight,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 8,
                        color: darkSurface,
                        width: double.infinity,
                        alignment: Alignment.centerLeft,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          width: MediaQuery.of(context).size.width * progress,
                          height: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [accentViolet, accentVioletLight],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Section Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "TODAY'S TASKS",
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (tasks.isNotEmpty)
                      Text(
                        "$left remaining",
                        style: TextStyle(
                          color: left == 0 ? greenAccent : textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Tasks Checklist ──
                Expanded(
                  child: tasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.check_circle_outline,
                                color: Color(0x336B7280),
                                size: 56,
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No tasks yet",
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Tap the button below to add your first task",
                                style: TextStyle(
                                  color: Color(0x996B7280),
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: ReorderableListView.builder(
                            itemCount: tasks.length,
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex -= 1;
                              provider.swapTasksLocal(oldIndex, newIndex);
                              provider.saveTaskOrder();
                            },
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return Dismissible(
                                key: ValueKey(task.id),
                                direction: DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  return await _showDeleteConfirmDialog(context, task);
                                },
                                onDismissed: (direction) {
                                  if (task.id != null) {
                                    provider.deleteTask(task.id!);
                                  }
                                },
                                background: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: redAccent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 28),
                                  alignment: Alignment.centerRight,
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: _buildTaskCard(provider, task),
                                ),
                              );
                            },
                          ),
                        ),
                ),

                // ── Bottom Button Row ──
                Row(
                  children: [
                    // Reset Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => provider.resetDay(),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: darkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: glassBorder, width: 1),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.refresh, color: textSecondary, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Reset day",
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Add Task Button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showAddTaskDialog(context, provider),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [accentViolet, accentVioletLight],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Add task",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Task Card Builder ──
  Widget _buildTaskCard(TaskProvider provider, Task task) {
    Color taskColor;
    try {
      taskColor = Color(int.parse(task.colorHex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      taskColor = accentViolet;
    }

    return GestureDetector(
      onTap: () => provider.toggleTask(task),
      child: Container(
        decoration: BoxDecoration(
          color: darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: glassBorder, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          children: [
            // Custom checkbox
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: task.isCompleted ? taskColor : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: task.isCompleted ? Colors.transparent : taskColor.withOpacity(0.4),
                  width: task.isCompleted ? 0 : 2,
                ),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),

            // Task title
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      color: task.isCompleted ? textTertiary : textPrimary,
                      fontSize: 16,
                      fontWeight: task.isCompleted ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  if (task.isCompleted)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Container(
                          height: 2,
                          color: taskColor.withOpacity(0.6),
                          width: double.infinity,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Color indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.isCompleted ? taskColor.withOpacity(0.3) : taskColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Swipe Delete Confirmation dialog ──
  Future<bool> _showDeleteConfirmDialog(BuildContext context, Task task) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: darkSurface,
          shape: RoundedCornerShape(20),
          title: const Text(
            "Delete Task",
            style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to delete \"${task.title}\"? This action cannot be undone.",
            style: const TextStyle(color: textSecondary, fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel", style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: redAccent,
                shape: RoundedCornerShape(12),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  // ── Add Task modal dialog ──
  void _showAddTaskDialog(BuildContext context, TaskProvider provider) {
    _taskController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: darkSurface,
          shape: RoundedCornerShape(24),
          title: Row(
            children: const [
              Icon(Icons.add, color: accentViolet, size: 22),
              SizedBox(width: 10),
              Text(
                "New Task",
                style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            child: TextField(
              controller: _taskController,
              autofocus: true,
              style: const TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: "Enter task name...",
                hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                filled: true,
                fillColor: darkSurfaceVariant,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: accentViolet, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: glassBorder, width: 1),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentViolet,
                shape: RoundedCornerShape(14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () {
                final name = _taskController.text.trim();
                if (name.isNotEmpty) {
                  final randomColor = presetTaskColors[Random().nextInt(presetTaskColors.length)];
                  provider.addTask(name, randomColor);
                }
                Navigator.pop(context);
              },
              child: const Text("Add Task", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

// Helper RoundedCornerShape class to keep standard border radius syntax clean
class RoundedCornerShape extends RoundedRectangleBorder {
  RoundedCornerShape(double radius)
      : super(borderRadius: BorderRadius.circular(radius));
}
