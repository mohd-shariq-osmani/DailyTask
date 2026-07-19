import WidgetKit
import SwiftUI

@main
struct DailyTaskWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyTaskWidget()
        DailyTaskReminderWidget()
    }
}
