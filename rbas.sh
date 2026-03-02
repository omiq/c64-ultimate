#!/bin/sh

# BASIC source file to tokenize and run (defaults to word-search.bas if not given)
BAS_FILE="${1:-word-search.bas}"

if [ ! -f "$BAS_FILE" ]; then
  echo "BASIC file not found: $BAS_FILE" >&2
  exit 1
fi

# Lowercase the BASIC source for petcat (it expects lowercase keywords)
tr 'A-Z' 'a-z' < "$BAS_FILE" | \
  petcat -v -f -w2 -c -o prg.prg --

python3 runner.py prg.prg

