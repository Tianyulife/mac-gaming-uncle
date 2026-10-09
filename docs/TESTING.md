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
