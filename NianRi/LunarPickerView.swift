import SwiftUI

struct LunarPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let initial: LunarDate
    let onSelect: (LunarDate, Date) -> Void

    @State private var year: Int
    @State private var month: Int
    @State private var day: Int
    @State private var leap: Bool

    init(initial: LunarDate, onSelect: @escaping (LunarDate, Date) -> Void) {
        self.initial = initial
        self.onSelect = onSelect
        _year = State(initialValue: initial.year)
        _month = State(initialValue: initial.month)
        _day = State(initialValue: initial.day)
        _leap = State(initialValue: initial.leap)
    }

    private var leapMonth: Int? { LunarCalendar.leapMonth(of: year) }
    private var maxDay: Int { LunarCalendar.daysInMonth(year: year, month: month, leap: leap) }
    private var value: LunarDate { LunarDate(year: year, month: month, day: day, leap: leap) }
    private var solar: Date? { LunarCalendar.toSolar(value) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 0) {
                        Picker("年", selection: $year) {
                            ForEach(1900...2100, id: \.self) { value in
                                Text("\(value)年").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker("月", selection: $month) {
                            ForEach(1...12, id: \.self) { value in
                                Text(LunarCalendar.monthName(value)).tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()

                        Picker("日", selection: $day) {
                            ForEach(1...maxDay, id: \.self) { value in
                                Text(LunarCalendar.dayName(value)).tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    }
                }

                Section {
                    if leapMonth == month {
                        Toggle("闰月", isOn: $leap)
                    }
                    HStack {
                        Text(value.fullLabel)
                            .font(.system(size: 16, design: .serif))
                        Spacer()
                        if let solar {
                            Text(AppDate.dateText(solar, format: "yyyy.MM.dd"))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                } footer: {
                    Text("按农历年、月、日选择；有闰月的年份可以打开闰月。")
                }
            }
            .navigationTitle("选择农历")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("选好了") {
                        guard let solar else { return }
                        onSelect(value, solar)
                        dismiss()
                    }
                    .foregroundStyle(Theme.cinnabar)
                    .disabled(solar == nil)
                }
            }
            .onChange(of: year) { _, _ in normalize() }
            .onChange(of: month) { _, _ in normalize() }
            .onChange(of: leap) { _, _ in normalize() }
        }
    }

    private func normalize() {
        if leapMonth != month { leap = false }
        day = min(day, maxDay)
    }
}
