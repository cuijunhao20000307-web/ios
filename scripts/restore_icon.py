from pathlib import Path
import base64
import hashlib
import lzma
import struct
import zlib

root = Path(__file__).resolve().parent.parent
payload = base64.b64decode((root / 'scripts/icon_pixels.b64').read_text())
assert hashlib.sha256(payload).hexdigest() == 'f145213bd46cf8240beb256146db03794afdbfd90a1182552f9de8c9153bf53c'
raw = lzma.decompress(payload)
n = struct.unpack_from('<H', raw)[0]
lut = raw[2:2+2047*3]
p = 2+2047*3
colors = raw[p:p+n*3]
indices = raw[p+n*3:]
assert len(indices) == 1024*1024
pixels = bytearray()
scanlines = bytearray()
for y in range(1024):
    scanlines.append(0)
    row = bytearray()
    for x in range(1024):
        i = indices[y*1024+x]
        k = (i-1)*3 if i else (x+y)*3
        row.extend(colors[k:k+3] if i else lut[k:k+3])
    pixels.extend(row)
    scanlines.extend(row)
assert hashlib.sha256(pixels).hexdigest() == '1a19c2671129e2553544ed2b76dd0a45777a113aab01c44cf71b0a13fe7bd2a6'
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind+data)&0xffffffff)
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB',1024,1024,8,2,0,0,0)) + chunk(b'IDAT',zlib.compress(scanlines,9)) + chunk(b'IEND',b'')
target = root / 'PocketLedger/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(png)
print('Original icon pixels restored:',target)
