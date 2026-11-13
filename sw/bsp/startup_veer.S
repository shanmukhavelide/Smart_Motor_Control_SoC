/* =============================================================================
 * Smart ControlSoC - VeeR EL2 Bare-Metal Startup Code: startup_veer.S
 * Target: RV32IMC VeeR EL2 Core
 * Reset Entry: 0xEE00_0000 (ICCM Base)
 * ============================================================================= */

    .section .text.init, "ax"
    .global _start
    .type _start, @function

_start:
    /* Disable global interrupts upon entry */
    csrw    mstatus, zero
    csrw    mie, zero

    /* Set up machine trap vector */
    la      t0, _trap_handler
    csrw    mtvec, t0

    /* Initialize Stack Pointer to top of DCCM */
    la      sp, _sp

    /* Initialize Global Pointer */
.option push
.option norelax
    la      gp, __global_pointer$
.option pop

    /* Copy .data from ICCM LMA to DCCM VMA */
    la      a0, _etext          /* Load address (source) */
    la      a1, _sdata          /* Destination start */
    la      a2, _edata          /* Destination end */
    bge     a1, a2, 2f
1:
    lw      t0, 0(a0)
    sw      t0, 0(a1)
    addi    a0, a0, 4
    addi    a1, a1, 4
    blt     a1, a2, 1b
2:

    /* Zero out .bss in DCCM */
    la      a0, _sbss
    la      a1, _ebss
    bge     a0, a1, 4f
3:
    sw      zero, 0(a0)
    addi    a0, a0, 4
    blt     a0, a1, 3b
4:

    /* Call main application */
    call    main

    /* Loop indefinitely if main returns */
_exit_loop:
    wfi
    j       _exit_loop

    .size _start, . - _start

/* =============================================================================
 * Default Machine Trap Handler
 * ============================================================================= */
    .section .text, "ax"
    .global _trap_handler
    .type _trap_handler, @function
_trap_handler:
    /* Trap occurred: loop or signal exception */
    csrr    t0, mcause
    csrr    t1, mepc
    j       _trap_handler
    .size _trap_handler, . - _trap_handler

