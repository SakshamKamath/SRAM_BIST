// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Chip-level testbench: drives croc_chip through its IO pads instead of croc_soc directly.
// Select it with `run_vsim.sh --tb tb_croc_chip`.
//
// JTAG chain on the chip: TDI -> boundary-scan TAP (IR 4) -> croc_soc TAPs -> TDO,
// so the VIP is told about one extra TAP in front of croc_soc.

`define TRACE_WAVE

module tb_croc_chip #(
  parameter int unsigned GpioCount = 32
);

  import tb_croc_pkg::*;

  localparam int unsigned BndScanIrWidth = 4;   // croc_chip: bndscan_jtag_top IrWidth

  logic rst_n;
  logic sys_clk;
  logic ref_clk;

  logic jtag_tck;
  logic jtag_trst_n;
  logic jtag_tms;
  logic jtag_tdi;
  logic jtag_tdo;

  logic uart_rx;
  logic uart_tx;

  tri1 [GpioCount-1:0] gpio_io;
  wire [3:0]           unused;

  wire status;

  tri VDD;
  tri VSS;
  tri VDDIO;
  tri VSSIO;

  string binary_path;

  assign VDD   = 1'b1;
  assign VDDIO = 1'b1;
  assign VSS   = 1'b0;
  assign VSSIO = 1'b0;

  // External board-level loopback used by sw/test/test_gpio.c.
  assign gpio_io[7:4] = gpio_io[3:0];

  initial begin
    if ($value$plusargs("binary=%s", binary_path)) begin
      $display("Running program: %s", binary_path);
    end else begin
      $display("No binary path provided. Running helloworld.");
      binary_path = "../sw/bin/helloworld.hex";
    end
  end

  // The boundary-scan TAP registers TDO, adding one flop: IR 4+1 bits, bypass 1+1 bits.
  croc_vip #(
    .GpioCount         ( GpioCount          ),
    .ExtraIrLenBefore  ( BndScanIrWidth + 1 ),
    .ExtraDrBitsBefore ( 2                  )
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
    .jtag_tck_i   ( jtag_tck    ),
    .jtag_trst_ni ( jtag_trst_n ),
    .jtag_tms_i   ( jtag_tms    ),
    .jtag_tdi_i   ( jtag_tdi    ),
    .jtag_tdo_o   ( jtag_tdo    ),
    .uart_rx_i    ( uart_rx     ),
    .uart_tx_o    ( uart_tx     ),
    .testmode_i   ( 1'b0        ),
    .status_o     ( status      ),
    .gpio0_io     ( gpio_io[0]  ),
    .gpio1_io     ( gpio_io[1]  ),
    .gpio2_io     ( gpio_io[2]  ),
    .gpio3_io     ( gpio_io[3]  ),
    .gpio4_io     ( gpio_io[4]  ),
    .gpio5_io     ( gpio_io[5]  ),
    .gpio6_io     ( gpio_io[6]  ),
    .gpio7_io     ( gpio_io[7]  ),
    .gpio8_io     ( gpio_io[8]  ),
    .gpio9_io     ( gpio_io[9]  ),
    .gpio10_io    ( gpio_io[10] ),
    .gpio11_io    ( gpio_io[11] ),
    .gpio12_io    ( gpio_io[12] ),
    .gpio13_io    ( gpio_io[13] ),
    .gpio14_io    ( gpio_io[14] ),
    .gpio15_io    ( gpio_io[15] ),
    .gpio16_io    ( gpio_io[16] ),
    .gpio17_io    ( gpio_io[17] ),
    .gpio18_io    ( gpio_io[18] ),
    .gpio19_io    ( gpio_io[19] ),
    .gpio20_io    ( gpio_io[20] ),
    .gpio21_io    ( gpio_io[21] ),
    .gpio22_io    ( gpio_io[22] ),
    .gpio23_io    ( gpio_io[23] ),
    .gpio24_io    ( gpio_io[24] ),
    .gpio25_io    ( gpio_io[25] ),
    .gpio26_io    ( gpio_io[26] ),
    .gpio27_io    ( gpio_io[27] ),
    .gpio28_io    ( gpio_io[28] ),
    .gpio29_io    ( gpio_io[29] ),
    .gpio30_io    ( gpio_io[30] ),
    .gpio31_io    ( gpio_io[31] ),
    .unused0_o    ( unused[0]   ),
    .unused1_o    ( unused[1]   ),
    .unused2_o    ( unused[2]   ),
    .unused3_o    ( unused[3]   ),
    .VDD          ( VDD         ),
    .VSS          ( VSS         ),
    .VDDIO        ( VDDIO       ),
    .VSSIO        ( VSSIO       )
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
