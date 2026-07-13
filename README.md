# DailyTask (Flutter Remake)

DailyTask is a premium, cinematic dark-themed checklist tracking and habit analytics application built in Flutter. It is designed to run seamlessly across Android, iOS, Web, and Desktop platforms, and supports interactive widgets with live state synchronization.

---

## 🚀 Prerequisites

Before you build and install the application, make sure you have the following installed on your machine:

1. **Flutter SDK**: Version `3.22.0` or higher.
2. **Dart SDK**: Synced with your Flutter installation.
3. **For Android Development**:
   - Android Studio (with the Android SDK and SDK Command-line Tools installed).
   - Java Development Kit (JDK 17 recommended).
4. **For iOS & macOS Development**:
   - macOS computer.
   - Xcode (latest version).
   - CocoaPods (`pod install`).
   - Active Apple Developer Account (for code signing and App Group entitlements).

---

## 🛠️ Setup & Installation

Clone the repository and fetch the dependencies:

```bash
git clone https://github.com/mohd-shariq-osmani/DailyTask.git
cd DailyTask
flutter pub get
```

---

## 📱 Platform Build Instructions

### 1. Android Installation
You can build and deploy the application to a physical Android device or emulator.

* **Developer Mode**: Ensure developer mode and USB Debugging are enabled on your physical device. Connect the device via USB.
* **Run in Debug Mode**:
  ```bash
  flutter run -d <your-device-id>
  ```
* **Build Debug/Release APK**:
  ```bash
  # Build a debug APK
  flutter build apk --debug
  
  # Build a release App Bundle (for Play Store upload)
  flutter build appbundle
  ```
* **Install manually via ADB**:
  ```bash
  adb install build/app/outputs/flutter-apk/app-debug.apk
  ```

#### 🧩 Android Widget Support:
- The Android widget leverages a native SQLite background service helper (`DailyTaskWidgetProvider.kt`) to directly toggle completion states inside the database. It is registered in the launcher widgets library automatically.

---

### 2. iOS Installation (macOS & Xcode Required)
iOS requires provisioning profiles and code signing entitlements due to Sandbox restrictions.

1. **Install CocoaPods Dependencies**:
   ```bash
   cd ios
   pod install
   cd ..
   ```
2. **Open the Project in Xcode**:
   Open `ios/Runner.xcworkspace` in Xcode.
3. **Configure Code Signing**:
   - Select the main **`Runner`** project target.
   - Go to the **Signing & Capabilities** tab.
   - Select your personal Apple Developer Team under **Team**.
   - Select the **`DailyTaskWidgetExtension`** target in the sidebar and repeat the step (assigning the same developer team).
4. **Configure App Groups Entitlement**:
   - To sync data between the main app and the WidgetKit extension, they must share an App Group container.
   - In both targets under **Signing & Capabilities**, click `+ Capability` and search for **App Groups**.
   - Check the box for **`group.com.daily.dailyTask`** (or create it if it's missing).
5. **Install on physical device**:
   - Connect your iPhone.
   - Select your iPhone as the build target in Xcode or terminal.
   - Press the **Play** button (**`Cmd + R`**) in Xcode or run:
     ```bash
     flutter run -d <your-iphone-id>
     ```

---

### 3. Desktop Platforms (macOS, Windows, Linux)
Ensure desktop configurations are enabled in your Flutter installation:

```bash
# Enable macOS desktop
flutter config --enable-macos-desktop

# Enable Windows desktop
flutter config --enable-windows-desktop

# Enable Linux desktop
flutter config --enable-linux-desktop
```

* **Run Desktop App**:
  ```bash
  # Run on macOS
  flutter run -d macos
  
  # Run on Windows
  flutter run -d windows
  
  # Run on Linux
  flutter run -d linux
  ```

---

### 4. Web Build
Build the web project using the canvaskit renderer for premium performance:

```bash
# Run web client locally
flutter run -d chrome

# Build production bundle
flutter build web --web-renderer canvaskit
```

---

## 🎨 Interactive Widgets Architecture (iOS 17+)

DailyTask features state-of-the-art interactive widgets. When you toggle a task from your Home Screen:
1. **Interactive SwiftUI Action**: A `Button(intent: ToggleTaskIntent(taskId: id))` catches the click event on the widget.
2. **App Group Sync**: The intent writes the mutated JSON checklist back to the shared container preference group: `group.com.daily.dailyTask`.
3. **Automatic Reordering**: Completed tasks are pushed to the end of the widget list layout via a custom SwiftUI sort block.
4. **App Resumption Sync**: Once you resume or open the main Flutter application, a `WidgetsBindingObserver` captures the app lifecycle change, retrieves the new values over the MethodChannel, and updates the local SQLite database (`databases/dailytask.db`) automatically.
