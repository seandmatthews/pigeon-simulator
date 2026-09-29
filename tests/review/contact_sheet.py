"""Build contact sheets (grids of labelled frames) from a run folder.
Usage: python contact_sheet.py <run_dir> [count=24] [cols=4]"""
import glob, math, os, struct, sys, zlib

run = sys.argv[1]
count = int(sys.argv[2]) if len(sys.argv) > 2 else 24
cols = int(sys.argv[3]) if len(sys.argv) > 3 else 4

def read_jpeg_size(path):
    with open(path, 'rb') as f:
        data = f.read()
    i = 2
    while i < len(data):
        if data[i] != 0xFF: i += 1; continue
        marker = data[i+1]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3):
            h, w = struct.unpack('>HH', data[i+5:i+9])
            return w, h
        elif marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
            i += 2
        else:
            length = struct.unpack('>H', data[i+2:i+4])[0]
            i += 2 + length
    return None

# pure-python PNG writer (no PIL dependency)
def write_png(path, w, h, rgb):
    def chunk(typ, data):
        c = struct.pack('>I', len(data)) + typ + data
        return c + struct.pack('>I', zlib.crc32(typ + data) & 0xffffffff)
    raw = b''.join(b'\x00' + rgb[y*w*3:(y+1)*w*3] for y in range(h))
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 6))
    png += chunk(b'IEND', b'')
    open(path, 'wb').write(png)

# tiny baseline JPEG decoder is overkill: instead decode via Godot? No — use JPEG export frames only as files;
# for the contact sheet we re-encode thumbnails using straight byte copy is impossible.
# So: contact sheet via HTML gallery instead + full-size views.
frames = sorted(glob.glob(os.path.join(run, 'f*.png')))
if not frames:
    print('no frames'); sys.exit(1)
pick = [frames[int(i * (len(frames) - 1) / max(1, count - 1))] for i in range(count)]
html = os.path.join(run, 'contact_sheet.html')
with open(html, 'w', encoding='utf-8') as f:
    f.write('<html><body style="background:#111;color:#ddd;font-family:monospace">')
    for p in pick:
        name = os.path.basename(p)
        f.write(f'<div style="display:inline-block;margin:4px"><div>{name}</div>'
                f'<img src="{name}" style="width:320px;display:block"></div>')
    f.write('</body></html>')
w, h = read_jpeg_size(frames[0]) or (1280, 720)
print(f"{len(frames)} frames ({w}x{h}); picked {len(pick)} -> {html}")
