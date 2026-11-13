/* =============================================================================
 * Smart ControlSoC - VeeR EL2 Bare-Metal Linker Script: link_veer.ld
 * Target Core: Western Digital / CHIPS Alliance VeeR EL2 (RV32IMC)
 * Architecture: RV32IM / ABI: ilp32
 * Code Location: ICCM (0xEE00_0000, 64 KB)
 * Data/Stack Location: DCCM (0xF004_0000, 64 KB)
 * ============================================================================= */

OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
    /* Instruction Closely Coupled Memory (ICCM: 64 KB at 0xEE00_0000) */
    ICCM (rx)  : ORIGIN = 0xEE000000, LENGTH = 64K
    /* Data Closely Coupled Memory (DCCM: 64 KB at 0xF004_0000) */
    DCCM (rwx) : ORIGIN = 0xF0040000, LENGTH = 64K
}

STACK_SIZE = 4K;

SECTIONS
{
    /* Code section placed at reset entry address */
    .text :
    {
        . = ALIGN(4);
        *(.text.init)
        *(.text .text.*)
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        . = ALIGN(4);
        _etext = .;
    } > ICCM

    /* Initialized data placed in DCCM, loaded from ICCM */
    .data : AT(_etext)
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > DCCM

    /* Uninitialized data in DCCM (zero-initialized) */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > DCCM

    /* Stack region at the top of DCCM */
    .stack (NOLOAD) :
    {
        . = ALIGN(16);
        _sstack = .;
        . = . + STACK_SIZE;
        . = ALIGN(16);
        _estack = .;
        _sp = _estack;
    } > DCCM

    /* Global pointer initialization */
    __global_pointer$ = MIN(_sdata + 0x800, MAX(_sdata, _edata - 0x800));
}

