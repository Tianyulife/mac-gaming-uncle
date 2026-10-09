# 测试指南

## 自动化

```bash
scripts/check.sh
```

该命令运行 Wine 补丁校验测试、Swift 单元测试、Release 构建以及五个 Windows 测试程序的交叉编译。当前测试覆盖：

- 模型 JSON 往返、SemVer、SQLite 持久化；
- Ed25519 Manifest 验签、渲染器优先级、内核反作弊阻断；
- VDF、Steam AppManifest、PE 架构/DirectX/反作弊分析；
- 内置配方的加载和身份优先级；
- GPTK 下载监测、D3DMetal 缓存指纹与自动失效；
- Steam CEF 修复、登录状态解析、中文字体与 UE 参数顺序。
- Mac Gaming Uncle Wine 11 Manifest、本地运行时安装，以及 D3DMetal 原生库/PE Bridge 路径不会被 LaunchPlan 覆盖。

## Apple Silicon 硬件矩阵

在 M 系列真机上按顺序执行：

1. `indie-smoke-x64.exe`：验证 Rosetta、Wine 64 位、窗口和输入。
2. `indie-smoke-x86.exe`：验证新 WoW64 和 32 位窗口。
3. `indie-d3d11-fixture.exe`：先使用 DXMT，再验证 D3DMetal 与 WineD3D 回退。
4. `indie-d3d12-fixture.exe`：必须使用用户导入的 D3DMetal。
5. Steam：使用 Mac Gaming Uncle Wine 11 登录，扫描 `steamapps`，验证 AppID、名称、BuildID 和多库路径。
6. 一款用户拥有、无内核级反作弊的游戏持续运行 30 分钟，记录 Runtime、Renderer、系统版本和退出状态。

## 失败矩阵

必须验证：损坏哈希/签名、非 Apple GPTK、双层 DMG 中断、错误 DLL Overlay、磁盘不足、中文/空格路径、外置盘、Bottle 并发锁、Wine 非零退出、快照回退和离线启动。

正式发布不能要求 `sudo`、关闭 SIP/Gatekeeper，或对用户目录执行递归 quarantine 清除。

## 实验空间音频

补丁回放、双架构编译和空间对象/设备失效测试见 [SPATIAL_AUDIO.md](SPATIAL_AUDIO.md)。本机结果单独记录在 [SPATIAL_AUDIO_VALIDATION.md](SPATIAL_AUDIO_VALIDATION.md)。普通音频、D3DMetal、手柄和物理多声道仍分别验收。

### 完整运行时打包检查

`scripts/build-indie-wine11.sh` 在打包前生成 `build-info.json`（实际 macOS、SDK、编译器和构建脚本哈希）与 `package-audit.json`（必需文件、双架构 PE、x86_64 Mach-O、可重定位依赖与补丁哈希检查）。实际环境记录不替代 `source.lock.json` 的参考工具链，也不构成该工具链的复现声明。上游 Autoconf 要求构建目录不含空白；默认临时目录符合此要求，输出目录可含空格。

Wine 配置显式设置 `ac_cv_func_pipe2=no`，使用已有 `pipe`/`fcntl` 路径。SDK 27 提供的 `pipe2` 仅在 macOS 27 可用，不能仅凭新系统上的 configure 探测将其引入最低目标为 macOS 15 的制品。打包检查同时拒绝 ntdll 对 `_pipe2` 的导入；这不替代旧 macOS 真机测试。

解压后再次验证，确保验证的是最终制品：

```sh
python3 scripts/verify-wine-runtime.py /path/to/wine-runtime
INDIE_TEST_WINE_RUNTIME=/path/to/wine-runtime \
  swift test --jobs 4 --filter PackagedWineIntegrationTests
```

集成测试通过产品本地导入器安装到隔离目录，再通过 `WineRuntimeProvider` 初始化独立容器并执行命令。路径同时包含中文和空格；测试结束关闭对应 wineserver 并清理目录。未提供环境变量时明确跳过，不记为真实运行时通过。

已导入 GPTK 时，可额外验证产品 D3DMetal 启动链路：

```sh
INDIE_TEST_WINE_RUNTIME=/path/to/wine-runtime \
INDIE_TEST_D3DMETAL_ROOT=/path/to/imported/renderer \
INDIE_TEST_D3DMETAL_LOGS=/path/to/logs \
  swift test --jobs 4 --filter testPackagedRuntimeWithImportedD3DMetal
```

先编译下方 Windows 探针。测试使用独立容器，将探针复制到 C: 盘，再通过产品 Bridge 安装与 LaunchPlan 分别运行 D3D11、D3D12 的 120 帧测试，并核对实际加载导入的 `libd3dshared.dylib`。不修改 Steam 或游戏容器。

```sh
scripts/build-windows-fixtures.sh
python3 scripts/smoke-wine-runtime.py /path/to/wine-runtime \
  --output dist/runtime-smoke \
  --mmdevapi-tests /path/to/wine-build/dlls/mmdevapi/tests
```

冒烟脚本使用全新的临时 prefix，记录 32/64 位命令、窗口、内置 WineD3D D3D11、XInput 和可选双架构空间音频/普通音频测试。窗口测试会短暂显示窗口；`--smoke` 模式的 D3D11/12 探针须成功提交 120 帧，提前关闭不记为通过。XInput 返回“未连接手柄”单独记录，不能据此宣称实体手柄通过。脚本仅在该临时容器禁用附加组件，游戏默认配置不变。没有 D3DMetal 导入时不执行 D3D12，也不宣称 D3DMetal 通过。

## Wine 版本管理

在“高级设置 → 运行环境 → Wine 运行环境”核对“当前使用”和“正在运行”：前者为下次启动选择，后者根据该运行时目录内的真实进程检测，每两秒刷新。未手动选择时使用已安装的最新 Mac Gaming Uncle Wine；显式选择保留到下次打开应用，导入更高版本不会覆盖选择。普通本地 Wine 可以删除，但不作为 Mac Gaming Uncle 游戏引擎候选。

切换前退出游戏及 Windows Steam；有 Wine 进程时拒绝切换。删除需确认，当前选择或仍在运行的版本无法删除。删除仅将应用管理的运行时目录移到废纸篓，保留容器、游戏及原始导入来源。自动化检查覆盖显式选择、失效选择回退、外部目录/符号链接保护和运行中版本拒绝删除。

可使用 `MAC_GAMING_UNCLE_APP_DESTINATION=/absolute/path/Preview.app scripts/build-app.sh` 在独立目录构建开发应用，避免替换正在打开的应用包。

## Steam 获取与界面状态

商店输入停顿 350 ms 自动搜索，回车/按钮仍可立即搜索；每次改词或清空输入均使旧请求失效并取消请求。加载、短关键词、无匹配、连接失败分开显示。游戏库筛选无结果可一键恢复全部；首页不会用 Steam 会话状态推断云存档同步，也不默认宣称游戏兼容性优秀。

SteamLibraryReader actor 将本地文件解析移出主线程：下载清单最多每秒读取一次，账户/成就/库位置每五秒更新，手动刷新可强制更新。元数据缓存每个应用进程只加载一次，写入在后台执行；资料补全保留八个请求的并发上限，结束/取消时清理任务引用。失败按 10、20、40…秒重试，上限五分钟；手动刷新重置重试间隔。单个资料请求超时为 15 秒。

SteamRefreshPolicyTests 验证旧搜索响应与清空后的响应不能覆盖界面、无结果和错误分离、重试间隔与重置、扫描频率/强制刷新/根目录变化，以及下载完成在下一秒生效而无需等待完整账户扫描。网络及真实账户信息仍通过可选本机检查验证，不以合成数据测试替代 Steam 服务连通性。

## 展示检查

商店与游戏库工具栏在空间不足时拆成两行；游戏标题保留两行并可悬停查看完整名称。主页和商店横向列表提供按当前可见卡片数量翻页的左右按钮，到首尾禁用；触控板滚动和滚动条仍可使用。商店列表按游戏 ID 去重并展示全部条目，不再只展示前 20 项。检查宽窗口、最小窗口、长游戏名、翻页后继续滚动，以及过滤/切换分类后的翻页状态。
