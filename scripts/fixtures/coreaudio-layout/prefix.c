#include <AudioToolbox/AudioToolbox.h>
#include <CoreAudio/CoreAudio.h>
#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "windef.h"
#include "winbase.h"
#include "wingdi.h"
#include "mmreg.h"
#define AUDCLNT_E_UNSUPPORTED_FORMAT ((HRESULT)0x88890008)
#define AUDCLNT_E_DEVICE_INVALIDATED ((HRESULT)0x88890004)
#define TRACE(...) ((void)0)
struct coreaudio_stream {UINT32 spatial_dry_output[2], spatial_dry_output_count;};
static AudioDeviceID dev_id_from_device(const char *device) {return 1;}
static BOOL fallback_allowed;
static HRESULT get_device_mix_format(const char *device, WAVEFORMATEXTENSIBLE *format) {if(!fallback_allowed)return AUDCLNT_E_UNSUPPORTED_FORMAT;memset(format,0,sizeof(*format));format->Format.nChannels=2;format->dwChannelMask=3;return S_OK;}
static UInt32 raw_size, actual_channels;
static char raw_data[8192];
static OSStatus fake_size(AudioObjectID id, const AudioObjectPropertyAddress *addr, UInt32 qsize, const void *q, UInt32 *size)
{*size = addr->mSelector == kAudioDevicePropertyPreferredChannelLayout ? raw_size : sizeof(AudioBufferList); return noErr;}
static OSStatus fake_data(AudioObjectID id, const AudioObjectPropertyAddress *addr, UInt32 qsize, const void *q, UInt32 *size, void *data)
{if(addr->mSelector==kAudioDevicePropertyPreferredChannelLayout)memcpy(data,raw_data,raw_size);else{AudioBufferList *b=data;memset(b,0,sizeof(*b));b->mNumberBuffers=1;b->mBuffers[0].mNumberChannels=actual_channels;}return noErr;}
#define AudioObjectGetPropertyDataSize fake_size
#define AudioObjectGetPropertyData fake_data
