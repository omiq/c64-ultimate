# --------------------------------------------------------------------
# httpget — pure C HTTP client for C64 + SwiftLink (cc65 toolchain)
# --------------------------------------------------------------------
#
# Builds  httpget.prg  — standalone .prg, loads at $0801 (default BASIC),
# auto-runs via cc65's BASIC stub (SYS 2061 / 2064 / etc).
#
# Usage on C64:
#   LOAD "HTTPGET",8
#   RUN
#
# The program does the full dial+HTTP handshake itself (direct ACIA
# polling, no KERNAL RS232 hooks) and dumps the response body to:
#   1. Screen (for visual confirmation / debug)
#   2. SEQ file "HGRESULT" on the same drive (for BASIC to consume)
#
# Then exits cleanly. BASIC can then do:
#   OPEN 2,8,2,"HGRESULT,S,R"
#   GET#2,A$: ... etc
# --------------------------------------------------------------------

CC      = cl65
OUT     = wotd.prg
SRCS    = wotd.c nmi.s
CFLAGS  = -t c64 -O

all: $(OUT)

$(OUT): $(SRCS)
	$(CC) $(CFLAGS) -o $(OUT) $(SRCS)

# build + deploy + auto-run on C64U via runner.py (no disk, no power cycle)
run: $(OUT)
	python3 ../runner.py $(OUT)

clean:
	rm -f *.o *.prg *.map *.lst

.PHONY: all run clean
