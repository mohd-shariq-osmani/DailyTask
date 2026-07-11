package com.dailytask.app.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailytask.app.data.TaskCompletionHistory
import com.dailytask.app.ui.theme.*
import com.dailytask.app.viewmodel.TaskViewModel
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(
    viewModel: TaskViewModel,
    onNavigateBack: () -> Unit
) {
    val history by viewModel.allHistory.collectAsState()
    val currentTasks by viewModel.allTasks.collectAsState()

    var selectedRange by remember { mutableStateOf(7) }

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

    val displayStats = remember(combinedStats, selectedRange) {
        if (combinedStats.size > selectedRange) {
            combinedStats.takeLast(selectedRange)
        } else {
            combinedStats
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
    ) {
        // Ambient glow
        Box(
            modifier = Modifier
                .size(300.dp)
                .align(Alignment.BottomStart)
                .offset(x = (-100).dp, y = 100.dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            AccentVioletMuted.copy(alpha = 0.06f),
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
                            text = "Analytics",
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
                // Range Selector
                RangeSelector(
                    selectedRange = selectedRange,
                    onRangeSelected = { selectedRange = it }
                )

                Spacer(modifier = Modifier.height(20.dp))

                // Graph Card
                GraphCard(stats = displayStats, days = selectedRange)

                Spacer(modifier = Modifier.height(20.dp))

                // Stats summaries
                StatsSummaryCards(statsList = combinedStats)
            }
        }
    }
}

@Composable
fun RangeSelector(selectedRange: Int, onRangeSelected: (Int) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(DarkSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(14.dp))
            .padding(4.dp)
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selectedRange == 7) AccentViolet else Color.Transparent)
                .clickable { onRangeSelected(7) }
                .padding(vertical = 11.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "Last 7 Days",
                color = if (selectedRange == 7) Color.White else TextSecondary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp
            )
        }
        Box(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(10.dp))
                .background(if (selectedRange == 30) AccentViolet else Color.Transparent)
                .clickable { onRangeSelected(30) }
                .padding(vertical = 11.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "Last 30 Days",
                color = if (selectedRange == 30) Color.White else TextSecondary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 13.sp
            )
        }
    }
}

@Composable
fun GraphCard(stats: List<TaskCompletionHistory>, days: Int) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(DarkSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
            .padding(20.dp)
    ) {
        Column {
            Text(
                text = "Completion Trend",
                color = TextPrimary,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = "Completed vs. Total tasks",
                color = TextSecondary,
                fontSize = 12.sp
            )

            Spacer(modifier = Modifier.height(24.dp))

            if (stats.isEmpty()) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(220.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Not enough data yet.\nCheck back tomorrow!",
                        color = TextSecondary,
                        textAlign = TextAlign.Center,
                        fontSize = 14.sp
                    )
                }
            } else {
                StatsGraph(stats = stats)
            }
        }
    }
}

@Composable
fun StatsGraph(stats: List<TaskCompletionHistory>) {
    Canvas(
        modifier = Modifier
            .fillMaxWidth()
            .height(220.dp)
    ) {
        val width = size.width
        val height = size.height

        val maxTotal = stats.maxOf { it.totalCount }.coerceAtLeast(1)
        val paddingLeft = 30.dp.toPx()
        val paddingBottom = 25.dp.toPx()
        val paddingTop = 10.dp.toPx()
        val paddingRight = 10.dp.toPx()

        val graphWidth = width - paddingLeft - paddingRight
        val graphHeight = height - paddingTop - paddingBottom

        // Grid lines
        val gridLines = 4
        for (i in 0..gridLines) {
            val y = paddingTop + graphHeight * (1f - (i.toFloat() / gridLines))
            drawLine(
                color = Color(0x0DFFFFFF),
                start = Offset(paddingLeft, y),
                end = Offset(width - paddingRight, y),
                strokeWidth = 1.dp.toPx()
            )
        }

        val stepX = if (stats.size > 1) graphWidth / (stats.size - 1) else graphWidth

        val completedPoints = stats.mapIndexed { index, entry ->
            val x = paddingLeft + index * stepX
            val ratio = entry.completedCount.toFloat() / maxTotal.toFloat()
            val y = paddingTop + graphHeight * (1f - ratio)
            Offset(x, y)
        }

        val totalPoints = stats.mapIndexed { index, entry ->
            val x = paddingLeft + index * stepX
            val ratio = entry.totalCount.toFloat() / maxTotal.toFloat()
            val y = paddingTop + graphHeight * (1f - ratio)
            Offset(x, y)
        }

        // Total line (dashed)
        val totalPath = Path().apply {
            totalPoints.forEachIndexed { i, pt ->
                if (i == 0) moveTo(pt.x, pt.y) else lineTo(pt.x, pt.y)
            }
        }
        drawPath(
            path = totalPath,
            color = AccentVioletMuted.copy(alpha = 0.3f),
            style = Stroke(
                width = 1.5.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 10f))
            )
        )

        // Completed area gradient
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
                        AccentViolet.copy(alpha = 0.20f),
                        AccentViolet.copy(alpha = 0.0f)
                    ),
                    startY = completedPoints.map { it.y }.minOrNull() ?: 0f,
                    endY = paddingTop + graphHeight
                )
            )
        }

        // Completed line
        val completedLinePath = Path().apply {
            completedPoints.forEachIndexed { i, pt ->
                if (i == 0) moveTo(pt.x, pt.y) else lineTo(pt.x, pt.y)
            }
        }
        drawPath(
            path = completedLinePath,
            color = AccentViolet,
            style = Stroke(width = 2.5.dp.toPx(), cap = StrokeCap.Round)
        )

        // Data dots
        completedPoints.forEach { pt ->
            drawCircle(
                color = DarkSurface,
                radius = 5.dp.toPx(),
                center = pt
            )
            drawCircle(
                color = AccentViolet,
                radius = 3.dp.toPx(),
                center = pt
            )
        }

        // Date tick marks
        if (stats.size > 1) {
            val labelIndices = if (stats.size <= 5) {
                stats.indices.toList()
            } else {
                listOf(0, stats.size / 2, stats.size - 1)
            }
            labelIndices.forEach { idx ->
                val pt = completedPoints[idx]
                drawLine(
                    color = Color(0x1AFFFFFF),
                    start = Offset(pt.x, paddingTop + graphHeight),
                    end = Offset(pt.x, paddingTop + graphHeight + 4.dp.toPx()),
                    strokeWidth = 1.dp.toPx()
                )
            }
        }
    }
}

@Composable
fun StatsSummaryCards(statsList: List<TaskCompletionHistory>) {
    val totalCompletedTasks = statsList.sumOf { it.completedCount }
    val totalCountTasks = statsList.sumOf { it.totalCount }

    val avgCompletionRate = if (totalCountTasks > 0) {
        (totalCompletedTasks.toFloat() / totalCountTasks.toFloat() * 100).toInt()
    } else 0

    // Streak calculation
    var currentStreak = 0
    val sortedStats = statsList.sortedByDescending { it.date }
    val todayStr = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE)
    val yesterdayStr = LocalDate.now().minusDays(1).format(DateTimeFormatter.ISO_LOCAL_DATE)

    var checkedDate = if (sortedStats.firstOrNull()?.date == todayStr) {
        LocalDate.now()
    } else if (sortedStats.firstOrNull()?.date == yesterdayStr) {
        LocalDate.now().minusDays(1)
    } else {
        null
    }

    if (checkedDate != null) {
        for (stat in sortedStats) {
            val statDate = LocalDate.parse(stat.date, DateTimeFormatter.ISO_LOCAL_DATE)
            if (statDate == checkedDate && stat.completedCount == stat.totalCount && stat.totalCount > 0) {
                currentStreak++
                checkedDate = checkedDate!!.minusDays(1)
            } else if (statDate == checkedDate) {
                break
            }
        }
    }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        // Success Rate Card
        Column(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(20.dp))
                .background(DarkSurface)
                .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
                .padding(20.dp),
            horizontalAlignment = Alignment.Start
        ) {
            Text(
                text = "SUCCESS RATE",
                color = TextSecondary,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "$avgCompletionRate%",
                color = GreenAccent,
                fontSize = 28.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = (-0.5).sp
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Overall average",
                color = TextSecondary.copy(alpha = 0.6f),
                fontSize = 11.sp
            )
        }

        // Streak Card
        Column(
            modifier = Modifier
                .weight(1f)
                .clip(RoundedCornerShape(20.dp))
                .background(DarkSurface)
                .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
                .padding(20.dp),
            horizontalAlignment = Alignment.Start
        ) {
            Text(
                text = "STREAK",
                color = TextSecondary,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
            Spacer(modifier = Modifier.height(12.dp))
            Text(
                text = "$currentStreak Days",
                color = AccentVioletLight,
                fontSize = 28.sp,
                fontWeight = FontWeight.Black,
                letterSpacing = (-0.5).sp
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "Perfect completions",
                color = TextSecondary.copy(alpha = 0.6f),
                fontSize = 11.sp
            )
        }
    }
}
