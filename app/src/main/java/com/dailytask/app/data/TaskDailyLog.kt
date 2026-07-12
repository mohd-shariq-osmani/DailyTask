package com.dailytask.app.data

import androidx.room.Entity

@Entity(tableName = "task_daily_log", primaryKeys = ["date", "taskId"])
data class TaskDailyLog(
    val date: String, // "yyyy-MM-dd"
    val taskId: Long, // Changed from Int to Long to match Task.id
    val taskTitle: String,
    val isCompleted: Boolean,
    val colorHex: String
)
