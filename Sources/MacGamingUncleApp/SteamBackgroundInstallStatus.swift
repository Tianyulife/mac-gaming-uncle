import SwiftUI
import IndieCore

enum SteamInstallationRequestState {
    case preparing, waiting, confirmation, failed
    var blocksSubmission: Bool { self == .preparing || self == .waiting }
    var label: String {
        switch self {
        case .preparing: L("正在提交安装请求…")
        case .waiting: L("等待 Steam 下载和校验…")
        case .confirmation: L("需要在 Steam 中确认")
        case .failed: L("安装请求未确认，请重试")
        }
    }
}

struct SteamBackgroundInstallStatus: View {
    @EnvironmentObject private var model: MacGamingUncleAppModel
    let appID: UInt64
    let state: SteamInstallationRequestState
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(state.label, systemImage: state == .failed ? "exclamationmark.triangle" : "arrow.down.circle")
            if state == .preparing { ProgressView().controlSize(.small) }
            if let progress = model.steamBridgeDownloads[appID]?.progress {
                ProgressView(value: progress)
            }
            HStack {
                if !state.blocksSubmission {
                    Button(L("重试")) { Task { await model.installSteamGame(appID: appID) } }
                }
                Button(L("在 Steam 中查看")) { Task { await model.openSteamClient(.game(appID)) } }
            }.disabled(model.isWorking || model.isOpeningSteamClient)
        }.font(.callout).frame(width: 240, alignment: .leading)
    }
}
