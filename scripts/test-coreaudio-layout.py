#!/usr/bin/env python3
"""Exercise the patched Wine CoreAudio layout helpers using mocked device data.

Requires macOS/Xcode and the patched CrossOver Wine source tree. AudioFormat
layout expansion uses Apple's real framework; device properties are fixtures.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('wine_source', type=Path)
args = parser.parse_args()
wine = args.wine_source.resolve()
fixtures = Path(__file__).resolve().parent / 'fixtures' / 'coreaudio-layout'
source = (wine / 'dlls/winecoreaudio.drv/coreaudio.c').read_text()
start = source.index('static AudioChannelLabel wave_speaker_to_channel_label')
end = source.index('static BOOL spatial_transport_speaker_to_coordinates', start)
text = ((fixtures / 'prefix.c').read_text()
        + 'struct wave_channel_layout {AudioChannelLayout layout; AudioChannelDescription extra_descriptions[17];};\n'
        + source[start:end] + (fixtures / 'main.c').read_text())
with tempfile.TemporaryDirectory(prefix='mgu-coreaudio-layout-') as directory:
    root = Path(directory)
    test = root / 'layout-test.c'
    test.write_text(text)
    executable = root / 'layout-test'
    subprocess.run(['xcrun', 'clang', '-D__WINESRC__', '-DWINE_UNIX_LIB',
                    '-I' + str(wine / 'include'), str(test),
                    '-framework', 'AudioToolbox', '-framework', 'CoreAudio',
                    '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
