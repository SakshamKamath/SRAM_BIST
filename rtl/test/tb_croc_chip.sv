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

  // Testbench drivers for the other GPIO pins (boundary-scan test), released ('z) by default
  logic [GpioCount-1:0] gpio_drv    = '0;
  logic [GpioCount-1:0] gpio_drv_en = '0;
  for (genvar i = 0; i < GpioCount; i++) begin : gen_gpio_drv
    if (i < 4 || i > 7) begin : gen_drv
      assign gpio_io[i] = gpio_drv_en[i] ? gpio_drv[i] : 1'bz;
    end
  end

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

  ////////////////////////////////////////////////////////////////////////////
  //  Boundary-scan test (+bscan_test, with sw/test/test_bscan.c)
  ////////////////////////////////////////////////////////////////////////////
  // JTAG chain: TDI -> bndscan TAP (IR 4) -> obi_jtag TAP (IR 2) -> DMI TAP (IR 5) -> TDO.
  // bndscan and obi_jtag register TDO, which adds one stage each. IR 0 is BYPASS in all three.
  // BSR cells (croc_chip): [0] uart_rx, [1] testmode, [2] uart_tx, [3] status,
  //                        [4..7] unused0..3, [8..39] gpio0..31. Bit 0 is shifted out first.

  localparam int unsigned BsrLen      = 40;
  localparam int unsigned BsUartRx    = 0;
  localparam int unsigned BsTestmode  = 1;
  localparam int unsigned BsUartTx    = 2;
  localparam int unsigned BsStatus    = 3;
  localparam int unsigned BsUnused    = 4;
  localparam int unsigned BsGpio      = 8;

  localparam int unsigned IrChainLen  = (BndScanIrWidth + 1) + (2 + 1) + 5;  // 13
  localparam int unsigned IrBsOfs     = 5 + (2 + 1) + 1;   // bndscan IR bit 0 in the IR stream
  localparam int unsigned DrAfterBs   = 1 + 2 + 1;         // bndscan TDO stage, obi_jtag, DMI bypass
  localparam int unsigned BypassChain = 2 + 2 + 1;         // all three TAPs in BYPASS

  localparam realtime BsTimeout = 5ms;

  // Must match sw/test/test_bscan.c
  localparam logic [7:0] BscanReady = 8'hA5;
  localparam logic [7:0] BscanGo    = 8'h5A;
  localparam logic [7:0] BscanDone  = 8'hC3;

  typedef enum logic [BndScanIrWidth-1:0] {
    BsBypass        = 0,
    BsSamplePreload = 1,
    BsExtest        = 2,
    BsIntest        = 3
  } bs_instr_e;

  int unsigned bs_checks = 0;
  int unsigned bs_errors = 0;

  task automatic bs_check(input string what, input bit ok);
    bs_checks++;
    if (ok) $display("@%t | [JTAG-TEST] PASS: %s", $time, what);
    else begin
      bs_errors++;
      $error("@%t | [JTAG-TEST] FAIL: %s", $time, what);
    end
  endtask

  // Load instructions into the bndscan and obi_jtag TAPs, the DMI TAP goes to BYPASS.
  localparam int unsigned ObiIrWidth = 2;
  localparam int unsigned IrObiOfs   = 5 + 1;              // obi_jtag IR bit 0 in the IR stream

  task automatic chain_set_ir(input logic [BndScanIrWidth-1:0] bs_instr,
                              input logic [ObiIrWidth-1:0]     obi_instr);
    logic wdata[];
    wdata = new[IrChainLen];
    foreach (wdata[i]) wdata[i] = 1'b0;
    for (int i = 0; i < BndScanIrWidth; i++) wdata[IrBsOfs + i]  = bs_instr[i];
    for (int i = 0; i < ObiIrWidth; i++)     wdata[IrObiOfs + i] = obi_instr[i];
    i_vip.jtag_dbg.jtag.write_tms(1);   // select DR scan
    i_vip.jtag_dbg.jtag.write_tms(1);   // select IR scan
    i_vip.jtag_dbg.jtag.write_tms(0);   // capture IR
    i_vip.jtag_dbg.jtag.write_tms(0);   // shift IR
    i_vip.jtag_dbg.jtag.write_bits(wdata, 1);
    i_vip.jtag_dbg.jtag.write_tms(1);   // update IR
    i_vip.jtag_dbg.jtag.write_tms(0);   // run-test/idle
    // The DMI TAP IR was overwritten: make the VIP select it again on its next access
    i_vip.jtag_dbg.jtag.ir_select = '1;
  endtask

  task automatic bs_set_ir(input bs_instr_e instr);
    chain_set_ir(instr, '0);
  endtask

  // Shift wdata through the whole chain (capture before, update after), return TDO bits.
  task automatic chain_scan_dr(input logic wdata[], output logic rdata[]);
    i_vip.jtag_dbg.jtag.shift_dr();
    i_vip.jtag_dbg.jtag.readwrite_bits(rdata, wdata, 1);
    i_vip.jtag_dbg.jtag.update_dr(1'b0);
  endtask

  // Capture the BSR, shift in wvec, update. Returns the captured cells.
  task automatic bs_scan_dr(input logic [BsrLen-1:0] wvec, output logic [BsrLen-1:0] rvec);
    logic wdata[], rdata[];
    wdata = new[DrAfterBs + BsrLen];
    foreach (wdata[i]) wdata[i] = 1'b0;
    for (int i = 0; i < BsrLen; i++) wdata[DrAfterBs + i] = wvec[i];
    i_vip.jtag_dbg.jtag.shift_dr();
    i_vip.jtag_dbg.jtag.readwrite_bits(rdata, wdata, 1);
    i_vip.jtag_dbg.jtag.update_dr(1'b0);
    for (int i = 0; i < BsrLen; i++) rvec[i] = rdata[DrAfterBs + i];
  endtask

  // All TAPs in BYPASS: a pattern must come out after exactly BypassChain TCK cycles.
  task automatic bs_check_bypass();
    logic wdata[], rdata[];
    logic [15:0] pat = 16'hB38F;
    bit ok = 1;
    bs_set_ir(BsBypass);
    wdata = new[16 + BypassChain];
    foreach (wdata[i]) wdata[i] = (i < 16) ? pat[i] : 1'b0;
    i_vip.jtag_dbg.jtag.shift_dr();
    i_vip.jtag_dbg.jtag.readwrite_bits(rdata, wdata, 1);
    i_vip.jtag_dbg.jtag.update_dr(1'b0);
    for (int i = 0; i < 16; i++) if (rdata[i + BypassChain] !== pat[i]) ok = 0;
    bs_check($sformatf("BYPASS: chain of %0d bypass bits", BypassChain), ok);
  endtask

  // Wait until gpio_io[lsb +: 8] == val, or time out.
  task automatic bs_wait_gpio(input int unsigned lsb, input logic [7:0] val, output bit ok);
    ok = 0;
    fork
      begin wait (gpio_io[lsb +: 8] === val); ok = 1; end
      #(BsTimeout);
    join_any
    disable fork;
  endtask

  // Part A: JTAG only, core still asleep in the bootrom (all GPIOs are inputs)
  task automatic bs_part_a();
    logic [BsrLen-1:0] vec, cap;

    $display("@%t | [BSCAN] Part A: BYPASS, SAMPLE, EXTEST", $time);
    bs_check_bypass();

    // SAMPLE: the BSR captures the pins driven by the testbench (pattern and its inverse)
    bs_set_ir(BsSamplePreload);
    for (int p = 0; p < 2; p++) begin
      gpio_drv_en = ~32'h0000_00F0;               // pins 7:4 follow 3:0 (loopback)
      gpio_drv    = (p == 0) ? 32'hC35A_9609 : ~32'hC35A_9609;
      #(100ns);
      bs_scan_dr('0, cap);
      bs_check($sformatf("SAMPLE: gpio cells = pins (0x%08h)", gpio_io),
               cap[BsGpio +: GpioCount] === gpio_io);
    end
    bs_check("SAMPLE: uart_rx cell = pin (1)", cap[BsUartRx]   === uart_rx);
    bs_check("SAMPLE: testmode cell = 0",      cap[BsTestmode] === 1'b0);
    bs_check("SAMPLE: status/unused cells = pins",
             cap[BsStatus] === status && cap[BsUnused +: 4] === unused);
    gpio_drv_en = '0;

    // EXTEST: preload, then the BSR drives the output pads (uart_tx kept at idle 1)
    for (int p = 0; p < 2; p++) begin
      vec = '0;
      vec[BsUartTx]      = 1'b1;
      vec[BsStatus]      = (p == 0);
      vec[BsUnused +: 4] = (p == 0) ? 4'b1010 : 4'b0101;
      if (p == 0) begin
        bs_set_ir(BsSamplePreload);
        bs_scan_dr(vec, cap);
        bs_set_ir(BsExtest);
      end else begin
        bs_scan_dr(vec, cap);
      end
      #(100ns);
      bs_check($sformatf("EXTEST: status=%0b unused=%4b driven from the BSR",
                         vec[BsStatus], vec[BsUnused +: 4]),
               status === vec[BsStatus] && unused === vec[BsUnused +: 4] && uart_tx === 1'b1);
    end
    bs_set_ir(BsBypass);
    #(100ns);
    bs_check("BYPASS: status back to the core (0)", status === 1'b0);
  endtask

  // Part B: with test_bscan running on the core
  task automatic bs_part_b();
    logic [BsrLen-1:0] vec, cap;
    bit ok;

    $display("@%t | [BSCAN] Part B: SAMPLE of core outputs, INTEST", $time);
    bs_wait_gpio(8, BscanReady, ok);
    bs_check("core drives READY on gpio[15:8]", ok);

    bs_set_ir(BsSamplePreload);
    bs_scan_dr('0, cap);
    bs_check($sformatf("SAMPLE: gpio[15:8] cells = core outputs (0x%02h)", cap[BsGpio + 8 +: 8]),
             cap[BsGpio + 8 +: 8] === BscanReady);

    // GO through the pins, core starts echoing gpio[23:16] (pins: 0x00) to gpio[15:8]
    gpio_drv[31:16] = {BscanGo, 8'h00};
    gpio_drv_en     = 32'hFFFF_0000;
    bs_wait_gpio(8, 8'h00, ok);
    bs_check("core echoes gpio[23:16] pins (0x00)", ok);

    // INTEST: the core inputs come from the BSR (gpio[23:16] = 0x3C), not from the pins
    vec = '0;
    vec[BsUartRx]          = 1'b1;               // UART idle
    vec[BsTestmode]        = 1'b0;
    vec[BsGpio + 16 +: 16] = {BscanGo, 8'h3C};
    bs_set_ir(BsSamplePreload);
    bs_scan_dr(vec, cap);
    bs_set_ir(BsIntest);
    bs_wait_gpio(8, 8'h3C, ok);
    bs_check("INTEST: core reads gpio[23:16] from the BSR (echo 0x3C on the pins)", ok);
    bs_scan_dr(vec, cap);
    bs_check($sformatf("INTEST: gpio[15:8] cells capture core outputs (0x%02h)", cap[BsGpio + 8 +: 8]),
             cap[BsGpio + 8 +: 8] === 8'h3C);

    // Back to the pins, then let the program finish
    bs_set_ir(BsBypass);
    bs_wait_gpio(8, 8'h00, ok);
    bs_check("BYPASS: core reads the pins again (echo 0x00)", ok);
    gpio_drv[31:24] = BscanDone;
  endtask

  ////////////////////////////////////////////////////////////////////////////
  //  OBI crossbar JTAG isolation test (+obi_jtag_test)
  ////////////////////////////////////////////////////////////////////////////
  // obi_jtag TAP instruction XcnctIsolation (IR 1): the OBI cuts around the main crossbar
  // run on TCK and form one scan chain, and the crossbar address map comes from a JTAG
  // register. DR chain (TDI -> TDO) in the obi_jtag TAP:
  //   isolation register (addr map, en_default_idx, default_idx) -> TDO stage ->
  //   cuts at managers 0..3 (A, R) -> cuts at subordinates 0..4 (A, R)
  // A cut cell holds only channel data (no valid): Capture loads the cut input, Update
  // drives the cut output. With no request anywhere, every subordinate-side arbiter
  // passes manager 3's A channel, so data injected into manager cut 3 is captured only by
  // the subordinate cut it decodes to (all others see '0 from the demux).
  // Run with the core asleep in the bootrom (before program load).

  localparam int unsigned XbarMgrs  = croc_pkg::NumXbarManagers;        // 4
  localparam int unsigned XbarSubs  = croc_pkg::NumXbarSubordinates;    // 5
  localparam int unsigned XbarRules = $size(croc_pkg::CrocAddrMap);     // 4
  localparam int unsigned MgrA      = $bits(croc_pkg::mgr_obi_a_chan_t);
  localparam int unsigned MgrR      = $bits(croc_pkg::mgr_obi_r_chan_t);
  localparam int unsigned SubA      = $bits(croc_pkg::sbr_obi_a_chan_t);
  localparam int unsigned SubR      = $bits(croc_pkg::sbr_obi_r_chan_t);
  localparam int unsigned InjMgr    = XbarMgrs - 1;   // manager whose data reaches subordinates

  localparam logic [ObiIrWidth-1:0] ObiBypass = 0;
  localparam logic [ObiIrWidth-1:0] ObiXcnct  = 1;

  // Same layout as xcnct_isol_misc_t in obi_jtag_top
  typedef struct packed {
    croc_pkg::addr_map_rule_t [XbarRules-1:0]                       addrmap;
    logic [XbarMgrs-1:0]                                            en_default_idx;
    logic [XbarMgrs-1:0][cf_math_pkg::idx_width(XbarSubs)-1:0]      default_idx;
  } xbar_isol_t;

  localparam int unsigned IsolW       = $bits(xbar_isol_t);
  localparam int unsigned CutsW       = XbarMgrs * (MgrA + MgrR) + XbarSubs * (SubA + SubR);
  localparam int unsigned ObiAfter    = 1;                       // DMI bypass
  localparam int unsigned ObiBefore   = 2;                       // bndscan bypass + TDO stage
  localparam int unsigned ObiChainLen = ObiBefore + IsolW + 1 + CutsW + ObiAfter;

  // Stream position (0 = next to TDO) of bit 0 of a cut register
  function automatic int unsigned obi_cut_pos(input bit sub_side, input int unsigned idx,
                                              input bit r_reg);
    int unsigned off, w;
    if (!sub_side) begin
      off = idx * (MgrA + MgrR) + (r_reg ? MgrA : 0);
      w   = r_reg ? MgrR : MgrA;
    end else begin
      off = XbarMgrs * (MgrA + MgrR) + idx * (SubA + SubR) + (r_reg ? SubA : 0);
      w   = r_reg ? SubR : SubA;
    end
    return ObiAfter + CutsW - off - w;
  endfunction

  localparam int unsigned ObiIsolPos = ObiAfter + CutsW + 1;   // bit 0 of the isolation register

  function automatic xbar_isol_t obi_default_isol();
    xbar_isol_t isol;
    isol.addrmap        = croc_pkg::CrocAddrMap;
    isol.en_default_idx = '1;                       // as croc_domain
    isol.default_idx    = '0;
    return isol;
  endfunction

  // Two scans with the same vector: the first updates (isolation map + manager cut A),
  // the second captures what reached the subordinate cuts. Returns the captured A
  // channels of all subordinate cuts.
  task automatic obi_inject(input xbar_isol_t isol, input croc_pkg::mgr_obi_a_chan_t a,
                            output croc_pkg::sbr_obi_a_chan_t sub_a [XbarSubs]);
    logic wdata[], rdata[];
    logic [IsolW-1:0] isol_bits = isol;
    logic [MgrA-1:0]  a_bits    = a;
    logic [SubA-1:0]  cap;
    int unsigned      p;
    wdata = new[ObiChainLen];
    foreach (wdata[i]) wdata[i] = 1'b0;
    for (int b = 0; b < IsolW; b++) wdata[ObiIsolPos + b] = isol_bits[b];
    p = obi_cut_pos(0, InjMgr, 0);
    for (int b = 0; b < MgrA; b++) wdata[p + b] = a_bits[b];
    chain_scan_dr(wdata, rdata);   // update: inject
    chain_scan_dr(wdata, rdata);   // capture: read back
    for (int s = 0; s < XbarSubs; s++) begin
      p = obi_cut_pos(1, s, 0);
      for (int b = 0; b < SubA; b++) cap[b] = rdata[p + b];
      sub_a[s] = cap;
    end
  endtask

  // Inject a write to addr from manager 3 and check that only subordinate exp captures it.
  task automatic obi_check_route(input string what, input xbar_isol_t isol,
                                 input logic [31:0] addr, input int unsigned exp);
    croc_pkg::mgr_obi_a_chan_t a;
    croc_pkg::sbr_obi_a_chan_t sub_a [XbarSubs];
    bit ok = 1;
    string got = "";
    a            = '0;
    a.addr       = addr;
    a.we         = 1'b1;
    a.be         = 4'hF;
    a.wdata      = 32'hC0DE_0000 | addr[15:0];
    a.aid        = 1'b1;
    obi_inject(isol, a, sub_a);
    // A subordinate "received" the request if any request field is non-zero. aid is not
    // used for this: obi_mux always prepends the selected manager index (3) to it.
    for (int s = 0; s < XbarSubs; s++) begin
      bit hit = (sub_a[s].addr !== '0 || sub_a[s].we !== '0 ||
                 sub_a[s].be   !== '0 || sub_a[s].wdata !== '0);
      if (hit) got = {got, $sformatf(" %0d", s)};
      if (s == exp) begin
        if (sub_a[s].addr !== a.addr || sub_a[s].we !== a.we || sub_a[s].be !== a.be ||
            sub_a[s].wdata !== a.wdata || sub_a[s].aid !== {2'(InjMgr), a.aid}) ok = 0;
      end else if (hit) ok = 0;
    end
    bs_check($sformatf("OBI %s: 0x%08h -> subordinate %0d (captured at:%s)",
                       what, addr, exp, (got == "") ? " none" : got), ok);
    if (!ok)
      for (int s = 0; s < XbarSubs; s++)
        $display("            subordinate %0d: addr=0x%08h we=%0b be=%01h wdata=0x%08h aid=%0d",
                 s, sub_a[s].addr, sub_a[s].we, sub_a[s].be, sub_a[s].wdata, sub_a[s].aid);
  endtask

  task automatic obi_test();
    logic wdata[], rdata[];
    logic [31:0] pat = 32'h9E37_79B9;
    xbar_isol_t isol;
    bit ok = 1;

    $display("@%t | [OBI-JTAG] XcnctIsolation: chain %0d bits (isol %0d, cuts %0d)",
             $time, IsolW + 1 + CutsW, IsolW, CutsW);
    chain_set_ir(BsBypass, ObiXcnct);

    // Scan-chain length and integrity: the pattern comes out after the whole chain
    wdata = new[32 + ObiChainLen];
    foreach (wdata[i]) wdata[i] = (i < 32) ? pat[i] : 1'b0;
    chain_scan_dr(wdata, rdata);
    for (int i = 0; i < 32; i++) if (rdata[i + ObiChainLen] !== pat[i]) ok = 0;
    bs_check($sformatf("OBI scan chain: %0d bits from TDI to TDO", ObiChainLen), ok);

    // Routing with the normal address map
    isol = obi_default_isol();
    obi_check_route("periph",            isol, 32'h0300_0000, croc_pkg::XbarPeriph);
    obi_check_route("user",              isol, 32'h2000_0000, croc_pkg::XbarUser);
    obi_check_route("SRAM bank 0",       isol, 32'h1000_0010, croc_pkg::XbarBank0);
    obi_check_route("SRAM bank 1",       isol, 32'h1000_0828, croc_pkg::XbarBank0 + 1);
    obi_check_route("unmapped->default", isol, 32'h9000_0000, croc_pkg::XbarError);

    // Address map from JTAG: swap the two SRAM banks
    foreach (isol.addrmap[r]) begin
      if (isol.addrmap[r].idx == croc_pkg::XbarBank0)          isol.addrmap[r].idx = croc_pkg::XbarBank0 + 1;
      else if (isol.addrmap[r].idx == croc_pkg::XbarBank0 + 1) isol.addrmap[r].idx = croc_pkg::XbarBank0;
    end
    obi_check_route("JTAG map, banks swapped", isol, 32'h1000_0828, croc_pkg::XbarBank0);
    obi_check_route("JTAG map, banks swapped", isol, 32'h1000_0010, croc_pkg::XbarBank0 + 1);

    // Default index from JTAG: unmapped addresses of manager 3 go to periph
    isol = obi_default_isol();
    isol.default_idx[InjMgr] = croc_pkg::XbarPeriph;
    obi_check_route("JTAG default_idx=periph", isol, 32'h9000_0000, croc_pkg::XbarPeriph);

    // Leave isolation: crossbar back on the system clock and the hard-wired map
    chain_set_ir(BsBypass, ObiBypass);
    $display("@%t | [OBI-JTAG] Isolation off", $time);
  endtask

  logic [31:0] tb_data;
  bit bscan_test;
  bit obi_jtag_test;

  initial begin
    $timeformat(-9, 0, "ns", 12);
    bscan_test    = $test$plusargs("bscan_test");
    obi_jtag_test = $test$plusargs("obi_jtag_test");

    #ClkPeriodSys;

    i_vip.jtag_init();
    if (bscan_test)    bs_part_a();
    if (obi_jtag_test) obi_test();

    // The bus must still work after isolation: this write is read back over the crossbar

    i_vip.jtag_write_reg32(SramBaseAddr, 32'h1234_5678, 1'b1);
    i_vip.jtag_load_hex(binary_path);

    $display("@%t | [CORE] Waking core via CLINT msip", $time);
    i_vip.jtag_write_reg32(ClintBaseAddr, 32'h1);

    i_vip.jtag_halt();
    i_vip.jtag_resume();

    if (bscan_test) bs_part_b();
    if (bscan_test || obi_jtag_test) begin
      if (bs_errors == 0)
        $display("@%t | [JTAG-TEST] All %0d checks passed", $time, bs_checks);
      else
        $error("@%t | [JTAG-TEST] %0d of %0d checks FAILED", $time, bs_errors, bs_checks);
    end

    $display("@%t | [CORE] Wait for end of code...", $time);
    i_vip.jtag_wait_for_eoc(tb_data);

    repeat (50) @(posedge sys_clk);
    $finish();
  end

endmodule
