VERSION := v2.7.3

OBJECTS := prefix.o startup.o callback.o main.o vsprintf.o string.o peloader.o
OBJECTS += int13.o vdisk.o cpio.o stdio.o lznt1.o xca.o die.o cmdline.o
OBJECTS += wimpatch.o huffman.o lzx.o wim.o wimfile.o pause.o sha1.o cookie.o
OBJECTS += paging.o memmap.o

HEADERS := $(wildcard *.h)

HOST_CC := $(CC)
AS := $(AS)
ECHO := echo
OBJCOPY := objcopy
AR := ar
RANLIB := ranlib
RM := rm
DIFF := diff
CUT := cut

CFLAGS += -Os -ffreestanding -Wall -Werror -Wextra -nostdinc -I. -fshort-wchar
CFLAGS += -DVERSION="\"$(VERSION)\""

CFLAGS += -m32 -march=i386 -malign-double -fno-pic

# Enable stack protection if available
#
SPG_TEST = $(CC) -fstack-protector-strong -mstack-protector-guard=global \
		 -x c -c /dev/null -o /dev/null >/dev/null 2>&1
SPG_FLAGS := $(shell $(SPG_TEST) && $(ECHO) '-fstack-protector-strong ' \
					    '-mstack-protector-guard=global')
CFLAGS += $(SPG_FLAGS)

# Inhibit unwanted debugging information
CFI_TEST = $(CC) -fno-dwarf2-cfi-asm -fno-exceptions -fno-unwind-tables \
		 -fno-asynchronous-unwind-tables -x c -c /dev/null \
		 -o /dev/null >/dev/null 2>&1
CFI_FLAGS := $(shell $(CFI_TEST) && \
	       $(ECHO) '-fno-dwarf2-cfi-asm -fno-exceptions ' \
		    '-fno-unwind-tables -fno-asynchronous-unwind-tables')
WORKAROUND_CFLAGS += $(CFI_FLAGS)

# Inhibit warnings from taking address of packed struct members
WNAPM_TEST = $(CC) -Wno-address-of-packed-member -x c -c /dev/null \
		   -o /dev/null >/dev/null 2>&1
WNAPM_FLAGS := $(shell $(WNAPM_TEST) && \
		 $(ECHO) '-Wno-address-of-packed-member')
WORKAROUND_CFLAGS += $(WNAPM_FLAGS)

# Inhibit LTO
LTO_TEST = $(CC) -fno-lto -x c -c /dev/null -o /dev/null >/dev/null 2>&1
LTO_FLAGS := $(shell $(LTO_TEST) && $(ECHO) '-fno-lto')
WORKAROUND_CFLAGS += $(LTO_FLAGS)

CFLAGS += $(WORKAROUND_CFLAGS)
CFLAGS += $(EXTRA_CFLAGS)

ifneq ($(DEBUG),)
CFLAGS += -DDEBUG=$(DEBUG)
endif

CFLAGS += -include compiler.h

###############################################################################
#
# Final targets

all : wimboot

wimboot : wimboot.elf
	$(OBJCOPY) -Obinary $< $@

wimboot.elf : $(OBJECTS) script.lds
	$(LD) -m elf_i386 -T script.lds -o $@ $(OBJECTS)

%.o : %.S $(HEADERS) Makefile
	$(CC) $(CFLAGS) -DASSEMBLY -Ui386 -E $< | as --32 -o $@

%.o : %.c $(HEADERS) Makefile
	$(CC) $(CFLAGS) -c $< -o $@

clean :
	$(RM) -f *.o *.elf wimboot
