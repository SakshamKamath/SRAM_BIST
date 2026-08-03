module fifo #(
    parameter P_FIFO_DEPTH = 2,
    parameter P_DATA_WIDTH = 32

) 
    (
        input                     clk_i,
        input                     rst_ni,
        input                     wen_i,
        input                     ren_i,
        input  [P_DATA_WIDTH-1:0] data_i,
        output [P_DATA_WIDTH-1:0] data_o,
        output                    full_o,
        output                    empty_o
    );

    localparam MEMDEPTH = 1 << P_FIFO_DEPTH;

    logic [MEMDEPTH-1:0][P_DATA_WIDTH-1:0]memfifo;
    logic [P_FIFO_DEPTH:0]wr_ptr_d, wr_ptr_q, rd_ptr_d, rd_ptr_q;

    always_ff @(posedge clk_i) begin
        if(!rst_ni) begin
            wr_ptr  <= '0;
            rd_ptr  <= '0;
            memfifo <= '0;
        end else begin
            wr_ptr_q <= wr_ptr_d;
            rd_ptr_q <= rd_ptr_d;
        end
    end
    
    always_comb begin
        if (wr_en && !full) begin
            wr_ptr_d = wr_ptr_q + 1'b1;
        end
        if (rd_en && !empty) begin
            rd_ptr_d = rd_ptr_q + 1'b1;
        end
    end

    always_ff @(posedge clk) begin
        if (wr_en && !full) begin
        memfifo[w_ptr[ADDR_WIDTH-1:0]] <= data_i;
        end
    end

    // ---------------------------------------------------------------------------
    // Memory Read Operation
    // ---------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rd_en && !empty) begin
        data_o <= memfifo[r_ptr[ADDR_WIDTH-1:0]];
        end
    end

    assign empty_o = (w_ptr == r_ptr);

    // Full: Lower address bits match, but MSBs differ (indicating 1 rollover difference)
    assign full_o  = (w_ptr[ADDR_WIDTH-1:0] == r_ptr[ADDR_WIDTH-1:0]) && 
                     (w_ptr[ADDR_WIDTH]     != r_ptr[ADDR_WIDTH]);

endmodule