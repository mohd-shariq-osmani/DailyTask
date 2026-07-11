package com.dailytask.app

import android.os.Bundle
import android.content.Intent
import android.content.ComponentName
import android.appwidget.AppWidgetManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.dailytask.app.ui.screens.TaskListScreen
import com.dailytask.app.ui.screens.StatsScreen
import com.dailytask.app.ui.theme.DailyTaskTheme
import com.dailytask.app.viewmodel.TaskViewModel
import com.dailytask.app.data.DailyTaskDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        handleVoiceIntent(intent)
        
        setContent {
            DailyTaskTheme {
                val navController = rememberNavController()
                val viewModel: TaskViewModel = viewModel()

                Surface(
                    modifier = Modifier.fillMaxSize()
                ) {
                    NavHost(
                        navController = navController,
                        startDestination = "task_list"
                    ) {
                        composable("task_list") {
                            TaskListScreen(
                                viewModel = viewModel,
                                onNavigateToStats = { navController.navigate("stats") }
                            )
                        }
                        composable("stats") {
                            StatsScreen(
                                viewModel = viewModel,
                                onNavigateBack = { navController.popBackStack() }
                            )
                        }
                    }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleVoiceIntent(intent)
    }

    private fun handleVoiceIntent(intent: Intent?) {
        if (intent == null) return
        val taskName = intent.getStringExtra("taskName")
        if (!taskName.isNullOrBlank()) {
            CoroutineScope(Dispatchers.IO).launch {
                val db = DailyTaskDatabase.getDatabase(applicationContext)
                val dao = db.taskDao()
                val tasks = dao.getAllTasks()
                val matchedTask = tasks.find { it.title.equals(taskName, ignoreCase = true) }
                if (matchedTask != null) {
                    dao.updateTask(matchedTask.copy(isCompleted = true))
                    
                    // Trigger widget refresh
                    val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
                    val componentName = ComponentName(applicationContext, DailyTaskWidgetProvider::class.java)
                    val ids = appWidgetManager.getAppWidgetIds(componentName)
                    appWidgetManager.notifyAppWidgetViewDataChanged(
                        ids, 
                        resources.getIdentifier("widget_task_list", "id", packageName)
                    )
                    
                    val updateIntent = Intent(applicationContext, DailyTaskWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                    }
                    sendBroadcast(updateIntent)
                }
            }
        }
    }
}
