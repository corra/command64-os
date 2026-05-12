#!/bin/bash
# tests/build_tests.sh

KICKASS="tools/KickAss.jar"
OUTDIR="$(pwd)/tests/bin"

mkdir -p "$OUTDIR"

echo "Compiling tests..."
java -jar $KICKASS tests/src/hello.asm -odir $OUTDIR
java -jar $KICKASS tests/src/color.asm -odir $OUTDIR
java -jar $KICKASS tests/src/extcls.asm -odir $OUTDIR
java -jar $KICKASS tests/src/apitest.asm -odir $OUTDIR
java -jar $KICKASS tests/src/vmmtest.asm -odir $OUTDIR

echo "Done."
