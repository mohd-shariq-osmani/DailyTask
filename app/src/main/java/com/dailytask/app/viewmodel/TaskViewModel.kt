package com.dailytask.app.viewmodel

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.dailytask.app.DailyTaskWidgetProvider
import com.dailytask.app.data.DailyTaskDatabase
import com.dailytask.app.data.Task
import com.dailytask.app.data.TaskDailyLog
import com.dailytask.app.data.TaskRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class TaskViewModel(application: Application) : AndroidViewModel(application) {
    private val repository: TaskRepository
    
    private val _uiTasks = MutableStateFlow<List<Task>>(emptyList())
    val allTasks = _uiTasks.asStateFlow()
    private var isDraggingList = false
        
    val allHistory = DailyTaskDatabase.getDatabase(application).taskDao().getAllHistoryFlow()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val allDailyLogs = DailyTaskDatabase.getDatabase(application).taskDao().getAllDailyLogsFlow()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    init {
        val database = DailyTaskDatabase.getDatabase(application)
        repository = TaskRepository(database.taskDao(), application)
        
        // Listen to database task updates only when not dragging
        viewModelScope.launch {
            database.taskDao().getAllTasksFlow().collect { list ->
                if (!isDraggingList) {
                    _uiTasks.value = list
                }
            }
        }

        // Trigger date check and reset on launch
        viewModelScope.launch {
            repository.checkAndResetDailyTasks()
            updateWidget()
        }
    }

    fun addTask(title: String, colorHex: String) {
        viewModelScope.launch {
            repository.insert(Task(title = title, colorHex = colorHex))
            updateWidget()
        }
    }

    fun toggleTask(task: Task) {
        viewModelScope.launch {
            repository.update(task.copy(isCompleted = !task.isCompleted))
            updateWidget()
        }
    }

    fun deleteTask(task: Task) {
        viewModelScope.launch {
            repository.delete(task)
            updateWidget()
        }
    }

    // Swaps tasks in memory instantly for smooth drag-and-drop animation
    fun swapTasksLocal(fromIndex: Int, toIndex: Int) {
        isDraggingList = true
        val list = _uiTasks.value.toMutableList()
        if (fromIndex in list.indices && toIndex in list.indices) {
            val temp = list[fromIndex]
            list[fromIndex] = list[toIndex]
            list[toIndex] = temp
            _uiTasks.value = list
        }
    }

    // Persists the current task ordering into the SQLite database when drag ends
    fun saveTaskOrder() {
        viewModelScope.launch {
            val list = _uiTasks.value
            list.forEachIndexed { index, task ->
                if (task.displayOrder != index) {
                    repository.update(task.copy(displayOrder = index))
                }
            }
            isDraggingList = false
            updateWidget()
        }
    }

    // Fetch snapshot task logs for a specific day
    suspend fun getTaskLogsForDate(dateStr: String): List<TaskDailyLog> {
        return repository.getTaskLogsForDate(dateStr)
    }

    fun resetDay() {
        viewModelScope.launch {
            repository.resetCompletionStates()
            updateWidget()
        }
    }

    fun triggerDailyCheck() {
        viewModelScope.launch {
            repository.checkAndResetDailyTasks()
            updateWidget()
        }
    }

    fun clearAllAnalyticsData() {
        viewModelScope.launch {
            repository.clearAllAnalyticsData()
            updateWidget()
        }
    }

    private fun updateWidget() {
        val context = getApplication<Application>().applicationContext
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, DailyTaskWidgetProvider::class.java)
        val ids = appWidgetManager.getAppWidgetIds(componentName)
        
        // Notify widget data changes
        appWidgetManager.notifyAppWidgetViewDataChanged(ids, context.resources.getIdentifier("widget_task_list", "id", context.packageName))
        
        // Standard broadcast to update widget layouts
        val updateIntent = Intent(context, DailyTaskWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        context.sendBroadcast(updateIntent)
    }
}
