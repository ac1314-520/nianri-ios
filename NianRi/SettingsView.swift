import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: NianRiStore
    @State private var copiedWeChat = false
    @State private var notificationMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("提醒") {
                    Button {
                        Task {
                            let granted = await NotificationManager.shared.requestAuthorization()
                            if granted {
                                NotificationManager.shared.reschedule(events: store.data.anniversaries)
                                notificationMessage = "通知权限已开启，纪念日提醒会在这台 iPhone 上生效。"
                            } else {
                                notificationMessage = "通知权限未开启。可以到系统设置 → 通知 → 念日里打开。"
                            }
                        }
                    } label: {
                        Label("允许今天提醒", systemImage: "bell")
                    }
                    if let notificationMessage {
                        Text(notificationMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                    Text("每条纪念日都可以单独设置提醒时间。iOS 不保证精确到秒，系统会按自己的节奏送达。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.faint)
                }

                Section("数据与隐私") {
                    Label("只属于这台 iPhone", systemImage: "checkmark.shield")
                        .font(.system(size: 15, weight: .medium))
                    Text("无账号、无广告、无统计 SDK。\n纪念日、照片、日记、打卡、记账、生理期和愿望都保存在应用私有目录，不上传服务器。\n只有刷新天气或点击 GitHub 反馈时才会联网。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(4)
                    Text("删除应用会删除本地数据。当前版本没有云端同步。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.faint)
                }

                Section("锁屏小组件") {
                    Label("念日倒计时", systemImage: "rectangle.inset.filled.and.person.filled")
                    Text("在 iOS 桌面或锁屏长按 → 添加小组件 → 搜索「念日」，可以添加圆形、矩形和行内倒计时。需要先在 Xcode 中为 App 和 Widget 添加同一个 App Group。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(4)
                }

                Section("反馈与建议") {
                    Link(destination: URL(string: "https://github.com/ac1314-520/nianri/issues/new")!) {
                        Label("报告一个问题 / 提功能建议", systemImage: "bubble.left.and.bubble.right")
                    }
                    Button {
                        UIPasteboard.general.string = "MiManchi13l4520"
                        copiedWeChat = true
                    } label: {
                        HStack {
                            Label("作者微信", systemImage: "message")
                            Spacer()
                            Text(copiedWeChat ? "已复制" : "MiManchi13l4520")
                                .font(.system(size: 11))
                                .foregroundStyle(copiedWeChat ? Theme.sage : Theme.cinnabar)
                        }
                    }
                    Text("反馈会公开在 GitHub Issues，请不要附带照片、纪念日标题或其他私密内容。")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Theme.faint)
                }

                Section("生理期提示") {
                    Text("周期预测根据本机记录和周期长度估算，仅供参考，不用于诊断或避孕。应用内建议是一般生活提示，不替代医生诊断。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(4)
                }

                Section("关于") {
                    HStack(spacing: 12) {
                        Text("念")
                            .font(.system(size: 24, design: .serif))
                            .foregroundStyle(Theme.cream)
                            .frame(width: 46, height: 46)
                            .background(Theme.cinnabar)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("念日")
                                .font(.system(size: 18, design: .serif))
                                .foregroundStyle(Theme.ink)
                            Text("NIANRI · 纪念日手帐  iOS 1.2.0")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Text("一些干净、安静、只属于你的日子。")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.faint)
                    Link("打开念日 GitHub 仓库", destination: URL(string: "https://github.com/ac1314-520/nianri")!)
                        .font(.system(size: 12))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .tint(Theme.cinnabar)
        }
    }
}
