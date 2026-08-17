import struct
import os
import sys

if len(sys.argv) < 2:
    print("Usage: python3 splice_header.py <vendor_boot.img>")
    sys.exit(1)

mk_path = sys.argv[1]
script_dir = os.path.dirname(os.path.realpath(__file__))
stock_path = os.path.join(script_dir, "stock_header.bin")

with open(stock_path, "rb") as f:
    stock_header = bytearray(f.read(4096))

with open(mk_path, "rb") as f:
    mk_header = f.read(4096)
    f.seek(4096)
    mk_payload = f.read()

stock_header[24:28] = mk_header[24:28]
stock_header[112:116] = mk_header[112:116]
stock_header[124:128] = mk_header[124:128]
stock_header[136:140] = mk_header[136:140]

with open(mk_path, "wb") as f:
    f.write(stock_header)
    f.write(mk_payload)

print(f"MTK SPLICER: Splicing complete! {mk_path}")
