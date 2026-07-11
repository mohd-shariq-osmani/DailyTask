package com.dailytask.app.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface TaskDao {
    // Tasks queries
    @Query("SELECT * FROM tasks ORDER BY displayOrder ASC")
    fun getAllTasksFlow(): Flow<List<Task>>

    @Query("SELECT * FROM tasks ORDER BY displayOrder ASC")
    suspend fun getAllTasks(): List<Task>

    @Query("SELECT MAX(displayOrder) FROM tasks")
    suspend fun getMaxDisplayOrder(): Int?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTask(task: Task): Long

    @Update
    suspend fun updateTask(task: Task)

    @Delete
    suspend fun deleteTask(task: Task)

    @Query("UPDATE tasks SET isCompleted = 0")
    suspend fun resetAllTasksCompletion()

    // History queries
    @Query("SELECT * FROM task_history ORDER BY date ASC")
    fun getAllHistoryFlow(): Flow<List<TaskCompletionHistory>>

    @Query("SELECT * FROM task_history ORDER BY date ASC")
    suspend fun getAllHistory(): List<TaskCompletionHistory>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertHistory(historyEntry: TaskCompletionHistory)
}
