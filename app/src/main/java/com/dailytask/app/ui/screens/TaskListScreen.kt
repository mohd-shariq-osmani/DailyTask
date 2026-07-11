package com.dailytask.app.ui.screens

import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.compose.ui.window.Dialog
import com.dailytask.app.data.Task
import com.dailytask.app.ui.theme.*
import com.dailytask.app.viewmodel.TaskViewModel
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TaskListScreen(
    viewModel: TaskViewModel,
    onNavigateToStats: () -> Unit
) {
    val tasks by viewModel.allTasks.collectAsState()
    var showAddDialog by remember { mutableStateOf(false) }
    var taskToDelete by remember { mutableStateOf<Task?>(null) }

    val currentDateStr = remember {
        LocalDate.now().format(DateTimeFormatter.ofPattern("EEE, d MMM")).uppercase()
    }

    val total = tasks.size
    val completed = tasks.count { it.isCompleted }
    val left = total - completed
    val progress = if (total > 0) completed.toFloat() / total.toFloat() else 0f
    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(600, easing = LinearOutSlowInEasing),
        label = "progressAnim"
    )

    // Drag and drop state
    var draggedIndex by remember { mutableStateOf<Int?>(null) }
    var dragOffset by remember { mutableFloatStateOf(0f) }
    val density = LocalDensity.current
    val itemHeightPx = remember { with(density) { 96.dp.toPx() } }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBackground)
    ) {
        // ── Ambient glow blob (cinematic atmosphere) ─────────────────
        Box(
            modifier = Modifier
                .size(360.dp)
                .offset(x = (-60).dp, y = (-40).dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            AccentViolet.copy(alpha = 0.06f),
                            Color.Transparent
                        ),
                        radius = 500f
                    )
                )
        )
        Box(
            modifier = Modifier
                .size(280.dp)
                .align(Alignment.BottomEnd)
                .offset(x = 80.dp, y = 120.dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(
                            AccentVioletMuted.copy(alpha = 0.05f),
                            Color.Transparent
                        ),
                        radius = 400f
                    )
                )
        )

        Scaffold(
            topBar = {
                CenterAlignedTopAppBar(
                    title = {
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .background(DarkSurface)
                                .border(1.dp, GlassBorder, RoundedCornerShape(12.dp))
                                .padding(horizontal = 16.dp, vertical = 7.dp)
                        ) {
                            Text(
                                text = currentDateStr,
                                color = TextSecondary,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 12.sp,
                                letterSpacing = 0.8.sp
                            )
                        }
                    },
                    navigationIcon = {
                        Box(modifier = Modifier.padding(start = 8.dp)) {
                            Icon(
                                imageVector = Icons.Default.CheckCircle,
                                contentDescription = "DailyTask",
                                tint = AccentViolet,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    },
                    actions = {
                        IconButton(
                            onClick = onNavigateToStats,
                            modifier = Modifier.size(48.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.BarChart,
                                contentDescription = "Statistics",
                                tint = TextSecondary,
                                modifier = Modifier.size(24.dp)
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
                Spacer(modifier = Modifier.height(12.dp))

                // ── Title: Daily + Task ──────────────────────────────
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Daily",
                        color = TextPrimary,
                        fontSize = 38.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = (-0.5).sp
                    )
                    Text(
                        text = "Task",
                        color = AccentViolet,
                        fontSize = 38.sp,
                        fontWeight = FontWeight.Black,
                        letterSpacing = (-0.5).sp
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Subtitle
                Text(
                    text = "Stay consistent. Build habits.",
                    color = TextSecondary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Normal,
                    letterSpacing = 0.2.sp
                )

                Spacer(modifier = Modifier.height(28.dp))

                // ── Progress Bar ─────────────────────────────────────
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = "PROGRESS",
                            color = TextSecondary,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 1.5.sp
                        )
                        Text(
                            text = "$completed / $total",
                            color = AccentVioletLight,
                            fontSize = 14.sp,
                            fontWeight = FontWeight.Bold
                        )
                    }

                    Spacer(modifier = Modifier.height(10.dp))

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(8.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(DarkSurface)
                    ) {
                        Box(
                            modifier = Modifier
                                .fillMaxHeight()
                                .fillMaxWidth(animatedProgress)
                                .clip(RoundedCornerShape(4.dp))
                                .background(
                                    Brush.horizontalGradient(
                                        colors = listOf(AccentViolet, AccentVioletLight)
                                    )
                                )
                        )
                    }
                }

                Spacer(modifier = Modifier.height(28.dp))

                // ── Section Header ───────────────────────────────────
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "TODAY'S TASKS",
                        color = TextSecondary,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        letterSpacing = 1.5.sp
                    )
                    if (tasks.isNotEmpty()) {
                        Text(
                            text = "$left remaining",
                            color = if (left == 0) GreenAccent else TextSecondary,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                // ── Task List ────────────────────────────────────────
                if (tasks.isEmpty()) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(
                                imageVector = Icons.Default.CheckCircleOutline,
                                contentDescription = null,
                                tint = TextSecondary.copy(alpha = 0.3f),
                                modifier = Modifier.size(56.dp)
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "No tasks yet",
                                color = TextSecondary,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "Tap the button below to add your first task",
                                color = TextSecondary.copy(alpha = 0.6f),
                                fontSize = 14.sp,
                                textAlign = TextAlign.Center
                            )
                        }
                    }
                } else {
                    LazyColumn(
                        state = rememberLazyListState(),
                        modifier = Modifier.weight(1f),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        contentPadding = PaddingValues(bottom = 16.dp)
                    ) {
                        itemsIndexed(tasks, key = { _, task -> task.id }) { index, task ->
                            val isCurrentDragging = index == draggedIndex
                            val itemOffset = if (isCurrentDragging) dragOffset else 0f

                            val dismissState = rememberSwipeToDismissBoxState(
                                confirmValueChange = { dismissValue ->
                                    if (dismissValue == SwipeToDismissBoxValue.EndToStart) {
                                        taskToDelete = task
                                        false
                                    } else {
                                        false
                                    }
                                }
                            )

                            SwipeToDismissBox(
                                state = dismissState,
                                enableDismissFromStartToEnd = false,
                                modifier = Modifier
                                    .animateItem()
                                    .zIndex(if (isCurrentDragging) 1f else 0f)
                                    .offset { IntOffset(0, itemOffset.roundToInt()) }
                                    .pointerInput(tasks) {
                                        detectDragGesturesAfterLongPress(
                                            onDragStart = {
                                                draggedIndex = index
                                                dragOffset = 0f
                                            },
                                            onDrag = { change, dragAmount ->
                                                change.consume()
                                                dragOffset += dragAmount.y

                                                val currentDragIndex = draggedIndex
                                                    ?: return@detectDragGesturesAfterLongPress

                                                if (dragOffset > itemHeightPx) {
                                                    if (currentDragIndex < tasks.size - 1) {
                                                        viewModel.swapTasksLocal(
                                                            currentDragIndex,
                                                            currentDragIndex + 1
                                                        )
                                                        draggedIndex = currentDragIndex + 1
                                                        dragOffset -= itemHeightPx
                                                    }
                                                } else if (dragOffset < -itemHeightPx) {
                                                    if (currentDragIndex > 0) {
                                                        viewModel.swapTasksLocal(
                                                            currentDragIndex,
                                                            currentDragIndex - 1
                                                        )
                                                        draggedIndex = currentDragIndex - 1
                                                        dragOffset += itemHeightPx
                                                    }
                                                }
                                            },
                                            onDragEnd = {
                                                viewModel.saveTaskOrder()
                                                draggedIndex = null
                                                dragOffset = 0f
                                            },
                                            onDragCancel = {
                                                viewModel.saveTaskOrder()
                                                draggedIndex = null
                                                dragOffset = 0f
                                            }
                                        )
                                    },
                                backgroundContent = {
                                    // Swipe-to-delete red reveal
                                    Box(
                                        modifier = Modifier
                                            .fillMaxSize()
                                            .clip(RoundedCornerShape(20.dp))
                                            .background(RedAccent)
                                            .padding(horizontal = 28.dp),
                                        contentAlignment = Alignment.CenterEnd
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.DeleteOutline,
                                            contentDescription = "Delete",
                                            tint = Color.White,
                                            modifier = Modifier.size(24.dp)
                                        )
                                    }
                                },
                                content = {
                                    PremiumTaskCard(
                                        task = task,
                                        onToggle = { viewModel.toggleTask(task) }
                                    )
                                }
                            )
                        }
                    }
                }

                // ── Bottom Action Panel ──────────────────────────────
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    // Reset Button
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(DarkSurface)
                            .border(1.dp, GlassBorder, RoundedCornerShape(16.dp))
                            .clickable { viewModel.resetDay() },
                        contentAlignment = Alignment.Center
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Refresh,
                                contentDescription = "Reset",
                                tint = TextSecondary,
                                modifier = Modifier.size(18.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Reset day",
                                color = TextPrimary,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold
                            )
                        }
                    }

                    // Add Task Button
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(52.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .drawBehind {
                                // Accent glow behind button
                                drawCircle(
                                    color = AccentViolet.copy(alpha = 0.15f),
                                    radius = size.width * 0.6f,
                                    center = Offset(size.width / 2, size.height / 2)
                                )
                            }
                            .background(
                                Brush.horizontalGradient(
                                    colors = listOf(AccentViolet, AccentVioletLight)
                                ),
                                shape = RoundedCornerShape(16.dp)
                            )
                            .clickable { showAddDialog = true },
                        contentAlignment = Alignment.Center
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = "Add",
                                tint = Color.White,
                                modifier = Modifier.size(20.dp)
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "Add task",
                                color = Color.White,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }
                }
            }
        }

        if (showAddDialog) {
            PremiumAddTaskDialog(
                onDismiss = { showAddDialog = false },
                onConfirm = { title ->
                    if (title.isNotBlank()) {
                        val randomColor = PresetTaskColors.random()
                        viewModel.addTask(title, randomColor)
                    }
                    showAddDialog = false
                }
            )
        }

        if (taskToDelete != null) {
            AlertDialog(
                onDismissRequest = { taskToDelete = null },
                title = {
                    Text(
                        text = "Delete Task",
                        color = TextPrimary,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                },
                text = {
                    Text(
                        text = "Are you sure you want to delete \"${taskToDelete?.title}\"? This action cannot be undone.",
                        color = TextSecondary,
                        fontSize = 15.sp
                    )
                },
                confirmButton = {
                    Button(
                        onClick = {
                            taskToDelete?.let { viewModel.deleteTask(it) }
                            taskToDelete = null
                        },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = RedAccent,
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text("Delete", fontWeight = FontWeight.Bold)
                    }
                },
                dismissButton = {
                    TextButton(
                        onClick = { taskToDelete = null }
                    ) {
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

// ── Premium Task Card ────────────────────────────────────────────────
@Composable
fun PremiumTaskCard(
    task: Task,
    onToggle: () -> Unit
) {
    val taskColor = remember(task.colorHex) {
        try {
            Color(android.graphics.Color.parseColor(task.colorHex))
        } catch (e: Exception) {
            AccentViolet
        }
    }

    val strikeProgress by animateFloatAsState(
        targetValue = if (task.isCompleted) 1f else 0f,
        animationSpec = tween(350, easing = LinearOutSlowInEasing),
        label = "strike"
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(DarkSurface)
            .border(1.dp, GlassBorder, RoundedCornerShape(20.dp))
            .clickable { onToggle() }
            .padding(horizontal = 20.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Custom checkbox
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(RoundedCornerShape(9.dp))
                .background(if (task.isCompleted) taskColor else Color.Transparent)
                .border(
                    width = if (task.isCompleted) 0.dp else 2.dp,
                    color = if (task.isCompleted) Color.Transparent else taskColor.copy(alpha = 0.4f),
                    shape = RoundedCornerShape(9.dp)
                )
                .clickable { onToggle() },
            contentAlignment = Alignment.Center
        ) {
            if (task.isCompleted) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Done",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        Spacer(modifier = Modifier.width(16.dp))

        // Task title with strikethrough
        Text(
            text = task.title,
            color = if (task.isCompleted) TextTertiary else TextPrimary,
            fontSize = 17.sp,
            fontWeight = if (task.isCompleted) FontWeight.Normal else FontWeight.SemiBold,
            modifier = Modifier
                .weight(1f)
                .drawWithContent {
                    drawContent()
                    if (strikeProgress > 0f) {
                        val y = size.height / 2f
                        drawLine(
                            color = taskColor.copy(alpha = 0.7f),
                            start = Offset(0f, y),
                            end = Offset(size.width * strikeProgress, y),
                            strokeWidth = 2.dp.toPx()
                        )
                    }
                },
            letterSpacing = 0.1.sp
        )

        Spacer(modifier = Modifier.width(12.dp))

        // Color indicator dot
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(taskColor.copy(alpha = if (task.isCompleted) 0.3f else 1f))
        )
    }
}

// ── Premium Add Task Dialog ──────────────────────────────────────────
@Composable
fun PremiumAddTaskDialog(
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var text by remember { mutableStateOf("") }

    Dialog(onDismissRequest = onDismiss) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(DarkSurface)
                .border(1.dp, GlassBorder, RoundedCornerShape(24.dp))
                .padding(28.dp)
        ) {
            Column {
                // Header
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = null,
                        tint = AccentViolet,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(modifier = Modifier.width(10.dp))
                    Text(
                        text = "New Task",
                        color = TextPrimary,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Spacer(modifier = Modifier.height(24.dp))

                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    placeholder = {
                        Text(
                            text = "Enter task name...",
                            color = TextSecondary.copy(alpha = 0.5f)
                        )
                    },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = TextPrimary,
                        unfocusedTextColor = TextPrimary,
                        focusedBorderColor = AccentViolet,
                        unfocusedBorderColor = GlassBorder,
                        focusedContainerColor = DarkSurfaceVariant,
                        unfocusedContainerColor = DarkSurfaceVariant,
                        cursorColor = AccentViolet
                    ),
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(14.dp),
                    singleLine = true
                )

                Spacer(modifier = Modifier.height(28.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text(
                            text = "Cancel",
                            color = TextSecondary,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Button(
                        onClick = { onConfirm(text) },
                        colors = ButtonDefaults.buttonColors(
                            containerColor = AccentViolet,
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(14.dp),
                        modifier = Modifier.height(48.dp)
                    ) {
                        Text(
                            text = "Add Task",
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                    }
                }
            }
        }
    }
}
