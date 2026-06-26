# MS-DOS 4.0 Label Command Behavior

`LABEL` command could be both interactive and non-interactive, depending exactly on how you typed it.

## ⚡ Non-Interactive Mode (Direct Input)

If you supplied the text directly in the command line, it was completely non-interactive. It would change the disk name instantly and return you straight to the command prompt.

**Syntax**: `LABEL [drive:][label-text]`
**Example**: `LABEL A:MYDISK`

_(This immediately changed the drive A: label to "MYDISK" without asking any questions)._

## 💬 Interactive Mode (The Prompt)

If you typed the command without providing a new label name, it switched into an interactive prompt.

**Syntax**: `LABEL` or `LABEL A:`

### The Interaction

1. It would first display the current name and the 32-bit Volume Serial Number (which was a big new feature introduced in MS-DOS 4.0).

2. It then prompted you: Volume label (11 characters, ENTER for none)?

3. You could either type a new 11-character name and press ENTER, or press ENTER on an empty
line.

4. If you pressed ENTER on an empty line, it would double-check your intent by prompting: Delete current volume label (Y/N)?

## References

* _Source_: [LABEL command - Virtual Dr Forums-Computer Tech Support](https://discussions.virtualdr.com/showthread.php?70178-LABEL-command)
* _Source_: [label | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/label)
* _Source_: [LABEL](https://info.wsisiz.edu.pl/~bse26236/batutil/help/LABEL_S.HTM)
* _Source_: [Disk label command - Windows CMD - SS64](https://ss64.com/nt/label.html)
* _Source_: [label (command) - Wikipedia](https://en.wikipedia.org/wiki/Label_%28command%29)
