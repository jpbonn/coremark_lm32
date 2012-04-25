OUTPUT_FORMAT("elf32-lm32")
/* ENTRY(_mystart) */
STARTUP(coremark_lm32/crt0.o)

__DYNAMIC = 0;

MEMORY {
	sdram : ORIGIN = 0x40000000, LENGTH = 0x4000000  /* upper 64M of SDRAM */
}

SECTIONS
{
	.text :
	{
		_ftext = .;
		*(.text .stub .text.* .gnu.linkonce.t.*)
		_etext = .;
	} > sdram

	.rodata :
	{
		. = ALIGN(4);
		_frodata = .;
		*(.rodata .rodata.* .gnu.linkonce.r.*)
		*(.rodata1)
		/* we use _erodata for copying .data section to sdram. */
		. = ALIGN(4);
		_erodata = .; 
	} > sdram

	.data :
	{
		. = ALIGN(4);
		_fdata = .;
		*(.data .data.* .gnu.linkonce.d.*)
		*(.data1)
		_gp = ALIGN(16);
		*(.sdata .sdata.* .gnu.linkonce.s.*)
		_edata = .;
	} > sdram

	.bss :
	{
		. = ALIGN(4);
		_fbss = .;
		*(.dynsbss)
		*(.sbss .sbss.* .gnu.linkonce.sb.*)
		*(.scommon)
		*(.dynbss)
		*(.bss .bss.* .gnu.linkonce.b.*)
		*(COMMON)
		. = ALIGN(4);
		_ebss = .;
		_end = .;
                PROVIDE (end = .);
	} > sdram
}

PROVIDE(_fstack = ORIGIN(sdram) + LENGTH(sdram) - 4);
