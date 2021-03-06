/*
 * Copyright (c) 2019 Carlo Caione <ccaione@baylibre.com>
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/**
 * @file
 * @brief Thread context switching for ARM64 Cortex-A
 *
 * This module implements the routines necessary for thread context switching
 * on ARM64 Cortex-A.
 */

#include <toolchain.h>
#include <linker/sections.h>
#include <offsets_short.h>
#include <arch/cpu.h>
#include <syscall.h>
#include "macro.h"

GDATA(_kernel)
GDATA(_k_neg_eagain)

/**
 * @brief PendSV exception handler, handling context switches
 *
 * The PendSV exception is the only execution context in the system that can
 * perform context switching. When an execution context finds out it has to
 * switch contexts, it pends the PendSV exception.
 *
 * When PendSV is pended, the decision that a context switch must happen has
 * already been taken. In other words, when z_arm64_pendsv() runs, we *know* we
 * have to swap *something*.
 *
 * For Cortex-A, PendSV exception is not supported by the architecture and this
 * function is directly called either by _isr_wrapper() in case of preemption,
 * or z_arm64_svc() in case of cooperative switching.
 */
GTEXT(z_arm64_pendsv)
SECTION_FUNC(TEXT, z_arm64_pendsv)
#ifdef CONFIG_TRACING
	stp	xzr, x30, [sp, #-16]!
	bl	sys_trace_thread_switched_in
	ldp	xzr, x30, [sp], #16
#endif
	/* load _kernel into x1 and current k_thread into x2 */
	ldr	x1, =_kernel
	ldr	x2, [x1, #_kernel_offset_to_current]

	/* addr of callee-saved regs in thread in x0 */
	ldr	x0, =_thread_offset_to_callee_saved
	add	x0, x0, x2

	/* Store rest of process context including x30, SPSR_ELn and ELR_ELn */
	stp	x19, x20, [x0], #16
	stp	x21, x22, [x0], #16
	stp	x23, x24, [x0], #16
	stp	x25, x26, [x0], #16
	stp	x27, x28, [x0], #16
	stp	x29, x30, [x0], #16

	switch_el x3, 3f, 2f, 1f
3:
	mrs	x4, spsr_el3
	mrs	x5, elr_el3
	b	0f
2:
	mrs	x4, spsr_el2
	mrs	x5, elr_el2
	b	0f
1:
	mrs	x4, spsr_el1
	mrs	x5, elr_el1
0:
	stp	x4, x5, [x0], #16

	/* Save the current SP */
	mov	x6, sp
	str	x6, [x0]

	/* fetch the thread to run from the ready queue cache */
	ldr	x2, [x1, #_kernel_offset_to_ready_q_cache]
	str	x2, [x1, #_kernel_offset_to_current]

	/* load _kernel into x1 and current k_thread into x2 */
	ldr	x1, =_kernel
	ldr	x2, [x1, #_kernel_offset_to_current]

	/* addr of callee-saved regs in thread in x0 */
	ldr	x0, =_thread_offset_to_callee_saved
	add	x0, x0, x2

	/* Restore x19-x29 plus x30, SPSR_ELn and ELR_ELn */
	ldp	x19, x20, [x0], #16
	ldp	x21, x22, [x0], #16
	ldp	x23, x24, [x0], #16
	ldp	x25, x26, [x0], #16
	ldp	x27, x28, [x0], #16
	ldp	x29, x30, [x0], #16

	ldp	x4, x5, [x0], #16

	switch_el x3, 3f, 2f, 1f
3:
	msr	spsr_el3, x4
	msr	elr_el3, x5
	b	0f
2:
	msr	spsr_el2, x4
	msr	elr_el2, x5
	b	0f
1:
	msr	spsr_el1, x4
	msr	elr_el1, x5
0:
	ldr	x6, [x0]
	mov	sp, x6

#ifdef CONFIG_TRACING
	stp	xzr, x30, [sp, #-16]!
	bl	sys_trace_thread_switched_out
	ldp	xzr, x30, [sp], #16
#endif

	/* We restored x30 from the process stack. There are three possible
	 * cases:
	 *
	 * - We return to z_arm64_svc() when swappin in a thread that was
	 *   swapped out by z_arm64_svc() before jumping into
	 *   z_arm64_exit_exc()
	 * - We return to _isr_wrapper() when swappin in a thread that was
	 *   swapped out by _isr_wrapper() before jumping into
	 *   z_arm64_exit_exc()
	 * - We return (jump) into z_thread_entry_wrapper() for new threads
	 * (see thread.c)
	 */
	ret

/**
 *
 * @brief Entry wrapper for new threads
 *
 * @return N/A
 */

GTEXT(z_thread_entry_wrapper)
SECTION_FUNC(TEXT, z_thread_entry_wrapper)
	/*
	 * z_thread_entry_wrapper is called for every new thread upon the return
	 * of arch_swap() or ISR. Its address, as well as its input function
	 * arguments thread_entry_t, void *, void *, void * are restored from
	 * the thread stack (see thread.c).
	 * In this case, thread_entry_t, * void *, void * and void * are stored
	 * in registers x0, x1, x2 and x3. These registers are used as arguments
	 * to function z_thread_entry.
	 */
	ldp	x0, x1, [sp], #16
	ldp	x2, x3, [sp], #16

	/* ELR_ELn was set in thread.c to z_thread_entry() */
	eret

/**
 *
 * @brief Service call handler
 *
 * The service call (SVC) is used in the following occasions:
 * - Cooperative context switching
 * - IRQ offloading
 *
 * @return N/A
 */
GTEXT(z_arm64_svc)
SECTION_FUNC(TEXT, z_arm64_svc)
	/*
	 * Save the volatile registers and x30 on the process stack. This is
	 * needed if the thread is switched out.
	 */
	stp	x0, x1, [sp, #-16]!
	stp	x2, x3, [sp, #-16]!
	stp	x4, x5, [sp, #-16]!
	stp	x6, x7, [sp, #-16]!
	stp	x8, x9, [sp, #-16]!
	stp	x10, x11, [sp, #-16]!
	stp	x12, x13, [sp, #-16]!
	stp	x14, x15, [sp, #-16]!
	stp	x16, x17, [sp, #-16]!
	stp	x18, x30, [sp, #-16]!

	switch_el x3, 3f, 2f, 1f
3:
	mrs	x0, esr_el3
	b	0f
2:
	mrs	x0, esr_el2
	b	0f
1:
	mrs	x0, esr_el1
0:
	lsr	x1, x0, #26

	cmp	x1, #0x15 /* 0x15 = SVC */
	bne	inv

	/* Demux the SVC call */
	and	x2, x0, #0xff
	cmp	x2, #_SVC_CALL_CONTEXT_SWITCH
	beq	context_switch

#ifdef CONFIG_IRQ_OFFLOAD
	cmp	x2, #_SVC_CALL_IRQ_OFFLOAD
	beq	offload
	b	inv
offload:
	/* ++(_kernel->nested) to be checked by arch_is_in_isr() */
	ldr	x1, =_kernel
	ldr	x2, [x1, #_kernel_offset_to_nested]
	add	x2, x2, #1
	str	x2, [x1, #_kernel_offset_to_nested]

	bl	z_irq_do_offload

	/* --(_kernel->nested) */
	ldr	x1, =_kernel
	ldr	x2, [x1, #_kernel_offset_to_nested]
	sub	x2, x2, #1
	str	x2, [x1, #_kernel_offset_to_nested]
	b	exit
#endif
	b	inv

context_switch:
	bl	z_arm64_pendsv

exit:
	b	z_arm64_exit_exc

inv:
	mov	x1, sp
	mov	x0, #0 /* K_ERR_CPU_EXCEPTION */
	b	z_arm64_fatal_error


/**
 * @brief Restore volatile registers and x30
 *
 * This is the common exit point for z_arm64_pendsv() and _isr_wrapper(). We
 * restore the registers saved on the process stack including X30. The return
 * address used by eret (in ELR_ELn) is either restored by z_arm64_pendsv() if
 * a context-switch happened or not touched at all by the ISR if there was no
 * context-switch.
 *
 * @return N/A
 */

GTEXT(z_arm64_exit_exc)
SECTION_FUNC(TEXT, z_arm64_exit_exc)
	/*
	 * In x30 we can have:
	 *
	 * - The address of irq_unlock() in swap.c when swapping in a thread
	 *   that was cooperatively swapped out (used by ret in
	 *   z_arm64_call_svc())
	 * - A previos generic value if the thread that we are swapping in was
	 *   swapped out preemptively by the ISR.
	 */
	ldp	x18, x30, [sp], #16
	ldp	x16, x17, [sp], #16
	ldp	x14, x15, [sp], #16
	ldp	x12, x13, [sp], #16
	ldp	x10, x11, [sp], #16
	ldp	x8, x9, [sp], #16
	ldp	x6, x7, [sp], #16
	ldp	x4, x5, [sp], #16
	ldp	x2, x3, [sp], #16
	ldp	x0, x1, [sp], #16

	/*
	 * In general in the  ELR_ELn register we can find:
	 *
	 * - The address of ret in z_arm64_call_svc() in case of arch_swap()
	 *   (see swap.c)
	 * - The address of the next instruction at the time of the IRQ when the
	 *   thread was switched out.
	 * - The address of z_thread_entry() for new threads (see thread.c).
	 */
	eret

GTEXT(z_arm64_call_svc)
SECTION_FUNC(TEXT, z_arm64_call_svc)
	svc	#_SVC_CALL_CONTEXT_SWITCH
	ret

#ifdef CONFIG_IRQ_OFFLOAD
GTEXT(z_arm64_offload)
SECTION_FUNC(TEXT, z_arm64_offload)
	svc	#_SVC_CALL_IRQ_OFFLOAD
	ret
#endif

