#!/bin/sh
petcat -v -2 -o prg.prg -- /home/chrisg/github/c64-ultimate/word-search.bas
python3 runner.py prg.prg

