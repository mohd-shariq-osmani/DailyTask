# DailyTask

A clean, dark-themed Android application to manage daily recurring tasks.

## Features
- **Daily Routine Checklist**: Tasks automatically reset every night.
- **Home Screen Widget**: Track completion progress and check off tasks directly from your home screen.
- **Interactive Gestures**: Drag and drop tasks to change their order, and swipe left on a task to delete it with a confirmation prompt.
- **Progress Tracking**: Analytics screen showing daily completion rates and perfect streak metrics over 7-day and 30-day periods.
- **Google Assistant Shortcuts**: Mark tasks complete using voice commands.

## Architecture & Tech Stack
- **Language**: Kotlin
- **UI Framework**: Jetpack Compose
- **Database**: Room Database (SQLite) for local storage
- **Asynchronous Flow**: Kotlin Coroutines & Flow
- **Architecture Pattern**: MVVM

## Build & Run
1. Open the project in Android Studio.
2. Build via Gradle:
   ```bash
   ./gradlew assembleDebug
   ```
3. Run or install the generated APK on your device:
   ```bash
   adb install app/build/outputs/apk/debug/app-debug.apk
   ```
