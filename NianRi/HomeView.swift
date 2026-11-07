import SwiftUI
import PhotosUI
import Photos
import UIKit
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject private var store: NianRiStore
    var openWorkbench: () -> Void

    @State private var showingEditor = false
    @State private var editingEvent: Anniversary?
    @State private var detailEvent: Anniversary?
    @State private var deletedEvent: Anniversary?
    @State private var undoVisible = false
    @State private var undoTask: Task<Void, Never>?
    @State private var displayEvents: [Anniversary] = []
    @State private var draggingID: UUID?

    private var visibleEvents: [Anniversary] {
        displayEvents.isEmpty ? store.homeEvents : displayEvents
    }
    private var hero: Anniversary? { visibleEvents.first }
    private var rest: [Anniversary] { Array(visibleEvents.dropFirst()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if store.data.anniversaries.count > 1 {
                    Text("长按卡片可拖动排序")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                        .padding(.top, 8)
                }
                heroSection
                restSection
                if !store.data.anniversaries.isEmpty {
                    addButton
                        .padding(.top, 18)
                }
                Text("把喜欢藏进岁月，把陪伴过成日常。")
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                Text("念日 · 今日手记")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
        }
        .nianriScreen()
        .onAppear { syncOrder() }
        .onChange(of: store.data.anniversaries) { _, _ in
            if draggingID == nil { syncOrder() }
        }
        .sheet(isPresented: $showingEditor) {
            AnniversaryEditorView(event: editingEvent)
                .environmentObject(store)
        }
        .fullScreenCover(item: $detailEvent, onDismiss: {
            syncOrder()
        }) { event in
            AnniversaryDetailView(eventID: event.id)
                .environmentObject(store)
        }
        .overlay(alignment: .bottom) {
            if undoVisible, let event = deletedEvent {
                HStack(spacing: 12) {
                    Text("已删除「\(event.title)」")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.cream)
                        .lineLimit(1)
                    Spacer()
                    Button("撤销") {
                        undoDelete()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Theme.ink)
                .clipShape(Capsule())
                .shadow(color: Theme.ink.opacity(0.2), radius: 10, y: 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 76)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        if let hero {
            SwipeDeleteRow(onDelete: {
                deleteWithUndo(hero)
            }) {
                AnniversaryHero(event: hero) {
                    detailEvent = hero
                }
                .background(Theme.cream)
            }
            .padding(.top, 18)
            .onDrag {
                draggingID = hero.id
                return NSItemProvider(object: hero.id.uuidString as NSString)
            }
            .onDrop(of: [UTType.text], delegate: AnniversaryDropDelegate(
                targetID: hero.id,
                events: $displayEvents,
                draggingID: $draggingID,
                onDropFinished: persistOrder
            ))
        } else {
            emptyState
                .padding(.top, 18)
        }
    }

    @ViewBuilder
    private var restSection: some View {
        if !rest.isEmpty {
            SectionHeading(title: "所有日子", detail: String(format: "%02d", store.data.anniversaries.count))
                .padding(.top, 28)
                .padding(.bottom, 10)
            LazyVStack(spacing: 10) {
                ForEach(rest) { event in
                    SwipeDeleteRow(onDelete: {
                        deleteWithUndo(event)
                    }) {
                        EventRow(event: event)
                            .background(Theme.cream)
                            .onTapGesture {
                                detailEvent = event
                            }
                    }
                    .onDrag {
                        draggingID = event.id
                        return NSItemProvider(object: event.id.uuidString as NSString)
                    }
                    .onDrop(of: [UTType.text], delegate: AnniversaryDropDelegate(
                        targetID: event.id,
                        events: $displayEvents,
                        draggingID: $draggingID,
                        onDropFinished: persistOrder
                    ))
                }
            }
        }
    }

    private var addButton: some View {
        Button {
            editingEvent = nil
            showingEditor = true
        } label: {
            Label("写下一个日子", systemImage: "plus")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 11) {
                    Text("念")
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.cream)
                        .frame(width: 46, height: 46)
                        .background(Theme.cinnabar)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    Text("念日")
                        .font(.system(size: 27, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Button {
                    editingEvent = nil
                    showingEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.cream)
                        .frame(width: 44, height: 44)
                        .background(Theme.cinnabar)
                        .clipShape(Circle())
                }
                .accessibilityLabel("写下一个日子")
                Button(action: openWorkbench) {
                    Image(systemName: "rectangle.grid.2x2")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 44, height: 44)
                        .background(Theme.cream)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.line, lineWidth: 0.8))
                }
                .accessibilityLabel("打开工作台")
            }
            HStack {
                Text(AppDate.todayText("yyyy年M月d日 EEEE"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                Spacer()
                Text("今日")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.cinnabar)
            }
            .padding(.top, 5)
        }
        .padding(.top, 8)
    }

    private func syncOrder() {
        displayEvents = store.homeEvents
    }

    private func persistOrder(_ events: [Anniversary]) {
        store.setHomeOrder(events.map(\.id))
    }

    private func deleteWithUndo(_ event: Anniversary) {
        undoTask?.cancel()
        deletedEvent = event
        store.removeAnniversary(event, deletePhoto: false)
        NotificationManager.shared.reschedule(events: store.data.anniversaries)
        withAnimation(.easeOut(duration: 0.2)) { undoVisible = true }

        undoTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            if deletedEvent?.id == event.id {
                if let photo = event.photo {
                    store.deletePhoto(photo)
                }
                deletedEvent = nil
                withAnimation(.easeIn(duration: 0.2)) { undoVisible = false }
            }
        }
    }

    private func undoDelete() {
        undoTask?.cancel()
        guard let event = deletedEvent else { return }
        store.addAnniversary(event)
        NotificationManager.shared.reschedule(events: store.data.anniversaries)
        deletedEvent = nil
        withAnimation(.easeIn(duration: 0.2)) { undoVisible = false }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 90, style: .continuous)
                    .stroke(Theme.cinnabar.opacity(0.22), lineWidth: 1)
                    .frame(width: 190, height: 224)
                Circle()
                    .fill(Theme.cinnabarSoft)
                    .frame(width: 94, height: 94)
                Circle()
                    .fill(Theme.cinnabar)
                    .frame(width: 48, height: 48)
                Circle()
                    .fill(Theme.cream)
                    .frame(width: 10, height: 10)
                    .offset(x: -13, y: -13)
            }
            Text("有些日子，值得被郑重记住。")
                .font(.system(size: 23, design: .serif))
                .foregroundStyle(Theme.ink)
            Text("从相遇、生日，到一场远行。\n选一张照片，给它一个名字。")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .foregroundStyle(Theme.muted)
            Button("写下第一个日子") {
                editingEvent = nil
                showingEditor = true
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 230)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
}

struct AnniversaryHero: View {
    let event: Anniversary
    let onTap: () -> Void

    private var number: Int {
        event.recurring ? max(0, event.daysSince) : abs(event.daysUntil)
    }

    private var kicker: String {
        if event.recurring {
            return event.isToday ? "今天 · 相伴第" : "相伴第"
        }
        if event.daysUntil > 0 { return "还有" }
        if event.daysUntil == 0 { return "今天" }
        return "已经"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PhotoView(filename: event.photo, cornerRadius: 30)
                .frame(height: 370)
            LinearGradient(
                colors: [Color.clear, Theme.ink.opacity(0.18), Theme.ink.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Text(event.recurring ? "每年" : "倒数")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.cream.opacity(0.9))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Theme.cream.opacity(0.16))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(event.title)
                    .font(.system(size: 27, design: .serif))
                    .foregroundStyle(Theme.cream)
                    .lineLimit(2)
                Text("\(event.dateLabel)  ·  \(event.recurrenceLabel)")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.cream.opacity(0.72))
                    .padding(.top, 8)
                Text(kicker)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.cream.opacity(0.72))
                    .padding(.top, 22)
                HStack(alignment: .lastTextBaseline, spacing: 7) {
                    Text("\(number)")
                        .font(.system(size: 71, weight: .light, design: .serif))
                        .foregroundStyle(Theme.cream)
                    Text("天")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.cream.opacity(0.8))
                }
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.cream.opacity(0.72))
                    .padding(.top, 3)
            }
            .padding(22)
        }
        .frame(height: 370)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title)，\(footer)")
    }

    private var footer: String {
        if event.recurring {
            if event.isToday { return "今天 · 周年快乐" }
            return "距离下一个周年 · 还有 \(max(0, event.daysUntil)) 天"
        }
        if event.daysUntil > 0 { return "期待 · \(AppDate.dateText(event.date, format: "yyyy年M月d日 EEEE"))" }
        if event.daysUntil == 0 { return "就是今天 · \(AppDate.dateText(event.date, format: "yyyy年M月d日 EEEE"))" }
        return "已经走过 · \(abs(event.daysUntil)) 天"
    }
}

struct EventRow: View {
    let event: Anniversary

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if event.photo != nil {
                    PhotoView(filename: event.photo, cornerRadius: 12, fitWide: false)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent(event.accentIndex).opacity(0.18))
                    Text(AppDate.dateText(event.date, format: "M月\nd日"))
                        .font(.system(size: 11, weight: .medium, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.accent(event.accentIndex))
                }
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(event.recurring
                     ? (event.lunarDate == nil
                        ? "每年 \(AppDate.dateText(event.date, format: "M月d日"))"
                        : "每年农历 \(event.lunarDate?.shortLabel ?? "")")
                     : event.dateLabel)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.recurring ? "相伴第" : (event.daysUntil >= 0 ? "还有" : "已经"))
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.faint)
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text("\(event.recurring ? max(0, event.daysSince) : abs(event.daysUntil))")
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text("天")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                }
            }
        }
        .padding(12)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 0.7))
    }
}

struct AnniversaryEditorView: View {
    @EnvironmentObject private var store: NianRiStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Anniversary
    @State private var reminderTime: Date
    @State private var photoItem: PhotosPickerItem?
    @State private var newPhotoData: Data?
    @State private var musicName: String?
    @State private var musicTitle: String?
    @State private var showAudioPicker = false
    @State private var lunarMode: Bool
    @State private var lunarDate: LunarDate?
    @State private var showLunarPicker = false
    @State private var photoAsset: PHAsset?
    @State private var showValidation = false
    @State private var showDelete = false
    private let isNew: Bool
    private let originalPhoto: String?

    init(event: Anniversary?) {
        let seeded = event ?? Anniversary(title: "", date: Date())
        _draft = State(initialValue: seeded)
        let total = seeded.reminderMinuteOfDay ?? 540
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = total / 60
        components.minute = total % 60
        _reminderTime = State(initialValue: Calendar.current.date(from: components) ?? Date())
        _musicName = State(initialValue: seeded.music)
        _musicTitle = State(initialValue: seeded.musicTitle)
        _lunarMode = State(initialValue: seeded.lunar == true)
        _lunarDate = State(initialValue: seeded.lunarDate)
        isNew = event == nil
        originalPhoto = event?.photo
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名字") {
                    TextField("例如：我们相遇的那一天", text: $draft.title)
                        .font(.system(size: 22, design: .serif))
                }

                Section("日子") {
                    if lunarMode {
                        Button {
                            showLunarPicker = true
                        } label: {
                            HStack {
                                Text("农历日期")
                                Spacer()
                                Text(lunarDate?.fullLabel ?? "选择农历")
                                    .foregroundStyle(Theme.cinnabar)
                            }
                        }
                    } else {
                        DatePicker("日期", selection: $draft.date, displayedComponents: .date)
                    }
                    Toggle("按农历纪念", isOn: $lunarMode)
                        .onChange(of: lunarMode) { _, enabled in
                            if enabled {
                                if lunarDate == nil {
                                    lunarDate = LunarCalendar.fromSolar(draft.date)
                                }
                            } else if let lunarDate, let solar = LunarCalendar.toSolar(lunarDate) {
                                draft.date = solar
                            }
                        }
                    Picker("类型", selection: $draft.recurring) {
                        Text("每年纪念").tag(true)
                        Text("单次倒数").tag(false)
                    }
                    .pickerStyle(.segmented)
                    Text(draft.recurring
                         ? (lunarMode ? "每年农历同一天都会再次被点亮。" : "每年同一天都会再次被点亮。")
                         : "只倒数这一次，也可以记录已经走过的日子。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }

                Section("颜色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(0..<Theme.accents.count, id: \.self) { index in
                            Button {
                                draft.accentIndex = index
                            } label: {
                                ZStack {
                                    Circle().fill(Theme.accent(index))
                                    if draft.accentIndex == index {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Theme.cream)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                photoSection

                Section("故事") {
                    TextEditor(text: $draft.note)
                        .frame(minHeight: 90)
                        .font(.system(size: 14))
                }

                Section("声音") {
                    MusicAttachmentView(
                        name: musicName,
                        title: musicTitle,
                        editable: true,
                        onPick: { showAudioPicker = true },
                        onRemove: {
                            if let old = musicName, old != draft.music {
                                store.deleteAudio(old)
                            }
                            musicName = nil
                            musicTitle = nil
                        }
                    )
                }

                Section("提醒") {
                    Toggle("这一天提醒我", isOn: $draft.reminderEnabled)
                    if draft.reminderEnabled {
                        Stepper("提前 \(draft.reminderDaysBefore) 天", value: $draft.reminderDaysBefore, in: 0...30)
                        DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            showDelete = true
                        } label: {
                            Text("删除这一天")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle(isNew ? "写下一个日子" : "编辑这一天")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAudioPicker) {
                AudioDocumentPicker { url in
                    showAudioPicker = false
                    if let saved = store.saveAudio(from: url, suggestedTitle: url.deletingPathExtension().lastPathComponent) {
                        if let old = musicName, old != draft.music {
                            store.deleteAudio(old)
                        }
                        musicName = saved.name
                        musicTitle = saved.title
                    }
                }
            }
            .sheet(isPresented: $showLunarPicker) {
                if let value = lunarDate {
                    LunarPickerView(initial: value) { selected, solar in
                        lunarDate = selected
                        draft.date = solar
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.muted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .foregroundStyle(Theme.cinnabar)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                photoAsset = nil
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        newPhotoData = data
                    }
                    guard item.nianriNeedsOriginalAsset else { return }
                    _ = await store.requestPhotoLibraryAccess()
                    if let identifier = item.itemIdentifier {
                        photoAsset = PHAsset.fetchAssets(
                            withLocalIdentifiers: [identifier],
                            options: nil
                        ).firstObject
                    }
                    if let asset = photoAsset, let data = await store.originalImageData(for: asset) {
                        newPhotoData = data
                    }
                }
            }
            .alert("给这一天起个名字吧", isPresented: $showValidation) {
                Button("知道了", role: .cancel) {}
            }
            .alert("删除这一天？", isPresented: $showDelete) {
                Button("删除", role: .destructive) {
                    store.deleteAnniversary(draft)
                    NotificationManager.shared.reschedule(events: store.data.anniversaries)
                    dismiss()
                }
                Button("先留着", role: .cancel) {}
            } message: {
                Text("「\(draft.title)」的照片和记录会一起删除。")
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
                Section("照片") {
                    PhotosPicker(
                        selection: $photoItem,
                        matching: .images
                    ) {
                        HStack(spacing: 14) {
                            if let data = newPhotoData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 74, height: 74)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            } else {
                                PhotoView(filename: draft.photo, cornerRadius: 14)
                                    .frame(width: 74, height: 74)
                            }
                            Text(draft.photo == nil && newPhotoData == nil ? "从相册选择" : "换一张")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Theme.cinnabar)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
    }

    private func save() {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            showValidation = true
            return
        }
        draft.title = title
        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        draft.reminderMinuteOfDay = (time.hour ?? 9) * 60 + (time.minute ?? 0)

        if let newPhotoData, let name = store.savePhoto(newPhotoData) {
            if let old = originalPhoto, old != name {
                store.deletePhoto(old)
            }
            draft.photo = name
        }
        if let old = draft.music, old != musicName {
            store.deleteAudio(old)
        }
        draft.music = musicName
        draft.musicTitle = musicTitle
        if lunarMode, let lunarDate {
            draft.lunar = true
            draft.lunarYear = lunarDate.year
            draft.lunarMonth = lunarDate.month
            draft.lunarDay = lunarDate.day
            draft.lunarLeap = lunarDate.leap
        } else {
            draft.lunar = false
            draft.lunarYear = nil
            draft.lunarMonth = nil
            draft.lunarDay = nil
            draft.lunarLeap = nil
        }

        if isNew {
            store.addAnniversary(draft)
        } else {
            store.updateAnniversary(draft)
        }
        NotificationManager.shared.reschedule(events: store.data.anniversaries)
        if draft.reminderEnabled {
            Task {
                _ = await NotificationManager.shared.requestAuthorization()
            }
        }
        dismiss()
    }
}

private struct AnniversaryDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var events: [Anniversary]
    @Binding var draggingID: UUID?
    var onDropFinished: ([Anniversary]) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggingID,
              dragged != targetID,
              let from = events.firstIndex(where: { $0.id == dragged }),
              let to = events.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.easeInOut(duration: 0.16)) {
            events.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        onDropFinished(events)
        return true
    }
}
