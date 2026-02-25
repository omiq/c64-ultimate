#!/bin/sh
# Lowercase the BASIC source for petcat (it expects lowercase keywords)
tr 'A-Z' 'a-z' < /home/chrisg/github/c64-ultimate/word-search.bas | \
  petcat -v -f -w2 -c -o prg.prg --
python3 runner.py prg.prg

