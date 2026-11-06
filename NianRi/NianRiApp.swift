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
        TabView(selection: $selectedTab) {
            HomeView(openWorkbench: { selectedTab = .workbench })
                .tabItem {
                    Label("首页", systemImage: "house")
                }
                .tag(RootTab.home)

            WorkbenchView(openRecords: { tab in
                recordsTab = tab
                selectedTab = .records
            })
            .tabItem {
                Label("工作台", systemImage: "rectangle.grid.2x2")
            }
            .tag(RootTab.workbench)

            RecordsView(initialTab: $recordsTab)
                .tabItem {
                    Label("记录", systemImage: "book.closed")
                }
                .tag(RootTab.records)

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
                .tag(RootTab.settings)
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
