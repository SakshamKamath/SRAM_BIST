# Behavioral models for the IHP13 tech cells and SRAM macros.
# Sourced by run_vsim.sh only when TECHFUNCTIONAL=1 (--techfunctional).
# Must run BEFORE compile_rtl.tcl.

set ROOT ".."

proc tech_vlog {desc args} {
    puts "INFO: compile_tech_func.tcl: $desc"
    if {[catch { vlog -incr -sv {*}$args }]} {
        puts "ERROR: compile_tech_func.tcl: $desc failed"
        return -code error "tech compile failed: $desc"
    }
}

# 1. Standard cells (INVX2, MUX2X2, ...)
tech_vlog "EZ130 8T standard cells" \
    "+define+TECHFUNCTIONAL" \
    "$ROOT/technology/verilog/ez130_8t.v"

# 2. SRAM macro: core model first, then the wrapper that instantiates it
tech_vlog "SRAM macro 256x64 bm_bist" \
    "+define+TECHFUNCTIONAL" \
    "+define+FUNCTIONAL" \
    "+define+SIM" \
    "$ROOT/technology/verilog/RM_IHPSG13_1P_core_behavioral_bm_bist.v" \
    "$ROOT/technology/verilog/RM_IHPSG13_1P_256x64_c2_bm_bist.v"