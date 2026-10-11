# Universal frame interpolation — experimental, opt-in

Included in the 0.4.0 research preview. The application exposes 2× only, off by
default. Internal 4×/static-detail laboratory APIs are not enabled by the UI.

## Scope

- macOS 26+, Apple Silicon, one active game window, SDR, 2× only.
- Per-game opt-in persisted in GameConfiguration; missing legacy value means off.
- Game Settings → Universal Frame Interpolation → Open panel. Enable automatic
  following once. Authorize screen capture explicitly if necessary, then start the
  game normally. Full executable path + PID + process start time identify a run;
  title text is not used to identify the game. Multiple matching processes are
  considered ambiguous and do not trigger capture.
- The foreground game's largest eligible window must have stable dimensions in two
  consecutive one-second observations. Capture still waits for valid moving frames.
  Switching away tears down the stream/overlay; returning rechecks and restarts.
  A rebuilt window or changed dimensions are matched again. Static frames reveal the
  original without forcing a restart. Unsupported windows fail once, not every poll.
- Manual Stop or the emergency key suppresses automatic restart for currently
  observed game runs, including focus changes and window rebuilds. A new PID/start-time
  identity resets suppression. The panel's Rearm button explicitly clears suppression.
- Closing the interpolation panel does not stop automatic following. Disabling its
  saved preference removes that game's watcher. Application quit cancels all watchers.
- First screen-capture authorization is user-controlled; no microphone permission,
  audio capture, recording to disk, DLL injection, Wine/DPI change or input remapping.
- Control + Option + Command + F12 is a globally registered emergency stop. Switching
  away, target closure/minimization/resizing, display changes or
  watchdog expiry removes the overlay. The original game remains untouched.
- Exclusive fullscreen is outside the supported first-version scope.

## Pipeline

SCStream (target window only, no cursor/audio, 30 FPS ceiling and capped processing size) →
bounded owned IOSurface pool → single-slot newest-frame stream → private-queue exact
duplicate and sampled scene-cut checks → VideoToolbox frame processor → bounded
original/interpolated pairs → CAMetalDisplayLink → MetalFX Spatial upscale →
nonactivating, mouse-through CAMetalLayer overlay at the original window bounds.

Model preparation and conversion/inference run on a private queue. Only one request
can be in flight. The independent UI watchdog can remove the overlay even if the
processor stalls. The UI explicitly states the 1280×720 processing budget and reports
both processing and physical output dimensions. Alignment rounds dimensions down to
multiples of 16, preserving the padded backend pixel budget. The game's resolution,
DPI and window bounds are not changed. Backend errors retain the original image.

Presentation queues at most four images (two pairs), with two GPU submissions in
flight. A smoothed host-clock schedule absorbs completion jitter, bounds additional
queue latency to 100 ms, and resets on late pairs. Sustained inference overruns trigger
a one-second cooldown showing the original game. The clock also reserves the display
link's predicted presentation lead; treating its target time as the current time
coalesced generated frames in the real-game test. Isolated late pairs are dropped
without hiding/showing the overlay. Starvation reveals the original within 150 ms.
The scheduling callback requests the
screen's maximum refresh rate (capped at 120); repeated refreshes reuse the cached
upscaled texture. Actual OS refresh selection can differ. Overflow clears the
old timeline before restarting, rather than accumulating delayed frames.

Capture buffers MUST NOT be retained by the display queue: doing so exhausted the
ScreenCaptureKit surface pool in the initial prototype. The corrected implementation
transfers to a private pool limited to 8 buffers before releasing the capture frame.
The stream queue remains depth 3 with bufferingNewest(1).

Frame submission counts are not measured monitor FPS or engine simulation FPS.
Additional original/generated presentation counters use drawable.presentedTime;
interval percentiles cover the latest 600 distinct frame presentations. Repeated
refreshes are counted separately. These callbacks measure compositor presentations,
not game simulation speed, input latency, or a photodiode measurement of the panel.
Capture lacks engine motion/depth/UI buffers; HUD artifacts and added latency remain
possible. Scene-cut detection is heuristic; duplicate rejection compares full pixels.
Repeated capture images leave the last distinct image and queued pairs intact; the
watchdog handles sustained stillness. A stall is timed from the current processing
request, not the last displayed image, avoiding false failures on resuming motion.

Wine's tested borderless window uses window layer 26. Manual and automatic selection
accept layers 0 and 26, still restricting automatic selection to the known process.
The translucent, nonactivating overlay sits immediately above that target and can
join another application's full-screen Space. Focus and visibility protection remain.

Release 0.6.1 (build 11) hides and pauses output as soon as
the exact target window is reported offscreen, retaining the processor for at most
one second. Returning within that period requires fresh work; visibility epochs
discard analysis/inference crossing the gap. Missing windows, size changes, process
exit, focus changes and display topology changes still stop the session. Automatic
following delegates a missing on-screen candidate to the active stream's watchdog
when the same process remains foreground and capture permission is valid. It cannot
bypass the one-second bound. Stopped diagnostics retain the final counters, stop
kind/status and last observed window size, layer and onscreen state.

Four offline regressions cover brief visibility recovery, stale in-flight results,
the fixed timeout, repeated gaps and invalid clocks. These changes are compiled in
the source checkout and developer fixtures and included in release 0.6.1. The
installed 0.6.0 build 10 was retained during testing. Clean end-to-end gameplay
acceptance remains pending.
The later fixed-scene probe below records over five minutes of sustained output,
but ends in a visibility interruption after that measurement window; its exit
status remains a failure rather than being relabeled as a clean probe pass.

A second independent watchdog checks distinct drawable presentations while fresh
output is expected, rather than trusting generated/submitted counts. Zero initial
presentations expire after two seconds; a previously working display with no new
distinct presentations expires after one second. Static scenes and hidden overlays
reset that observation period. Four regressions cover initial/running timeout,
progress, static scenes and invalid clocks. The running status requires actual
presentation evidence. Diagnostic snapshots also include the overlay's window ID,
level, geometry, on-screen flag and AppKit occlusion visibility.

## Local game evidence: M3 Max / macOS 26.6.2, 2026-10-11

Black Myth Wukong, existing DX12 + MetalFX run, game-internal frame generation off.
Capture processing was 1104×720, with a 3024×1964 overlay output. No game resolution
or Wine DPI changes were made by these interpolation tests. The following rates count
drawable presentation callbacks after discarding the first five snapshots. They are
not game-engine FPS or a measurement of physical panel refreshes.

| Trial | Evidence | Result |
| --- | --- | --- |
| Capture only, 20 seconds | 29.91 sampled changing images/s, no overlay | Baseline for the capture path |
| Initial game overlay | Generated images, zero drawable presentations | Failed: floating level 3 was below game layer 26 |
| Layer/visibility/watchdog fixes, 60 seconds | 13.89 presentation callbacks/s, P95 interval 63.61 ms | Failed pacing; zero capture-copy failures |
| 30 FPS capture and fewer hide/show transitions, 60 seconds | 36.04 callbacks/s, P95 interval 56.41 ms | Improved, still irregular |
| Predicted presentation lead included, 60 seconds | 54.42 callbacks/s, P95 interval 31.25 ms, P99 40.98 ms; processing P95 12.25 ms | 1,659 original / 1,643 generated presentations; zero copy failures and renderer backpressure |
| Attempted 300-second probe | 70 active snapshots, processing P95 12.39 ms, zero copy failures | Interrupted by target visibility change; not a completed five-minute acceptance test |

The prediction lead observed at the end of the successful one-minute trial was
41.53 ms. Its 3,436 submitted images and 3,302 presented images are different
counters; neither alone establishes game FPS. Occasional long intervals and image
quality/input latency in combat remain unverified. Local build 10 contains these fixes,
is a development build, and is not a published release. The installed application's
screen-capture permission must be granted independently of the developer probe.

Further debugging on 2026-10-11 confirmed the installed build 10's capture permission
after the user enabled it, and observed both original and generated presentations in
the main application. The installed app also reproduced a visibility/geometry stop.
One isolated 60-second probe stayed active and generated 1,761 frames but recorded
zero original/generated presentations, 516 renderer backpressure events and zero
capture-copy failures. This is a failed display test, not a throughput success.
A subsequent 12-second probe with additional overlay telemetry recorded 312 original
and 305 generated presentations, processing P95 12.12 ms, interval P95 33.33 ms.
Its overlay was visible/on-screen at level 27 above the game's level 26, with the
game foreground and unchanged 1512×982 logical / 3024×1964 physical dimensions.
The difference between those runs remains unexplained; metadata instrumentation
alone is not evidence of a fix. The independent presentation watchdog addresses the
unbounded false-running state while this intermittent display problem is investigated.
An attempted follow-up long run stopped at approximately 10 seconds while the
overlay's x coordinate moved to -1574 and target onscreen state disappeared. The
user confirmed switching desktops/other applications during that run. This is an
expected lifetime interruption, not evidence of a crash, thermal slowdown or a
failed five-minute foreground run.

A repeat fixed-scene probe produced uninterrupted original/generated presentations
through 302.98 seconds, with the target foreground and both target/overlay on-screen.
At 304.04 seconds the overlay moved left; by 305.11 it was hidden and the target's
on-screen flag was absent. At 306.27 the bounded visibility watchdog stopped the
session with a transient reason. The user confirmed switching applications at the
end of this run. The old fixture requested
300 one-second samples rather than a monotonic 300-second deadline, so per-sample
work extended the wall-clock run. The fixture now uses ContinuousClock and a fixed
deadline. The interrupted run contains 291 snapshots and exits 2; it is not a clean
fixture acceptance pass.

The first 300 seconds nevertheless provide a sustained foreground observation.
After excluding the first five snapshots, 292.72 measured seconds averaged 52.30
distinct drawable presentation callbacks/s. Per-minute rates were 50.73, 51.68,
51.63, 53.82 and 53.53 callbacks/s, with no progressive decline. The last snapshot
before 300 seconds recorded 7,839 original and 7,754 generated presentations,
zero capture-copy failures, zero renderer backpressure, 598 deadline drops and 374
presentation skips. Processing P95 was 14.53 ms; recent presentation interval P95
was 33.33 ms and P99 41.67 ms. Uneven intervals remain; these numbers do not prove
a stable 60 FPS display or higher engine FPS. The capture ceiling remains 30 FPS.

Thirteen game resource samples over 240 seconds showed RSS about 9.01 GiB, spanning
only 5.2 MiB, and CPU readings 417–576% (multi-core units). pmset recorded no thermal
or performance warning. Neither those readings nor stable presentation throughput
exclude GPU frequency changes: this run did not record GPU clock or temperature.
The user reported 40 FPS in the game HUD and a somewhat better experience. That
HUD reading is the underlying game rate, while the overlay callbacks above measure
the separate presentation path. HUD artifacts, input latency and combat behavior
were not specifically assessed. The complete regression run after these changes executed 138 tests,
with four skipped and no failures. An earlier concurrent-game run timed out once in
the existing Wine helper recovery test; its isolated rerun and the final full run
passed. The installed 0.6.0 build 10 remains unchanged; this probe used the source revision included in 0.6.1 in a separate helper,
which has now exited.

## Local evidence: M3 Max / macOS 26.6.2, 2026-09-07

- Synthetic processor probe: 1280×720 produced six intermediate frames, roughly
  9–14 ms per request after initialization.
- 1920×1080 generation failed with VTFrameProcessorErrorDomain -19730,
  "Processor is not initialized". A non-nil configuration and isSupported=true do
  NOT establish resolution support. No claim of working 1080p on this machine.
- End-to-end moving-window capture: after buffer-ownership fix, a 12-second test
  stayed active, generated 359 frames and submitted 716 original/intermediate
  frames, with 2 expired frames. These are submission counts, not measured display FPS.
- Mouse-through test incremented the underlying window's click counter.
- System Events hotkey test stopped interpolation while the target remained active.
- Initial stalls triggered fallback safely. No game settings were modified by tests.

Fixtures: FrameInterpolationProbe.swift, InterpolationPattern.swift,
InterpolationCaptureProbe.swift. Unit tests cover admission timing, invalid/repeated
timestamps, scene cuts, legacy/default-off preference persistence, automatic following
state transitions, run-scoped manual suppression and process identity parsing.

## Remaining acceptance

Real game quality/latency, sustained operation and multi-display movement require
further testing. Processing size is capped independently of the game's window size;
never force existing games to 720p from this module. First
rollout stays experimental, opt-in, and is not a promise to support every game.

## Reproducible local probes

`scripts/build-interpolation-fixtures.sh` builds the production capture, processing
and presentation sources into an isolated probe plus a moving-window target. It does
not modify a game or its saved configuration. Launch `dist/interpolation-fixtures/InterpolationPattern`,
then run `dist/interpolation-fixtures/InterpolationCaptureProbe --duration 30 --output /tmp/interpolation.json`.
Keep the target foreground; changing focus is an expected transient stop. `--list`
lists visible eligible windows; `--window <window-id>` selects a real game for a
separate test. Stop game-internal frame generation before evaluating this overlay.
`--list --pid <game-pid>` also lists that process's offscreen windows and their layers.
`InterpolationBaselineProbe --window <window-id> --duration 20 --output /tmp/baseline.json`
captures without generation or an overlay; its sampled changing-image counter is not
engine FPS. Run baseline and interpolation probes separately, with no builds running.
Output JSON records one snapshot per second; success requires both original and
generated drawable presentations. A generation/submission count alone does not pass.
`--duration` uses a monotonic elapsed-time deadline, not a target snapshot count.

References / prior art:

- https://developer.apple.com/documentation/videotoolbox/vtlowlatencyframeinterpolationconfiguration
- https://developer.apple.com/videos/play/wwdc2022/10155/ — IOSurface pool lifetime
- https://github.com/Lospi/MetalDuck — public architecture reference, not bundled
