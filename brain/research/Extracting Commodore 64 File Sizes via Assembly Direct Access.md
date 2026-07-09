# Extracting Commodore 64 File Sizes via Assembly Direct Access

## Technical Background

Standard Commodore DOS does not record the exact byte length of a file in its directory; instead, it stores the size of the file in `256-byte blocks`. Becausethe drive mechanism reserves the first `2 bytes` of each block as pointers to the next track and sector in the chain, standard `PRG` files actually contain `254 bytes`of usable payload per block, except for the very first sector which contains `252 bytes` of payload due to the `2-byte` load address.

## The 6502 Assembly Process

To fetch a program's size in 6502 assembly, you cannot use the high-level LOAD commands. You must interrogate the disk drive at the raw sector level using Direct Access Commands. This requires opening a command channel and a raw data channel, reading the directory sectors starting at Track 18, Sector 1, and parsing the `32-byte directory entries to find your file's block count.  

### Architectural Process

1. **Open the Command and Data Channels:**  You must first open the command channel (logical file 15, secondary address 15)and a data channel (e.g., logical file 2,secondary address 2) to the disk drive at device 8. To allocate a raw data bufferinside the drive's RAM, you specify the filename `"#"` for the data channel. Inassembly, you configure the logical file, device, and secondary address by loadingthe accumulator, `X`, and `Y` registers, and calling the `SETLFS` routine at `$FFBA`.You then set the filename pointer using `SETNAM` at `$FFBD`, and execute the `OPEN`routine at `$FFC0` for both channels.

2. **Execute a Block Read (U1):** The directory entries begin on Track 18, Sector 1. To instruct the drive to fetch this block, you must send the Block Read command U1 over the command channel. Call CHKOUT at `$FFC9` with the accumulator set to `$0F` to make the command channel the active output device. Then, use CHROUT at `$FFD2` in a loop to send the PETSCII string `"U1 2 0 18 1"`, terminating the string with a carriage return (`$0D`). Call `CLRCHN` at `$FFCC` to restore default I/O.

3. **Read the Directory Sector:** With the sector now sitting in the 1541's data buffer, call `CHKIN` at `$FFC6` with your data channel (logical file 2) in the `X` register to make it the active input device. You can now sequentially read the `256 bytes` of the block by calling `CHRIN` at `$FFCF`.

4. **Parse the Directory Entries:** The first two bytes of the sector you read are the track and sector pointers to the *next* directory block. You must save these in zero page memory; if your file isn't in the current block, you will use these values to issue the next U1 command. If the track pointer is `0`, you have reached the end of the directory without finding your file.Following those two pointer bytes, the remainder of the block contains up to eight `32-byte` directory entries. For each entry, you must examine specific byte offsets:

5. **Byte 2 (File Type):** Check if the file is a valid program. `$82` indicates a standard PRG file, while `$00` indicates a scratched or unused entry.

6. **Bytes 5-20 (Filename):** This field contains the `16-character` filename, padded with shifted-space characters (`$A0`) if the name is shorter than 16 characters. You will need to write a comparison loop here to match these bytes against the target filename in your assembly program.

7. **Extract the Block Size:** Once your string comparison yields a match, you simply look at offsets `30` and `31` of that specific `32-byte` directory entry. These two bytes contain the low byte and high byte, respectively, of the file's total block size.  

8. **Clean Up:** Once you have retrieved the size, cleanly shut down the serial bus to prevent lockups. Load the logical file numbers into the accumulator and call `CLOSE` at `$FFC3` for both files, followed by a final `CLRCHN` at `$FFCC`.

9. **Final Calculation:** By taking the `16-bit` block count extracted from bytes 30 and 31 and multiplying it by `254` (the number of payload bytes per sector), you can establish a highly accurate approximation of the program's actual byte length.
