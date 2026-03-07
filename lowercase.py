#!/usr/bin/env python3
"""
Read a text file and convert A-Z to lowercase.
Usage: python3 lowercase.py <file>              (overwrites in place)
       python3 lowercase.py <infile> <outfile>   (writes to outfile)
"""

import sys


def main():
    if len(sys.argv) < 2:
        print("Usage: lowercase.py <file> [outfile]", file=sys.stderr)
        sys.exit(1)

    in_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else in_path

    with open(in_path, "r", encoding="utf-8", errors="replace") as f:
        text = f.read()

    with open(out_path, "w", encoding="utf-8", newline="") as f:
        f.write(text.lower())

    if out_path == in_path:
        print(f"Updated {in_path}")
    else:
        print(f"Wrote {out_path}")


if __name__ == "__main__":
    main()
