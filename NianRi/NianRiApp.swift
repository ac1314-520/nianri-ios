import SwiftUI

enum RootTab: Hashable {
    case home, workbench, records, settings
}

@main
struct NianRiApp: App {
    @StateObject private var store = NianRiStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.cinnabar)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: NianRiStore
    @State private var selectedTab: RootTab = .home
    @State private var recordsTab: RecordsTab = .diary

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    HomeView(openWorkbench: { selectedTab = .workbench })
                case .workbench:
                    WorkbenchView(openRecords: { tab in
                        recordsTab = tab
                        selectedTab = .records
                    })
                case .records:
                    RecordsView(initialTab: $recordsTab)
                case .settings:
                    SettingsView()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 84)
            }

            LiquidTabBar(selection: $selectedTab)
        }
        .task {
            NotificationManager.shared.reschedule(events: store.data.anniversaries)
        }
        .onOpenURL { url in
            if url.scheme == "nianri" {
                selectedTab = .home
            }
        }
    }
}
