#!/usr/bin/env python3
"""
Report which lines in a text file are longer than 80 characters.
Usage: python3 line-length-check.py <file> [max_length]
       (default max_length is 80)
"""

import sys


def main():
    if len(sys.argv) < 2:
        print("Usage: line-length-check.py <file> [max_length]", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    max_len = int(sys.argv[2]) if len(sys.argv) > 2 else 80

    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    long_lines = []
    for i, line in enumerate(lines, start=1):
        # strip trailing newline for length; raw line length might include \r\n
        length = len(line.rstrip("\r\n"))
        if length > max_len:
            long_lines.append((i, length, line.rstrip()))

    if not long_lines:
        print(f"All lines are <={max_len} characters.")
        return

    print(f"Lines over {max_len} characters ({len(long_lines)} total):\n")
    for num, length, text in long_lines:
        preview = text[:60] + "..." if len(text) > 60 else text
        print(f"  {num:5}: {length} chars  {preview}")


if __name__ == "__main__":
    main()
