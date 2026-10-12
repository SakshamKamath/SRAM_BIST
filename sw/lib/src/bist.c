#include <stdint.h>
#include "bist.h"

// Memory-mapped 32-bit register access. volatile forces a real bus access every time.
#define MBIST_REG(offset) (*(volatile uint32_t *)(uintptr_t)(MBIST_TEST_BASE_ADDRESS + (offset)))

// Number of macros the hardware actually implements (max 32 = width of the start register).
// Set this to 8 if only status register 0 exists in silicon.
#ifndef MBIST_NUM_MACROS
#define MBIST_NUM_MACROS            32u
#endif

#define MBIST_STATUS_BITS_PER_MACRO 4u
#define MBIST_MACROS_PER_STATUS_REG (32u / MBIST_STATUS_BITS_PER_MACRO)   // 8
#define MBIST_STATUS_FIELD_MASK     0xFu   // one macro's 4-bit status field (before shifting)
#define MBIST_STATUS_DONE           0x1u   // expected value of the field when the macro is done

// Byte distance between consecutive status registers. ASSUMPTION: contiguous 32-bit
// registers. Override from mbist.h or the build if the spec says otherwise.
#ifndef MBIST_STATUS_REG_STRIDE
#define MBIST_STATUS_REG_STRIDE     4u
#endif

#define MBIST_POLL_TIMEOUT          10000u   // max polls before giving up (tune for your clock)

#define MBIST_OK                    0
#define MBIST_ERR_TIMEOUT          (-1)
#define MBIST_ERR_BAD_MACRO        (-2)

// Runs MBIST on one macro (0 .. MBIST_NUM_MACROS-1).
uint32_t mbist_run_macro(uint32_t macro)
{
    if (macro >= MBIST_NUM_MACROS)
        return MBIST_ERR_BAD_MACRO;

    const uint32_t start_bit    = 1u << macro;                                 // bit n -> macro n
    const uint32_t status_off   = MBIST_STATUS_READ_OFFSET0 +
                                  (macro / MBIST_MACROS_PER_STATUS_REG) * MBIST_STATUS_REG_STRIDE;
    const uint32_t status_shift = (macro % MBIST_MACROS_PER_STATUS_REG) * MBIST_STATUS_BITS_PER_MACRO;
    const uint32_t status_mask  = MBIST_STATUS_FIELD_MASK << status_shift;
    const uint32_t status_done  = MBIST_STATUS_DONE << status_shift;

    // Trigger MBIST for this macro. Plain write (not read-modify-write): the start
    // register is a trigger, so we don't want to re-write stale bits for other macros.
    // MBIST_REG(MBIST_START_OFFSET) = start_bit;
    *reg32(MBIST_TEST_BASE_ADDRESS, MBIST_START_OFFSET) = start_bit;

    // printf("MBIST polling starts %x\n", (MBIST_REG(status_off)));
    // Poll the read-only status register until this macro's field reads 0x1.
    uint32_t polls = 0;
    // while ((MBIST_REG(status_off) & status_mask) != status_done) {
    while ((*reg32(MBIST_TEST_BASE_ADDRESS, MBIST_STATUS_READ_OFFSET0) & status_mask) != status_done) {
        if (polls >= MBIST_POLL_TIMEOUT)
            return MBIST_ERR_TIMEOUT;
        polls = polls+1;
    }
    return MBIST_OK;
}

