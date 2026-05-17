# --------------------------------------------------------------------
# httpget-tool — resident HTTP fetcher with REU storage + SYS API
# --------------------------------------------------------------------
#
# Loads at $C000 (above BASIC) as a "library" the user installs once,
# then calls from BASIC via SYS entries.

CC      = cl65
OUT     = httptool.prg
SRCS    = entry.s httptool.c nmi.s
CFLAGS  = -t none -O -C httptool.cfg

all: $(OUT)

$(OUT): $(SRCS) httptool.cfg
	$(CC) $(CFLAGS) -o $(OUT) $(SRCS)

# deploy via runner.py (no disk, no power cycle)
run: $(OUT)
	python3 ../runner.py $(OUT)

clean:
	rm -f *.o *.prg *.map *.lst *.lbl

.PHONY: all run clean
