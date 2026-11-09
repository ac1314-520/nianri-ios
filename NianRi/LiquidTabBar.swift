import SwiftUI
import UIKit

extension RootTab: Identifiable {
    var id: String { String(describing: self) }

    var title: String {
        switch self {
        case .home: return "首页"
        case .workbench: return "工作台"
        case .records: return "记录"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .workbench: return "square.grid.2x2"
        case .records: return "book.closed"
        case .settings: return "gearshape"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .workbench: return "square.grid.2x2.fill"
        case .records: return "book.closed.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct LiquidTabBar: View {
    @Binding var selection: RootTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(RootTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(barBorder, lineWidth: 0.8)
                )
                .shadow(color: Theme.ink.opacity(0.14), radius: 22, x: 0, y: 10)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: selection)
    }

    private var barBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.75),
                Color.white.opacity(0.16),
                Theme.line.opacity(0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var selectedBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.95),
                Color.white.opacity(0.28),
                Theme.cinnabar.opacity(0.22)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func tabButton(_ tab: RootTab) -> some View {
        let selected = selection == tab
        Button {
            guard selection != tab else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                selection = tab
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            tabLabel(tab, selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func tabLabel(_ tab: RootTab, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: selected ? tab.selectedIcon : tab.icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20, height: 20)
            if selected {
                Text(tab.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .fixedSize()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .foregroundStyle(selected ? Theme.ink : Theme.muted)
        .padding(.horizontal, selected ? 14 : 11)
        .frame(height: 48)
        .background {
            if selected {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(selectedBorder, lineWidth: 0.9))
                    .shadow(color: Theme.ink.opacity(0.12), radius: 12, x: 0, y: 5)
                    .matchedGeometryEffect(id: "liquid-tab-selection", in: namespace)
            }
        }
    }
}
