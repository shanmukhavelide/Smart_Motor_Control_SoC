/* =============================================================================
 * Smart ControlSoC - RISC-V Startup Assembly: startup.S
 * Target: VeeR EL2 RISC-V Core (RV32IM / ilp32)
 * ============================================================================= */

    .section .text.init, "ax", @progbits
    .global _start
    .global _trap_handler
    .type _start, @function

_start:
    /* Disable interrupts initially */
    csrw mie, zero

    /* Set trap vector */
    la t0, _trap_handler
    csrw mtvec, t0

    /* Initialize Global Pointer (GP) */
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    /* Initialize Stack Pointer (SP) */
    la sp, _sp

    /* Initialize DATA section (copy initialized globals from ROM to RAM) */
    la a0, _etext       /* Source in ROM */
    la a1, _sdata       /* Destination in RAM */
    la a2, _edata       /* End of RAM data */
    bgeu a1, a2, 2f

1:
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    bltu a1, a2, 1b
2:

    /* Clear BSS section (zero-initialize uninitialized globals) */
    la a0, _sbss
    la a1, _ebss
    bgeu a0, a1, 4f

3:
    sw zero, 0(a0)
    addi a0, a0, 4
    bltu a0, a1, 3b
4:

    /* Jump to main application entry point */
    jal ra, main

    /* If main returns, loop indefinitely */
_hang:
    wfi
    j _hang

    /* Default Trap / Interrupt Handler */
    .align 4
_trap_handler:
    /* Minimal trap return stub */
    mret

    .size _start, . - _start

