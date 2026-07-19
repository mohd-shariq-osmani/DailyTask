import WidgetKit
import SwiftUI
import AppIntents

// Task model matching Flutter's representation
struct WidgetTask: Codable, Identifiable {
    var id: Int
    var title: String
    var isCompleted: Bool
    var colorHex: String
}

// Widget Data format saved in UserDefaults
struct WidgetData: Codable {
    var tasks: [WidgetTask]
    var completedCount: Int
    var totalCount: Int
}

// iOS 17+ Background Interactive Toggle Intent
@available(iOS 17.0, *)
struct ToggleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Task"
    
    @Parameter(title: "Task ID")
    var taskId: Int

    init() {}
    
    init(taskId: Int) {
        self.taskId = taskId
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.daily.dailyTask")
        if let jsonString = defaults?.string(forKey: "widget_data"),
           let jsonData = jsonString.data(using: .utf8) {
            do {
                var data = try JSONDecoder().decode(WidgetData.self, from: jsonData)
                if let index = data.tasks.firstIndex(where: { $0.id == taskId }) {
                    // Toggle completion
                    data.tasks[index].isCompleted.toggle()
                    data.completedCount = data.tasks.filter { $0.isCompleted }.count
                    
                    // Save update back to Shared App Group Group container
                    let encodedData = try JSONEncoder().encode(data)
                    if let updatedJsonString = String(data: encodedData, encoding: .utf8) {
                        defaults?.set(updatedJsonString, forKey: "widget_data")
                        defaults?.synchronize()
                    }
                }
            } catch {
                print("ToggleTaskIntent error: \(error)")
            }
        }
        
        // Reload widgets
        WidgetCenter.shared.reloadAllTimelines()
        
        // Post Darwin notification to notify main app process immediately
        let notificationName = CFNotificationName("com.dailytask.widget.update" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
        
        return .result()
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: getPreviewData())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), data: getWidgetData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date(), data: getWidgetData())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func getWidgetData() -> WidgetData {
        let defaults = UserDefaults(suiteName: "group.com.daily.dailyTask")
        if let jsonString = defaults?.string(forKey: "widget_data"),
           let jsonData = jsonString.data(using: .utf8) {
            do {
                return try JSONDecoder().decode(WidgetData.self, from: jsonData)
            } catch {
                print("Error decoding widget data: \(error)")
            }
        }
        return getPreviewData()
    }
    
    private func getPreviewData() -> WidgetData {
        let previewTasks = [
            WidgetTask(id: 1, title: "Gym", isCompleted: false, colorHex: "#8B5CF6"),
            WidgetTask(id: 2, title: "Multivitamin", isCompleted: true, colorHex: "#F472B6"),
            WidgetTask(id: 3, title: "Creatine", isCompleted: false, colorHex: "#34D399"),
            WidgetTask(id: 4, title: "Marinate chick...", isCompleted: false, colorHex: "#F472B6"),
            WidgetTask(id: 5, title: "Protein", isCompleted: false, colorHex: "#FBBF24"),
            WidgetTask(id: 6, title: "Isha namaz", isCompleted: false, colorHex: "#F472B6"),
            WidgetTask(id: 7, title: "Omega 3", isCompleted: false, colorHex: "#38BDF8")
        ]
        return WidgetData(
            tasks: previewTasks,
            completedCount: 1,
            totalCount: 7
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct DailyTaskWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            buildSmallWidget()
        case .systemMedium:
            buildMediumWidget()
        case .systemLarge:
            buildLargeWidget()
        default:
            buildMediumWidget()
        }
    }

    // Date formatting helper matching: WED, 3 JUN
    private func getFormattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: Date()).uppercased()
    }

    // Sorting tasks: push completed tasks to the end of the list
    private func getSortedTasks() -> [WidgetTask] {
        return entry.data.tasks.sorted { (t1, t2) -> Bool in
            if t1.isCompleted == t2.isCompleted {
                return t1.id < t2.id
            }
            return !t1.isCompleted && t2.isCompleted
        }
    }

    // ── Small Widget ──
    @ViewBuilder
    private func buildSmallWidget() -> some View {
        VStack(spacing: 8) {
            // Header
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#8B5CF6"))
                Text("Daily")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text("Task")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#8B5CF6"))
            }
            .padding(.top, 4)

            Spacer()

            // Circular Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 6)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(entry.data.totalCount > 0 ? Double(entry.data.completedCount) / Double(entry.data.totalCount) : 0.0))
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#8B5CF6"), Color(hex: "#A78BFA")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(Angle(degrees: -90))
                
                Text("\(entry.data.completedCount)/\(entry.data.totalCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Text(entry.data.totalCount - entry.data.completedCount == 0 ? "All Done! 🔥" : "\(entry.data.totalCount - entry.data.completedCount) remaining")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(entry.data.totalCount - entry.data.completedCount == 0 ? Color(hex: "#34D399") : Color(hex: "#6B7280"))
                .padding(.bottom, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0C0C12"))
    }

    // ── Medium Widget (Exactly matching your screenshot) ──
    @ViewBuilder
    private func buildMediumWidget() -> some View {
        let sortedTasks = getSortedTasks()
        
        VStack(alignment: .leading, spacing: 8) {
            // Header Row
            HStack(alignment: .top) {
                // Left Icon Badge
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#1A1A28"))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(.white)
                    )
                
                Spacer()
                
                // Right titles
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Daily Focus")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                    Text("\(entry.data.completedCount)/\(entry.data.totalCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#8B5CF6"))
                }
            }
            
            // Date label
            Text(getFormattedDate())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(hex: "#50505A"))
                .padding(.top, -4)
            
            // 2-Column Task Grid
            HStack(alignment: .top, spacing: 14) {
                // Column 1
                VStack(alignment: .leading, spacing: 5) {
                    let col1Tasks = sortedTasks.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
                    ForEach(col1Tasks.prefix(4)) { task in
                        buildGridItemRow(task)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Column 2
                VStack(alignment: .leading, spacing: 5) {
                    let col2Tasks = sortedTasks.enumerated().filter { $0.offset % 2 != 0 }.map { $0.element }
                    ForEach(col2Tasks.prefix(4)) { task in
                        buildGridItemRow(task)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // Bottom Dashboard row
            HStack(spacing: 10) {
                // Active tasks left card
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ACTIVE")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color(hex: "#50505A"))
                        Text("\(entry.data.totalCount - entry.data.completedCount)")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(Color(hex: "#8B5CF6"))
                        Text("tasks left")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#50505A"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#0F0F16"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
                
                // Today completion rate card
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TODAY")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(Color(hex: "#50505A"))
                        Text("\(entry.data.totalCount > 0 ? Int((Double(entry.data.completedCount) / Double(entry.data.totalCount)) * 100) : 0)%")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(Color(hex: "#34D399"))
                        Text("complete")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#50505A"))
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#0F0F16"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
            }
            .padding(.bottom, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0C0C12"))
    }

    // Grid Row Item Builder supporting Interactive AppIntents in iOS 17+
    @ViewBuilder
    private func buildGridItemRow(_ task: WidgetTask) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleTaskIntent(taskId: task.id)) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: task.colorHex))
                        .frame(width: 6, height: 6)
                        .opacity(task.isCompleted ? 0.35 : 1.0)
                    
                    Text(task.title)
                        .font(.system(size: 11, weight: task.isCompleted ? .regular : .bold))
                        .foregroundColor(task.isCompleted ? Color(hex: "#404048") : .white)
                        .strikethrough(task.isCompleted, color: Color(hex: task.colorHex).opacity(0.3))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
        } else {
            // Fallback for iOS 16/15
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: task.colorHex))
                    .frame(width: 6, height: 6)
                    .opacity(task.isCompleted ? 0.35 : 1.0)
                
                Text(task.title)
                    .font(.system(size: 11, weight: task.isCompleted ? .regular : .bold))
                    .foregroundColor(task.isCompleted ? Color(hex: "#404048") : .white)
                    .strikethrough(task.isCompleted, color: Color(hex: task.colorHex).opacity(0.3))
                    .lineLimit(1)
            }
        }
    }

    // ── Large Widget (Checklist + Status split panel) ──
    @ViewBuilder
    private func buildLargeWidget() -> some View {
        let sortedTasks = getSortedTasks()
        
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#8B5CF6"))
                    Text("Daily")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                    Text("Task")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(Color(hex: "#8B5CF6"))
                }
                Spacer()
                
                Text("\(entry.data.completedCount)/\(entry.data.totalCount) DONE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#A78BFA"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#0D0D11"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            }
            
            // Progress Bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#0D0D11"))
                    .frame(height: 6)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#8B5CF6"), Color(hex: "#A78BFA")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: max(0, min(300, 300 * CGFloat(entry.data.totalCount > 0 ? Double(entry.data.completedCount) / Double(entry.data.totalCount) : 0.0))),
                        height: 6
                    )
            }
            .frame(height: 6)
            
            // Split grid details
            HStack(alignment: .top, spacing: 14) {
                // Left Column: Checklist (up to 5 items)
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY'S CHECKLIST")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "#6B7280"))
                        .padding(.bottom, 2)
                    
                    if sortedTasks.isEmpty {
                        Text("No tasks.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    } else {
                        ForEach(sortedTasks.prefix(5)) { task in
                            buildLargeListItemRow(task)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Right Column: Summary Card
                VStack(alignment: .leading, spacing: 10) {
                    Text("HABIT INSIGHTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "#6B7280"))
                        .padding(.bottom, 2)
                    
                    // Completion rate card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RATE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#6B7280"))
                        Text("\(entry.data.totalCount > 0 ? Int((Double(entry.data.completedCount) / Double(entry.data.totalCount)) * 100) : 0)%")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(Color(hex: "#34D399"))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#0D0D11"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )

                    // Today status card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TODAY STATUS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#6B7280"))
                        Text(entry.data.totalCount - entry.data.completedCount == 0 ? "🔥 Clean" : "⚡ \(entry.data.totalCount - entry.data.completedCount) Left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(entry.data.totalCount - entry.data.completedCount == 0 ? Color(hex: "#A78BFA") : .white)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#0D0D11"))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
                .frame(width: 110)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0C0C12"))
    }

    // Large Widget Row Item Builder supporting Interactive AppIntents in iOS 17+
    @ViewBuilder
    private func buildLargeListItemRow(_ task: WidgetTask) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleTaskIntent(taskId: task.id)) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: task.colorHex))
                        .frame(width: 6, height: 6)
                        .opacity(task.isCompleted ? 0.3 : 1.0)
                    
                    Text(task.title)
                        .font(.system(size: 11, weight: task.isCompleted ? .regular : .semibold))
                        .foregroundColor(task.isCompleted ? Color(hex: "#404040") : .white)
                        .strikethrough(task.isCompleted, color: Color(hex: task.colorHex).opacity(0.4))
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(hex: "#0D0D11"))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        } else {
            // Fallback for iOS 16/15
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: task.colorHex))
                    .frame(width: 6, height: 6)
                    .opacity(task.isCompleted ? 0.3 : 1.0)
                
                Text(task.title)
                    .font(.system(size: 11, weight: task.isCompleted ? .regular : .semibold))
                    .foregroundColor(task.isCompleted ? Color(hex: "#404040") : .white)
                    .strikethrough(task.isCompleted, color: Color(hex: task.colorHex).opacity(0.4))
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(hex: "#0D0D11"))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

struct DailyTaskWidget: Widget {
    let kind: String = "DailyTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                DailyTaskWidgetEntryView(entry: entry)
                    .containerBackground(Color(hex: "#0C0C12"), for: .widget)
            } else {
                DailyTaskWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Daily Tasks")
        .description("Track your checklists and daily consistency instantly from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// SwiftUI Color extension for HEX conversion
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// iOS 17+ Background Interactive Toggle Reminder Intent
@available(iOS 17.0, *)
struct ToggleReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Reminder"
    
    @Parameter(title: "Reminder ID")
    var reminderId: Int

    init() {}
    
    init(reminderId: Int) {
        self.reminderId = reminderId
    }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults(suiteName: "group.com.daily.dailyTask")
        if let jsonString = defaults?.string(forKey: "reminders_data"),
           let jsonData = jsonString.data(using: .utf8) {
            do {
                var data = try JSONDecoder().decode(ReminderWidgetData.self, from: jsonData)
                if let index = data.reminders.firstIndex(where: { $0.id == reminderId }) {
                    // Toggle completion
                    data.reminders[index].isCompleted.toggle()
                    
                    // Once completed, it disappears immediately from the list!
                    if data.reminders[index].isCompleted {
                        data.reminders.remove(at: index)
                    }
                    data.totalCount = data.reminders.count
                    
                    let encodedData = try JSONEncoder().encode(data)
                    if let updatedJsonString = String(data: encodedData, encoding: .utf8) {
                        defaults?.set(updatedJsonString, forKey: "reminders_data")
                        defaults?.synchronize()
                    }
                }
            } catch {
                print("ToggleReminderIntent error: \(error)")
            }
        }
        
        WidgetCenter.shared.reloadAllTimelines()
        
        // Post Darwin notification to notify main app process immediately
        let notificationName = CFNotificationName("com.dailytask.widget.update" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
        
        return .result()
    }
}

// Reminder Models
struct ReminderWidgetTask: Codable, Identifiable {
    var id: Int
    var title: String
    var isCompleted: Bool
    var colorHex: String
}

struct ReminderWidgetData: Codable {
    var reminders: [ReminderWidgetTask]
    var totalCount: Int
}

struct ReminderEntry: TimelineEntry {
    let date: Date
    let data: ReminderWidgetData
}

struct ReminderProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        ReminderEntry(date: Date(), data: getPreviewData())
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> ()) {
        let entry = ReminderEntry(date: Date(), data: getWidgetData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> ()) {
        let entry = ReminderEntry(date: Date(), data: getWidgetData())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
    
    private func getWidgetData() -> ReminderWidgetData {
        let defaults = UserDefaults(suiteName: "group.com.daily.dailyTask")
        if let jsonString = defaults?.string(forKey: "reminders_data"),
           let jsonData = jsonString.data(using: .utf8) {
            do {
                return try JSONDecoder().decode(ReminderWidgetData.self, from: jsonData)
            } catch {
                print("Error decoding reminders widget data: \(error)")
            }
        }
        return getPreviewData()
    }
    
    private func getPreviewData() -> ReminderWidgetData {
        let previewReminders = [
            ReminderWidgetTask(id: 101, title: "Buy groceries", isCompleted: false, colorHex: "#38BDF8"),
            ReminderWidgetTask(id: 102, title: "Call mechanic", isCompleted: false, colorHex: "#8B5CF6"),
            ReminderWidgetTask(id: 103, title: "Pay utility bill", isCompleted: false, colorHex: "#FBBF24")
        ]
        return ReminderWidgetData(
            reminders: previewReminders,
            totalCount: 3
        )
    }
}

struct ReminderWidgetEntryView : View {
    var entry: ReminderProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            buildSmallWidget()
        case .systemMedium:
            buildMediumWidget()
        case .systemLarge:
            buildLargeWidget()
        default:
            buildMediumWidget()
        }
    }

    // Small Widget
    @ViewBuilder
    private func buildSmallWidget() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 3) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#8B5CF6"))
                Text("Reminders")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 4)

            Spacer()

            Text("\(entry.data.totalCount)")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(Color(hex: "#8B5CF6"))

            Text("active")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "#6B7280"))

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0C0C12"))
    }

    // Medium Widget
    @ViewBuilder
    private func buildMediumWidget() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#1A1A28"))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "bell.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Reminders")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                    Text("\(entry.data.totalCount) remaining")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#8B5CF6"))
                }
            }
            
            // Checklist list (up to 4 items in a vertical list)
            VStack(alignment: .leading, spacing: 5) {
                if entry.data.reminders.isEmpty {
                    Text("No active reminders 🎉")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#6B7280"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 10)
                } else {
                    ForEach(entry.data.reminders.prefix(4)) { reminder in
                        buildReminderRow(reminder)
                    }
                }
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0C0C12"))
    }

    // Large Widget
    @ViewBuilder
    private func buildLargeWidget() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#8B5CF6"))
                    Text("My Reminders")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                }
                Spacer()
                
                Text("\(entry.data.totalCount) ACTIVE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#A78BFA"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#0D0D11"))
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if entry.data.reminders.isEmpty {
                    Spacer()
                    Text("All caught up! 🎉")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#6B7280"))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                } else {
                    ForEach(entry.data.reminders.prefix(7)) { reminder in
                        buildReminderRow(reminder)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#0C0C12"))
    }

    @ViewBuilder
    private func buildReminderRow(_ reminder: ReminderWidgetTask) -> some View {
        if #available(iOS 17.0, *) {
            Button(intent: ToggleReminderIntent(reminderId: reminder.id)) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: reminder.colorHex))
                        .frame(width: 6, height: 6)
                        .opacity(reminder.isCompleted ? 0.35 : 1.0)
                    
                    Text(reminder.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(hex: "#0D0D11"))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: reminder.colorHex))
                    .frame(width: 6, height: 6)
                
                Text(reminder.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(hex: "#0D0D11"))
            .cornerRadius(8)
        }
    }
}

struct DailyTaskReminderWidget: Widget {
    let kind: String = "DailyTaskReminderWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReminderProvider()) { entry in
            if #available(iOS 17.0, *) {
                ReminderWidgetEntryView(entry: entry)
                    .containerBackground(Color(hex: "#0C0C12"), for: .widget)
            } else {
                ReminderWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Reminders")
        .description("Never forget active to-dos and one-off reminders.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
