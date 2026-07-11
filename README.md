# DailyTask

DailyTask is a clean, modern, premium Android application built with Jetpack Compose. It allows you to manage and track your recurring daily tasks, routine goals, and streaks securely in one place.
DailyTask is designed for complete privacy—it stores all task details, completion histories, and streak counts locally on your device, ensuring your data never leaves your phone.

## Key Features
- **Daily Recurrence & Auto-Reset**: Keep your focus on today's routine. Completed tasks automatically reset at midnight, preparing you for the next day.
- **Interactive Gestures**: Long-press and drag any task to change its ordering, or swipe left on a task to delete it with a double-check confirmation prompt.
- **Home Screen Widget**: Custom widget displaying your tasks in a two-column grid. Tasks are automatically sorted (completed pushed to the bottom), with dynamic active count indicators and live completion rates.
- **Streak & Trend Analytics**: Beautiful offline stats dashboard. Tracks success rates, current streaks of perfect completion days, and draws an area line graph plotting 7-day and 30-day habits.
- **Google Assistant Voice shortcuts**: Integration with Android's built-in shortcuts framework, allowing you to ask Assistant or Gemini to mark tasks as complete hands-free.

## Tech Stack & Architecture
- UI Framework: Jetpack Compose (Kotlin-first declarative UI)
- Database / Storage: Local SQLite Persistence via Room Database (DAO, Entities, Migrations)
- Asynchronous Flow: Kotlin Coroutines & Flow API
- Architecture Pattern: MVVM (Model-View-ViewModel) with repository layers
- OS Integration: AppWidgetProvider (RemoteViews) & Google Assistant shortcuts

## Installation & Setup
1. Clone the Repository:
   ```bash
   git clone https://github.com/mohd-shariq-osmani/DailyTask.git
   cd DailyTask
   ```

2. Open in Android Studio:
   - Select File > Open and choose the `DailyTask` folder.
   - Allow Gradle to sync and download the required toolchain and SDK packages.

3. Run the Application:
   - Connect your Android device via USB or Wi-Fi debugging.
   - Build and deploy the debug package (`app-debug.apk`).

## Project Structure
```
app/src/main/
├── AndroidManifest.xml          # Main application manifest declaring shortcuts and widget providers
├── java/com/dailytask/app/
│   ├── MainActivity.kt          # Main entry point and voice assistant intent router
│   ├── DailyTaskWidgetProvider.kt # Widget lifecycle coordinator and remote layouts updater
│   ├── data/
│   │   ├── Task.kt              # Room entity mapping task title, color, and order
│   │   ├── TaskCompletionHistory.kt # Room entity logging daily completion summaries
│   │   ├── TaskDao.kt           # Room query operations interface
│   │   ├── DailyTaskDatabase.kt # Main SQLite database client mapping migration paths
│   │   └── TaskRepository.kt    # Data source coordinator handling date checks & midnight resets
│   ├── viewmodel/
│   │   └── TaskViewModel.kt     # App state manager handling memory-swaps & widget broadcasts
│   └── ui/
│       ├── theme/               # Cinema dark colors, typography definitions & themes
│       └── screens/
│           ├── TaskListScreen.kt # Checklist dashboard with reorder & swipe actions
│           └── StatsScreen.kt   # Analytics dashboard with line chart Canvas drawings
└── res/
    ├── layout/                  # XML templates for the home screen widget columns & layout
    ├── xml/                     # Widget configuration settings and Assistant shortcuts mappings
    └── mipmap-*/                # Premium custom Launcher launcher icons
```

## Security & Privacy Policy
- Offline Local Storage: All data stays on your local device. The application does not require any network permissions (such as `android.permission.INTERNET`), guaranteeing your daily routine telemetry never leaves your device.
- Automatic Backfill: A localized offline clock-check backfills missed days with zero counts if the application is not opened, preserving clean analytics.
