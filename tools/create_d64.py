import sys, os

def create_d64(out_path, prg_paths):
    # 1541 Disk Geometry: Sectors per track (Tracks 1-35)
    SPT = [21]*17 + [19]*7 + [18]*6 + [17]*5
    OFFS = [sum(SPT[:i])*256 for i in range(36)]
    IMG = bytearray(174848) # Total size of a standard D64

    # Initialize BAM (Track 18, Sector 0)
    B = OFFS[17]
    IMG[B:B+4] = [18, 1, 0x41, 0] # Next dir track/sector, DOS version 'A'
    for t in range(1, 36):
        o = B + 4 + (t-1)*4
        IMG[o] = SPT[t-1] # Free sectors count
        m = (1 << SPT[t-1]) - 1 # Bitmask (1 = free)
        IMG[o+1:o+4] = [m & 0xFF, (m >> 8) & 0xFF, (m >> 16) & 0xFF]

    # Mark BAM (T18, S0) and Directory (T18, S1) as used
    IMG[B+4+17*4] -= 2
    IMG[B+4+17*4+1] &= ~0x03

    # Disk Header (Name, ID, DOS version)
    # Use unshifted PETSCII (lowercase in mixed mode) for the header
    IMG[B+0x90:B+0xA0] = b"TEST DISK".ljust(16, b"\xA0")
    IMG[B+0xA2:B+0xA4] = b"2B" # Disk ID
    IMG[B+0xA5:B+0xA7] = [0x32, 0x41] # "2A"

    # Initialize Directory Sector (T18, S1)
    D = OFFS[17] + 256
    IMG[D:D+2] = [0, 0xFF] # No next dir sector

    def alloc():
        """Finds and marks the first available sector as used."""
        for t in range(1, 36):
            if t == 18: continue # Skip directory track
            o = B + 4 + (t-1)*4
            if IMG[o] > 0:
                m = IMG[o+1] | (IMG[o+2] << 8) | (IMG[o+3] << 16)
                for s in range(SPT[t-1]):
                    if (m >> s) & 1:
                        IMG[o] -= 1
                        m &= ~(1 << s)
                        IMG[o+1:o+4] = [m & 0xFF, (m >> 8) & 0xFF, (m >> 16) & 0xFF]
                        return t, s
        return None, None

    # Add up to 8 files (one directory sector)
    for i, path in enumerate(prg_paths[:8]):
        if not os.path.exists(path): continue
        with open(path, "rb") as f: data = f.read()
        
        # Explicit filename encoding for C64 unshifted (lowercase)
        name_raw = os.path.basename(path).upper().replace(".PRG","")[:16]
        # Map uppercase ASCII to unshifted PETSCII (which is lowercase in mixed mode)
        # 'A' (65) -> $41
        name_petscii = bytearray()
        for char in name_raw:
            if 'A' <= char <= 'Z':
                name_petscii.append(ord(char)) # Already matches PETSCII $41-$5A
            elif '0' <= char <= '9':
                name_petscii.append(ord(char)) # Matches PETSCII $30-$39
            else:
                name_petscii.append(ord(char))
        
        name = name_petscii.ljust(16, b"\xA0")
        
        ft, fs, pt, ps, cnt = None, None, None, None, 0
        for j in range(0, len(data), 254):
            t, s = alloc()
            if not t: break
            if not ft: ft, fs = t, s # Store first sector for directory
            if pt: # Link previous sector to this one
                o = OFFS[pt-1] + ps*256
                IMG[o], IMG[o+1] = t, s
            o = OFFS[t-1] + s*256
            chunk = data[j:j+254]
            IMG[o+2:o+2+len(chunk)] = chunk
            pt, ps, cnt = t, s, cnt + 1
        
        if pt: # Finalize last sector
            o = OFFS[pt-1] + ps*256
            IMG[o], IMG[o+1] = 0, (len(data) % 254 + 1) if len(data) % 254 else 255
            
        # Write Directory Entry
        e = D + 2 + i*32
        IMG[e:e+3] = [0x82, ft, fs] # Type PRG, Track, Sector
        IMG[e+3:e+19] = name
        IMG[e+28:e+30] = [cnt & 0xFF, cnt >> 8] # File size in sectors

    with open(out_path, "wb") as f: f.write(IMG)
    print(f"Created {out_path} with {len(prg_paths[:8])} files.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python create_d64.py output.d64 input1.prg [input2.prg ...]")
    else:
        create_d64(sys.argv[1], sys.argv[2:])
