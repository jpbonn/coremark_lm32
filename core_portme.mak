#File : core_portme.mak
# Command line:
#  make XCFLAGS="-DTOTAL_DATA_SIZE=6000 -DMAIN_HAS_NOARGC=1" PORT_DIR=coremark_lm32 clean

# We utilize the Milkymist bios for I/O and timer.
MMDIR          = /home/jpbonn/Documents/mico32/milkymist
MMDIR          = /opt/milkymist/milkymist/
#############################################################################
# Mico32 toolchain
#
COMPILERRT_DIR=/home/jp/Documents/baseline/compiler-rt-lm32/lm32/emb
# try out the gcc compiled lm32-elf newlib instead of our clang compiled one
NEWLIB_DIR=/home/jpbonn/Documents/mico32/lm32-gcc/install/lm32-elf
# use the clang compiled newlib
NEWLIB_DIR=/home/jp/Documents/baseline/newlib/build/install/lm32-elf
LIBGLOSS_DIR=/home/jp/Documents/baseline/newlib/build-libgloss/install/lib/

# Toolchain options
#
#INCLUDES_NOLIBC ?= -nostdinc -I$(MMDIR)/software/include/base ASFD
INCLUDES_NOLIBC ?= -I$(MMDIR)/software/include/base
INCLUDES = $(INCLUDES_NOLIBC) -I$(MMDIR)/software/include -I$(MMDIR)/tools -I$(NEWLIB_DIR)/include
#ASFLAGS = $(INCLUDES) -nostdinc
ASFLAGS = $(INCLUDES)
# later: -Wmissing-prototypes
PORT_CFLAGS = -g -O9 -Wall -Wstrict-prototypes -Wold-style-definition -Wshadow \
	 -mbarrel-shift-enabled -mmultiply-enabled -mdivide-enabled \
	 -msign-extend-enabled -fno-builtin -fsigned-char \
	 -fsingle-precision-constant $(INCLUDES)
#LDFLAGS = -nostdlib -nodefaultlibs

############################################################################

# Flag : OUTFLAG
#	Use this flag to define how to to get an executable (e.g -o)
OUTFLAG= -o
CC=clang -march=lm32 -ccc-host-triple lm32 -ccc-gcc-name lm32-rtems4.11-gcc
LD		= lm32-rtems4.11-ld
AS		= lm32-rtems4.11-as
OBJCOPY		= lm32-rtems4.11-objcopy
# Flag : CFLAGS
#	Use this flag to define compiler options. Note, you can add compiler options from the command line using XCFLAGS="other flags"
#PORT_CFLAGS = -O0 -g -march=lm32 -ccc-host-triple lm32 -ccc-gcc-name lm32-rtems4.11-gcc 
FLAGS_STR = "$(PORT_CFLAGS) $(XCFLAGS) $(XLFLAGS) $(LFLAGS_END)"
CFLAGS = $(PORT_CFLAGS) -I$(PORT_DIR) -I. -DFLAGS_STR=\"$(FLAGS_STR)\" 
#Flag : LFLAGS_END
#	Define any libraries needed for linking or other flags that should come at the end of the link line (e.g. linker scripts). 
#	Note : On certain platforms, the default clock_gettime implementation is supported but requires linking of librt.
SEPARATE_COMPILE=1
# Flag : SEPARATE_COMPILE
# You must also define below how to create an object file, and how to link.
OBJOUT 	= -o
LFLAGS 	= -nostdlib -nodefaultlibs -T $(PORT_DIR)/linker.ld -N --start-group
ASFLAGS =
OFLAG 	= -o
COUT 	= -c

#LFLAGS_END = --end-group  -L$(MMDIR)/software/libhpdmc -L$(MMDIR)/software/libbase -L$(MMDIR)/software/libhal -L$(MMDIR)/software/libnet -L$(NEWLIB_DIR)/lib --start-group -lbase-light -lhal -lc -lm --end-group -L$(COMPILERRT_DIR) -lcompiler_rt 
LFLAGS_END = --end-group  -L$(MMDIR)/software/libhpdmc -L$(MMDIR)/software/libbase -L$(MMDIR)/software/libhal -L$(MMDIR)/software/libnet -L$(NEWLIB_DIR)/lib --start-group -lbase-light -lhal -lc -lm --end-group -L$(COMPILERRT_DIR) -lcompiler_rt -L$(LIBGLOSS_DIR) -lnosys
#LFLAGS_END = --end-group  -L$(MMDIR)/software/libhpdmc -L$(MMDIR)/software/libbase -L$(MMDIR)/software/libhal -L$(MMDIR)/software/libnet -L$(NEWLIB_DIR)/lib --start-group -lbase-light -lhal -lc -lm --end-group -L$(COMPILERRT_DIR) -lcompiler_rt
 
# Flag : PORT_SRCS
# 	Port specific source files can be added here
#	You may also need cvt.c if the fcvt functions are not provided as intrinsics by your compiler!
PORT_SRCS = $(PORT_DIR)/core_portme.c $(PORT_DIR)/ee_printf.c
vpath %.c $(PORT_DIR)
vpath %.s $(PORT_DIR)

# Flag: PORT_OBJS
# Port specific object files can be added here
#PORT_OBJS = $(PORT_DIR)/crt0.o $(PORT_DIR)/core_portme.o $(PORT_DIR)/ee_printf.o $(PORT_DIR)/isr.o
PORT_OBJS = $(PORT_DIR)/core_portme.o $(PORT_DIR)/ee_printf.o $(PORT_DIR)/isr.o
PORT_CLEAN = $(PORT_DIR)/*.o *.bin *.out *.fbi *.o


# Flag : LOAD
#	For a simple port, we assume self hosted compile and run, no load needed.

# Flag : RUN
#	For a simple port, we assume self hosted compile and run, simple invocation of the executable

LOAD = echo "Please set LOAD to the process of loading the executable to the flash"
RUN = echo "Please set LOAD to the process of running the executable (e.g. via jtag, or board reset)"
RUN = qemu-system-lm32 -M milkymist -nographic -kernel

OEXT = .o
EXE = .out

$(OPATH)$(PORT_DIR)/%$(OEXT) : %.c
	$(CC) $(CFLAGS) $(XCFLAGS) $(COUT) $< $(OBJOUT) $@

$(OPATH)%$(OEXT) : %.c
	$(CC) $(CFLAGS) $(XCFLAGS) $(COUT) $< $(OBJOUT) $@

$(OPATH)$(PORT_DIR)/%$(OEXT) : %.S
	$(AS) $(ASFLAGS) $< $(OBJOUT) $@

$(OPATH)$(PORT_DIR)/%$(OEXT) : %.s
	$(AS) $(ASFLAGS) $< $(OBJOUT) $@

# Target: port_postbuild
# Generate boot images for Milkymist One
.PHONY: port_postbuild
port_postbuild: $(OUTNAME)
	echo "Doing postbuild on $(OUTNAME)"
	$(OBJCOPY) -O binary $(OUTNAME) coremark.bin
	mkmmimg coremark.bin write coremark.fbi

# Target: port_prebuild
# Build crt0.o separately.  It was getting linked in twice if
# it was added to PORT_OBJS since the linker STARTUP directive
# included it too.
.PHONY: port_prebuild
port_prebuild:
	echo "*******Doing prebuild "
	make $(PORT_DIR)/crt0.o

# Target : port_pre% and port_post%
# For the purpose of this simple port, no pre or post steps needed.
.PHONY : port_prebuild port_prerun port_postrun port_preload port_postload
port_pre% port_post% : 

# FLAG : OPATH
# Path to the output folder. Default - current folder.
OPATH = ./
MKDIR = mkdir -p

