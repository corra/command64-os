#!/bin/bash
# tests/build_tests.sh

KICKASS="../../tools/KickAss.jar"
OUTDIR="../bin"

mkdir -p $OUTDIR

echo "Compiling tests..."
java -jar $KICKASS src/hello.asm -odir $OUTDIR
java -jar $KICKASS src/color.asm -odir $OUTDIR
java -jar $KICKASS src/extcls.asm -odir $OUTDIR

echo "Done."
