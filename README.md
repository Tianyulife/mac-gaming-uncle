<div align="center">
  <img src="Assets/MacGamingUncleIcon.png" width="144" alt="Mac Gaming Uncle icon">
  <h1>Mac Gaming Uncle</h1>
  <p><strong>Run Windows games you own on Apple Silicon Macs.</strong></p>
  <p>Native SwiftUI · Wine · Apple D3DMetal · MetalFX · DXVK</p>
  <p><a href="https://github.com/enginefuture/mac-gaming-uncle/releases/download/v0.6.1/Mac-Gaming-Uncle-0.6.1-macOS-arm64.dmg">Download the 0.6.1 DMG</a> · <a href="https://github.com/enginefuture/mac-gaming-uncle/releases/tag/v0.6.1">Release notes</a></p>
  <p>English · <a href="README.zh-CN.md">简体中文</a></p>
</div>

Version 0.6.1 improves experimental universal 2× frame interpolation, presentation pacing and Wine game-window detection, and fixes CRLF parsing of Steam Cloud logs. It retains Wine `11.0.9-services.1` and the spatial audio/Steam lifecycle improvements introduced in [0.6.0](docs/releases/0.6.0.md). See the [0.6.1 release notes](docs/releases/0.6.1.md).

## Universal frame interpolation and Black Myth: Wukong

Universal interpolation creates an intermediate image between captured game images and presents them through a mouse-through overlay. Its purpose is smoother displayed motion; it does not increase game simulation/rendering FPS or solve the underlying CPU/GPU bottleneck. It uses Apple's VideoToolbox, ScreenCaptureKit and MetalFX Spatial APIs. Architecture research references [MetalDuck](https://github.com/Lospi/MetalDuck); no LSFG model is bundled.

**Requirements:** Apple Silicon, macOS 26+, one windowed/borderless SDR game window and screen-capture permission. The app itself still supports macOS 15+. This feature is experimental and off by default. Open **Game Settings → Universal Frame Interpolation → Open panel**, enable automatic following, use **Authorize screen capture / Refresh**, and enable Mac Gaming Uncle under **System Settings → Privacy & Security → Screen & System Audio Recording** if requested. Reopen the app if macOS requires it. Disable the game's own frame generation when evaluating this feature, then keep the game foreground. Only the target game window is captured; no audio is captured or recording saved.

Capture is capped at 30 FPS and a processing budget of 1280×720; generated images are upscaled to the original window's physical output dimensions. This cap is separate from the game's rendering resolution. The target is up to two presented images per captured pair, not a guarantee of 60 FPS or twice the game's HUD FPS. Switching away pauses/stops the overlay; automatic following rechecks on return. Static scenes, capture/processing stalls and a display that stops actually presenting reveal the original game. Manual Stop suppresses automatic restart for that game run. Emergency stop: **Control + Option + Command + F12**.

**Black Myth: Wukong fixed-scene test, 2026-10-11:** M3 Max, macOS 26.6.2, Wine `11.0.9-services.1`, locally imported GPTK 4.0b2 / D3DMetal, DX12 + MetalFX/DLSS mapping, in-game frame generation off. The user confirmed DLSS could be selected in the earlier launch test. This is an experimental MetalFX mapping, not NVIDIA RTX hardware support.

| Observation | Result |
| --- | --- |
| Game HUD and user feedback | 40 FPS; somewhat smoother than before |
| Interpolation processing → physical overlay output | 1104×720 → 3024×1964; no game resolution or Wine DPI changes |
| First five minutes, excluding five startup snapshots | 52.30 distinct drawable presentation callbacks/s; per-minute rates 50.73 / 51.68 / 51.63 / 53.82 / 53.53, without progressive decline |
| Last snapshot before 300 seconds | Processing P95 14.53 ms; presentation interval P95 33.33 ms, P99 41.67 ms; zero capture-copy failures and renderer backpressure |
| End of the probe | Visibility protection stopped it at 306.27 seconds after the user switched applications; probe exit 2, not a clean full-run pass |

These presentation callbacks are **not engine FPS or a physical monitor refresh measurement**. Intervals remain uneven; stable 60 FPS, doubled performance and universal compatibility are not established. An earlier 60-second attempt generated frames with zero actual presentations; the new independent presentation watchdog prevents that false-running state, but the intermittent display cause remains unresolved. The five-minute probe used the production capture/presentation sources in a separate helper, not a five-minute acceptance test of the packaged app. Possible added latency, HUD ghosting and combat image quality remain unvalidated. Direct 1920×1080 interpolation failed on this machine; higher output resolutions use the capped processing path. See [implementation and full test history](docs/FRAME_INTERPOLATION.md) and [release validation](docs/validation/release-0.6.1-20261011.json).

<p align="center">
  <img src="Assets/MacGamingUncleHero.png" width="100%" alt="Uncle was not wrong—he was simply early.">
</p>

> [!IMPORTANT]
> Mac Gaming Uncle is an open-source compatibility research project, not a virtual machine. The app bundle contains no Windows, Steam, games, or Apple D3DMetal. Onboarding downloads the original GPTK image separately through our R2 channel and verifies it before local import. Apple's original license and noncommercial distribution terms still apply. See [GPTK distribution](docs/GPTK_DISTRIBUTION.md).

## Beginner installation guide

You can install the DMG directly. No programming, Xcode, or source build is required.

### 1. Check your Mac

Open ** → About This Mac**. You need an Apple Silicon (M-series) Mac with **macOS 15 or later**; Intel Macs are not supported. Have an Internet connection, your Steam account, and enough free disk space for the components and games you plan to install.

### 2. Download the installer

Select **[Download Mac Gaming Uncle 0.6.1 (DMG)](https://github.com/enginefuture/mac-gaming-uncle/releases/download/v0.6.1/Mac-Gaming-Uncle-0.6.1-macOS-arm64.dmg)**.

Alternatively, open the [Release page](https://github.com/enginefuture/mac-gaming-uncle/releases/tag/v0.6.1) and choose `Mac-Gaming-Uncle-0.6.1-macOS-arm64.dmg` under **Assets**. `Source code`, `.sha256`, and the Wine `.tar.xz` are source archives, checksums, and a runtime that the app downloads automatically—not the app installer.

### 3. Install and open the app

1. In Finder's Downloads folder, double-click the downloaded `.dmg`.
2. Drag **Mac Gaming Uncle** onto the **Applications** folder icon and wait for copying to finish.
3. Open **Mac Gaming Uncle** from Finder's Applications folder, rather than running it from the mounted DMG.
4. Eject the installer disk from Finder's sidebar when finished.

This research preview is not notarized. If macOS cannot verify the developer, check that the download came from the official repository linked above. If you decide to trust it, after attempting to open the app, go to **System Settings → Privacy & Security → Security → Open Anyway** and follow the prompts. See [Apple's instructions](https://support.apple.com/en-us/102445). If macOS reports malware or a damaged file, stop, download again, and report the issue rather than disabling system protection.

### 4. Choose your language, finish setup, and sign in to Steam

The app follows your system language (English or Simplified Chinese, with English as the fallback). Use **Language / 语言** on the setup card or in **Advanced Settings → Preferences** to choose **System**, **English**, or **简体中文**, then reopen the app to apply. This changes the app interface and requested Store text, not the language of an already-running game or Steam client.

The first launch automatically displays two setup steps:

1. **Install the game environment**: the app checks and installs Rosetta, Wine, controller support, and graphics components. Keep it open while setup runs. If a step fails, read the error and select **Retry and continue**; completed components are retained.
2. **Sign in to Steam**: the app installs and updates Windows Steam, then opens its official login window. Scan the QR code using the Steam mobile app, or enter your Steam credentials and any required verification code. A separate Steam window is expected.

The initial Steam update can take several minutes. After signing in, return to Mac Gaming Uncle; library synchronization is automatic. Being signed in to the native macOS Steam app does not sign you in to this Windows Steam installation.

### 5. Install and play a game

Open **Library**, select a game you own, and choose **Install**. Select a target library and confirm. Steam downloads in the background; the app shows progress and speed, and enables **Start Game** only after installation and verification. Extra confirmation or login may require the explicit **Steam Client** entry. Browsing the Store does not grant ownership; obtain the appropriate license through Steam first.

Use **Storage & Libraries** to attach a library on another mounted disk, and **Uninstall Game** in game details to remove an installation with confirmation. See the [storage guide](docs/STEAM_STORAGE.md). Version 0.5.0 also fixes stale Steam connection status and installation popups; see the [release notes](docs/releases/0.5.0.md).

Start with default settings. Open **Game Settings** when you need to adjust resolution, HUD, or controller options. Pair a controller with macOS first, then inspect it using the controller shortcut in the top bar. The first game launch may take longer while graphics caches are built. A library listing does not mean a game has been verified compatible.

### Troubleshooting and updates

| Symptom | What to do |
| --- | --- |
| Signed in, but the library is empty | Wait for Steam to write its account cache, then choose **Sync Library** on Home or **Refresh** in Library. Check that you signed in to the Windows Steam opened by this app. The list depends on local Steam caches and may not include every owned title. |
| Component installation fails | Check the error, network connection, and free disk space, then retry. |
| A game fails to launch or renders incorrectly | Report its name, error, and renderer in [Issues](https://github.com/enginefuture/mac-gaming-uncle/issues). Do not include passwords, verification codes, or login files. |
| Updating the app | Exit your game and Mac Gaming Uncle, download the new DMG, and replace the app in Applications. Keep the application data directory to retain components and games. |

Closing Mac Gaming Uncle also shuts down its managed Steam. Save and exit your game before closing the app.

## Why this project exists

For years, “gaming on a Mac” was treated as a punchline. We want it to become ordinary and simple: install the app, sign in to Steam, download a game, and press Play. People should not need to learn Wine, bottles, graphics translation, and launch flags before they can enjoy games they already own.

Mac Gaming Uncle's long-term goal is to provide a SteamOS-like experience on the Mac: the system absorbs compatibility complexity while game installation, configuration, updates, and launching become as automatic as possible. It is not a SteamOS port and is not affiliated with Valve; the inspiration is SteamOS's product principle of hiding difficult technology behind a simple experience.

### Permanent noncommercial commitment

The official Mac Gaming Uncle project and its official releases will remain permanently noncommercial: no paid edition, subscriptions, advertising, paid compatibility lists, game commissions, or sale of user data. Compatibility recipes, issue records, and core implementation remain public. Success means helping more Mac users play games they legally own—not generating revenue.

> This commitment governs the official project's operation. The source remains under Apache License 2.0, which permits third-party use and redistribution under its terms; the official project will not use “noncommercial” branding to restrict ordinary open-source collaboration.

## Project status

Mac Gaming Uncle is currently a `0.6.1` research preview for Apple Silicon and macOS 15 or later. It now provides a Steam-client shell, native Store and Library, per-game settings, a reusable global Steam session, and an SDL/XInput controller launch path.

Hardware validation: Apple M3 Max, macOS 26.6.2, GPTK 4.0 beta 2, and Mac Gaming Uncle Wine 11.0.2. `Grim Dawn 1.3.0.8 (x64)` has been validated with its complete Chinese UI, Steam integration, XInput controller support, and Apple's in-game Metal HUD (D3D11, approximately 114 FPS); `Ruins of Dawn` reaches its main menu.

## Screenshots

These screenshots were captured from Mac Gaming Uncle 0.2.0 running on real hardware.

<table>
  <tr>
    <td width="50%"><strong>Home and recently played</strong><br><a href="docs/screenshots/0.2.0/home.png"><img src="docs/screenshots/0.2.0/home.png" width="100%" alt="Mac Gaming Uncle Home"></a></td>
    <td width="50%"><strong>Native Steam Store</strong><br><a href="docs/screenshots/0.2.0/store.png"><img src="docs/screenshots/0.2.0/store.png" width="100%" alt="Mac Gaming Uncle native Steam Store"></a></td>
  </tr>
  <tr>
    <td width="50%"><strong>Account Library and game details</strong><br><a href="docs/screenshots/0.2.0/library.png"><img src="docs/screenshots/0.2.0/library.png" width="100%" alt="Mac Gaming Uncle Library"></a></td>
    <td width="50%"><strong>Per-game settings entry</strong><br><a href="docs/screenshots/0.2.0/library-settings-entry.png"><img src="docs/screenshots/0.2.0/library-settings-entry.png" width="100%" alt="Mac Gaming Uncle settings entry"></a></td>
  </tr>
  <tr>
    <td width="50%"><strong>Per-game configuration</strong><br><a href="docs/screenshots/0.2.0/per-game-settings.png"><img src="docs/screenshots/0.2.0/per-game-settings.png" width="100%" alt="Mac Gaming Uncle per-game settings"></a></td>
    <td width="50%"><strong>Controller Center</strong><br><a href="docs/screenshots/0.2.0/controller-center.png"><img src="docs/screenshots/0.2.0/controller-center.png" width="100%" alt="Mac Gaming Uncle Controller Center"></a></td>
  </tr>
</table>

## Features

- Native SwiftUI/AppKit interface with English and Simplified Chinese, including onboarding, settings, controller management, diagnostics, and status/error messages.
- Pixel-game brand art: a tired mustached uncle app icon, a whole-apple controller mark, and a transparent pixel apple for launch buttons, with no bite or play triangle.
- Top-level navigation focuses on Home, Store, and Library; controllers, downloads, and runtime setup remain supporting tools without a separate Community channel.
- A focused Steam-client shell with a native Store home/categories/search experience, account library, artwork, details, install, and launch actions.
- Public Store browsing requires no web login; wishlist, purchase, and account actions open a clearly labeled `store.steampowered.com` secure page without copying Steam CEF's encrypted session cookies.
- Reads AppIDs, playtime, and recent activity from the local Steam `localconfig.vdf` without reading or uploading authentication tokens, and caches official Store metadata locally.
- Downloads the Windows Steam installer from Valve's official CDN.
- Downloads the original GPTK 4 image through the project's Cloudflare R2 channel, verifying size, SHA-256, DMG integrity and Apple signature.
- Imports the complete D3DMetal framework, Wine PE bridge and Unix bridge while retaining the original image and license separately.
- Builds and installs Mac Gaming Uncle Wine 11 from corresponding public source, with GCC 15 MinGW, new WoW64, MSync, SDL2 winebus/XInput, Steam CEF fixes, and a native D3DMetal bridge path.
- Repairs Steam CEF compatibility and installs CJK fonts with DirectWrite font linking.
- Resolves the x64/`*-Win64-Shipping.exe` target, then lets Steam create it through `-applaunch` so SteamAPI, renderer, and HUD state are inherited intact.
- Keeps a global signed-in Steam session and reuses it whenever launch environments are compatible; it restarts only for conflicting renderer, HUD, synchronization, or virtual-desktop settings.
- Installs native D3DMetal PE bridges into the bottle with versioned backups, and automatically repairs the CEF wrapper after a Steam update replaces it.
- Invalidates shader caches when the GPTK version, source hash, MetalFX, DXR, Metal 4, macOS version, or compatibility arguments change.
- Auditable game recipes matched by Steam AppID and executable name.
- Static PE architecture, DirectX import, and anti-cheat inspection; kernel anti-cheat is blocked before launch.
- Apple Metal Performance HUD in the same Mac Gaming Uncle Wine 11 process that runs the game.
- Per-game settings for virtual-desktop resolution, renderer, synchronization, Metal HUD, MetalFX, Metal 4, and launch arguments; settings survive Steam rescans.
- A dedicated Controller Center for Bluetooth discovery, device/battery/capability status, player assignment, live input and rumble tests, plus per-game SDL HIDAPI compatibility.
- SQLite state, isolated Wine bottles, recoverable backups, CLI diagnostics, and automated tests.

## How it works

```text
Windows game
     │
     ├─ Win32 / Win64 APIs ──────────────→ Wine
     ├─ x86_64 instructions ─────────────→ Rosetta 2
     └─ Direct3D 11 / 12 ─→ D3DMetal ───→ Metal
                           └→ DXVK/MoltenVK (fallback)

Steam AppManifest → discovery → game recipe → immutable LaunchPlan → isolated bottle
```

Mac Gaming Uncle composes, verifies, and launches these layers. It does not modify game content or bypass DRM, licensing, or anti-cheat systems.

## Quick start

### Requirements

- Apple Silicon Mac
- macOS 15 or later
- Network access to the component download servers
- A Steam account and games you legally own

### Build from source

For developers only: this requires Xcode 26 or a compatible full Swift 6 toolchain. Other users should follow the Beginner installation guide above.

If you do not need a development environment, download the mount-verified [Mac Gaming Uncle 0.6.1 DMG](https://github.com/enginefuture/mac-gaming-uncle/releases/download/v0.6.1/Mac-Gaming-Uncle-0.6.1-macOS-arm64.dmg) and verify it with the adjacent [SHA-256 file](https://github.com/enginefuture/mac-gaming-uncle/releases/download/v0.6.1/Mac-Gaming-Uncle-0.6.1-macOS-arm64.dmg.sha256).

```bash
git clone https://github.com/enginefuture/mac-gaming-uncle.git
cd mac-gaming-uncle
scripts/build-app.sh
open "dist/Mac Gaming Uncle.app"
```

Build and mount-verify a distributable DMG:

```bash
scripts/build-dmg.sh
```

The current open-source research preview is ad-hoc signed and not notarized. If Gatekeeper blocks a verified GitHub Release download, remove quarantine after reviewing its source:

```bash
xattr -dr com.apple.quarantine "/Applications/Mac Gaming Uncle.app"
```

Development builds are ad-hoc signed. Set a Developer ID for distribution:

```bash
MAC_GAMING_UNCLE_CODESIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  scripts/build-app.sh
```

### Game settings

MetalFX/DLSS mapping is experimental and disabled by default. It can only help games that already implement DLSS, and recipes can explicitly disable it. `Grim Dawn` does not use DLSS, so Mac Gaming Uncle ignores the global MetalFX toggle for that title to prevent the NVNGX GPU-spoof path from dropping its UI.

“Prefer Metal 4” is enabled by default, but Mac Gaming Uncle first queries the active `MTLDevice` for hardware and OS support. Unsupported systems fall back automatically, and the option can be disabled for a title that regresses. The D3DMetal release, the game's Direct3D API, and the Metal submission path are separate dimensions; a HUD reading `Game Porting Toolkit 4.0b2 · D3D11` is expected.

“Show Apple Metal HUD” relays Apple's HUD environment through Steam to the target game. It does not switch to Apple Evaluation Wine or bypass Steam. The HUD appears only with D3DMetal or DXMT. The `Grim Dawn 1.3` recipe selects the x64 executable and D3DMetal 4, matches the game resolution to the Mac display's logical-point dimensions, and backs up `options.txt` before enabling the classic HUD and native gamepad support. It also disables MSync and Steam Overlay for this title to avoid missing UI and displaced pointer hit regions.

## Development and testing

```bash
swift test
swift build -c release
swift run macgamingunclectl --json doctor
scripts/check.sh
scripts/build-indie-wine11.sh
```

Useful CLI commands:

```text
macgamingunclectl doctor
macgamingunclectl pe <game.exe>
macgamingunclectl steam-scan <steamapps-directory>
macgamingunclectl recipes validate <recipes-directory>
macgamingunclectl gptk import <apple-gptk.dmg|mounted-directory>
macgamingunclectl wine latest
macgamingunclectl wine gaming-install
macgamingunclectl wine local-install <runtime-root>
macgamingunclectl dxvk install <bottle-root>
macgamingunclectl dxmt install
macgamingunclectl steam repair <bottle-root> [wrapper.exe]
macgamingunclectl fonts repair <bottle-root> <runtime-root>
```

Further reading:

- [Architecture](docs/ARCHITECTURE.md)
- [Runtime supply chain](docs/RUNTIME_SUPPLY_CHAIN.md)
- [Testing guide](docs/TESTING.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)

## Compatibility boundaries

- Wine is a compatibility layer, not a security sandbox. Windows processes still run with the current macOS user's permissions.
- Kernel anti-cheat, Windows drivers, UWP, some DRM systems, and software requiring AVX-512 generally do not work.
- Compatibility for 32-bit titles, D3D9/10/11, launchers, and video playback varies by game.
- D3DMetal, Steam, and games remain subject to their own terms. This repository does not provide those binaries.
- Mac Gaming Uncle is not affiliated with Apple, Valve, CodeWeavers, or any game publisher.

## Contributing

Reproducible compatibility reports, game recipes, tests, and code improvements are welcome. Issues should include the Mac model, macOS version, GPTK/D3DMetal version, Steam AppID, launch arguments, and relevant logs with personal information removed.

Do not submit game files, account credentials, Apple download media, D3DMetal binaries, or material intended to bypass DRM or anti-cheat systems.

## License

Mac Gaming Uncle source code is licensed under the [Apache License 2.0](LICENSE). Third-party components remain under their own licenses or terms; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
