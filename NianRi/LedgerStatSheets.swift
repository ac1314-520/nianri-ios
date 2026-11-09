import SwiftUI

struct LedgerDaysSheet: View {
    @Environment(\.dismiss) private var dismiss
    let month: Date
    let entries: [LedgerEntry]

    private var grouped: [(day: Int, entries: [LedgerEntry])] {
        Dictionary(grouping: entries, by: \.epochDay)
            .map { (day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(grouped, id: \.day) { group in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(AppDate.relativeDayText(group.day).isEmpty
                                     ? AppDate.dayText(group.day, format: "M月d日")
                                     : AppDate.relativeDayText(group.day))
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                Text(AppDate.dayText(group.day, format: "M月d日 · EEEE"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Theme.faint)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(group.entries.count) 笔")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.muted)
                                Text(money(group.entries.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }))
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.cinnabar)
                            }
                        }
                        .padding(16)
                        if group.day != grouped.last?.day {
                            Divider().overlay(Theme.line).padding(.leading, 16)
                        }
                    }
                }
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(20)
            }
            .background(Theme.paper)
            .navigationTitle("本月有账")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.cinnabar)
                }
            }
        }
    }
}

struct LedgerLoanSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [LedgerEntry]

    private var loans: [LedgerEntry] {
        entries.filter { $0.category == "贷款" || $0.category == "还贷" }
            .sorted { $0.epochDay > $1.epochDay }
    }

    private var borrowed: Int {
        loans.filter { $0.income }.reduce(0) { $0 + $1.amountCents }
    }

    private var repaid: Int {
        loans.filter { !$0.income }.reduce(0) { $0 + $1.amountCents }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("贷款余额")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                        Text(money(max(0, borrowed - repaid)))
                            .font(.system(size: 34, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.ink)
                        HStack {
                            Text("借入 \(money(borrowed))")
                            Text("已还 \(money(repaid))")
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.faint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Theme.cream)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    if loans.isEmpty {
                        Text("还没有贷款或还贷记录。在「记一笔」里选择收入 → 贷款，或支出 → 还贷。")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .padding(18)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(loans) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.category)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Theme.ink)
                                        Text(AppDate.dayText(entry.epochDay, format: "yyyy年M月d日"))
                                            .font(.system(size: 9.5))
                                            .foregroundStyle(Theme.faint)
                                    }
                                    Spacer()
                                    Text((entry.income ? "+" : "-") + money(entry.amountCents))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(entry.income ? Theme.sage : Theme.cinnabar)
                                }
                                .padding(16)
                                if entry.id != loans.last?.id {
                                    Divider().overlay(Theme.line).padding(.leading, 16)
                                }
                            }
                        }
                        .background(Theme.cream)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                }
                .padding(20)
            }
            .background(Theme.paper)
            .navigationTitle("贷款与还贷")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(Theme.cinnabar)
                }
            }
        }
    }
}
