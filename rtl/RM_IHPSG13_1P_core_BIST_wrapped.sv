module RM_IHPSG13_1P_core_BIST_wrapped #(
    parameter P_DATA_WIDTH    = 24,
    parameter P_ADDR_WIDTH    = 14,
    parameter P_IR_WIDTH      = 4,
    parameter P_IDCODE_WIDTH  = 32,
    parameter IDCODE_VAL      = 32'h1080_0786
)
    (
        A_ADDR,
        A_DIN,
        A_BM,
        A_MEN,
        A_WEN,
        A_REN,
        A_CLK,
        A_DLY,
        A_DOUT,

        A_BIST_EN,
        A_BIST_ADDR,
        A_BIST_DIN,
        A_BIST_BM,
        A_BIST_MEN,
        A_BIST_WEN,
        A_BIST_REN,
        A_BIST_CLK

    );


input wire  [P_ADDR_WIDTH-1:0]  A_ADDR;
input wire  [P_DATA_WIDTH-1:0]  A_DIN;
input wire  [P_DATA_WIDTH-1:0]  A_BM;
input wire                      A_MEN;
input wire                      A_WEN;
input wire                      A_REN;
input wire                      A_CLK;
input wire                      A_DLY;
output wire [P_DATA_WIDTH-1:0]  A_DOUT;

input wire                      A_BIST_EN;
input wire  [P_ADDR_WIDTH-1:0]  A_BIST_ADDR;
input wire  [P_DATA_WIDTH-1:0]  A_BIST_DIN;
input wire  [P_DATA_WIDTH-1:0]  A_BIST_BM;
input wire                      A_BIST_MEN;
input wire                      A_BIST_WEN;
input wire                      A_BIST_REN;
input wire                      A_BIST_CLK;



jtag_tap_top #(
    .P_IR_WIDTH(P_IR_WIDTH),
    .P_IDCODE_WIDTH(P_IDCODE_WIDTH),
    .IDCODE_VAL(IDCODE_VAL)
) i_jtag_tap_top (
    .tclk_i        (A_BIST_CLK),
    .tms_i         (),
    .trst_ni       (),
    .tdi_i         (),
    .tdo_o         (),
    .tdo_en_o      (),
    .mbist_start_o ()
);


  march_bist_controller #(
      .P_DATA_WIDTH(P_DATA_WIDTH),
      .P_ADDR_WIDTH(P_ADDR_WIDTH),
      .P_FIFO_DEPTH(P_FIFO_DEPTH)
  ) u_bist_controller (
      .tdi_i    (tdi),
      .tms_i    (tms),
      .tclk_i   (tclk),
      .trst_ni  (trst_n),
      .tdo_o    (tdo),
      .start_i  (start),
      .busy_o   (busy),
      .done_o   (done),
      .fail_o   (fail),
      .rdata_i  (rdata),
      .memaddr_o(memaddr),
      .wdata_o  (wdata),
      .membm_o  (membm),   
      .memen_o  (memen),
      .memren_o (memren),
      .memwen_o (memwen)
  );



  
 SRAM_1P_behavioral_bm_bist #(
      .P_DATA_WIDTH      (P_DATA_WIDTH),
      .P_ADDR_WIDTH      (P_ADDR_WIDTH),
      .EN_FAULT_INJECTION(1'b1),         // Master Fault Switch ON
      .MASK_SAF_1        (MY_SAF_1),
      .MASK_TF_01        (MY_TF_01),
      .MASK_RDF          (MY_RDF)
  ) u_sram_mem (
      .A_ADDR    (memaddr),
      .A_DIN     (wdata),
      .A_BM      (membm_32b),
      .A_MEN     (memen),
      .A_WEN     (memwen),
      .A_REN     (memren),
      .A_CLK     (tclk),
      .A_DLY     (1'b0),
      .A_DOUT    (rdata),

      .A_BIST_EN  (),
      .A_BIST_ADDR(),
      .A_BIST_DIN (),
      .A_BIST_BM  (),
      .A_BIST_MEN (),
      .A_BIST_WEN (),
      .A_BIST_REN (),
      .A_BIST_CLK ()
  );





endmodule