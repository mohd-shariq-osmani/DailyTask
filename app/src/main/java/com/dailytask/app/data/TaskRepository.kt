package com.dailytask.app.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

class TaskRepository(
    private val taskDao: TaskDao,
    context: Context
) {
    private val sharedPreferences: SharedPreferences =
        context.getSharedPreferences("daily_task_prefs", Context.MODE_PRIVATE)

    companion object {
        private const val KEY_LAST_ACTIVE_DATE = "last_active_date"
        private const val TAG = "TaskRepository"
    }

    val allTasks: Flow<List<Task>> = taskDao.getAllTasksFlow()
    val allHistory: Flow<List<TaskCompletionHistory>> = taskDao.getAllHistoryFlow()

    suspend fun insert(task: Task): Long = withContext(Dispatchers.IO) {
        val maxOrder = taskDao.getMaxDisplayOrder() ?: 0
        taskDao.insertTask(task.copy(displayOrder = maxOrder + 1))
    }

    suspend fun update(task: Task) = withContext(Dispatchers.IO) {
        taskDao.updateTask(task)
    }

    suspend fun delete(task: Task) = withContext(Dispatchers.IO) {
        taskDao.deleteTask(task)
    }

    suspend fun swapTasks(task1: Task, task2: Task) = withContext(Dispatchers.IO) {
        val order1 = task1.displayOrder
        val order2 = task2.displayOrder
        taskDao.updateTask(task1.copy(displayOrder = order2))
        taskDao.updateTask(task2.copy(displayOrder = order1))
    }

    /**
     * Checks if the date has changed since the last app usage.
     * If it has, compiles and logs history for the previous date(s),
     * resets task completion states, and updates the last active date.
     */
    suspend fun checkAndResetDailyTasks() = withContext(Dispatchers.IO) {
        val today = LocalDate.now()
        val todayStr = today.format(DateTimeFormatter.ISO_LOCAL_DATE) // "yyyy-MM-dd"
        
        val lastActiveStr = sharedPreferences.getString(KEY_LAST_ACTIVE_DATE, null)
        
        if (lastActiveStr == null) {
            // First time initialization, just save today's date
            sharedPreferences.edit().putString(KEY_LAST_ACTIVE_DATE, todayStr).apply()
            return@withContext
        }

        if (lastActiveStr != todayStr) {
            Log.d(TAG, "Date change detected! Last active: $lastActiveStr, Today: $todayStr")
            
            try {
                val lastActiveDate = LocalDate.parse(lastActiveStr, DateTimeFormatter.ISO_LOCAL_DATE)
                val daysBetween = ChronoUnit.DAYS.between(lastActiveDate, today)

                if (daysBetween > 0) {
                    val currentTasks = taskDao.getAllTasks()
                    val totalTasksCount = currentTasks.size
                    
                    if (totalTasksCount > 0) {
                        // 1. Log actual progress for the last active date
                        val completedCount = currentTasks.count { it.isCompleted }
                        taskDao.insertHistory(
                            TaskCompletionHistory(
                                date = lastActiveStr,
                                completedCount = completedCount,
                                totalCount = totalTasksCount
                            )
                        )

                        // 2. Backfill intermediate days where user did not open the app
                        for (i in 1 until daysBetween) {
                            val missedDate = lastActiveDate.plusDays(i)
                            val missedDateStr = missedDate.format(DateTimeFormatter.ISO_LOCAL_DATE)
                            
                            taskDao.insertHistory(
                                TaskCompletionHistory(
                                    date = missedDateStr,
                                    completedCount = 0, // No tasks completed
                                    totalCount = totalTasksCount
                                )
                            )
                        }
                    }
                    
                    // 3. Reset task checkboxes in the database
                    taskDao.resetAllTasksCompletion()
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error performing daily reset", e)
            }

            // 4. Update the saved active date
            sharedPreferences.edit().putString(KEY_LAST_ACTIVE_DATE, todayStr).apply()
        }
    }
    
    // For manual resetting/debugging if needed
    suspend fun resetCompletionStates() = withContext(Dispatchers.IO) {
        taskDao.resetAllTasksCompletion()
    }
}
