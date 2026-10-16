// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

`define TRACE_WAVE

module tb_croc_chip #(
  parameter int unsigned GpioCount = 9
);

  import tb_croc_pkg::*;

  logic rst_n;
  logic sys_clk;
  logic ref_clk;
  logic pll_ref_clk;

  logic jtag_tck;
  logic jtag_trst_n;
  logic jtag_tms;
  logic jtag_tdi;
  logic jtag_tdo;

  logic uart_rx;
  logic uart_tx;
  logic sd_clk;
  logic pll_cktst;

  tri1 [GpioCount-1:0] gpio_io;
  tri1 [3:0] sd_dat_io;
  tri1 sd_cmd_io;

  wire status;

  tri VDD;
  tri VSS;
  tri VDDIO;
  tri VSSIO;
  tri DVDD_DRV;
  tri DVSS_DRV;
  tri PLL_AVDD;
  tri PLL_AVSS;

  string binary_path;

  assign VDD   = 1'b1;
  assign VDDIO = 1'b1;
  assign VSS   = 1'b0;
  assign VSSIO = 1'b0;
  assign DVDD_DRV = 1'b1;
  assign DVSS_DRV = 1'b0;
  assign PLL_AVDD = 1'b1;
  assign PLL_AVSS = 1'b0;

  // Keep the optional PLL disabled and on the primary clock; its dedicated
  // reference pad still receives a separate 20 MHz clock.
  initial pll_ref_clk = 1'b0;
  always #(ClkPeriodSys/2) pll_ref_clk = ~pll_ref_clk;

  // External board-level loopback used by sw/test/test_gpio.c.
  assign gpio_io[7:4] = gpio_io[3:0];
  assign gpio_io[8] = 1'b0;

  initial begin
    if ($value$plusargs("binary=%s", binary_path)) begin
      $display("Running program: %s", binary_path);
    end else begin
      $display("No binary path provided. Running the generated MAYO end-to-end fixture.");
      // Build the fallback with `make -C sw/mayo_end_to_end`.
      binary_path = "../sw/bin/mayo_end_to_end/generated/end_to_end.hex";
    end
  end

  croc_vip #(
    .GpioCount ( GpioCount )
  ) i_vip (
    .rst_no        ( rst_n    ),
    .sys_clk_o     ( sys_clk  ),
    .ref_clk_o     ( ref_clk  ),
    .jtag_tck_o    ( jtag_tck ),
    .jtag_trst_no  ( jtag_trst_n ),
    .jtag_tms_o    ( jtag_tms ),
    .jtag_tdi_o    ( jtag_tdi ),
    .jtag_tdo_i    ( jtag_tdo ),
    .uart_rx_o     ( uart_rx  ),
    .uart_tx_i     ( uart_tx  ),
    .gpio_out_en_i ( '0       ),
    .gpio_out_i    ( '0       ),
    .gpio_in_o     (          )
  );

  croc_chip i_croc_chip (
    .clk_i        ( sys_clk     ),
    .rst_ni       ( rst_n       ),
    .ref_clk_i    ( ref_clk     ),
    .pll_ref_clk_i( pll_ref_clk ),
    .jtag_tck_i   ( jtag_tck    ),
    .jtag_trst_ni ( jtag_trst_n ),
    .jtag_tms_i   ( jtag_tms    ),
    .jtag_tdi_i   ( jtag_tdi    ),
    .jtag_tdo_o   ( jtag_tdo    ),
    .uart_rx_i    ( uart_rx     ),
    .uart_tx_o    ( uart_tx     ),
    .testmode_i   ( 1'b0        ),
    .status_o     ( status      ),
    .pll_en_i     ( 1'b0        ),
    .pll_bp_i     ( 1'b1        ),
    .pll_select_i ( 1'b0        ),
    .pll_n_i      ( 8'd20       ),
    .pll_od_i     ( 2'b00       ),
    .pll_clksel_i ( 1'b0        ),
    .pll_cktst_o  ( pll_cktst   ),
    .gpio0_io     ( gpio_io[0]  ),
    .gpio1_io     ( gpio_io[1]  ),
    .gpio2_io     ( gpio_io[2]  ),
    .gpio3_io     ( gpio_io[3]  ),
    .gpio4_io     ( gpio_io[4]  ),
    .gpio5_io     ( gpio_io[5]  ),
    .gpio6_io     ( gpio_io[6]  ),
    .gpio7_io     ( gpio_io[7]  ),
    .gpio8_io     ( gpio_io[8]  ),
    .sd_clk_o     ( sd_clk      ),
    .sd_cd_ni     ( 1'b1        ),
    .sd_dat_io0   ( sd_dat_io[0]),
    .sd_dat_io1   ( sd_dat_io[1]),
    .sd_dat_io2   ( sd_dat_io[2]),
    .sd_dat_io3   ( sd_dat_io[3]),
    .sd_cmd_io    ( sd_cmd_io   ),
    .VDD          ( VDD         ),
    .VSS          ( VSS         ),
    .VDDIO        ( VDDIO       ),
    .VSSIO        ( VSSIO       ),
    .DVDD_DRV     ( DVDD_DRV    ),
    .DVSS_DRV     ( DVSS_DRV    ),
    .PLL_AVDD     ( PLL_AVDD    ),
    .PLL_AVSS     ( PLL_AVSS    )
  );

  logic [31:0] tb_data;

  initial begin
    $timeformat(-9, 0, "ns", 12);

    #ClkPeriodSys;

    i_vip.jtag_init();
    i_vip.jtag_write_reg32(SramBaseAddr, 32'h1234_5678, 1'b1);
    i_vip.jtag_load_hex(binary_path);

    $display("@%t | [CORE] Waking core via CLINT msip", $time);
    i_vip.jtag_write_reg32(ClintBaseAddr, 32'h1);

    i_vip.jtag_halt();
    i_vip.jtag_resume();

    $display("@%t | [CORE] Wait for end of code...", $time);
    i_vip.jtag_wait_for_eoc(tb_data);

    repeat (50) @(posedge sys_clk);
    $finish();
  end

endmodule
