package com.dailytask.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "task_history")
data class TaskCompletionHistory(
    @PrimaryKey
    val date: String, // format: "yyyy-MM-dd"
    val completedCount: Int,
    val totalCount: Int
)
