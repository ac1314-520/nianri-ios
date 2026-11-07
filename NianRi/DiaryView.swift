import SwiftUI
import PhotosUI
import Photos
import UniformTypeIdentifiers
import UIKit

/// 日记：搜索、筛选、完整阅读、编辑、删除撤销和往年今日。
/// 文件名保持纯 ASCII，避免 macOS 解压/同步时出现找不到或重名副本。
struct DiaryView: View {
    @EnvironmentObject private var store: NianRiStore

    @State private var text = ""
    @State private var moodKey: String?
    @State private var editingId: UUID?
    @State private var editingDay = AppDate.today
    @State private var photoItem: PhotosPickerItem?
    @State private var newPhotoData: Data?
    @State private var photoName: String?
    @State private var musicName: String?
    @State private var musicTitle: String?
    @State private var showAudioPicker = false
    @State private var originalPhoto: String?
    @State private var originalMusic: String?
    @State private var liveAsset: PHAsset?
    @State private var showLivePlayer = false

    @State private var allMonths = true
    @State private var monthCursor = AppDate.startOfMonth(Date())
    @State private var filterMood: String?
    @State private var searchText = ""

    @State private var selectedEntry: DiaryEntry?
    @State private var deletedEntry: DiaryEntry?
    @State private var showUndo = false
    @State private var showEmptyAlert = false

    private var diary: [DiaryEntry] { store.data.workbench.diary }

    private var filtered: [DiaryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return diary.filter { entry in
            let monthOK = allMonths || AppDate.sameMonth(AppDate.date(epochDay: entry.epochDay), monthCursor)
            let moodOK = filterMood == nil || entry.moodKey == filterMood
            let moodLabel = MoodCatalog.option(entry.moodKey)?.label ?? ""
            let textOK = query.isEmpty
                || entry.text.localizedCaseInsensitiveContains(query)
                || moodLabel.localizedCaseInsensitiveContains(query)
            return monthOK && moodOK && textOK
        }
        .sorted {
            if $0.epochDay != $1.epochDay { return $0.epochDay > $1.epochDay }
            return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
        }
    }

    private var todayCount: Int {
        diary.filter { $0.epochDay == AppDate.today }.count
    }

    private var composerHint: String {
        if editingId != nil {
            return "正在编辑这一篇；也可以点「写新的一条」继续记录。"
        }
        if todayCount > 0 {
            return "今天已经写了 \(todayCount) 篇，还可以继续写。"
        }
        return "今天还没有记录，一句话也算把今天留住。"
    }

    private var statsMonth: Date {
        allMonths ? AppDate.startOfMonth(Date()) : monthCursor
    }

    private var monthEntries: [DiaryEntry] {
        diary.filter { AppDate.sameMonth(AppDate.date(epochDay: $0.epochDay), statsMonth) }
    }

    private var streak: Int {
        let days = Set(diary.map(\.epochDay))
        var cursor = AppDate.today
        if !days.contains(cursor) { cursor -= 1 }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor -= 1
        }
        return count
    }

    private var pastToday: [DiaryEntry] {
        let calendar = Calendar.current
        let today = Date()
        let currentYear = calendar.component(.year, from: today)
        return diary.filter { entry in
            let date = AppDate.date(epochDay: entry.epochDay)
            return calendar.component(.year, from: date) < currentYear
                && calendar.component(.month, from: date) == calendar.component(.month, from: today)
                && calendar.component(.day, from: date) == calendar.component(.day, from: today)
        }
        .sorted { $0.epochDay > $1.epochDay }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            composer
                .alert("写一点点，再收下这一页。", isPresented: $showEmptyAlert) {
                    Button("知道了", role: .cancel) {}
                }
            filterCard
                .padding(.top, 12)
            statsCard
                .padding(.top, 12)

            if showPastToday {
                pastTodayCard
                    .padding(.top, 12)
            }

            HStack(alignment: .lastTextBaseline) {
                Text(filterTitle)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.ink)
                Text("\(filtered.count) 篇")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
                Spacer()
            }
            .padding(.top, 24)
            .padding(.bottom, 9)

            if filtered.isEmpty {
                Card {
                    Text(diary.isEmpty ? "还没有日记。" : "这个筛选下还没有日记。")
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(Theme.ink)
                    Text(diary.isEmpty ? "在今天的这一页里，写下一句话。" : "换个关键词、心情或月份看看。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 5)
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { entry in
                        SwipeDeleteRow(onDelete: {
                            delete(entry)
                        }) {
                            diaryRow(entry)
                                .background(Theme.cream)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            DiaryDetailView(
                entry: entry,
                onEdit: {
                    loadForEditing(entry)
                    selectedEntry = nil
                },
                onDelete: {
                    selectedEntry = nil
                    delete(entry)
                }
            )
            .environmentObject(store)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            liveAsset = nil
            if let identifier = item.itemIdentifier {
                let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                if let asset = result.firstObject, asset.mediaSubtypes.contains(.photoLive) {
                    liveAsset = asset
                }
            }
            Task {
                if let asset = liveAsset, let data = await store.imageData(for: asset) {
                    newPhotoData = data
                } else if let data = try? await item.loadTransferable(type: Data.self) {
                    newPhotoData = data
                }
            }
        }
        .fileImporter(
            isPresented: $showAudioPicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            if let saved = store.saveAudio(from: url, suggestedTitle: url.deletingPathExtension().lastPathComponent) {
                if let old = musicName, old != originalMusic {
                    store.deleteAudio(old)
                }
                musicName = saved.name
                musicTitle = saved.title
            }
        }
        .alert("已删除这篇日记", isPresented: $showUndo) {
            Button("撤销") {
                undoDelete()
            }
            Button("知道了", role: .cancel) {
                deletedEntry = nil
            }
        } message: {
            Text("可以点「撤销」恢复。")
        }
    }

    private var composer: some View {
        Card {
            HStack(alignment: .lastTextBaseline) {
                Text(editingId == nil ? "写下今天" : "编辑这一页")
                    .font(.system(size: 18, design: .serif))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(AppDate.dayText(editingDay, format: "M月d日 · EEEE"))
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.muted)
            }
            Text(composerHint)
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
                .padding(.top, 5)
            HStack(spacing: 4) {
                ForEach(MoodCatalog.all) { mood in
                    let selected = moodKey == mood.key
                    Button {
                        moodKey = selected ? nil : mood.key
                    } label: {
                        Text(mood.label)
                            .font(.system(size: 9.5, weight: selected ? .medium : .regular))
                            .foregroundStyle(selected ? mood.color : Theme.muted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(selected ? mood.color.opacity(0.14) : Color.clear)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(selected ? Color.clear : Theme.line, lineWidth: 0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 9)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 13, design: .serif))
                    .foregroundStyle(Theme.inkSoft)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 112)
                    .padding(8)
                    .background(Theme.paper.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.line, lineWidth: 0.7)
                    )
                if text.isEmpty {
                    Text("今天发生了什么？")
                        .font(.system(size: 13, design: .serif))
                        .foregroundStyle(Theme.faint)
                        .padding(.leading, 14)
                        .padding(.top, 16)
                        .allowsHitTesting(false)
                }
            }
            .padding(.top, 9)

            HStack(alignment: .top, spacing: 10) {
                PhotosPicker(selection: $photoItem, matching: .any(of: [.images, .livePhotos])) {
                    HStack(spacing: 6) {
                        if let newPhotoData, let image = UIImage(data: newPhotoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 38, height: 38)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        } else if photoName != nil {
                            PhotoView(filename: photoName, cornerRadius: 9)
                                .frame(width: 38, height: 38)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 14))
                        }
                        Text(photoName == nil && newPhotoData == nil ? "照片" : "换照片")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(Theme.paper)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 9)

            MusicAttachmentView(
                name: musicName,
                title: musicTitle,
                editable: true,
                onPick: { showAudioPicker = true },
                onRemove: {
                    if let old = musicName, old != originalMusic {
                        store.deleteAudio(old)
                    }
                    musicName = nil
                    musicTitle = nil
                }
            )
            .padding(.top, 8)

            HStack {
                Text("\(text.count) 字")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
                Spacer()
                if editingId != nil {
                    Button("写新的一条") {
                        startNewEntry()
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.cinnabar)
                }
            }
            .padding(.top, 5)

            Button(editingId == nil ? "收下这一页" : "保存修改") {
                saveDiary()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 8)
        }
    }

    private var filterCard: some View {
        Card {
            HStack(spacing: 4) {
                Button {
                    allMonths = false
                    monthCursor = AppDate.calendar.date(byAdding: .month, value: -1, to: allMonths ? AppDate.startOfMonth(Date()) : monthCursor) ?? monthCursor
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 30, height: 30)
                        .background(Theme.paper)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Text(allMonths ? "全部日记" : AppDate.monthLabel(monthCursor))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                Button {
                    allMonths = false
                    monthCursor = AppDate.calendar.date(byAdding: .month, value: 1, to: allMonths ? AppDate.startOfMonth(Date()) : monthCursor) ?? monthCursor
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 30, height: 30)
                        .background(Theme.paper)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                if !allMonths || filterMood != nil || !searchText.isEmpty {
                    Button("重置") {
                        allMonths = true
                        filterMood = nil
                        searchText = ""
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.cinnabar)
                }
            }

            HStack(spacing: 3) {
                filterMoodButton(label: "全部", selected: filterMood == nil, color: Theme.cinnabar) {
                    filterMood = nil
                }
                ForEach(MoodCatalog.all) { mood in
                    filterMoodButton(label: mood.label, selected: filterMood == mood.key, color: mood.color) {
                        filterMood = filterMood == mood.key ? nil : mood.key
                    }
                }
            }
            .padding(.top, 8)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.faint)
                TextField("搜索日记正文、心情", text: $searchText)
                    .font(.system(size: 11.5))
                    .textInputAutocapitalization(.never)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(Theme.paper)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 0.7))
            .padding(.top, 9)
        }
    }

    private var statsCard: some View {
        Card {
            HStack(alignment: .lastTextBaseline, spacing: 7) {
                Text("\(monthEntries.count)")
                    .font(.system(size: 28, weight: .regular, design: .serif))
                    .foregroundStyle(Theme.cinnabar)
                Text("篇 · 记录了 \(Set(monthEntries.map(\.epochDay)).count) 天" + (streak > 0 ? " · 连续 \(streak) 天" : ""))
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.muted)
            }
            let counts = Dictionary(grouping: monthEntries.compactMap(\.moodKey), by: { $0 }).mapValues { $0.count }
            if !counts.isEmpty {
                HStack(spacing: 5) {
                    ForEach(MoodCatalog.all) { mood in
                        if let count = counts[mood.key], count > 0 {
                            Text("\(mood.label) \(count)")
                                .font(.system(size: 9))
                                .foregroundStyle(mood.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(mood.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 8)
            } else {
                Text("这个月还没有记录心情。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.faint)
                    .padding(.top, 6)
            }
        }
    }

    private var showPastToday: Bool {
        allMonths && filterMood == nil && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !pastToday.isEmpty
    }

    private var pastTodayCard: some View {
        Card {
            Text("往年今天")
                .font(.system(size: 10, weight: .medium))
                .tracking(0.7)
                .foregroundStyle(Theme.muted)
            Text("同一天，曾经写过这些。")
                .font(.system(size: 10))
                .foregroundStyle(Theme.faint)
                .padding(.top, 3)
            ForEach(pastToday.prefix(3)) { entry in
                Button {
                    selectedEntry = entry
                } label: {
                    HStack(alignment: .top, spacing: 7) {
                        Text(AppDate.dayText(entry.epochDay, format: "yyyy"))
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.cinnabar)
                        Text(entry.text)
                            .font(.system(size: 11.5, design: .serif))
                            .foregroundStyle(Theme.inkSoft)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(.top, 7)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filterTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "搜索 “\(searchText)”"
        }
        if !allMonths && filterMood != nil {
            return "\(AppDate.monthLabel(monthCursor)) · \(MoodCatalog.option(filterMood)?.label ?? "")"
        }
        if !allMonths { return AppDate.monthLabel(monthCursor) }
        if let mood = MoodCatalog.option(filterMood) { return "全部 · \(mood.label)" }
        return "全部日记"
    }

    private func filterMoodButton(label: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? color : Theme.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 27)
                .background(selected ? color.opacity(0.12) : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func diaryRow(_ entry: DiaryEntry) -> some View {
        HStack(alignment: .top, spacing: 11) {
            if entry.photo != nil {
                PhotoView(filename: entry.photo, cornerRadius: 12)
                    .frame(width: 44, height: 44)
            }
            VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(AppDate.dayText(entry.epochDay, format: "M月d日 · EEEE"))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.muted)
                if let createdAt = entry.createdAt {
                    Text(AppDate.dateText(createdAt, format: "HH:mm"))
                        .font(.system(size: 8.5))
                        .foregroundStyle(Theme.faint)
                }
                if let mood = MoodCatalog.option(entry.moodKey) {
                    Text(mood.label)
                        .font(.system(size: 8))
                        .foregroundStyle(mood.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(mood.color.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
                Text("\(entry.text.count) 字")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.faint)
            }
            Text(entry.text)
                .font(.system(size: 12.5, design: .serif))
                .foregroundStyle(Theme.inkSoft)
                .lineSpacing(3)
                .lineLimit(5)
            if let music = entry.music, let title = entry.musicTitle {
                Button {
                    if let url = store.audioURL(for: music) {
                        AudioPlayer.shared.toggle(name: music, url: url)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: AudioPlayer.shared.isPlaying(music) ? "pause.fill" : "play.fill")
                        Text(title).lineLimit(1)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.cinnabar)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEntry = entry
        }
    }

    private func startNewEntry() {
        editingId = nil
        editingDay = AppDate.today
        text = ""
        moodKey = nil
        photoName = nil
        musicName = nil
        musicTitle = nil
        newPhotoData = nil
        photoItem = nil
        originalPhoto = nil
        originalMusic = nil
    }

    private func loadForEditing(_ entry: DiaryEntry) {
        editingId = entry.id
        editingDay = entry.epochDay
        text = entry.text
        moodKey = entry.moodKey
        photoName = entry.photo
        musicName = entry.music
        musicTitle = entry.musicTitle
        newPhotoData = nil
        photoItem = nil
        originalPhoto = entry.photo
        originalMusic = entry.music
        liveAsset = nil
    }

    private func saveDiary() {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            showEmptyAlert = true
            return
        }
        let id = editingId ?? UUID()
        let existing = store.data.workbench.diary.first { $0.id == id }
        var savedPhoto = photoName
        if let data = newPhotoData, let name = store.savePhoto(data) {
            if let old = photoName, old != originalPhoto {
                store.deletePhoto(old)
            }
            savedPhoto = name
            photoName = name
            if let liveAsset {
                store.saveLiveVideo(asset: liveAsset, photoName: name) { _ in }
            }
            newPhotoData = nil
            photoItem = nil
        }
        let entry = DiaryEntry(
            id: id,
            epochDay: editingDay,
            text: value,
            moodKey: moodKey,
            createdAt: existing?.createdAt ?? Date(),
            photo: savedPhoto,
            music: musicName,
            musicTitle: musicTitle
        )
        store.updateWorkbench { data in
            data.diary.removeAll { $0.id == id }
            data.diary.append(entry)
            data.diary.sort {
                if $0.epochDay != $1.epochDay { return $0.epochDay > $1.epochDay }
                return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
            if let moodKey {
                data.moods[String(entry.epochDay)] = moodKey
            } else {
                data.moods.removeValue(forKey: String(entry.epochDay))
            }
        }
        if let old = originalPhoto, old != savedPhoto {
            store.deletePhoto(old)
        }
        if let old = originalMusic, old != musicName {
            store.deleteAudio(old)
        }
        originalPhoto = savedPhoto
        originalMusic = musicName
        editingId = id
    }

    private func delete(_ entry: DiaryEntry) {
        store.updateWorkbench { data in
            data.diary.removeAll { $0.id == entry.id }
        }
        if editingId == entry.id {
            editingId = nil
            editingDay = AppDate.today
            text = ""
            moodKey = nil
        }
        deletedEntry = entry
        showUndo = true
    }

    private func undoDelete() {
        guard let entry = deletedEntry else { return }
        store.updateWorkbench { data in
            if !data.diary.contains(where: { $0.id == entry.id }) {
                data.diary.append(entry)
                data.diary.sort {
                    if $0.epochDay != $1.epochDay { return $0.epochDay > $1.epochDay }
                    return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                }
            }
        }
        deletedEntry = nil
    }
}

private struct DiaryDetailView: View {
    @EnvironmentObject private var store: NianRiStore
    @Environment(\.dismiss) private var dismiss
    let entry: DiaryEntry
    var onEdit: () -> Void
    var onDelete: () -> Void

    @State private var showDelete = false
    @State private var showLivePlayer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(AppDate.dayText(entry.epochDay, format: "yyyy年M月d日 · EEEE"))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                        if let createdAt = entry.createdAt {
                            Text(AppDate.dateText(createdAt, format: "HH:mm"))
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.faint)
                        }
                        Spacer()
                        if let mood = MoodCatalog.option(entry.moodKey) {
                            Text(mood.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(mood.color)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(mood.color.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    if entry.photo != nil {
                        ZStack(alignment: .bottomTrailing) {
                            PhotoView(filename: entry.photo, cornerRadius: 20)
                                .frame(height: 230)
                                .onTapGesture {
                                    if store.liveVideoURL(for: entry.photo) != nil { showLivePlayer = true }
                                }
                                .onLongPressGesture(minimumDuration: 0.35) {
                                    if store.liveVideoURL(for: entry.photo) != nil { showLivePlayer = true }
                                }
                            if let url = store.liveVideoURL(for: entry.photo) {
                                Button {
                                    showLivePlayer = true
                                } label: {
                                    Label("实况", systemImage: "play.fill")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Theme.cream)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 7)
                                        .background(.black.opacity(0.52))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                                .sheet(isPresented: $showLivePlayer) {
                                    LivePhotoPlayerSheet(url: url)
                                }
                            }
                        }
                    }
                    Text(entry.text)
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(7)
                        .textSelection(.enabled)
                    if let music = entry.music, let title = entry.musicTitle {
                        MusicAttachmentView(
                            name: music,
                            title: title,
                            editable: false
                        )
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.paper)
            .navigationTitle("这一页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("编辑") { onEdit() }
                        .foregroundStyle(Theme.cinnabar)
                    Menu {
                        Button("删除这篇日记", role: .destructive) {
                            showDelete = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Theme.cinnabar)
                    }
                }
            }
            .alert("删除这篇日记？", isPresented: $showDelete) {
                Button("删除", role: .destructive) {
                    dismiss()
                    onDelete()
                }
                Button("先留着", role: .cancel) {}
            } message: {
                Text("可以点「撤销」恢复。")
            }
        }
    }
}
