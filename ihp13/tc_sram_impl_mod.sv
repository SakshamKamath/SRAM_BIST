// Copyright 2023 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Thomas Benz <tbenz@iis.ee.ethz.ch>
// - Tobias Senti <tsenti@student.ethz.ch>
// - Paul Scheffler <paulsc@iis.ee.ethz.ch>

module tc_sram_blackbox #(
  parameter int unsigned NumWords     = 32'd0,
  parameter int unsigned DataWidth    = 32'd0,
  parameter int unsigned ByteWidth    = 32'd0,
  parameter int unsigned NumPorts     = 32'd0,
  parameter int unsigned Latency      = 32'd0,
  parameter              SimInit      = "none",
  parameter bit          PrintSimCfg  = 1'b0,
  parameter              ImplKey      = "none"
) ();
endmodule

module tc_sram_impl #(
  parameter int unsigned NumWords     = 32'd1024,
  parameter int unsigned DataWidth    = 32'd128,
  parameter int unsigned ByteWidth    = 32'd8,
  parameter int unsigned NumPorts     = 32'd2,
  parameter int unsigned Latency      = 32'd1,
  parameter              SimInit      = "none",
  parameter bit          PrintSimCfg  = 1'b0,
  parameter              ImplKey      = "none",
  parameter type         impl_in_t    = logic,
  parameter type         impl_out_t   = logic,
  parameter impl_out_t   ImplOutSim   = '0,
  parameter int unsigned IdCodeWidth  = 32'd32,
  parameter int unsigned IdCodeVal    = 32'h1080_0786,
  parameter int unsigned FifoDepth    = 32'd2,  // Depth is 2**FifoDepth
  parameter int unsigned IrWidth      = 32'd4,
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth,
  parameter type         addr_t    = logic [AddrWidth-1:0],
  parameter type         data_t    = logic [DataWidth-1:0],
  parameter type         be_t      = logic [BeWidth-1:0]
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,

  input  impl_in_t             impl_i,
  output impl_out_t            impl_o,

  input  logic  [NumPorts-1:0] req_i,
  input  logic  [NumPorts-1:0] we_i,
  input  addr_t [NumPorts-1:0] addr_i,
  input  data_t [NumPorts-1:0] wdata_i,
  input  be_t   [NumPorts-1:0] be_i,

  output data_t [NumPorts-1:0] rdata_o,


  // JTAG Interface
  input  logic         testmode_i,
  input  logic         tck_i,    // JTAG test clock pad
  input  logic         tms_i,    // JTAG test mode select pad
  input  logic         trst_ni,  // JTAG test reset pad
  input  logic         td_i,     // JTAG test data input pad
  output logic         td_o,     // JTAG test data output pad
  output logic         tdo_oe_o  // Data out output enable
);

  localparam P1L1 = (NumPorts == 1 & Latency == 1);

  // Assemble bit mask
  data_t [NumPorts-1:0] bm;

  for (genvar p = 0; p < NumPorts; ++p) begin : gen_bm_ports
      for (genvar b = 0; b < DataWidth; ++b) begin : gen_bm_bits
        assign bm[p][b] = be_i[p][b/ByteWidth];
      end
  end

  // We drive a static value for `impl_o` in behavioral simulation.
  assign impl_o = ImplOutSim;



  //----------------- BIST Related Modules ------------------------
  // Signals required for connecting
  logic mbist_start, mbist_erraddr_read;

  // Signals driven by march controller
  logic [AddrWidth-1:0] march_addr;
  logic [DataWidth-1:0] march_wdata;
  logic [DataWidth-1:0] march_bitmask;
  logic                 march_memen;
  logic                 march_memwen;
  logic                 march_memren;
  logic                 march_busy;
  logic                 march_fail;
  logic                 march_done;
  logic [AddrWidth-1:0] mbist_erraddr;

  logic [DataWidth-1:0] march_rdata;
  assign march_rdata = rdata_o;


  jtag_tap_top #(
    .P_IR_WIDTH(IrWidth),
    .P_IDCODE_WIDTH(IdCodeWidth),
    .P_ADDR_WIDTH(AddrWidth),
    .IDCODE_VAL(IdCodeVal)
  ) i_jtag_tap_top (
    .tclk_i                (tck_i),
    .tms_i                 (tms_i),
    .trst_ni               (trst_ni),
    .tdi_i                 (td_i),
    .mbist_erraddr_i       (mbist_erraddr),
    .mbist_fifo_notempty_i (march_fail),
    .tdo_o                 (td_o),
    .tdo_en_o              (tdo_en_o),
    .mbist_start_o         (mbist_start),
    .mbist_erraddr_read_o  (mbist_erraddr_read)
  );


  march_bist_controller #(
    .P_DATA_WIDTH(DataWidth),
    .P_ADDR_WIDTH(AddrWidth),
    .P_FIFO_DEPTH(FifoDepth)
  ) u_bist_controller (
    .tdi_i            (td_i),
    .tms_i            (tms_i),
    .tclk_i           (tck_i),
    .trst_ni          (trst_ni),
    .tdo_o            (),
    .start_i          (mbist_start),
    .erraddr_rd_i     (mbist_erraddr_read),
    .busy_o           (march_busy),
    .done_o           (march_done),
    .fail_o           (march_fail),
    .rdata_i          (march_rdata),
    .memaddr_o        (march_addr),
    .wdata_o          (march_wdata),
    .membm_o          (march_bitmask),   
    .memen_o          (march_memen),
    .memren_o         (march_memren),
    .memwen_o         (march_memwen),
    .mbist_erraddr_o  (mbist_erraddr)
  );



  // Generate desired cuts
  if (NumWords == 64 && DataWidth == 64 && P1L1) begin: gen_64x64xBx1
     
      
    //----------------- IHP SRAM Macro ------------------------
    
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;


    RM_IHPSG13_1P_64x64_c2_bm_bist i_cut (
      .A_CLK   ( clk_i    ),
      .A_DLY   ( impl_i  ),
      .A_ADDR  ( addr_i [0][5:0] ),
      .A_BM    ( bm64     ),
      .A_MEN   ( req_i    ),
      .A_WEN   ( we_i     ),
      .A_REN   ( ~we_i    ),
      .A_DIN   ( wdata64  ),
      .A_DOUT       ( rdata64       ),
      .A_BIST_CLK   ( tck_i         ),
      .A_BIST_ADDR  ( march_addr    ),
      .A_BIST_DIN   ( march_wdata   ),
      .A_BIST_BM    ( march_bitmask ),
      .A_BIST_MEN   ( march_memen   ),
      .A_BIST_WEN   ( march_memwen  ),
      .A_BIST_REN   ( march_memren  ),
      .A_BIST_EN    ( march_busy    )
    );

  end else if (NumWords == 256 & DataWidth == 64 & P1L1) begin : gen_256x64xBx1
  
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut (
      .A_CLK   ( clk_i    ),
      .A_DLY   ( impl_i  ),
      .A_ADDR  ( addr_i [0][7:0] ),
      .A_BM    ( bm64     ),
      .A_MEN   ( req_i    ),
      .A_WEN   ( we_i     ),
      .A_REN   ( ~we_i    ),
      .A_DIN        ( wdata64  ),
      .A_DOUT       ( rdata64  ),
      .A_BIST_CLK   ( tck_i         ),
      .A_BIST_ADDR  ( march_addr    ),
      .A_BIST_DIN   ( march_wdata   ),
      .A_BIST_BM    ( march_bitmask ),
      .A_BIST_MEN   ( march_memen   ),
      .A_BIST_WEN   ( march_memwen  ),
      .A_BIST_REN   ( march_memren  ),
      .A_BIST_EN    ( march_busy    )
    );

  end else if (NumWords == 512 & DataWidth == 64 & P1L1) begin : gen_512x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_512x64_c2_bm_bist i_cut (
      .A_CLK   ( clk_i    ),
      .A_DLY   ( impl_i  ),
      .A_ADDR  ( addr_i [0][8:0] ),
      .A_BM    ( bm64     ),
      .A_MEN   ( req_i    ),
      .A_WEN   ( we_i     ),
      .A_REN   ( ~we_i    ),
      .A_DIN        ( wdata64  ),
      .A_DOUT       ( rdata64  ),
      .A_BIST_CLK   ( tck_i         ),
      .A_BIST_ADDR  ( march_addr    ),
      .A_BIST_DIN   ( march_wdata   ),
      .A_BIST_BM    ( march_bitmask ),
      .A_BIST_MEN   ( march_memen   ),
      .A_BIST_WEN   ( march_memwen  ),
      .A_BIST_REN   ( march_memren  ),
      .A_BIST_EN    ( march_busy    )
    );

  end else if (NumWords == 1024 & DataWidth == 64 & P1L1) begin : gen_1024x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_1024x64_c2_bm_bist i_cut (
       .A_CLK   ( clk_i    ),
       .A_DLY   ( impl_i  ),
       .A_ADDR  ( addr_i [0][9:0] ),
       .A_BM    ( bm64     ),
       .A_MEN   ( req_i    ),
       .A_WEN   ( we_i     ),
       .A_REN   ( ~we_i    ),
       .A_DIN        ( wdata64  ),
       .A_DOUT       ( rdata64  ),
       .A_BIST_CLK   ( tck_i         ),
       .A_BIST_ADDR  ( march_addr    ),
       .A_BIST_DIN   ( march_wdata   ),
       .A_BIST_BM    ( march_bitmask ),
       .A_BIST_MEN   ( march_memen   ),
       .A_BIST_WEN   ( march_memwen  ),
       .A_BIST_REN   ( march_memren  ),
       .A_BIST_EN    ( march_busy    )
      );

  end else if (NumWords == 2048 & DataWidth == 64 & P1L1) begin : gen_2048x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_2048x64_c2_bm_bist i_cut (
       .A_CLK   ( clk_i    ),
       .A_DLY   ( impl_i   ),
       .A_ADDR  ( addr_i [0][10:0] ),
       .A_BM    ( bm64     ),
       .A_MEN   ( req_i    ),
       .A_WEN   ( we_i     ),
       .A_REN   ( ~we_i    ),
       .A_DIN        ( wdata64  ),
       .A_DOUT       ( rdata64  ),
       .A_BIST_CLK   ( tck_i         ),
       .A_BIST_ADDR  ( march_addr    ),
       .A_BIST_DIN   ( march_wdata   ),
       .A_BIST_BM    ( march_bitmask ),
       .A_BIST_MEN   ( march_memen   ),
       .A_BIST_WEN   ( march_memwen  ),
       .A_BIST_REN   ( march_memren  ),
       .A_BIST_EN    ( march_busy    )
      );
  end else if (NumWords == 512 && DataWidth == 32 && P1L1) begin: gen_512x32xBx1
    logic [63:0] wdata64, rdata64, bm64;
    logic [63:0] wdata64_bist, bm64_bist;
    logic sel_d, sel_q;

    //Adding bist write signals too

    // muxing neighboring bits instead of upper/lower 32bit reduces routing
    always_comb begin : gen_bit_interleaving
      for (int i = 0; i < 32; i++) begin
          // duplicate each bit
          wdata64[2*i]   = wdata_i[0][i]; // even bits (active if addr LSB is 0)
          bm64[2*i]      = bm[0][i] & ~addr_i[0][0];
          wdata64[2*i+1] = wdata_i[0][i]; // odd bits  (active if addr LSB is 1)
          bm64[2*i+1]    = bm[0][i] & addr_i[0][0];

          wdata64_bist[2*i]   = march_wdata[i];
          bm64_bist[2*i]      = march_bitmask[i] & ~march_addr[0];
          wdata64_bist[2*i+1] = march_wdata[i];
          bm64_bist[2*i+1]    = march_bitmask[i] & march_addr[0];

          if(~sel_q) begin
            rdata_o[0][i] = rdata64[2*i];   // even bits
          end else begin
            rdata_o[0][i] = rdata64[2*i+1]; // odd bitss
          end
      end
    end

    // LSB needed for read in next cycle
    assign sel_d = march_busy ? march_addr[0] : addr_i[0][0];

    tc_clk_mux2 i_dft_tck_mux (
      .clk0_i    ( clk_i      ),
      .clk1_i    ( tck_i      ), // bypass the inverted clock for testing
      .clk_sel_i ( march_busy ),
      .clk_o     ( tck        )
    );

    always_ff @(posedge tck or negedge rst_ni) begin : proc_mem_sel_q
      if(~rst_ni)             sel_q <= '0;
      else if (req_i & ~we_i) sel_q <= sel_d;
    end

    RM_IHPSG13_1P_256x64_c2_bm_bist i_cut (
     .A_CLK   ( clk_i   ),
     .A_DLY   ( impl_i  ),
     .A_ADDR  ( addr_i [0][8:1] ),
     .A_BM    ( bm64    ),
     .A_MEN   ( req_i   ),
     .A_WEN   ( we_i    ),
     .A_REN   ( ~we_i   ),
     .A_DIN        ( wdata64 ),
     .A_DOUT       ( rdata64 ),
     .A_BIST_CLK   ( tck_i            ),
     .A_BIST_ADDR  ( march_addr[8:1]  ),
     .A_BIST_DIN   ( wdata64_bist     ),
     .A_BIST_BM    ( bm64_bist        ),
     .A_BIST_MEN   ( march_memen      ),
     .A_BIST_WEN   ( march_memwen     ),
     .A_BIST_REN   ( march_memren     ),
     .A_BIST_EN    ( march_busy       )
    );

  end else if (NumWords == 1024 && DataWidth == 32 && P1L1) begin: gen_1024x32xBx1
    logic [63:0] wdata64, rdata64, bm64;
    logic [63:0] wdata64_bist, bm64_bist;
    logic sel_d, sel_q;

    // muxing neighboring bits instead of upper/lower 32bit reduces routing
    always_comb begin : gen_bit_interleaving
      for (int i = 0; i < 32; i++) begin
   // duplicate each bit
          wdata64[2*i]   = wdata_i[0][i]; // even bits (active if addr LSB is 0)
          bm64[2*i]      = bm[0][i] & ~addr_i[0][0];
          wdata64[2*i+1] = wdata_i[0][i]; // odd bits  (active if addr LSB is 1)
          bm64[2*i+1]    = bm[0][i] & addr_i[0][0];

          wdata64_bist[2*i]   = march_wdata[i];
          bm64_bist[2*i]      = march_bitmask[i] & ~march_addr[0];
          wdata64_bist[2*i+1] = march_wdata[i];
          bm64_bist[2*i+1]    = march_bitmask[i] & march_addr[0];

          if(~sel_q) begin
            rdata_o[0][i] = rdata64[2*i];   // even bits
          end else begin
            rdata_o[0][i] = rdata64[2*i+1]; // odd bitss
          end
      end
    end

    // LSB needed for read in next cycle
    assign sel_d = march_busy ? march_addr[0] : addr_i[0][0];

    tc_clk_mux2 i_dft_tck_mux (
      .clk0_i    ( clk_i      ),
      .clk1_i    ( tck_i      ), // bypass the inverted clock for testing
      .clk_sel_i ( march_busy ),
      .clk_o     ( tck        )
    );

    always_ff @(posedge tck or negedge rst_ni) begin : proc_mem_sel_q
      if(~rst_ni)             sel_q <= '0;
      else if (req_i & ~we_i) sel_q <= sel_d;
    end


    RM_IHPSG13_1P_512x64_c2_bm_bist i_cut (
     .A_CLK   ( clk_i   ),
     .A_DLY   ( impl_i  ),
     .A_ADDR  ( addr_i [0][9:1] ),
     .A_BM    ( bm64    ),
     .A_MEN   ( req_i   ),
     .A_WEN   ( we_i    ),
     .A_REN   ( ~we_i   ),
     .A_DIN        ( wdata64 ),
     .A_DOUT       ( rdata64 ),
     .A_BIST_CLK   ( tck_i            ),
     .A_BIST_ADDR  ( march_addr[9:1]  ),
     .A_BIST_DIN   ( wdata64_bist     ),
     .A_BIST_BM    ( bm64_bist        ),
     .A_BIST_MEN   ( march_memen      ),
     .A_BIST_WEN   ( march_memwen     ),
     .A_BIST_REN   ( march_memren     ),
     .A_BIST_EN    ( march_busy       )
    );    
  end else if (NumWords == 2048 && DataWidth == 32 && P1L1) begin: gen_2048x32xBx1
    logic [63:0] wdata64, rdata64, bm64;
    logic [63:0] wdata64_bist, bm64_bist;

    logic sel_d, sel_q;

    // muxing neighboring bits instead of upper/lower 32bit reduces routing
    always_comb begin : gen_bit_interleaving
      for (int i = 0; i < 32; i++) begin
   // duplicate each bit
          wdata64[2*i]   = wdata_i[0][i]; // even bits (active if addr LSB is 0)
          bm64[2*i]      = bm[0][i] & ~addr_i[0][0];
          wdata64[2*i+1] = wdata_i[0][i]; // odd bits  (active if addr LSB is 1)
          bm64[2*i+1]    = bm[0][i] & addr_i[0][0];

          wdata64_bist[2*i]   = march_wdata[i];
          bm64_bist[2*i]      = march_bitmask[i] & ~march_addr[0];
          wdata64_bist[2*i+1] = march_wdata[i];
          bm64_bist[2*i+1]    = march_bitmask[i] & march_addr[0];

          if(~sel_q) begin
            rdata_o[0][i] = rdata64[2*i];   // even bits
          end else begin
            rdata_o[0][i] = rdata64[2*i+1]; // odd bitss
          end
      end
    end

    // LSB needed for read in next cycle
    assign sel_d = march_busy ? march_addr[0] : addr_i[0][0];

    tc_clk_mux2 i_dft_tck_mux (
      .clk0_i    ( clk_i      ),
      .clk1_i    ( tck_i      ), // bypass the inverted clock for testing
      .clk_sel_i ( march_busy ),
      .clk_o     ( tck        )
    );

    always_ff @(posedge tck or negedge rst_ni) begin : proc_mem_sel_q
      if(~rst_ni)             sel_q <= '0;
      else if (req_i & ~we_i) sel_q <= sel_d;
    end

    RM_IHPSG13_1P_1024x64_c2_bm_bist i_cut (
     .A_CLK   ( clk_i   ),
     .A_DLY   ( impl_i  ),
     .A_ADDR  ( addr_i [0][10:1] ),
     .A_BM    ( bm64    ),
     .A_MEN   ( req_i   ),
     .A_WEN   ( we_i    ),
     .A_REN   ( ~we_i   ),
     .A_DIN        ( wdata64 ),
     .A_DOUT       ( rdata64 ),
     .A_BIST_CLK   ( tck_i           ),
     .A_BIST_ADDR  ( march_addr[10:1] ),
     .A_BIST_DIN   ( wdata64_bist    ),
     .A_BIST_BM    ( bm64_bist       ),
     .A_BIST_MEN   ( march_memen     ),
     .A_BIST_WEN   ( march_memwen    ),
     .A_BIST_REN   ( march_memren    ),
     .A_BIST_EN    ( march_busy      )
    );

  end else if (NumWords == 2048 & DataWidth == 64 & P1L1) begin : gen_2048x64xBx1
    logic [63:0] wdata64, rdata64, bm64;

    assign rdata_o = rdata64;
    assign wdata64 = wdata_i;
    assign bm64    = bm;

    RM_IHPSG13_1P_2048x64_c2_bm_bist i_cut (
       .A_CLK   ( clk_i    ),
       .A_DLY   ( impl_i   ),
       .A_ADDR  ( addr_i [0][10:0] ),
       .A_BM    ( bm64     ),
       .A_MEN   ( req_i    ),
       .A_WEN   ( we_i     ),
       .A_REN   ( ~we_i    ),
       .A_DIN        ( wdata64  ),
       .A_DOUT       ( rdata64  ),
       .A_BIST_CLK   ( tck_i         ),
       .A_BIST_ADDR  ( march_addr    ),
       .A_BIST_DIN   ( march_wdata   ),
       .A_BIST_BM    ( march_bitmask ),
       .A_BIST_MEN   ( march_memen   ),
       .A_BIST_WEN   ( march_memwen  ),
       .A_BIST_REN   ( march_memren  ),
       .A_BIST_EN    ( march_busy    )
      );

  end else begin : gen_blackbox

  `ifndef SYNTHESIS
    initial $fatal("No tc_sram for %m: NumWords %0d, DataWidth %0d NumPorts %0d, Latency %0d",
        NumWords, DataWidth, NumPorts);
  `endif

  // Instantiate a non-linkable blackbox with parameters for debugging
  `ifdef SYNTHESIS
    (* dont_touch = "true" *)
    tc_sram_blackbox #(
      .NumWords     ( NumWords    ),
      .DataWidth    ( DataWidth   ),
      .ByteWidth    ( ByteWidth   ),
      .NumPorts     ( NumPorts    ),
      .Latency      ( Latency     ),
      .SimInit      ( SimInit     ),
      .PrintSimCfg  ( PrintSimCfg ),
      .ImplKey      ( ImplKey     )
    ) i_sram_blackbox ();
  `endif

end

endmodule
