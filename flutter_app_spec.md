# DailyTask - Flutter Remake Specification

This document outlines the features, design, and architecture for remaking the **DailyTask** application in Flutter, targeting both Android and iOS platforms.

---

## 1. Design System & UI/UX Guidelines
We will follow the **Modern Dark (Cinema Mobile)** theme guidelines to achieve a premium, high-fidelity aesthetic.

### Color Palette
- **Background**: Near-Black (`#050507`) to optimize for OLED screens and prevent screen smear.
- **Surfaces/Cards**: Dark Elevated Charcoal (`#0D0D11`) with a hairline border (`rgba(255,255,255,0.06)`).
- **Primary Accent**: Refined Violet (`#8B5CF6`) with a soft glow effect.
- **Secondary Accent**: Lavender/Light Violet (`#A78BFA`).
- **Semantic Colors**:
  - Success/Completed: Emerald Green (`#34D399`).
  - Destructive/Delete: Red (`#EF4444`).
- **Text Palette**:
  - Primary: Warm White (`#F0F0F3`).
  - Secondary (Muted): Cool Gray (`#6B7280`).
  - Completed/Disabled: Muted Charcoal (`#404040`).

### Interactive Effects & Animations
- **Ambient Glow**: Dynamic, slow-moving radial background gradients in violet and indigo to create atmospheric depth.
- **Spring Physics**: Modal dismissals and card tap responses should use spring easing curves.
- **Smooth Easing**: Transition views with cubic-bezier-style easing curves (e.g. `cubic-bezier(0.16, 1, 0.3, 1)`).

---

## 2. Core Checklist & Task Features
The home screen serves as the core routine cockpit.

### Task List Features
- **Auto-Midnight Reset**: Tasks automatically reset to incomplete at midnight. If the app is not opened for days, the system backfills intermediate days with zero completion records in the history logs to maintain correct analytics.
- **Auto-Assigned Colors**: Adding a task automatically assigns it a color from a premium neon preset palette (e.g. violet, emerald, pink, sky blue, amber, orange, teal, indigo).
- **Completion Sorting**: Completed tasks animate with a strike-through using their assigned color and are automatically pushed to the bottom of the list.
- **Reordering**: Long-press and drag-and-drop gestures to manually rearrange active tasks.
- **Swipe-to-Dismiss**: Swiping left on a task card displays a red delete zone, which triggers a styled confirmation pop-up modal warning that the action is permanent.
- **Reset Button**: A secondary action to clear/uncheck all completions for the current day.

---

## 3. Flagship Analytics Dashboard
An in-depth, interactive statistics center divided into two tabs:

### Tab 1: Overview Dashboard
- **GitHub-Style Contribution Heatmap**:
  - A scrollable grid showing the last 13 weeks of completions.
  - Cells are color-graded based on daily completion rates (dark gray for 0% up to glowing violet for 100%).
  - Tapping a cell dynamically selects that date to load its data.
- **Canvas Trend Chart**:
  - Dynamic line/area graph plotting completion percentages.
  - Segmented controls to view progress by **Days** (last 7 or 30 days), **Weeks** (last 4 or 8 weeks), or **Months** (last 3 or 6 months).
  - Gestures/Taps on the chart draw a vertical dashed guide-line and display a tooltip detailing the exact completion rate.
- **Interactive Details Card**:
  - Shows progress for the selected day/week/month with an animated circular gauge.
- **Task List Breakdown**:
  - Displays the exact checklist of completed and incomplete tasks for the selected date.
- **Overall Metric Summary Cards**:
  - **Success Rate**: Overall percentage average.
  - **Streak Counters**: Current consecutive perfect days completed (🔥) and all-time max streak (🏆).

### Tab 2: Task-Wise Analysis
- Lists all active tasks with individual analysis cards:
  - Overall completion rate percentage.
  - Current completion streak 🔥 and maximum historical streak 🏆.
  - Most consistent workday (e.g., "Tuesday").
  - **7-Day Consistency Sparkline**: A row of 7 task-colored circular dots displaying completion status for the last 7 days.

### Settings Option
- **Reset History Data**: A destructive action at the bottom of the analytics views to permanently delete all history records and daily task logs, resetting streak counts without deleting the active task checklist.

---

## 4. Platform-Specific Integrations
- **Home Screen Widgets**:
  - **Android**: Custom AppWidget showing progress and listing tasks in a scrollable, two-column grid.
  - **iOS**: WidgetKit implementation matching the same layouts.
- **Voice Assistants**:
  - **Android**: Shortcuts integrations (shortcuts.xml) mapping semantic intents to Assistant/Gemini to check off tasks by voice.
  - **iOS**: Siri Shortcuts configuration for checking off tasks.

---

## 5. Proposed Flutter Architecture
- **State Management**: `flutter_riverpod` or simple `ChangeNotifier` (Provider) for lightweight architecture.
- **Local Persistence**: `sqflite` (SQLite) or `hive` (NoSQL) for local offline storage. Since the native app used Room, `sqflite` maps perfectly to the database structures.
- **Drawing/Charts**: Custom canvas painter or a package like `fl_chart`. We will use CustomPainter to match the exact premium gestured canvas design.
