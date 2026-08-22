module tb_jtag_march;





// Relevant Tasks

task jtag_reset();
    integer i;
    begin
        TEST_TMS <= 1'b1;
        TEST_TDI <= 1'b0;
        // 5 consecutive TMS=1 clocks forces TAP into Test-Logic-Reset state
        for (i = 0; i < 5; i = i + 1) begin
            @(negedge TEST_TCLK);
        end
        // Transition to Run-Test/Idle
        TEST_TMS <= 1'b0;
        @(negedge TEST_TCLK);
    end
endtask

task jtag_write_ir(
    input [3:0] ir_in,
    input integer ir_len
);
    integer i;
    begin
        // Navigate to Select-IR-Scan
        @(negedge TEST_TCLK) TEST_TMS <= 1'b1; // Select-DR-Scan
        @(negedge TEST_TCLK) TEST_TMS <= 1'b1; // Select-IR-Scan
        @(negedge TEST_TCLK) TEST_TMS <= 1'b0; // Capture-IR
        @(negedge TEST_TCLK) TEST_TMS <= 1'b0; // Shift-IR

        // Shift LSB-first into IR
        for (i = 0; i < ir_len; i = i + 1) begin
            TEST_TDI <= ir_in[i];
            // On the last bit, drive TMS high to exit Shift-IR state
            if (i == ir_len - 1)
                TEST_TMS <= 1'b1; // Exit1-IR
            else
                TEST_TMS <= 1'b0; // Shift-IR
            
            @(negedge TEST_TCLK);
        end

        // Complete TAP state transitions back to Idle
        TEST_TMS <= 1'b1; // Update-IR
        @(negedge TEST_TCLK);
        TEST_TMS <= 1'b0; // Run-Test/Idle
        @(negedge TEST_TCLK);
    end
endtask

task jtag_shift_dr(
    input  [14:0] dr_in,   // Data to write into DR via TDI
    output [14:0] dr_out,  // Data captured from DR via TDO
    input  integer dr_len  // Length of the DR chain
);
    integer i;
    begin
        dr_out = 15'b0;

        // Navigate to Select-DR-Scan
        @(negedge TEST_TCLK) TEST_TMS <= 1'b1; // Select-DR-Scan
        @(negedge TEST_TCLK) TEST_TMS <= 1'b0; // Capture-DR
        @(negedge TEST_TCLK) TEST_TMS <= 1'b0; // Shift-DR

        // Shift LSB-first into DR while reading TDO
        for (i = 0; i < dr_len; i = i + 1) begin
            TEST_TDI <= dr_in[i];

            // Sample TDO on the current cycle
            dr_out[i] = TEST_TDO;

            // On the last bit, drive TMS high to exit Shift-DR state
            if (i == dr_len - 1)
                TEST_TMS <= 1'b1; // Exit1-DR
            else
                TEST_TMS <= 1'b0; // Shift-DR

            @(negedge TEST_TCLK);
        end

        // Complete TAP state transitions back to Idle
        TEST_TMS <= 1'b1; // Update-DR
        @(negedge TEST_TCLK);
        TEST_TMS <= 1'b0; // Run-Test/Idle
        @(negedge TEST_TCLK);
    end
endtask






initial begin
    // Initialize signals
    TEST_TCLK   = 1'b0;
    TEST_TRSTNI = 1'b0;
    TEST_TMS    = 1'b1;
    TEST_TDI    = 1'b0;
    #100;
    TEST_TRSTNI = 1'b1; // Release hard reset

    // 1. Reset TAP FSM
    jtag_reset();

    // 2. Write custom opcode '4'b0010' (INSTR_MBIST) into IR
    jtag_write_ir(4'b0010, 4);

    // // 3. Shift out the DR chain to extract [ Valid_Bit | Fail_Address ]
    // // dr_len = 1 (Valid bit) + 14 (P_ADDR_WIDTH) = 15 bits
    // begin : read_fifo_loop
    //     reg [14:0] captured_dr;
    //     reg        valid_bit;
    //     reg [13:0] fail_addr;

    //     // Fetch 1st failed address from FIFO
    //     jtag_shift_dr(15'h0, captured_dr, 15);
    //     valid_bit = captured_dr[14];
    //     fail_addr = captured_dr[13:0];

    //     if (valid_bit) begin
    //         $display("[JTAG READ] Faulty Address Found: 0x%h", fail_addr);
    //     end else begin
    //         $display("[JTAG READ] FIFO Empty.");
    //     end
    // end
end

endmodule