package com.dailytask.daily_task

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.dailytask/widget"
    private var methodChannel: MethodChannel? = null

    private val widgetUpdateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            methodChannel?.invokeMethod("widgetUpdated", null)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "refreshWidget" -> {
                    refreshWidget(this)
                    result.success(null)
                }
                "refreshRemindersWidget" -> {
                    refreshRemindersWidget(this)
                    result.success(null)
                }
                "getWidgetData", "getRemindersData" -> {
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Register local broadcast receiver for widget updates
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(
                widgetUpdateReceiver,
                IntentFilter("com.dailytask.WIDGET_UPDATE"),
                Context.RECEIVER_NOT_EXPORTED
            )
        } else {
            registerReceiver(
                widgetUpdateReceiver,
                IntentFilter("com.dailytask.WIDGET_UPDATE")
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(widgetUpdateReceiver)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun refreshWidget(context: Context) {
        val intent = Intent(context, DailyTaskWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, DailyTaskWidgetProvider::class.java))
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        context.sendBroadcast(intent)
    }

    private fun refreshRemindersWidget(context: Context) {
        val intent = Intent(context, DailyReminderWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, DailyReminderWidgetProvider::class.java))
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        context.sendBroadcast(intent)
    }
}
