# Steam downloads and storage

1. Connect and mount the disk in macOS.
2. Open **Library → Storage & Libraries → Add / Attach Library**.
3. Choose a writable library folder, or an existing `SteamLibrary` / `steamapps` folder. Do not select a disk root. Steam registers the library; the app does not move installed games automatically.
4. Click **Install Game**, review the target path and free space, then confirm. Your last selection is remembered. A disconnected target is not silently replaced with the internal disk.
5. Download progress and speed appear in the game details. Estimated speed is labeled when Steam's native rate is unavailable. Play is enabled after installation and verification.
6. **Uninstall Game** requests removal through Steam after confirmation. No additional save/configuration/cloud cleanup is performed. Connect the library disk and quit the game before uninstalling.

Existing macOS builds may require Windows-specific files. Steam may verify or update imported content. Do not let multiple Steam clients write to the same library concurrently. Physical disk hotplug and all filesystem/Steam-version combinations have not been exhaustively tested.

The application uses existing Wine drive mappings. Read-only or unavailable locations cannot be installation targets. Library attachment is not macOS disk mounting or formatting.

## 中文

先在 macOS 连接并挂载磁盘，再进入 **游戏库 → 存储与游戏库 → 添加／挂载游戏库**，选择可写文件夹或已有的 `SteamLibrary / steamapps`。安装前会显示路径和可用空间，并记住上次选择；目标盘断开时不会自动改装到内置盘。

下载期间显示进度和速度，校验完成后才能启动。游戏详情中的 **卸载游戏** 需确认后才执行，不额外清理存档、配置或云数据。卸载前请连接磁盘并退出游戏。

不会自动搬迁已有游戏。Steam 可能校验、更新或下载 Windows 版本需要的文件；不要让多个客户端同时写入同一库。真实磁盘拔插、所有文件系统和 Steam 版本组合尚未全面验证。
