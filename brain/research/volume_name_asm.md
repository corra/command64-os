# C64 direct access to change volume name

Standard Commodore DOS does not provide a high-level command to rename a volume that preserves your data; the standard format command (e.g., `N0:<name>,<id>`) completely erases the disk, re-establishes the Block Allocation Map (BAM), and builds a fresh directory,,. To change a disk's volume name without destroying the files already stored on it, you have to bypass the standard DOS commands and manipulate the disk at the raw sector level using Direct Access Commands.

Under the hood, this is precisely how disk management utilities (like the DISK PAC "Change the Disk Name" routine) alter the volume name.

## Where the Volume Name Resides

The 1541 disk drive (and its compatibles) stores the volume name and the BAM on the directory track, which is heavily hardcoded to Track 18, Sector 0. Within this specific block of data, the 16-character diskette name resides exactly at byte offsets 144 through 159. To rename the disk, you must read this sector into memory, alter those 16 bytes, and write the sector back to the disk,,.

### The Assembly Approach

To accomplish this in 6510 assembly, you cannot merely POKE values into the drive. You must use the drive's Direct Access Commands `U1` (Block Read) and `U2` (Block Write) over the command channel (15) and push your modifications through a direct data buffer channel,. You will rely heavily on the C64's KERNAL I/O jump table.

Here is the architectural flow required to perform the change:

**1. Open the Command and Data Channels**
You must open the command channel (logical file 15) and a separate data channel (e.g., logical file 2) configured to allocate a raw data buffer by using the filename `"#"`.
In assembly, you initialize each channel using the `SETLFS` (`$FFBA`), `SETNAM` (`$FFBD`), and `OPEN` (`$FFC0`) KERNAL routines,,.

**2. Execute a Block Read (`U1`)**
Instruct the drive to read Track 18, Sector 0 into the buffer you just opened. To do this, you send the string `"U1 2 0 18 0"` to the command channel,.
In assembly, this means calling `CHKOUT` (`$FFC9`) to make file 15 the active output device, then loading each ASCII character of the command string into the accumulator and calling `CHROUT` (`$FFD2`) in a loop,. You must conclude the command string by sending an ASCII carriage return (`$0D`), followed by calling `CLRCHN` (`$FFCC`) to cleanly restore default I/O processing,.

**3. Set the Block Pointer (`B-P`)**
Rather than reading and writing the entire 256-byte sector over the serial bus, you can instruct the drive's internal pointer to jump directly to the volume name. Send the Block Pointer command `"B-P 2 144"` to channel 15 (using the same `CHKOUT` and `CHROUT` looping method),,. This points data channel 2 directly at byte 144, the beginning of the volume name.

**4. Overwrite the Volume Name**
With the pointer set, redirect your output to the data channel by calling `CHKOUT` (`$FFC9`) for logical file 2. Loop through your new 16-character volume name, using `CHROUT` (`$FFD2`) to send each byte directly into the disk's buffer,. (If your new name is shorter than 16 characters, you must pad the remainder of the 16 bytes with the shifted-space character, `$A0`, to overwrite any trailing characters from the old name.) Call `CLRCHN` (`$FFCC`) when finished.

**5. Execute a Block Write (`U2`)**
Now that the buffer inside the 1541's RAM has been modified, you must flush it back to the physical diskette. Call `CHKOUT` for file 15 again and send the block write command `"U2 2 0 18 0"`, terminated with a carriage return (`$0D`), to write the buffer back to Track 18, Sector 0,,.

**6. Close Channels and Clean Up**
Finally, cleanly shut down the serial bus to prevent corrupting any further disk operations. Load the logical file numbers into the accumulator one by one and call the KERNAL `CLOSE` routine (`$FFC3`), followed by a final `CLRCHN` (`$FFCC`),,.

### Warning on Direct Access

Direct access commands are powerful, and if you accidentally write to the wrong track or sector, you can garble the entire disk. It is strongly advised to test your assembly routines on a scratch disk first. Never attempt to issue a Validate (`V`) command over the command channel while your direct access data buffers are open, as it will scramble the unclosed file allocation mappings.
