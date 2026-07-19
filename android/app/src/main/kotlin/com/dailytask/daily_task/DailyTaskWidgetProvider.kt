package com.dailytask.daily_task

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import android.widget.RemoteViews
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter

class DailyTaskWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE_TASK = "com.dailytask.daily_task.ACTION_TOGGLE_TASK"
        const val EXTRA_TASK_ID = "com.dailytask.daily_task.EXTRA_TASK_ID"
        private const val TAG = "WidgetProvider"
    }

    // Task data holder helper
    data class WidgetTask(
        val id: Long,
        val title: String,
        val isCompleted: Boolean,
        val displayOrder: Int,
        val colorHex: String
    )

    private fun getDatabase(context: Context): SQLiteDatabase {
        // Path in standard databases directory matching sqflite output: databases/dailytask.db
        val dbPath = context.getDatabasePath("dailytask.db")
        return SQLiteDatabase.openDatabase(dbPath.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
    }

    private fun queryTasks(context: Context): List<WidgetTask> {
        val tasks = mutableListOf<WidgetTask>()
        var db: SQLiteDatabase? = null
        try {
            db = getDatabase(context)
            val cursor = db.query(
                "tasks", 
                arrayOf("id", "title", "isCompleted", "displayOrder", "colorHex"), 
                null, null, null, null, "displayOrder ASC"
            )
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                val title = cursor.getString(1)
                val isCompleted = cursor.getInt(2) == 1
                val displayOrder = cursor.getInt(3)
                val colorHex = cursor.getString(4)
                tasks.add(WidgetTask(id, title, isCompleted, displayOrder, colorHex))
            }
            cursor.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error querying database", e)
        } finally {
            db?.close()
        }
        return tasks
    }

    private fun toggleTaskInDb(context: Context, taskId: Long) {
        var db: SQLiteDatabase? = null
        try {
            db = getDatabase(context)
            // Query current state
            val cursor = db.query(
                "tasks",
                arrayOf("isCompleted"),
                "id = ?",
                arrayOf(taskId.toString()),
                null, null, null
            )
            if (cursor.moveToFirst()) {
                val currentVal = cursor.getInt(0)
                val newVal = if (currentVal == 1) 0 else 1
                
                val values = ContentValues().apply {
                    put("isCompleted", newVal)
                }
                db.update("tasks", values, "id = ?", arrayOf(taskId.toString()))
            }
            cursor.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error toggling task in DB", e)
        } finally {
            db?.close()
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE_TASK) {
            val taskId = intent.getLongExtra(EXTRA_TASK_ID, -1L)
            Log.d(TAG, "Toggling task in background: $taskId")
            if (taskId != -1L) {
                CoroutineScope(Dispatchers.IO).launch {
                    toggleTaskInDb(context, taskId)
                    
                    // Notify updates to all widgets
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val thisWidget = ComponentName(context, DailyTaskWidgetProvider::class.java)
                    val allWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                    
                    for (id in allWidgetIds) {
                        updateAppWidget(context, appWidgetManager, id)
                    }
                    
                    // Also notify the active main app activity (if running)
                    context.sendBroadcast(Intent("com.dailytask.WIDGET_UPDATE"))
                }
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val packageName = context.packageName
        
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val rawTasks = queryTasks(context)
                // Move completed tasks to the bottom of the widget list, preserving their relative display order
                val tasks = rawTasks.sortedWith(compareBy<WidgetTask> { it.isCompleted }.thenBy { it.displayOrder })
                
                val views = RemoteViews(packageName, R.layout.daily_task_widget)
                
                // 1. Clear existing views
                views.removeAllViews(R.id.widget_col1)
                views.removeAllViews(R.id.widget_col2)

                // 2. Set current date formatted as WED, 3 JUN
                val currentDateStr = LocalDate.now().format(DateTimeFormatter.ofPattern("EEE, d MMM")).uppercase()
                views.setTextViewText(R.id.widget_subtitle, currentDateStr)

                // 3. Calculate statistics
                val total = tasks.size
                val completed = tasks.count { it.isCompleted }
                val left = total - completed
                val progressPct = if (total > 0) ((completed.toFloat() / total.toFloat()) * 100).toInt() else 0

                // 4. Update header and bottom dashboard cards
                views.setTextViewText(R.id.widget_progress, "$completed/$total")
                views.setTextViewText(R.id.widget_dash_active_count, "$left")
                views.setTextViewText(R.id.widget_dash_pct, "$progressPct%")

                // 5. Populate task grid (cap at 10 items to prevent widget height overflow)
                val itemsToShow = tasks.take(10)
                itemsToShow.forEachIndexed { index, task ->
                    val taskViews = RemoteViews(packageName, R.layout.widget_grid_item)
                    
                    // Task Name styling
                    taskViews.setTextViewText(R.id.widget_grid_item_title, task.title)
                    if (task.isCompleted) {
                        // Dim text color if completed
                        taskViews.setTextColor(R.id.widget_grid_item_title, android.graphics.Color.parseColor("#48484A"))
                    } else {
                        taskViews.setTextColor(R.id.widget_grid_item_title, android.graphics.Color.WHITE)
                    }

                    // Task dot color setting
                    try {
                        taskViews.setInt(
                            R.id.widget_grid_item_dot,
                            "setColorFilter",
                            android.graphics.Color.parseColor(task.colorHex)
                        )
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }

                    // Click pending intent for checking/unchecking
                    val clickIntent = Intent(context, DailyTaskWidgetProvider::class.java).apply {
                        action = ACTION_TOGGLE_TASK
                        putExtra(EXTRA_TASK_ID, task.id)
                    }
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        task.id.toInt(), // unique request code per task
                        clickIntent,
                        flags
                    )
                    
                    taskViews.setOnClickPendingIntent(R.id.widget_grid_item_title, pendingIntent)
                    taskViews.setOnClickPendingIntent(R.id.widget_grid_item_dot, pendingIntent)

                    // Add to Column 1 (even) or Column 2 (odd)
                    if (index % 2 == 0) {
                        views.addView(R.id.widget_col1, taskViews)
                    } else {
                        views.addView(R.id.widget_col2, taskViews)
                    }
                }

                // Header click opens the app
                val appIntent = Intent(context, MainActivity::class.java)
                val appPendingIntent = PendingIntent.getActivity(
                    context,
                    99,
                    appIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_title, appPendingIntent)

                // Render updates
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating app widget", e)
            }
        }
    }
}
