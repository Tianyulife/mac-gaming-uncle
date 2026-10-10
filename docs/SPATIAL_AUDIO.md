# Windows spatial audio port (experimental)

This patch set adds Windows Spatial Audio object rendering to the existing
CrossOver FOSS Wine build. Games must actually use `ISpatialAudioClient` and
`ISpatialAudioObjectRenderStream` to supply dynamic objects. Ordinary stereo
mixes do not acquire object metadata through this change. There is no Dolby
Atmos bitstream output or head-tracking capability claim.

## Provenance and scope

- Destination repository baseline: `enginefuture/mac-gaming-uncle@1c65c3c527a43cb9ea3c0763acf2d4d8aa9e3a6c`.
- Wine source: the CrossOver 26.3.0 FOSS archive locked in
  `runtime/indie-wine11/source.lock.json`, after existing patches 0001–0003.
- Donor: [Switchyard Wine](https://github.com/jungwuk-ryu/switchyard-wine/tree/codex/macos-fex-pro-review-20261005),
  exact revision `ba57a08921dfe8f3a4281692b040cd2fa5acd94e`.
- Spatial implementation commits:
  `4694d9dff307277abc5f27e68a80941898d0347d`,
  `33905f4e445eb90abc1615714e9cfbeda2bb4dbf`,
  `9806392a89eb5176a51f8d2fac68423d3634e322`,
  `71fd097e6119c1076b67b2b7462edfa4441f2980`,
  `db0f01e161e4abda59d574ad8ff5a991b0e4b075`.
- Required upstream spatial prerequisites: object format decoupling
  `e237972495de7a70aef6587f332236292d69fa22` (Giovanni Mascellani) and
  stream Reset `d39f7c2e8958c0735d10074985ac81698b8dd023` (Paul Gofman).
- Original implementation author: jungwuk-ryu. The port retains Wine's
  LGPL-2.1-or-later notices. No FEX, native-gate SDK, ARM64EC translation,
  Switchyard application code or proprietary CrossOver payload is included.

The donor documentation and its measurements are references, not test results
for this port. The build packages the exact patch files and this provenance
notice alongside `source.lock.json`.

## Patch layout

| Patch | Content |
| --- | --- |
| 0004-spatial-audio-com.patch | COM contracts, static/dynamic object lifecycle, capacity/invalidation, audio-client helpers, shared Unix transport and non-CoreAudio ABI adapters |
| 0005-spatial-audio-coreaudio.patch | Spatial Mixer bed/point-source graph, physical output mapping, device timing/capability validation, synchronized PCM/metadata, real-time event relay and teardown |
| 0006-spatial-audio-tests.patch | Object/activation/reset/lifetime/invalidation tests and actual engine-period assertion |

Apply all patches in the locked order. The shared Unix ABI changes require the
client, CoreAudio and other driver call tables to be rebuilt together; do not
replace just `spatialaudio.c` or install just one rebuilt DLL.

ALSA, OSS and PulseAudio do not gain spatial rendering. Their private transport
rejection, pointer conversions and function tables are updated to match the
shared ABI, including new WoW64 calls.

## CrossOver adaptations

CrossOver 26.3.0 creates its audio timer through a PE `CreateThread` plus the
existing Unix `timer_loop` entry. The donor uses `PsCreateSystemThread`, which
this baseline does not export. This port keeps the PE-owned lifecycle:

1. Create the graph and its preallocated coalescing Mach semaphore.
2. Before publishing spatial activation, create the PE timer thread in
   `stream_init`; it runs the existing Unix call with the stream handle.
3. Spatial timer calls wait on the semaphore and relay endpoint-loss/audio
   events; normal timer calls retain the existing periodic behavior.
4. Events before relay startup remain pending in the semaphore. Initialization
   failures release the unpublished stream and join any created relay.
5. Teardown detaches/drains device listeners, signals and joins the PE relay,
   stops/drains audio callbacks, then disposes units/buffers/handles.

The object format stays mono float at 48 kHz rather than being replaced by
a physical endpoint's closest channel format. CoreAudio performs the output
conversion.

CrossOver's HALOutput path and AppKit/AVFoundation links are preserved. The
Spatial Mixer needs `-fblocks` for device property listeners. This port does
not import Switchyard's unrelated default-device migration code. Spatial
streams remain tied to the activated endpoint; callers must reacquire and
reactivate after invalidation.

## Native physical output layouts

The renderer queries CoreAudio's preferred output layout and expands tags or
bitmaps through AudioFormat into channel descriptions. It preserves labels,
flags, coordinates and physical channel order, including LeftTopMiddle and
RightTopMiddle. The Spatial Mixer output and HALOutput input both receive this
native layout. Windows masks remain input-bed representations and are not used
to encode the mixer's physical output. PCM/position frame synchronization and
the shared Unix ABI remain unchanged.

The reader checks description sizes, finite coordinates, a maximum of 64 output
channels, and agreement with actual output StreamConfiguration. Unknown, unused
or discrete channel labels cannot supply speaker directions. Mono/stereo may
fall back to an unambiguous existing mix format, but that fallback must still
match the actual output channel count; multichannel layouts are never guessed.
Non-spatial dry objects locate front-left/right or center in native channel
order. Devices without those named front channels are currently rejected.

Capability generations hash the complete normalized layout. Preferred-layout
changes are listened for when the property exists; failure to subscribe to an
existing property rejects dynamic capacity. Active streams are invalidated
rather than retargeted silently. Aggregate/virtual devices must expose their
intended speaker layout; aggregation alone cannot infer physical placement or
correct clock drift and inter-device delay.

The native helper test compiles the actual patched source helpers with mocked
device properties and Apple's real tag/bitmap expansion:

```sh
python3 scripts/test-coreaudio-layout.py /path/to/patched/wine/source
```

It exercises 5.1.2 top-middle labels, reordered front channels, coordinates and
layout identity, malformed sizes, channel-count mismatch, unknown/discrete
labels, tag/bitmap expansion, and verified stereo fallback.

## Build and test

The full runtime build uses seven hash-locked patches and emits
`11.0.9-services.1`, including the rendering-capacity fix and audio services,
to distinguish it from the previous `11.0.2` runtime:

```sh
scripts/build-indie-wine11.sh
```

The package records the actual toolchain in `build-info.json` independently of
the reference versions in `source.lock.json`. A packaging audit checks required
files, native/PE architectures, bundled dependency resolution and patch hashes
before the archive is emitted. Use a whitespace-free `INDIE_WINE_BUILD_ROOT`
when overriding the default temporary build directory. The output directory
may contain spaces. See `docs/TESTING.md` for extracted-artifact and product
importer integration checks.

Starting with app release `0.6.0`, the default installer downloads the published
`11.0.9-services.1` archive with its own pinned SHA-256. Existing users can install
the latest version in Advanced Settings, quit games and Windows Steam after cloud
sync, then select the new Wine version. Explicit older selections remain intact.
Local builds can still be imported for development. See [release notes](releases/0.6.0.md).

To replay patches on a clean, hash-verified extraction:

```sh
python3 scripts/apply-wine11-patches.py /path/to/sources/wine
```

After configuring a new WoW64 build using the project's toolchain, build both
PE architectures and the Unix backend:

```sh
make -j8 dlls/mmdevapi/all dlls/winecoreaudio.drv/all \
  dlls/mmdevapi/tests/x86_64-windows/mmdevapi_test.exe \
  dlls/mmdevapi/tests/i386-windows/mmdevapi_test.exe
```

Run each focused test in a dedicated disposable prefix with the newly built
client and backend, never a user's game prefix. For a complete Wine build:

```sh
WINEPREFIX=/absolute/path/to/test-prefix ./wine \
  dlls/mmdevapi/tests/x86_64-windows/mmdevapi_test.exe spatialaudio
WINEPREFIX=/absolute/path/to/test-prefix ./wine \
  dlls/mmdevapi/tests/i386-windows/mmdevapi_test.exe spatialaudio
```

A run that skips for no audio endpoint or zero dynamic capacity is not evidence
of dynamic rendering. Record check/failure/skip counts, device layout/rate,
object capacity, runtime identities and output logs. Also run `render`,
`capture`, `mmdevenum` and `propstore` to check normal audio.

`SWITCHYARD_SPATIAL_AUDIO_PROFILE=1 WINEDEBUG=+mmdevapi,+coreaudio` enables the
inherited bounded profiler. Its reported callback-allocation count is a source
path property, not an allocation-profiler measurement. The inherited
`SWITCHYARD_SPATIAL_AUDIO_FAULT_INVALIDATE_ON_START=1` and
`SWITCHYARD_SPATIAL_AUDIO_FAULT_INVALIDATE_BEFORE_START=1` hooks are for isolated
invalidation tests only; leave them unset for games.

## Release gate

Build/test outcomes for this checkout are recorded in
`docs/SPATIAL_AUDIO_VALIDATION.md`. Do not infer application compatibility from
module compilation or upstream tests. Before promoting the runtime, perform a
one-hour soak, real device changes/sleep-wake, stereo/headphone/multichannel
channel checks, confirmed object-audio game runs, D3DMetal launch and SDL/XInput
regressions. Keep the default release metadata at the existing validated
runtime until a new artifact has its own hash, signature and hardware results.

## Spatial stream services (2026-10-10)

Patch 0007 supplies `IAudioClock`, `IAudioClock2`, and `IAudioStreamVolume` from
`ISpatialAudioObjectRenderStreamBase::GetService`. Embedded service interfaces
hold stream references, retain the endpoint/render lifetime, and check sticky
spatial invalidation before accessing the underlying client. Clock/Clock2 share
IUnknown identity and can query each other; unsupported services return
E_NOINTERFACE and clear the output pointer. Null required outputs return
E_POINTER.

The stream clock reuses the existing client position/frequency pair: both are
byte-based in shared mode, so position/frequency yields elapsed seconds. Reset
clears the stream position. Clock2 obtains the activated CoreAudio endpoint's
raw device frame timeline; it does not reinterpret private PCM bytes as device
frames. A stopped stream returns AUDCLNT_S_POSITION_STALLED with its last
observed device position. CoreAudio host timestamps are mapped to Wine QPC's
continuous epoch, including the difference between sleep-excluding host time
and continuous time. Queries run on the calling thread; realtime render
callbacks do not gain blocking calls, logging, or allocations.

Volume channels follow this port's renderer input transport order: ordered
static channels, the dry channel, then dynamic-object slots. GetChannelCount
reports that stream's actual channel count, not the endpoint speaker count.
Controls reuse the existing per-input atomic gain path and combine with object
volume/session gain. All setters reject nonfinite values and values outside
[0,1]; batch validation completes before any channel is modified. This mapping
is the implementation's transport model; exact Windows channel mapping still
needs a Windows reference-machine conformance capture.

IsSpatialAudioStreamAvailable now checks the base object stream against the
activated endpoint capability, and returns STREAM_NOT_AVAILABLE for unsupported
stream interfaces. HRTF/metadata stream implementations remain separate work.

Validation: both i386 and x86_64 spatial suites execute 3090 checks, zero failures
and skips, with two pre-existing todo results. Added tests cover service
identity/reference lifetime, pointer/range errors, atomic rejection of invalid
volume batches, round trips, clocks during playback/stop/reset, and fault-driven
endpoint loss. The independent prefix uses WINEARCH=wow64; default-prefix setup
previously omitted syswow64 builtins, which explained the earlier x86 loader
failure. See work/full-runtime/spatial-services for logs and package audit.

References: [GetService](https://learn.microsoft.com/en-us/windows/win32/api/spatialaudioclient/nf-spatialaudioclient-ispatialaudioobjectrenderstreambase-getservice),
[clock units](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclock-getfrequency),
[device position](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclock2-getdeviceposition),
and [batch volume validation](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudiostreamvolume-setallvolumes).
