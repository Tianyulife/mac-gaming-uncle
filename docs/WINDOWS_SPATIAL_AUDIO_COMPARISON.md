# Windows 空间音频与 Wine 对照：Split Fiction 卡顿定位

2026-10-09。结论分为已复现事实、实现缺口和待验证原因，避免把 API 尚未完成等同于本次根因。

## Windows 的生成与输出流程

游戏引擎为声音对象提供单声道 PCM 和位置/音量；静态对象对应固定扬声器方向，动态对象可以移动。ISpatialAudioClient 查询格式与对象容量，激活带 EventHandle 的空间流。Start 后系统以事件请求下一批数据；游戏在 BeginUpdatingAudioObjects / EndUpdatingAudioObjects 之间写各对象缓冲与位置。空间渲染器将这些对象混合/渲染为当前输出设备支持的声音。游戏提供空间内容，平台完成输出渲染；仅成功查询容量不代表实际提交了对象。

微软示例建议等待事件设置合理超时，例如 100 ms，并在端点/渲染类型改变后尝试 Reset。这说明持续事件、资源失效及重建行为同样是接口契约的一部分。

## 实现对照

| 环节 | Windows 文档约定 | 当前 Wine | 本次证据 |
| --- | --- | --- | --- |
| 客户端、格式、容量 | 查询当前端点空间能力 | 返回支持，最大动态对象 31 | 游戏查询成功 |
| 流激活与对象 | 静态通道及动态对象，带事件 | COM 对象、PCM/元数据传输已实现 | 游戏请求 mask 0x1ffe、最多 31 动态对象；内部 44 通道 |
| 更新与渲染 | 事件唤醒，Begin → GetBuffer/位置 → End | CoreAudio Spatial Mixer、环形缓冲与事件转发 | 首批 Begin/End 成功；尚需原生错误证据 |
| 时钟与音量服务 | GetService 支持 IAudioClock、IAudioClock2、IAudioStreamVolume | 一律 E_NOTIMPL | 有实现缺口，但已捕获日志未显示游戏调用 |
| 特定流可用性 | IsSpatialAudioStreamAvailable 查询指定流 | E_NOTIMPL | 有实现缺口，已捕获日志未显示游戏调用 |
| 扩展对象流 | HRTF/Metadata 等各有独立接口与要求 | 尚未实现这些流接口 | 未证明游戏请求这些接口 |
| 端点变化与失效 | 事件/通知、停止/复位/重建 | 原生监听、失效事件、动态容量丢失通知 | 游戏大量重复激活；需要区分真实设备改变与渲染故障 |

## 已隔离范围

同工具链对照 control.1 流畅；与空间版比较，1600 个 Wine 模块仅 CoreAudio Unix 模块与双架构 mmdevapi.dll 不同，图形模块及 wine/wineserver 相同。probeoff.1 保留新 CoreAudio，只拒绝空间客户端激活，用户确认画面流畅且声音正常；恢复支持的 trace.1 又卡顿/卡死。因此空间 API 成功激活后的路径是必要排查范围，已有证据不支持先改图形层。

trace2.1 的 256 条公共标记中，记录 16 次客户端创建、16 次空间流激活入口、15 次启动入口，均集中在同一游戏线程。未记录 GetService、QueryInterface、IsSpatialAudioStreamAvailable 或独立更新失败标记。更新成功只记录最初四条，是诊断版主动限流，不能据此断言后续停止更新。公共日志已耗尽，不能排除限额后的接口请求。

这种重复建流异常优先指向失效/重建循环或事件驱动的持续运行问题；目前还不是经过验证的根因。新增 native-trace.1 仅加入原生诊断，实时回调写原子错误值，事件线程输出错误/阶段，设备监听回调输出 selector，保留原始空间语义。

## 文档与源码

- [Microsoft：渲染空间音频对象与完整更新示例](https://learn.microsoft.com/en-us/windows/win32/coreaudio/render-spatial-sound-using-spatial-audio-objects)
- [Microsoft：GetService 必须提供的服务](https://learn.microsoft.com/en-us/windows/win32/api/spatialaudioclient/nf-spatialaudioclient-ispatialaudioobjectrenderstreambase-getservice)
- [Microsoft：BeginUpdatingAudioObjects](https://learn.microsoft.com/en-us/windows/win32/api/spatialaudioclient/nf-spatialaudioclient-ispatialaudioobjectrenderstreambase-beginupdatingaudioobjects)
- [Microsoft：IsSpatialAudioStreamAvailable](https://learn.microsoft.com/en-us/windows/win32/api/spatialaudioclient/nf-spatialaudioclient-ispatialaudioclient-isspatialaudiostreamavailable)

源码构建树 dlls/mmdevapi/spatialaudio.c：GetService、IsSpatialAudioStreamAvailable、Start/Begin/End、失效通知。dlls/winecoreaudio.drv/coreaudio.c：schedule_spatial_positions、ca_spatial_render_cb、设备监听、unix_timer_loop。诊断补丁和游戏证据位于 work/full-runtime/spatial-trace2、spatial-native-trace。构建源文件在诊断构建后恢复，原实验包不变。

## 单点候选：Begin 返回了剩余槽位而非渲染容量

微软 BeginUpdatingAudioObjects 文档将 availableDynamicObjectCount 定义为本轮可渲染的动态对象数量。当前代码返回 max_dynamic_objects - allocated_dynamic_objects，游戏分配满 31 个对象后该值变为 0。此前测试也把满分配后的 0 固化为预期，不能独立证明 Windows 契约正确。

11.0.8-capacity.1 仅将 Begin 的动态数量改为 max_dynamic_objects；GetAvailableDynamicObjectCount 的分配余额及对象分配上限均不变，保留 trace2/native 诊断。修订对应测试断言为满分配时仍有渲染容量，不改变其余检查。

游戏日志确认 allocated=31、capacity=31、frames=512，32 条独立限流标记显示持续更新。目前该启动仅创建一个空间流，之前的重复建流现象消失；未记录原生失效/设备变化。这为容量语义导致重建循环提供强支持，但画面卡顿是否完全恢复仍待用户同场景确认，尚不宣布最终修复。

容量版 x64 空间测试执行 2998 项、0 失败、0 跳过、2 todo，48 个 Mach-O 包装审计通过。x86 测试在进入测试之前失败：新建独立测试 prefix 缺少 syswow64/kernel32.dll（c0000135），不能记为通过或解释为容量实现回归；需先修复测试 prefix 再补跑。

2026-10-10 用户确认容量单点对照在同一场景“画面流畅、操作和声音正常”。结合保留空间支持、只改变 Begin 动态数量语义、重复建流消失，可将本次卡顿/卡死归因于渲染容量被错误返回为未分配槽位数量。正式 0004 COM 补丁和 0006 测试已修订，source.lock.json 哈希更新，完整空间补丁组零 fuzz 重应用通过。其他缺失服务接口仍是实现后续工作，不是此次已验证原因。32 位独立测试 prefix 问题另行修复，当前只确认容量版 64 位完整测试通过。本结果不替代空间听感、设备拔插及长时压力验收。

## 服务补齐（2026-10-10）

新增正式 0007 补丁：空间流 GetService 提供音频时钟、设备时钟和流音量，并保留空间流及失效状态；CoreAudio 设备位置查询实现端点帧时间线/QPC 关联。补上基础流可用性查询，未支持的流类型返回不可用。音量按渲染输入 transport 声道控制，实际 Windows 的空间流服务声道映射仍待参考机核对。HRTF/Metadata 流仍未实现，不由本次服务补齐推断其支持。

11.0.9-services.1 包含此前动态容量修复及本次服务实现，不含诊断日志插桩。双架构各 3090 项、0 失败、0 跳过、2 既有 todo；48 个 Mach-O 审计通过，更新后的补丁零 fuzz 应用且源码与实测构建源完全一致。原先 x86 测试环境问题已用显式 WoW64 独立 prefix 修复。随后用户确认服务版在 7.1.4（12 声道、48 kHz）输出的同一游戏场景中“画面流畅、操作和声音正常”；真实游戏短测通过，实体方向听感、设备拔插/睡眠恢复和长时压力仍待验收。
