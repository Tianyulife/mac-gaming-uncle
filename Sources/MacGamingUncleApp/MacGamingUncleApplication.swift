import AppKit
import IndieCore
import SwiftUI

@main
struct MacGamingUncleApplication: App {
    @NSApplicationDelegateAdaptor(UncleApplicationDelegate.self) private var appDelegate
    @StateObject private var model = MacGamingUncleAppModel()

    var body: some Scene {
        Window("Mac Gaming Uncle", id: "steam-shell-main") {
            ContentView()
                .environmentObject(model)
                .environment(\.locale, AppLanguage.locale)
                .frame(minWidth: 1100, minHeight: 720)
                .onOpenURL { model.handleDeepLink($0) }
                .onAppear {
                    appDelegate.model = model
                    if #available(macOS 26, *) { AutomaticFrameInterpolation.shared.bind(model: model) }
                }
        }
        .commands { WindowOperationCommands() }
        .defaultSize(width: 1440, height: 920)
        .defaultPosition(.center)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))

        Settings {
            SettingsView()
                .environmentObject(model)
                .environment(\.locale, AppLanguage.locale)
                .frame(width: 560, height: 360)
        }
        WindowGroup(L("通用插帧（实验）"), id: "frame-interpolation", for: String.self) { id in
            if #available(macOS 26, *) {
                FrameInterpolationView(gameID: id.wrappedValue ?? "manual")
                    .environmentObject(model)
                    .environment(\.locale, AppLanguage.locale)
            } else {
                Text(L("通用插帧需要 macOS 26 或更新版本")).padding(32)
            }
        }
        .defaultSize(width: 620, height: 440)
        .commands {
            CommandMenu(L("通用插帧（实验）")) {
                Button(L("停止插帧")) {
                    if #available(macOS 26, *) { GameFrameInterpolation.shared.stop() }
                }
            }
        }
    }
}

@MainActor
final class UncleApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var model: MacGamingUncleAppModel?
    private var shutdownTask: Task<Void, Never>?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if #available(macOS 26, *) { AutomaticFrameInterpolation.shared.shutdown() }
        guard let model else { return .terminateNow }
        if shutdownTask == nil {
            shutdownTask = Task { @MainActor in
                let stopped = await model.shutdownManagedSteam()
                if stopped {
                    sender.reply(toApplicationShouldTerminate: true)
                } else {
                    let alert = NSAlert()
                    alert.messageText = L("Steam 仍需要运行")
                    alert.informativeText = L("游戏、云存档上传或客户端退出尚未确认。可取消退出继续等待，或仅退出 Mac Gaming Uncle 并保留 Steam 后台运行。")
                    alert.addButton(withTitle: L("取消退出，继续等待"))
                    alert.addButton(withTitle: L("退出应用，保留 Steam"))
                    let quitOnlyApp = alert.runModal() == .alertSecondButtonReturn
                    self.shutdownTask = nil
                    sender.reply(toApplicationShouldTerminate: quitOnlyApp)
                }
            }
        }
        return .terminateLater
    }
}
