/* =============================================================================
 * Smart ControlSoC - RISC-V Linker Script: link.ld
 * Architecture: RV32IM / ABI: ilp32
 * ============================================================================= */

OUTPUT_ARCH( "riscv" )
ENTRY( _start )

MEMORY
{
    /* Instruction / Code Memory (64 KB at 0x0000_0000) */
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    /* Data / Stack Memory (64 KB at 0x0001_0000) */
    RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 64K
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
    } > ROM

    /* Initialized data placed in RAM, loaded from ROM */
    .data : AT(_etext)
    {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > RAM

    /* Uninitialized data (zero-initialized) */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    /* Stack region at the top of RAM */
    .stack (NOLOAD) :
    {
        . = ALIGN(16);
        _sstack = .;
        . = . + STACK_SIZE;
        . = ALIGN(16);
        _estack = .;
        _sp = _estack;
    } > RAM

    /* Global pointer initialization */
    __global_pointer$ = MIN(_sdata + 0x800, MAX(_sdata, _edata - 0x800));
}

