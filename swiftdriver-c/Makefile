# --------------------------------------------------------------------
# SwiftDriver in C — build rules (cc65 toolchain)
# --------------------------------------------------------------------
#
# Produces  swiftdrv.prg  — load with  LOAD"SWIFTDRV",8,1 : SYS 49152
#
# Source order matters: entry.s MUST be first so its `jmp _swift_init`
# ends up as the first instruction at $C000 (SYS 49152 target).
#
#   entry.s   — 3-byte trampoline (jmp swift_init)
#   swift.c   — C init() + helpers
#   hooks.s   — KERNAL vector replacements (port of Bo's DOOPEN etc.)
#   nmi.s     — NMI ring-buffer ISR
# --------------------------------------------------------------------

CC      = cl65
OUT     = swiftdrv.prg
SRCS    = entry.s hooks.s nmi.s
# -t none = freestanding (no crt0, no libc startup)
# -C ... = our minimal linker config that pins code to $C000
CFLAGS  = -t none -O -C swift-c000.cfg -Ln swift.lbl --mapfile swift.map

all: $(OUT)

$(OUT): $(SRCS) swift-c000.cfg swift.h
	$(CC) $(CFLAGS) -o $(OUT) $(SRCS)

# --- test program ----------------------------------------------------
test: test_loopback.prg

test_loopback.prg: test_loopback.c $(OUT)
	$(CC) -t $(TARGET) -O -o $@ test_loopback.c

clean:
	rm -f *.o *.prg *.map *.lst

.PHONY: all test clean
