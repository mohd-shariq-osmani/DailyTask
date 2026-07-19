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

class DailyReminderWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE_REMINDER = "com.dailytask.daily_task.ACTION_TOGGLE_REMINDER"
        const val EXTRA_REMINDER_ID = "com.dailytask.daily_task.EXTRA_REMINDER_ID"
        private const val TAG = "ReminderWidgetProvider"
    }

    data class WidgetReminder(
        val id: Long,
        val title: String,
        val isCompleted: Boolean,
        val colorHex: String
    )

    private fun getDatabase(context: Context): SQLiteDatabase {
        val dbPath = context.getDatabasePath("dailytask.db")
        return SQLiteDatabase.openDatabase(dbPath.absolutePath, null, SQLiteDatabase.OPEN_READWRITE)
    }

    private fun queryActiveReminders(context: Context): List<WidgetReminder> {
        val reminders = mutableListOf<WidgetReminder>()
        var db: SQLiteDatabase? = null
        try {
            db = getDatabase(context)
            val cursor = db.query(
                "reminders", 
                arrayOf("id", "title", "isCompleted", "colorHex"), 
                "isCompleted = 0", null, null, null, "id DESC"
            )
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                val title = cursor.getString(1)
                val isCompleted = cursor.getInt(2) == 1
                val colorHex = cursor.getString(3)
                reminders.add(WidgetReminder(id, title, isCompleted, colorHex))
            }
            cursor.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error querying database", e)
        } finally {
            db?.close()
        }
        return reminders
    }

    private fun completeReminderInDb(context: Context, reminderId: Long) {
        var db: SQLiteDatabase? = null
        try {
            db = getDatabase(context)
            val values = ContentValues().apply {
                put("isCompleted", 1) // Mark as completed
            }
            db.update("reminders", values, "id = ?", arrayOf(reminderId.toString()))
        } catch (e: Exception) {
            Log.e(TAG, "Error completing reminder in DB", e)
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
        if (intent.action == ACTION_TOGGLE_REMINDER) {
            val reminderId = intent.getLongExtra(EXTRA_REMINDER_ID, -1L)
            Log.d(TAG, "Completing reminder in background: $reminderId")
            if (reminderId != -1L) {
                CoroutineScope(Dispatchers.IO).launch {
                    completeReminderInDb(context, reminderId)
                    
                    // Notify updates to reminders widgets
                    val appWidgetManager = AppWidgetManager.getInstance(context)
                    val thisWidget = ComponentName(context, DailyReminderWidgetProvider::class.java)
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
                val reminders = queryActiveReminders(context)
                val views = RemoteViews(packageName, R.layout.daily_reminder_widget)
                
                // 1. Clear existing views
                views.removeAllViews(R.id.widget_col1)
                views.removeAllViews(R.id.widget_col2)

                // 2. Calculate statistics
                val total = reminders.size

                // 3. Update header
                views.setTextViewText(R.id.widget_count, "$total")

                // 4. Populate reminder grid (cap at 10 items)
                val itemsToShow = reminders.take(10)
                itemsToShow.forEachIndexed { index, reminder ->
                    val reminderViews = RemoteViews(packageName, R.layout.widget_grid_item)
                    
                    // Title styling
                    reminderViews.setTextViewText(R.id.widget_grid_item_title, reminder.title)
                    reminderViews.setTextColor(R.id.widget_grid_item_title, android.graphics.Color.WHITE)

                    // Dot color
                    try {
                          reminderViews.setInt(
                              R.id.widget_grid_item_dot,
                              "setColorFilter",
                              android.graphics.Color.parseColor(reminder.colorHex)
                          )
                    } catch (e: Exception) {
                          e.printStackTrace()
                    }

                    // Click pending intent for checking off
                    val clickIntent = Intent(context, DailyReminderWidgetProvider::class.java).apply {
                        action = ACTION_TOGGLE_REMINDER
                        putExtra(EXTRA_REMINDER_ID, reminder.id)
                    }
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        reminder.id.toInt(),
                        clickIntent,
                        flags
                    )
                    
                    reminderViews.setOnClickPendingIntent(R.id.widget_grid_item_title, pendingIntent)
                    reminderViews.setOnClickPendingIntent(R.id.widget_grid_item_dot, pendingIntent)

                    // Add to Column 1 or 2
                    if (index % 2 == 0) {
                        views.addView(R.id.widget_col1, reminderViews)
                    } else {
                        views.addView(R.id.widget_col2, reminderViews)
                    }
                }

                // Header click opens the app
                val appIntent = Intent(context, MainActivity::class.java)
                val appPendingIntent = PendingIntent.getActivity(
                    context,
                    100, // unique request code
                    appIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_title, appPendingIntent)

                // Render updates
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating reminder widget", e)
            }
        }
    }
}
