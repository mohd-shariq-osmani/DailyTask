package com.dailytask.app.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailytask.app.data.Task
import com.dailytask.app.data.TaskCompletionHistory
import com.dailytask.app.data.TaskDailyLog
import com.dailytask.app.ui.theme.*
import com.dailytask.app.viewmodel.TaskViewModel
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters
import kotlin.math.roundToInt

// Data model representing a normalized point for the graph
data class StatPoint(
    val id: String,
    val label: String,
    val completedCount: Int,
    val totalCount: Int,
    val percentage: Float, // 0.0 to 1.0
    val rawDateDescription: String
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(
    viewModel: TaskViewModel,
    onNavigateBack: () -> Unit
) {
    val history by viewModel.allHistory.collectAsState()
    val currentTasks by viewModel.allTasks.collectAsState()
    val dailyLogs by viewModel.allDailyLogs.collectAsState()

    // ── Primary Tab Selection (Overview vs Task Analysis) ──────────────
    var statsTab by remember { mutableStateOf(0) } // 0 = Overview, 1 = Task Analysis
    var showDeleteConfirm by remember { mutableStateOf(false) }

    // ── Primary View Selection (Day, Week, Month) ────────────────────
    var activeTab by remember { mutableStateOf(0) } // 0 = Day, 1 = Week, 2 = Month
    
    // ── Granularity Limits ──────────────────────────────────────────
    var dayLimit by remember { mutableStateOf(7) }   // 7 or 30 days
    var weekLimit by remember { mutableStateOf(8) }  // 4 or 8 weeks
    var monthLimit by remember { mutableStateOf(6) } // 3 or 6 months

    // Combine history database entries with today's live progress
    val combinedStats = remember(history, currentTasks) {
        val todayStr = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE)
        val statsList = history.toMutableList()

        if (statsList.none { it.date == todayStr }) {
            val total = currentTasks.size
            if (total > 0) {
                val completed = currentTasks.count { it.isCompleted }
                statsList.add(
                    TaskCompletionHistory(
                        date = todayStr,
                        completedCount = completed,
                        totalCount = total
                    )
                )
            }
        }
        statsList.sortedBy { it.date }
    }

    // ── Day-wise Points Calculation ─────────────────────────────────
    val dayPoints = remember(combinedStats) {
        combinedStats.mapNotNull { entry ->
            try {
                val date = LocalDate.parse(entry.date)
                val dayName = date.format(DateTimeFormatter.ofPattern("EEEE"))
                val pct = if (entry.totalCount > 0) entry.completedCount.toFloat() / entry.totalCount else 0f
                StatPoint(
                    id = entry.date,
                    label = date.format(DateTimeFormatter.ofPattern("d")),
                    completedCount = entry.completedCount,
                    totalCount = entry.totalCount,
                    percentage = pct,
                    rawDateDescription = "$dayName, ${date.format(DateTimeFormatter.ofPattern("d MMM yyyy"))}"
                )
            } catch (e: Exception) {
                null
            }
        }
    }

    // ── Weekly Points Calculation ───────────────────────────────────
    val weekPoints = remember(combinedStats) {
        combinedStats.groupBy { entry ->
            try {
                val date = LocalDate.parse(entry.date)
                date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
            } catch (e: Exception) {
                LocalDate.now()
            }
        }.map { (monday, entries) ->
            val completed = entries.sumOf { it.completedCount }
            val total = entries.sumOf { it.totalCount }
            val pct = if (total > 0) completed.toFloat() / total else 0f
            val sunday = monday.plusDays(6)
            val rangeLabel = "${monday.format(DateTimeFormatter.ofPattern("d MMM"))} - ${sunday.format(DateTimeFormatter.ofPattern("d MMM"))}"
            StatPoint(
                id = monday.toString(),
                label = monday.format(DateTimeFormatter.ofPattern("d MMM")),
                completedCount = completed,
                totalCount = total,
                percentage = pct,
                rawDateDescription = "Week of $rangeLabel"
            )
        }.sortedBy { it.id }
    }

    // ── Monthly Points Calculation ──────────────────────────────────
    val monthPoints = remember(combinedStats) {
        combinedStats.groupBy { entry ->
            try {
                val date = LocalDate.parse(entry.date)
                YearMonth.from(date)
            } catch (e: Exception) {
                YearMonth.now()
            }
        }.map { (yearMonth, entries) ->
            val completed = entries.sumOf { it.completedCount }
            val total = entries.sumOf { it.totalCount }
            val pct = if (total > 0) completed.toFloat() / total else 0f
            StatPoint(
                id = yearMonth.toString(),
                label = yearMonth.format(DateTimeFormatter.ofPattern("MMM")),
                completedCount = completed,
                totalCount = total,
                percentage = pct,
                rawDateDescription = yearMonth.format(DateTimeFormatter.ofPattern("MMMM yyyy"))
            )
        }.sortedBy { it.id }
    }

    // ── Filter Display Points based on selections ───────────────────
    val displayPoints = remember(activeTab, dayPoints, weekPoints, monthPoints, dayLimit, weekLimit, monthLimit) {
        when (activeTab) {
            0 -> dayPoints.takeLast(dayLimit)
            1 -> weekPoints.takeLast(weekLimit)
            else -> monthPoints.takeLast(monthLimit)
        }
    }

    // ── Selected point details index (default to last point) ────────
    var selectedIndex by remember(displayPoints) { mutableStateOf<Int?>(null) }
    val activeSelectedIndex = selectedIndex ?: (displayPoints.size - 1).coerceAtLeast(0)
    val activePoint = if (displayPoints.isNotEmpty() && activeSelectedIndex in displayPoints.indices) {
        displayPoints[activeSelectedIndex]
    } else null

    // ── Dynamic selected date task lists logs retrieval ──────────────
    var selectedDayLogs by remember { mutableStateOf<List<TaskDailyLog>>(emptyList()) }

    LaunchedEffect(activePoint, currentTasks, dailyLogs) {
        if (activePoint != null && activeTab == 0) {
            val dateStr = activePoint.id
            val rawLogs = viewModel.getTaskLogsForDate(dateStr)
            if (rawLogs.isEmpty()) {
                val historyEntry = combinedStats.find { it.date == dateStr }
                if (historyEntry != null) {
                    val completed = historyEntry.completedCount
                    val total = historyEntry.totalCount
                    val generated = mutableListOf<TaskDailyLog>()
                    for (i in 1..total) {
                        generated.add(
                            TaskDailyLog(
                                date = dateStr,
                                taskId = -i.toLong(),
                                taskTitle = "Task $i",
                                isCompleted = i <= completed,
                                colorHex = "#8B5CF6"
                            )
                        )
                    }
                    selectedDayLogs = generated
                } else {
                    selectedDayLogs = emptyList()
                }
            } else {
                selectedDayLogs = rawLogs
            }
        } else {
            selectedDayLogs = emptyList()
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
    ) {
        // Subtle ambient glow
        Box(
            modifier = Modifier
                .size(320.dp)
                .align(Alignment.BottomStart)
                .offset(x = (-80).dp, y = 80.dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            AccentVioletMuted.copy(alpha = 0.04f),
                            Color.Transparent
                        )
                    )
                )
        )

        Scaffold(
            topBar = {
                CenterAlignedTopAppBar(
                    title = {
                        Text(
                            text = "Analytics Dashboard",
                            color = TextPrimary,
                            fontWeight = FontWeight.Bold,
                            fontSize = 18.sp,
                            letterSpacing = (-0.3).sp
                        )
                    },
                    navigationIcon = {
                        IconButton(onClick = onNavigateBack) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Back",
                                tint = TextSecondary
                            )
                        }
                    },
                    colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                        containerColor = Color.Transparent
                    )
                )
            },
            containerColor = Color.Transparent
        ) { paddingValues ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(horizontal = 24.dp)
            ) {
                // ── Dashboard Primary Tab Row ────────────────────────────────
                PrimaryTabRow(
                    selectedTab = statsTab,
                    onTabSelected = { statsTab = it }
                )

                Spacer(modifier = Modifier.height(18.dp))

                if (statsTab == 0) {
                    // ──── OVERVIEW VIEW ────
                    LazyColumn(
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(16.dp),
                        contentPadding = PaddingValues(bottom = 24.dp)
                    ) {
                        // 1. Contribution Heatmap
                        item {
                            Text(
                                text = "CONSISTENCY HEATMAP",
                                color = TextSecondary,
                                fontSize = 10.sp,
                                fontWeight = FontWeight.Bold,
                                letterSpacing = 1.sp
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            ContributionHeatmap(
                                combinedStats = combinedStats,
                                onDateSelected = { selectedDateStr ->
                                    // Switch to Days tab and select the date
                                    activeTab = 0
                                    val idx = dayPoints.indexOfFirst { it.id == selectedDateStr }
                                    if (idx != -1) {
                                        selectedIndex = idx
                                    }
                                }
                            )
                        }

                        // 2. Tab selection and granularity
                        item {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                StatsSegmentedTabs(
                                    activeTab = activeTab,
                                    onTabSelected = {
                                        activeTab = it
                                        selectedIndex = null
                                    },
                                    modifier = Modifier.width(200.dp)
                                )
                                Row {
                                    when (activeTab) {
                                        0 -> {
                                            GranularityChip(label = "7d", selected = dayLimit == 7, onClick = { dayLimit = 7 })
                                            Spacer(modifier = Modifier.width(6.dp))
                                            GranularityChip(label = "30d", selected = dayLimit == 30, onClick = { dayLimit = 30 })
                                        }
                                        1 -> {
                                            GranularityChip(label = "4w", selected = weekLimit == 4, onClick = { weekLimit = 4 })
                                            Spacer(modifier = Modifier.width(6.dp))
                                            GranularityChip(label = "8w", selected = weekLimit == 8, onClick = { weekLimit = 8 })
                                        }
                                        2 -> {
                                            GranularityChip(label = "3m", selected = monthLimit == 3, onClick = { monthLimit = 3 })
                                            Spacer(modifier = Modifier.width(6.dp))
                                            GranularityChip(label = "6m", selected = monthLimit == 6, onClick = { monthLimit = 6 })
                                        }
                                    }
                                }
                            }
                        }

                        // 3. Canvas Line Graph
                        item {
                            GraphCardContainer(
                                points = displayPoints,
                                selectedIndex = activeSelectedIndex,
                                onPointSelected = { selectedIndex = it }
                            )
                        }

                        // 4. Details card
                        item {
                            activePoint?.let { pt ->
                                InteractiveDetailsCard(point = pt)
                            }
                        }

                        // 5. Selected Day's Task List (Day-wise Breakdown)
                        if (activeTab == 0 && selectedDayLogs.isNotEmpty()) {
                            item {
                                Text(
                                    text = "TASK BREAKDOWN",
                                    color = TextSecondary,
                                    fontSize = 10.sp,
                                    fontWeight = FontWeight.Bold,
                                    letterSpacing = 1.sp
                                )
                            }
                            items(selectedDayLogs, key = { it.taskId }) { log ->
                                DayBreakdownTaskRow(log = log)
                            }
                        }

                        // 6. Basic stats metrics cards
                        item {
                            DynamicInsightsGrid(combinedStats = combinedStats)
                        }

                        // 7. Reset history button
                        item {
                            Spacer(modifier = Modifier.height(10.dp))
                            ResetHistoryButton(onClick = { showDeleteConfirm = true })
                        }
                    }
                } else {
                    // ──── TASK ANALYSIS VIEW ────
                    if (currentTasks.isEmpty()) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .weight(1f),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "No active tasks to analyze.",
                                color = TextSecondary,
                                fontSize = 14.sp
                            )
                        }
                    } else {
                        LazyColumn(
                            modifier = Modifier.weight(1f),
                            verticalArrangement = Arrangement.spacedBy(14.dp),
                            contentPadding = PaddingValues(bottom = 24.dp)
                        ) {
                            items(currentTasks, key = { it.id }) { task ->
                                TaskWiseAnalysisCard(
                                    task = task,
                                    combinedStats = combinedStats,
                                    dailyLogs = dailyLogs
                                )
                            }

                            // 2. Reset history button
                            item {
                                Spacer(modifier = Modifier.height(10.dp))
                                ResetHistoryButton(onClick = { showDeleteConfirm = true })
                            }
                        }
                    }
                }
            }
        }

        if (showDeleteConfirm) {
            AlertDialog(
                onDismissRequest = { showDeleteConfirm = false },
                title = {
                    Text(
                        text = "Delete Past Analytics?",
                        color = RedAccent,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                },
                text = {
                    Text(
                        text = "Are you sure you want to permanently clear all your past analytics data? This includes your completion trends, streak records, heatmap cells, and historical task-wise logs.\n\nWarning: Your current tasks will NOT be deleted, but your statistics will be completely reset. This action cannot be undone.",
                        color = TextSecondary,
                        fontSize = 15.sp,
                        lineHeight = 22.sp
                    )
                },
                confirmButton = {
                    Button(
                        onClick = {
                            viewModel.clearAllAnalyticsData()
                            showDeleteConfirm = false
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = RedAccent,
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Reset History", fontWeight = FontWeight.Bold)
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showDeleteConfirm = false }) {
                        Text("Cancel", color = TextSecondary, fontWeight = FontWeight.Medium)
                    }
                },
                containerColor = DarkSurface,
                shape = RoundedCornerShape(20.dp),
                modifier = Modifier.border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
            )
        }
    }
}

// ── Segmented Tab Selector (Overview vs Task Analysis) ────────────────
@Composable
fun PrimaryTabRow(
    selectedTab: Int,
    onTabSelected: (Int) -> Unit
) {
    TabRow(
        selectedTabIndex = selectedTab,
        containerColor = Color.Transparent,
        contentColor = AccentViolet,
        indicator = { tabPositions ->
            TabRowDefaults.SecondaryIndicator(
                Modifier.tabIndicatorOffset(tabPositions[selectedTab]),
                color = AccentViolet
            )
        },
        divider = {
            HorizontalDivider(color = GlassBorder)
        }
    ) {
        Tab(
            selected = selectedTab == 0,
            onClick = { onTabSelected(0) },
            text = { Text("Overview", fontSize = 14.sp, fontWeight = FontWeight.Bold) },
            selectedContentColor = AccentVioletLight,
            unselectedContentColor = TextSecondary
        )
        Tab(
            selected = selectedTab == 1,
            onClick = { onTabSelected(1) },
            text = { Text("Task Analysis", fontSize = 14.sp, fontWeight = FontWeight.Bold) },
            selectedContentColor = AccentVioletLight,
            unselectedContentColor = TextSecondary
        )
    }
}

// ── GitHub Style Heatmap ──────────────────────────────────────────────
@Composable
fun ContributionHeatmap(
    combinedStats: List<TaskCompletionHistory>,
    onDateSelected: (String) -> Unit
) {
    val today = remember { LocalDate.now() }
    val weeksCount = 13 // 13 columns (~3 months)
    // Find the Monday of 13 weeks ago
    val startMonday = remember {
        today.minusWeeks((weeksCount - 1).toLong()).with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(DarkSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(18.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // Day Labels (Mon, Wed, Fri, Sun)
            Column(
                modifier = Modifier.padding(end = 8.dp),
                verticalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                listOf("M", "", "W", "", "F", "", "S").forEach { label ->
                    Text(
                        text = label,
                        color = TextSecondary,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.height(14.dp)
                    )
                }
            }

            // Scrollable Grid of columns
            LazyRow(
                horizontalArrangement = Arrangement.spacedBy(5.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                items(weeksCount) { weekIdx ->
                    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        for (dayIdx in 0..6) {
                            val date = startMonday.plusWeeks(weekIdx.toLong()).plusDays(dayIdx.toLong())
                            val isFuture = date.isAfter(today)
                            val dateStr = date.format(DateTimeFormatter.ISO_LOCAL_DATE)

                            // Find stats
                            val stats = combinedStats.find { it.date == dateStr }
                            val pct = if (stats != null && stats.totalCount > 0) {
                                stats.completedCount.toFloat() / stats.totalCount
                            } else 0f

                            val cellColor = when {
                                isFuture -> Color.Transparent
                                stats == null || stats.totalCount == 0 -> Color(0x336B7280) // neutral empty
                                pct == 0f -> Color(0xFF131318) // no progress
                                pct <= 0.34f -> AccentViolet.copy(alpha = 0.2f)
                                pct <= 0.67f -> AccentViolet.copy(alpha = 0.5f)
                                pct < 1f -> AccentViolet.copy(alpha = 0.8f)
                                else -> AccentViolet // perfect day!
                            }

                            Box(
                                modifier = Modifier
                                    .size(14.dp)
                                    .clip(RoundedCornerShape(3.dp))
                                    .background(cellColor)
                                    .clickable(enabled = !isFuture && stats != null) {
                                        onDateSelected(dateStr)
                                    }
                            )
                        }
                    }
                }
            }
        }
    }
}

// ── Task Wise Analysis Card ──────────────────────────────────────────
@Composable
fun TaskWiseAnalysisCard(
    task: Task,
    combinedStats: List<TaskCompletionHistory>,
    dailyLogs: List<TaskDailyLog>
) {
    val todayStr = remember { LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE) }
    val taskColor = remember(task.colorHex) {
        try { Color(android.graphics.Color.parseColor(task.colorHex)) } catch (e: Exception) { AccentViolet }
    }

    // Compile historical completion states for this specific task
    val completionStates = remember(combinedStats, dailyLogs, task.title, task.isCompleted) {
        combinedStats.map { entry ->
            if (entry.date == todayStr) {
                entry.date to task.isCompleted
            } else {
                val matchedLog = dailyLogs.find { it.date == entry.date && it.taskTitle.equals(task.title, ignoreCase = true) }
                entry.date to (matchedLog?.isCompleted ?: false)
            }
        }
    }

    val totalLoggedDays = completionStates.size
    val totalCompletions = completionStates.count { it.second }
    val completionRate = if (totalLoggedDays > 0) {
        (totalCompletions.toFloat() / totalLoggedDays * 100).toInt()
    } else 0

    // Streak Calculations
    val currentStreak = remember(completionStates) {
        var streak = 0
        // check from most recent backwards
        for (i in completionStates.indices.reversed()) {
            if (completionStates[i].second) {
                streak++
            } else {
                // If it's today and they haven't checked it yet, keep checking from yesterday
                if (i == completionStates.size - 1 && completionStates[i].first == todayStr) {
                    continue
                }
                break
            }
        }
        streak
    }

    val bestStreak = remember(completionStates) {
        var maxStreak = 0
        var current = 0
        for (state in completionStates) {
            if (state.second) {
                current++
                if (current > maxStreak) maxStreak = current
            } else {
                current = 0
            }
        }
        maxStreak
    }

    // Preferred Day of Week
    val preferredDayText = remember(completionStates) {
        val completedDaysList = completionStates.filter { it.second }.map { LocalDate.parse(it.first).dayOfWeek }
        if (completedDaysList.isEmpty()) "N/A" else {
            val mostCommon = completedDaysList.groupBy { it }.maxByOrNull { it.value.size }
            mostCommon?.key?.name?.lowercase()?.replaceFirstChar { it.uppercase() } ?: "N/A"
        }
    }

    // 7-day sparkline list of booleans
    val lastSevenDaysList = remember(completionStates) {
        completionStates.takeLast(7).map { it.second }
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(DarkSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
            .padding(18.dp)
    ) {
        Column {
            // Card Title Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth()
            ) {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(CircleShape)
                        .background(taskColor)
                )
                Spacer(modifier = Modifier.width(10.dp))
                Text(
                    text = task.title,
                    color = TextPrimary,
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.weight(1f)
                )
                Text(
                    text = "$completionRate% rate",
                    color = AccentVioletLight,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Stats values grid (Completions, Streaks, Preferred workday)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text("TOTAL LOGGED", color = TextSecondary, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                    Text("$totalCompletions / $totalLoggedDays days", color = TextPrimary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 2.dp))
                }
                Column {
                    Text("STREAK", color = TextSecondary, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                    Text("🔥 $currentStreak days", color = AccentVioletLight, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 2.dp))
                }
                Column {
                    Text("BEST STREAK", color = TextSecondary, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                    Text("🏆 $bestStreak days", color = GreenAccent, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 2.dp))
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            HorizontalDivider(color = GlassBorder)
            Spacer(modifier = Modifier.height(14.dp))

            // Habit consistency sparkline & Preferred Day
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text("MOST CONSISTENT", color = TextSecondary, fontSize = 9.sp, fontWeight = FontWeight.Bold)
                    Text(preferredDayText, color = TextPrimary, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 2.dp))
                }

                // 7-day sparkline circles
                Column(horizontalAlignment = Alignment.End) {
                    Text("LAST 7 DAYS", color = TextSecondary, fontSize = 9.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(bottom = 6.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        lastSevenDaysList.forEach { completed ->
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(if (completed) taskColor else Color.Transparent)
                                    .border(
                                        width = if (completed) 0.dp else 1.5.dp,
                                        color = if (completed) Color.Transparent else taskColor.copy(alpha = 0.35f),
                                        shape = CircleShape
                                    )
                            )
                        }
                        // Pad grid if less than 7 days history
                        if (lastSevenDaysList.size < 7) {
                            for (i in 1..(7 - lastSevenDaysList.size)) {
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .clip(CircleShape)
                                        .background(Color.Transparent)
                                        .border(1.dp, GlassBorder, CircleShape)
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// ── Day-wise Breakdown Task Row ──────────────────────────────────────
@Composable
fun DayBreakdownTaskRow(log: TaskDailyLog) {
    val taskColor = remember(log.colorHex) {
        try { Color(android.graphics.Color.parseColor(log.colorHex)) } catch (e: Exception) { AccentViolet }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(DarkSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(14.dp))
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Status Check Indicator
        Box(
            modifier = Modifier
                .size(20.dp)
                .clip(RoundedCornerShape(6.dp))
                .background(if (log.isCompleted) taskColor else Color.Transparent)
                .border(
                    width = if (log.isCompleted) 0.dp else 1.5.dp,
                    color = if (log.isCompleted) Color.Transparent else taskColor.copy(alpha = 0.4f),
                    shape = RoundedCornerShape(6.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            if (log.isCompleted) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(12.dp)
                )
            }
        }

        Spacer(modifier = Modifier.width(14.dp))

        // Title text
        Text(
            text = log.taskTitle,
            color = if (log.isCompleted) TextTertiary else TextPrimary,
            fontSize = 15.sp,
            fontWeight = if (log.isCompleted) FontWeight.Normal else FontWeight.Medium,
            modifier = Modifier.weight(1f)
        )

        Spacer(modifier = Modifier.width(8.dp))

        // Small indicator pill
        Box(
            modifier = Modifier
                .clip(RoundedCornerShape(6.dp))
                .background(if (log.isCompleted) taskColor.copy(alpha = 0.15f) else Color(0x0CFFFFFF))
                .padding(horizontal = 8.dp, vertical = 4.dp)
        ) {
            Text(
                text = if (log.isCompleted) "Completed" else "Incomplete",
                color = if (log.isCompleted) taskColor else TextSecondary,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

// ── Secondary Granularity Limit Chip Picker ──────────────────────────
@Composable
fun GranularityChip(
    label: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(if (selected) AccentViolet.copy(alpha = 0.15f) else Color.Transparent)
            .border(
                width = 1.dp,
                color = if (selected) AccentViolet else GlassBorder,
                shape = RoundedCornerShape(8.dp)
            )
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 6.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            color = if (selected) AccentVioletLight else TextSecondary,
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

// ── Segmented Tab Controller (Days, Weeks, Months) ───────────────────
@Composable
fun StatsSegmentedTabs(
    activeTab: Int,
    onTabSelected: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(DarkSurfaceVariant)
            .border(1.dp, GlassBorder, RoundedCornerShape(12.dp))
            .padding(3.dp)
    ) {
        val tabLabels = listOf("D", "W", "M")
        tabLabels.forEachIndexed { idx, label ->
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (activeTab == idx) AccentViolet else Color.Transparent)
                    .clickable { onTabSelected(idx) }
                    .padding(vertical = 6.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = label,
                    color = if (activeTab == idx) Color.White else TextSecondary,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 12.sp
                )
            }
        }
    }
}

// ── Graph Container & Canvas Layout ─────────────────────────────────
@Composable
fun GraphCardContainer(
    points: List<StatPoint>,
    selectedIndex: Int,
    onPointSelected: (Int) -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(DarkSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
            .padding(top = 22.dp, start = 20.dp, end = 20.dp, bottom = 12.dp)
    ) {
        if (points.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(200.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "Insufficient completion records.\nCheck back tomorrow!",
                    color = TextSecondary,
                    textAlign = TextAlign.Center,
                    fontSize = 14.sp,
                    lineHeight = 22.sp
                )
            }
        } else {
            Column {
                InteractiveCanvasGraph(
                    points = points,
                    selectedIndex = selectedIndex,
                    onPointSelected = onPointSelected
                )
            }
        }
    }
}

@Composable
fun InteractiveCanvasGraph(
    points: List<StatPoint>,
    selectedIndex: Int,
    onPointSelected: (Int) -> Unit
) {
    val density = LocalDensity.current
    
    // Canvas bounds configurations
    val paddingLeft = with(density) { 30.dp.toPx() }
    val paddingRight = with(density) { 12.dp.toPx() }
    val paddingTop = with(density) { 14.dp.toPx() }
    val paddingBottom = with(density) { 26.dp.toPx() }

    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(180.dp)
            .pointerInput(points) {
                detectTapGestures { tapOffset ->
                    val graphWidth = size.width - paddingLeft - paddingRight
                    if (points.size > 1 && tapOffset.x >= paddingLeft) {
                        val stepX = graphWidth / (points.size - 1)
                        val relativeX = tapOffset.x - paddingLeft
                        val estimatedIndex = (relativeX / stepX).roundToInt()
                            .coerceIn(0, points.size - 1)
                        
                        // Select point if tap is within bounds
                        onPointSelected(estimatedIndex)
                    } else if (points.size == 1) {
                        onPointSelected(0)
                    }
                }
            }
    ) {
        val width = size.width
        val height = size.height

        val graphWidth = width - paddingLeft - paddingRight
        val graphHeight = height - paddingTop - paddingBottom

        // Draw horizontal grid lines
        val gridLines = 4
        for (i in 0..gridLines) {
            val y = paddingTop + graphHeight * (1f - (i.toFloat() / gridLines))
            // Grid guides
            drawLine(
                color = Color(0x0DFFFFFF),
                start = Offset(paddingLeft, y),
                end = Offset(width - paddingRight, y),
                strokeWidth = 1.dp.toPx()
            )
        }

        // Calculate points step size
        val stepX = if (points.size > 1) graphWidth / (points.size - 1) else graphWidth

        val completedPoints = points.mapIndexed { index, entry ->
            val x = paddingLeft + index * stepX
            val y = paddingTop + graphHeight * (1f - entry.percentage)
            Offset(x, y)
        }

        // 1. Draw area gradient underneath line
        if (completedPoints.isNotEmpty()) {
            val areaPath = Path().apply {
                moveTo(completedPoints.first().x, paddingTop + graphHeight)
                completedPoints.forEach { pt -> lineTo(pt.x, pt.y) }
                lineTo(completedPoints.last().x, paddingTop + graphHeight)
                close()
            }
            drawPath(
                path = areaPath,
                brush = Brush.verticalGradient(
                    colors = listOf(
                        AccentViolet.copy(alpha = 0.22f),
                        AccentViolet.copy(alpha = 0.0f)
                    ),
                    startY = completedPoints.map { it.y }.minOrNull() ?: 0f,
                    endY = paddingTop + graphHeight
                )
            )
        }

        // 2. Draw vertical dashed line for selected point
        if (selectedIndex in completedPoints.indices) {
            val selPt = completedPoints[selectedIndex]
            drawLine(
                color = AccentVioletLight.copy(alpha = 0.5f),
                start = Offset(selPt.x, paddingTop),
                end = Offset(selPt.x, paddingTop + graphHeight),
                strokeWidth = 1.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(8f, 8f))
            )
        }

        // 3. Draw connecting line
        val completedLinePath = Path().apply {
            completedPoints.forEachIndexed { i, pt ->
                if (i == 0) moveTo(pt.x, pt.y) else lineTo(pt.x, pt.y)
            }
        }
        drawPath(
            path = completedLinePath,
            color = AccentViolet,
            style = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
        )

        // 4. Draw horizontal timeline text labels (First, middle, last to prevent overlap)
        if (points.isNotEmpty()) {
            val textPaint = android.graphics.Paint().apply {
                color = android.graphics.Color.parseColor("#6B7280")
                textSize = 9.dp.toPx()
                textAlign = android.graphics.Paint.Align.CENTER
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }
            
            val labelIndices = if (points.size <= 6) {
                points.indices.toList()
            } else {
                listOf(0, points.size / 2, points.size - 1)
            }

            labelIndices.forEach { idx ->
                val pt = completedPoints[idx]
                val label = points[idx].label
                drawContext.canvas.nativeCanvas.drawText(
                    label,
                    pt.x,
                    height - 6.dp.toPx(),
                    textPaint
                )
            }
        }

        // 5. Draw interactive node bullets with active rings
        completedPoints.forEachIndexed { index, pt ->
            val isSelected = index == selectedIndex
            if (isSelected) {
                // outer glow
                drawCircle(
                    color = AccentViolet.copy(alpha = 0.25f),
                    radius = 9.dp.toPx(),
                    center = pt
                )
                // highlight ring
                drawCircle(
                    color = Color.White,
                    radius = 6.dp.toPx(),
                    center = pt
                )
            }
            drawCircle(
                color = DarkSurface,
                radius = 4.5.dp.toPx(),
                center = pt
            )
            drawCircle(
                color = if (isSelected) AccentViolet else AccentVioletLight,
                radius = 3.dp.toPx(),
                center = pt
            )
        }
    }
}

// ── Interactive Detail Panel ────────────────────────────────────────
@Composable
fun InteractiveDetailsCard(point: StatPoint) {
    val progressPct = (point.percentage * 100).toInt()
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(DarkSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
            .padding(20.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = point.rawDateDescription.uppercase(),
                color = TextSecondary,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "$progressPct% Completed",
                color = AccentVioletLight,
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraBold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "${point.completedCount} tasks done out of ${point.totalCount} total",
                color = TextPrimary.copy(alpha = 0.8f),
                fontSize = 13.sp
            )
        }

        Spacer(modifier = Modifier.width(16.dp))

        // Circular progress ring showing exact ratio
        Box(
            modifier = Modifier.size(54.dp),
            contentAlignment = Alignment.Center
        ) {
            val progressAnim by animateFloatAsState(
                targetValue = point.percentage,
                animationSpec = tween(500),
                label = "ring"
            )
            Canvas(modifier = Modifier.fillMaxSize()) {
                drawCircle(
                    color = Color(0x0DFFFFFF),
                    style = Stroke(width = 4.dp.toPx())
                )
                drawArc(
                    color = if (progressPct == 100) GreenAccent else AccentViolet,
                    startAngle = -90f,
                    sweepAngle = 360f * progressAnim,
                    useCenter = false,
                    style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round)
                )
            }
            Text(
                text = "${point.completedCount}/${point.totalCount}",
                color = TextPrimary,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

// ── In-Depth Advanced Analytics Calculations ─────────────────────────
@Composable
fun DynamicInsightsGrid(combinedStats: List<TaskCompletionHistory>) {
    // 1. Most Productive Day of Week
    val bestDayText = remember(combinedStats) {
        if (combinedStats.isEmpty()) "N/A" else {
            val dayOfWeekAverages = combinedStats.mapNotNull { entry ->
                try {
                    val date = LocalDate.parse(entry.date)
                    val pct = if (entry.totalCount > 0) entry.completedCount.toFloat() / entry.totalCount else 0f
                    date.dayOfWeek to pct
                } catch (e: Exception) {
                    null
                }
            }.groupBy { it.first }
             .mapValues { (_, pairs) -> pairs.map { it.second }.average() }

            val bestDay = dayOfWeekAverages.maxByOrNull { it.value }
            if (bestDay != null && bestDay.value > 0.0) {
                val dayName = bestDay.key.name.lowercase().replaceFirstChar { it.uppercase() }
                val pctText = (bestDay.value * 100).toInt()
                "$dayName ($pctText%)"
            } else "N/A"
        }
    }

    // 2. Consistency Index (% of perfect completion days)
    val consistencyIndex = remember(combinedStats) {
        if (combinedStats.isEmpty()) 0 else {
            val perfectDays = combinedStats.count { it.completedCount == it.totalCount && it.totalCount > 0 }
            (perfectDays.toFloat() / combinedStats.size * 100).toInt()
        }
    }

    // 3. Total Habits Logged (all-time completions sum)
    val totalAchievements = remember(combinedStats) {
        combinedStats.sumOf { it.completedCount }
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Left Column Insights
        Column(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(20.dp))
                .background(DarkSurface)
                .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
                .padding(16.dp)
        ) {
            Text(
                text = "BEST WORKDAY",
                color = TextSecondary,
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = bestDayText,
                color = AccentVioletLight,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Highest completion avg",
                color = TextSecondary.copy(alpha = 0.6f),
                fontSize = 10.sp
            )
        }

        // Right Column Insights
        Column(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(20.dp))
                .background(DarkSurface)
                .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
                .padding(16.dp)
        ) {
            Text(
                text = "CONSISTENCY INDEX",
                color = TextSecondary,
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "$consistencyIndex%",
                color = GreenAccent,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "$totalAchievements total completed tasks",
                color = TextSecondary.copy(alpha = 0.6f),
                fontSize = 10.sp
            )
        }
    }
}

// ── Reset History Button Component ────────────────────────────────────
@Composable
fun ResetHistoryButton(onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .border(1.dp, RedAccent.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
            .clickable { onClick() }
            .padding(vertical = 14.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.DeleteForever,
                contentDescription = "Reset History",
                tint = RedAccent,
                modifier = Modifier.size(20.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "Reset Analytics History",
                color = RedAccent,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}
