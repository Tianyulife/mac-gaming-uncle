import IndieCatalog
import IndieCore
import IndieRuntime
import SwiftUI

struct SteamInstallProgress: View {
    @EnvironmentObject private var model: MacGamingUncleAppModel
    let game: SteamGame
    private var transfer: SteamBridgeDownload? { model.steamBridgeDownloads[game.appID] }
    private var progress: Double? {
        if game.downloadIncomplete { return game.downloadProgress }
        if game.stagingIncomplete, let total = game.bytesToStage, total > 0 {
            return min(1,Double(game.bytesStaged ?? 0)/Double(total))
        }
        return transfer?.progress
    }
    private func bytes(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(min(9e18,max(0,value))), countStyle: .file)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(transfer?.paused == true ? L("下载已暂停") :
                (game.downloadIncomplete ? L("正在下载") : L("正在安装和校验")), systemImage: "arrow.down.circle")
                .font(.callout.weight(.semibold))
            if let progress {
                ProgressView(value: progress)
                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption).monospacedDigit()
            } else {
                ProgressView().controlSize(.small)
            }
            if let total = transfer?.totalBytes ?? game.bytesToDownload.map(Double.init), total > 0 {
                Text("\(bytes(transfer?.downloadedBytes ?? Double(game.bytesDownloaded ?? 0))) / \(bytes(total))")
                    .font(.caption).monospacedDigit()
            }
            if transfer?.paused == true {
                Text("0 B/s").font(.caption).monospacedDigit()
            } else if game.downloadIncomplete {
                if let speed = transfer?.bytesPerSecond ?? model.steamDownloadSpeeds[game.appID] {
                    Text((transfer?.bytesPerSecond == nil ? L("估算速度") + " · " : "") + bytes(speed) + "/s")
                        .font(.caption).monospacedDigit()
                } else {
                    Text(L("正在测量下载速度…")).font(.caption)
                }
            }
            Button(L("在 Steam 中查看"), systemImage: "arrow.up.forward.app") {
                Task { await model.openSteamClient(.game(game.appID)) }
            }
            .disabled(model.isWorking || model.isOpeningSteamClient)
            if model.steamInstallationRequests[game.appID] == .failed {
                Button(L("重试安装")) { Task { await model.installSteamGame(appID:game.appID) } }
                    .disabled(model.isWorking)
            }
            Text(L("Steam 后台下载，完成校验后即可开始游戏"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 260, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
