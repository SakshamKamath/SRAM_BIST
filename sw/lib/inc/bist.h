

#pragma once
#include <stdint.h>
// #include <stdio.h>
#include "config.h"
#include "uart.h"
#include "print.h"
#include "util.h"

#define MBIST_TEST_BASE_ADDRESS SOCCTRL_BASE_ADDR // Same as PeriphSocCtrl --> Check croc_pkg.sv

#define MBIST_START_OFFSET             0x40 // Check soc_ctrl_regs_pkg.sv
#define MBIST_RESUME_OR_RESET_OFFSET   0x44 // Check soc_ctrl_regs_pkg.sv
#define MBIST_ERRADDR_READ_OFFSET      0x48 // Check soc_ctrl_regs_pkg.sv
#define MBIST_STATUS_READ_OFFSET0      0x4C // Check soc_ctrl_regs_pkg.sv

/* Readme:
MBIST_START_OFFSET --> Triggers mbist start
MBIST_RESUME_OR_RESET_OFFSET --> Triggers either reset or resumption of mbist after fifo full of failures
MBIST_ERRADDR_READ_OFFSET  --> Triggers fifo read if register present for fifo address read
MBIST_STATUS_READ_OFFSET0  --> Read only register where the status of all macro mbist present (4bits per macro so 8 macros supported)
*/


// Function Declarations

uint32_t mbist_run_macro(uint32_t macro);