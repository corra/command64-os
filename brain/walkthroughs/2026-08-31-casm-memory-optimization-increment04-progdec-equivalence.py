def old(val, width):
    # PROG_DIGIT semantics: repeated 16-bit subtract, count in Y, print Y+'0'
    def digit(scratch, divisor):
        y = 0
        while scratch - divisor >= 0:
            scratch -= divisor
            y += 1
        return scratch, y
    out = []
    s = val
    divs = [10000,1000,100,10,1] if width == 5 else [10,1]
    for d in divs:
        s, y = digit(s, d)
        out.append(str(y))   # note: y can exceed 9 only if higher digits not stripped
    return ''.join(out)

def new(val, width):
    divLo = [10000,1000,100,10,1]
    start = 0 if width == 5 else 3
    s = val
    out = []
    x = start
    while x < 5:
        y = 0
        while True:
            tent = s - divLo[x]
            if tent < 0:      # bcc / borrow
                break
            s = tent
            y += 1
        out.append(str(y))
        x += 1
    return ''.join(out)

bad = 0
for width in (2,5):
    for v in range(0, 65536):
        a, b = old(v, width), new(v, width)
        if a != b:
            bad += 1
            if bad < 10:
                print(f"MISMATCH w={width} v={v}: old={a!r} new={b!r}")
print("total mismatches:", bad)
# also show a few sample renderings
for v in [0,1,9,10,99,100,257,999,1000,9999,10000,65535]:
    print(f"v={v:5d} w5={new(v,5)!r} w2={new(v,2)!r}")
