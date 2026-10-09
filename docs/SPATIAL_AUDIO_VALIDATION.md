# 空间音频移植验证记录

日期：2026-10-09（Asia/Shanghai）。这是本地移植的结果，不引用上游成绩作为本项目成绩。

## 最新结果：完整实验制品与产品导入

包含 FreeType、GMP、Nettle、GnuTLS、libinotify-kqueue、SDL2 的完整 `11.0.3-spatial.2` 已构建并打包。最终压缩包为 `indie-wine-11.0.3-spatial.2-macos-x86_64.tar.xz`，47,004,056 字节，SHA-256 `b2a970c8484884130325e967f8bd230708374910add5fdc5ee52585d1d640474`。开发应用包 `Mac-Gaming-Uncle-spatial-test.zip` 的 SHA-256 为 `56bf9f2cecdd7c2ed93d6611dcedf729d0e6334e3b935b6b639a3904957961b2`，ad-hoc 签名校验通过，未公证或发布。

实际环境仍为 Xcode/SDK 27 与 MinGW GCC 16.1，不是参考工具链复现。制品内 `build-info.json` 保存实际环境及构建脚本哈希，`package-audit.json` 保存打包检查。从最终压缩包重新解压后的 38 个原生模块、双架构关键 PE、补丁哈希及可重定位依赖检查均通过。

本轮修复两项构建问题：上游 Autoconf 不支持含空白的构建目录，入口现提前拒绝；旧 zsh 动态库路径拆分将多条依赖合并，导致 GnuTLS/Nettle 引用构建目录，现逐行正确改写。另设置 `ac_cv_func_pipe2=no`，使用已有 pipe/fcntl 路径，避免 SDK 27 将仅 macOS 27 可用的 pipe2 引入最低目标为 macOS 15 的 ntdll；最终 ntdll 不导入该符号。旧 macOS 真机兼容仍未验证。

界面通用 Wine 导入器现在识别本项目源码锁定标记，转交完整构建导入器，保留游戏引擎身份及 `11.0.3-spatial.2` 版本。真实制品通过该路径安装到中文、空格路径，再由产品 WineRuntimeProvider 初始化独立容器并执行 cmd，集成测试通过。新增逐游戏空间音频诊断日志开关，默认关闭；开启后诊断环境经游戏 LaunchPlan 传递到 Steam 启动链路，保留 D3DMetal 库路径。

| 最终解压制品检查 | 结果 |
| --- | --- |
| wineboot / x64、x86 cmd | 通过 |
| x64、x86 窗口自动退出探针 | 通过；不等同于中文字体视觉验收 |
| 内置 WineD3D D3D11 | 120 帧提交通过 |
| GPTK 4.0b2 D3DMetal D3D11 / D3D12 | 产品导入、Bridge 与 LaunchPlan 链路通过；各提交 120 帧，dyld 日志确认导入的 libd3dshared 与 D3DMetal.framework 已加载 |
| x86_64 spatialaudio | 2998 检查，0 失败，0 跳过，2 todo |
| i386 spatialaudio | 2998 检查，0 失败，0 跳过，2 todo |
| x86_64 render | 4440 检查，0 失败，2 跳过，177 todo |
| x86_64 mmdevenum / propstore | 72 / 241 检查，0 失败；propstore 保留 14 todo |
| XInput | 未连接实体手柄，不能作为实体输入通过 |

默认输出查询仍为虚拟 `Dolby_5.1.2`，8 声道及顶中坐标保留。测试使用新的临时容器，未改变 macOS 默认输出；临时容器禁用附加组件的设置不进入产品游戏默认配置。mmdevapi 测试程序由本次完整源码树重新编译。最终 Swift 检查为 98 项测试、0 失败、4 跳过（两项需要真实包/GPTK 的集成测试已独立实跑通过）；补丁测试 7 项、Release 构建及五个 Windows 探针编译通过。

结构化证据见 [spatial-runtime-20261009.json](validation/spatial-runtime-20261009.json)，原始运行日志保留在工作区 `work/full-runtime`。后续 D3DMetal 实跑测试在独立容器完成；日志含 Vulkan 未编译和 Apple Neural Engine Code 26 提示，但两个探针均成功完成，不能据此推导复杂游戏兼容。用户本机已安装实验引擎和 GPTK 4.0b2，Steam 已更新到官方登录界面。下一步测试《双影奇境》及当前默认设备，按 [游戏验收指南](SPLIT_FICTION_VALIDATION.md)记录。真实游戏、实体扬声器方向、一小时压力和设备事件仍未完成；默认下载仍为 11.0.2。

## 最新结果：CoreAudio 原生设备布局适配

本轮修改修复了下面历史记录中的默认 8 声道限制。补丁 `0005` 和锁定哈希已更新；构建版本为 `11.0.3-spatial.2`。本轮未重新运行无改动的 Swift 应用测试。

原生查询得到默认端点 `Dolby_5.1.2`（设备 ID 145，transport `virt`），8 个描述按设备顺序为：Left、Right、Center、LFE、LeftSurround、RightSurround、LeftTopMiddle、RightTopMiddle。顶部标签为 49/51，设备提供球面坐标 [-90,45,1] / [90,45,1]。保留这些原生描述，不再要求物理输出可表示为 Windows speaker mask。

| 本轮测试 | 检查数 | 失败 | 跳过 | todo |
| --- | ---: | ---: | ---: | ---: |
| x86_64 spatialaudio，Dolby_5.1.2 | 2998 | 0 | 0 | 2 |
| i386 spatialaudio，Dolby_5.1.2 | 2998 | 0 | 0 | 2 |
| x86_64 spatialaudio，内建立体声 | 2998 | 0 | 0 | 2 |
| i386 spatialaudio，内建立体声 | 2998 | 0 | 0 | 2 |
| x86_64 render，默认 8 声道设备 | 4440 | 0 | 2 | 177 |
| x86_64 mmdevenum | 72 | 0 | 0 | 0 |
| x86_64 propstore | 241 | 0 | 0 | 14 |

诊断 trace 确认：Spatial Mixer 使用 2 声道输入床、31 个 PointSources、8 个输出声道，输出类型 3、算法 7。最终 profile 66 个样本，p50=379541 ns、p95=484417 ns、p99=527333 ns，underrun/overrun/reentrant reject 均为 0。callback allocations=0 是源码路径属性，未运行分配探测器。

六个最终补丁在原始归档文件上重新应用成功（零 fuzz、零 offset），音频源码与实际编译文件逐字节一致。补丁管理测试 7 项通过，CoreAudio Clang 静态分析无报告，源码及仓库 diff 检查通过。编译无新增警告。原生布局辅助测试直接编译本次 Wine 的布局函数，设备属性用夹具，AudioFormat 展开用 Apple 真实框架；验证顶中标签、声道重排后的 dry 路由、坐标保留与变化身份、非法尺寸、实际声道数不符、未知/离散标签拒绝、tag/bitmap 展开，以及严格核对实际通道的双声道回退。

发现并修复了回归：内建设备提供含无效标签的首选布局。单/双声道允许原有格式回退并核对 StreamConfiguration；多声道仍拒绝猜测。最终两种设备、双架构测试均通过。仅临时 prefix 的 DefaultOutput 用于双声道回归，测试后已删除；macOS 默认设备未修改。

布局身份包含全部标签、flags、坐标和顺序；添加 PreferredChannelLayout 属性监听，布局改变时旧流失效。未主动改变系统设备布局以测试真实硬件事件。没有进行声学方向确认、多个物理设备间时钟/延迟测试、真实游戏或完整签名发行包验证。`Dolby_5.1.2` 端点暴露的虚拟布局已验证，不能等同于全部实体扬声器已验证。

## 源码与构建

- Mac Gaming Uncle 基线：`1c65c3c527a43cb9ea3c0763acf2d4d8aa9e3a6c`。
- 来源分支固定为 `ba57a08921dfe8f3a4281692b040cd2fa5acd94e`，提交清单与前置修复见 `source.lock.json`。
- CrossOver 26.3.0 归档 SHA-256：`ac99c8ca4b3848f3e81784135f023df266b61c2345726ea55a50b3e030dd6872`，已校验。
- 全部六个补丁在重新提取的原始文件上按锁定顺序应用成功，`--fuzz=0`；没有偏移或模糊匹配。11 个音频文件与实际编译源码逐字节一致。
- COM、CoreAudio 与空间音频测试程序的 i386/x86_64 PE 编译通过；CoreAudio Unix 模块为 x86_64。
- 诊断 Wine 的全部运行时目标构建通过，`wine --version` 返回 `wine-11.0`。

测试机：Apple M4、macOS 27.0.1 (26A434)。实际工具链为 Xcode 27.0、Apple Clang 21.0.0、SDK 27.0、MinGW GCC 16.1.0。

本机工具链与锁定文件声明的 Xcode 26.6/GCC 15.1 不同，不能当作那套工具链的复现。诊断构建采用 new WoW64、i386/x86_64，原生模块最低部署目标 15.0；为了聚焦音频，未启用 FreeType、GnuTLS、SDL、Vulkan 等可选依赖。未执行完整依赖打包、签名或发布，因此它不是供游戏使用的完整运行时制品。

基线 ntdll 在 SDK 27 下存在 `pipe2` 最低系统版本警告；本次没有修改这些无关代码。

## 自动化与静态分析

- `python3 scripts/test-wine11-patches.py`：7 项通过。覆盖真实补丁应用、重复应用拒绝、清单顺序、未知补丁、重复条目、路径穿越和哈希不匹配。
- `swift test --jobs 4`：96 项、0 失败，2 项跳过（选择性网络/Apple 签名集成与本机 Steam 缓存读取）。
- `zsh -n`：构建脚本与检查脚本通过。
- `git diff --check`：通过。
- Clang 静态分析：CoreAudio 与最终 `spatialaudio.c` 没有报告；通用 `client.c` 的 QueryInterface 路径报告一个空指针警告，未修改的 CrossOver 基线也报告同一问题。未声称整个基线没有问题。

## 首次移植的本机运行时测试（历史记录）

采用独立临时 prefix，未使用游戏容器。首次默认初始化在 180 秒时超时；诊断容器设置 `WINEDLLOVERRIDES=mscoree,mshtml,winemenubuilder.exe=d` 后完成初始化。这只用于隔离无关附加组件，不进入产品默认配置。

| 测试与设备 | 检查数 | 失败 | 跳过 | todo | 结果 |
| --- | ---: | ---: | ---: | ---: | --- |
| x86_64 spatialaudio，内建立体声 | 2998 | 0 | 0 | 2 | 通过 |
| i386 spatialaudio，内建立体声 | 2998 | 0 | 0 | 2 | 通过 |
| x86_64 render，系统默认设备 | 4440 | 0 | 2 | 177 | 通过，带已标注限制 |
| x86_64 mmdevenum | 72 | 0 | 0 | 0 | 通过 |
| x86_64 propstore | 241 | 0 | 0 | 14 | 通过，带已标注 todo |
| x86_64/i386 spatialaudio，系统默认 8 声道设备 | 各 86 | 各 9 | 0 | 各 1 | 布局不受支持；不能作为通过 |

默认设备的布局包含 `LeftTopMiddle` / `RightTopMiddle`（49/51），首次移植的映射无法在 WAVE mask 中准确表达。能力查询返回 `AUDCLNT_E_UNSUPPORTED_FORMAT`，测试由此报告失败。保留失败记录，未通过猜测映射或关闭检查来让测试变绿。

为验证对象实现，仅在临时 Wine prefix 的 `HKCU\Software\Wine\Drivers\winecoreaudio.drv` 设置 `DefaultOutput` 为内建立体声端点；没有修改 macOS 的默认音频设备。之后双架构的完整聚焦测试均通过，包括动态对象耗尽/复用、位置、音量、结束、Reset、最大对象持续提交、预 Start 失效、后端失效转发和回调重入释放。实际听感与真实多声道仍未验证。

`render` 的两项跳过与已有 todo 保留，未将它描述为无条件完整 WASAPI 兼容。未运行可能要求麦克风权限的 capture 测试。

## 短时性能记录

内建立体声端点使用 48 kHz、512 帧周期（10.6667 ms），实际报告 31 个动态对象。带诊断开关的 x86_64 聚焦测试再次通过 2998 项、0 失败、0 跳过、2 todo。

最大 31 对象路径采样 66 次：回调 p50 338166 ns、p95 434125 ns、p99 454125 ns；该短窗口内 underrun/overrun/重入拒绝均为 0。接口报告的流延迟为 167292 个 100 ns 单位（16.7292 ms），不是声学端到端实测延迟。回调分配计数是代码路径声明，未由 Allocations 验证。

短时数据仅用于证明本机渲染路径确实工作，不能推导一小时稳定性或所有硬件性能。

## 真实游戏回归发现

《双影奇境》在新 11.0.3-spatial.2 下严重卡顿并卡住，关闭 MetalFX、Metal 4 和音频诊断后仍复现。切回既有 11.0.2、保持基础配置，用户确认完全正常。实验包已暂时移出活动运行时目录。该结果阻止实验运行时推广；探针通过不代表真实游戏验收通过。回归可能来自空间音频补丁、构建工具链或其他运行时差异，需同源码/工具链的无补丁对照进一步定位。

## 尚未验收

- Xcode 26.6/GCC 15.1 参考工具链复现；完整依赖打包已在本轮实际工具链下完成。
- 真实游戏是否提交空间对象以及听感/坐标准确性。
- 物理 USB/HDMI 多声道输出、耳机、蓝牙、拔插、睡眠与采样率切换。
- 一小时压力测试、内存和线程 sanitizer、实测端到端声学延迟。
- D3DMetal 真实游戏与实体手柄的本机回归；D3D11/12 探针已通过，完整实验包已包含 SDL2，XInput 探针未检出连接的实体手柄。
- 应用默认发布制品更新；其下载地址和哈希仍对应既有 11.0.2。

源码移植与编译通过，不等于以上硬件、游戏或发布要求全部通过。

2026-10-10 用户调整默认输出为 7.1.4 后重新读取 CoreAudio：设备仍名 Dolby_5.1.2，实际输出已为 12 声道/48 kHz，具备前/中/低频/侧/后与四个顶部方向标签，顺序按原生布局保留。服务版 11.0.9-services.1 在此输出上执行 x64 空间套件 3090 项、0 失败、0 跳过、2 既有 todo。确认 7.1.4 端点渲染路径通过，不将其等同于实体扬声器方向听感验收。证据：work/full-runtime/spatial-services/output-layout-7.1.4.txt 和 spatial-7.1.4-x64.log。

2026-10-10 用户确认 11.0.9-services.1 在 7.1.4（12 声道、48 kHz）输出下，同一场景“画面流畅、操作和声音正常”。本轮真实游戏短测验收通过，新增时钟/音量服务未在该场景引入已观察到的回归。此结论不替代实体扬声器方向、设备拔插/睡眠恢复及长时压力验收，也不证明游戏已调用每一个新增服务接口。
