////////////////////////////////////////////////////////////////////////
//
// Extended SRAM Behavioral Model with Multi-Address & Bit-Masked Faults
//
////////////////////////////////////////////////////////////////////////

module SRAM_1P_behavioral_bm_bist (
    A_ADDR,
    A_DIN,
    A_BM,
    A_MEN,    // Memory enable input
    A_WEN,    // Common write enable input
    A_REN,    // Read enable input
    A_CLK,    // Clock input
    A_DLY,    // Delay selection signals
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

// Basic Parameters
parameter P_DATA_WIDTH = 24;
parameter P_ADDR_WIDTH = 14;
localparam MEM_DEPTH   = 2**(P_ADDR_WIDTH);

// ---------------------------------------------------------------------
// Fault Injection Control Parameters
// ---------------------------------------------------------------------
parameter EN_FAULT_INJECTION = 1'b0; // Master Enable

// Bitmask Arrays across Memory Depth [0 : MEM_DEPTH-1]
// For any address, setting bit 'i' to 1 enables the fault for bit 'i'
parameter [P_DATA_WIDTH-1:0] MASK_SAF_0  [0:MEM_DEPTH-1] = '{default: '0}; // Stuck-At 0 Mask
parameter [P_DATA_WIDTH-1:0] MASK_SAF_1  [0:MEM_DEPTH-1] = '{default: '0}; // Stuck-At 1 Mask
parameter [P_DATA_WIDTH-1:0] MASK_TF_01  [0:MEM_DEPTH-1] = '{default: '0}; // Transition Fault (Fails 0->1)
parameter [P_DATA_WIDTH-1:0] MASK_TF_10  [0:MEM_DEPTH-1] = '{default: '0}; // Transition Fault (Fails 1->0)
parameter [P_DATA_WIDTH-1:0] MASK_RDF    [0:MEM_DEPTH-1] = '{default: '0}; // Read Destructive Fault Mask
parameter [P_DATA_WIDTH-1:0] MASK_IRF    [0:MEM_DEPTH-1] = '{default: '0}; // Incorrect Read Fault Mask
parameter [P_DATA_WIDTH-1:0] MASK_DRDF   [0:MEM_DEPTH-1] = '{default: '0}; // Deceptive Read Destructive Fault Mask
parameter [P_DATA_WIDTH-1:0] MASK_WDF    [0:MEM_DEPTH-1] = '{default: '0}; // Write Destructive Fault Mask

// Coupling Fault Matrix: [Aggressor_Addr][Victim_Addr] -> Bitmask of victim bits flipped
parameter [P_DATA_WIDTH-1:0] MASK_CF_WRITE [0:MEM_DEPTH-1][0:MEM_DEPTH-1] = '{default: '{default: '0}};
parameter [P_DATA_WIDTH-1:0] MASK_CF_READ  [0:MEM_DEPTH-1][0:MEM_DEPTH-1] = '{default: '{default: '0}};

// Ports
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

// Internal Registers & Signals
reg [P_DATA_WIDTH-1:0] memory [0:MEM_DEPTH-1];
reg [P_DATA_WIDTH-1:0] dr_r;

wire [P_ADDR_WIDTH-1:0] ADDR_MUX;
wire [P_DATA_WIDTH-1:0] DIN_MUX;
wire [P_DATA_WIDTH-1:0] BM_MUX;
wire                    MEN_MUX;
wire                    WEN_MUX;
wire                    REN_MUX;
wire                    CLK_MUX;

// BIST Multiplexers
assign ADDR_MUX = (A_BIST_EN == 1'b1) ? A_BIST_ADDR : A_ADDR;
assign DIN_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_DIN  : A_DIN;
assign BM_MUX   = (A_BIST_EN == 1'b1) ? A_BIST_BM   : A_BM;
assign MEN_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_MEN  : A_MEN;
assign WEN_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_WEN  : A_WEN;
assign REN_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_REN  : A_REN;
assign CLK_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_CLK  : A_CLK;

// Internal helper variables
reg [P_DATA_WIDTH-1:0] write_data;
reg [P_DATA_WIDTH-1:0] current_mem;
integer i, v_addr;

always @(posedge CLK_MUX) begin
    if (MEN_MUX == 1'b1) begin
        
        // -----------------------------------------------------------------
        // WRITE OPERATION
        // -----------------------------------------------------------------
        if (WEN_MUX == 1'b1) begin
            current_mem = memory[ADDR_MUX];
            
            // Base byte-masked write calculation
            write_data = (current_mem & ~BM_MUX) | (DIN_MUX & BM_MUX);

            if (EN_FAULT_INJECTION) begin
                for (i = 0; i < P_DATA_WIDTH; i = i + 1) begin
                    if (BM_MUX[i]) begin
                        // Transition Fault 0 -> 1 (TF_01)
                        if (MASK_TF_01[ADDR_MUX][i] && !current_mem[i] && DIN_MUX[i]) begin
                            write_data[i] = 1'b0; 
                        end
                        // Transition Fault 1 -> 0 (TF_10)
                        if (MASK_TF_10[ADDR_MUX][i] && current_mem[i] && !DIN_MUX[i]) begin
                            write_data[i] = 1'b1; 
                        end
                        // Write Destructive Fault (WDF)
                        if (MASK_WDF[ADDR_MUX][i]) begin
                            write_data[i] = ~write_data[i];
                        end
                    end
                end

                // Trigger Coupling Faults caused by Write on victim addresses
                for (v_addr = 0; v_addr < MEM_DEPTH; v_addr = v_addr + 1) begin
                    if (MASK_CF_WRITE[ADDR_MUX][v_addr] != '0) begin
                        memory[v_addr] <= memory[v_addr] ^ MASK_CF_WRITE[ADDR_MUX][v_addr];
                    end
                end
            end

            // Apply Write Data to Memory
            memory[ADDR_MUX] <= write_data;

            // Concurrent Write-Through Read
            if (REN_MUX == 1'b1) begin
                dr_r <= write_data;
            end
        end

        // -----------------------------------------------------------------
        // READ OPERATION
        // -----------------------------------------------------------------
        else if (REN_MUX == 1'b1) begin
            dr_r <= memory[ADDR_MUX];

            if (EN_FAULT_INJECTION) begin
                // Incorrect Read Fault (IRF): Read output inverted on masked bits, cell unchanged
                if (MASK_IRF[ADDR_MUX] != '0) begin
                    dr_r <= memory[ADDR_MUX] ^ MASK_IRF[ADDR_MUX];
                end

                // Read Destructive Fault (RDF): Cell flips and wrong data is read out
                if (MASK_RDF[ADDR_MUX] != '0) begin
                    memory[ADDR_MUX] <= memory[ADDR_MUX] ^ MASK_RDF[ADDR_MUX];
                    dr_r             <= memory[ADDR_MUX] ^ MASK_RDF[ADDR_MUX];
                end

                // Deceptive Read Destructive Fault (DRDF): Correct data read out, cell flips after
                if (MASK_DRDF[ADDR_MUX] != '0) begin
                    memory[ADDR_MUX] <= memory[ADDR_MUX] ^ MASK_DRDF[ADDR_MUX];
                    dr_r             <= memory[ADDR_MUX];
                end

                // Trigger Coupling Faults caused by Read on victim addresses
                for (v_addr = 0; v_addr < MEM_DEPTH; v_addr = v_addr + 1) begin
                    if (MASK_CF_READ[ADDR_MUX][v_addr] != '0) begin
                        memory[v_addr] <= memory[v_addr] ^ MASK_CF_READ[ADDR_MUX][v_addr];
                    end
                end
            end
        end

        // -----------------------------------------------------------------
        // CONTINUOUS STUCK-AT FAULT OVERRIDE (SAF_0 and SAF_1)
        // -----------------------------------------------------------------
        if (EN_FAULT_INJECTION) begin
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                if (MASK_SAF_0[i] != '0 || MASK_SAF_1[i] != '0) begin
                    memory[i] <= (memory[i] & ~MASK_SAF_0[i]) | MASK_SAF_1[i];
                end
            end
        end

    end
end

assign A_DOUT = dr_r;

endmodule

























// ////////////////////////////////////////////////////////////////////////
// //
// // Copyright 2023 IHP PDK Authors
// // 
// // Licensed under the Apache License, Version 2.0 (the "License");
// // you may not use this file except in compliance with the License.
// // You may obtain a copy of the License at
// // 
// //     https://www.apache.org/licenses/LICENSE-2.0
// // 
// // Unless required by applicable law or agreed to in writing, software
// // distributed under the License is distributed on an "AS IS" BASIS,
// // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// // See the License for the specific language governing permissions and
// // limitations under the License.
// //
// ////////////////////////////////////////////////////////////////////////

// module SRAM_1P_behavioral_bm_bist (
//     A_ADDR,
//     A_DIN,
//     A_BM,
//     A_MEN,    // Memory enable input
//     A_WEN,    // Common write enable input
//     A_REN,    // Read enable input
//     A_CLK,    // Clock input
//     A_DLY,    // Delay selection signals
//     A_DOUT,

//     A_BIST_EN,
//     A_BIST_ADDR,
//     A_BIST_DIN,
//     A_BIST_BM,
//     A_BIST_MEN,
//     A_BIST_WEN,
//     A_BIST_REN,
//     A_BIST_CLK
// );

// // Basic Parameters
// parameter P_DATA_WIDTH = 24;
// parameter P_ADDR_WIDTH = 14;

// // ---------------------------------------------------------------------
// // Fault Injection Control Parameters
// // ---------------------------------------------------------------------
// parameter EN_FAULT_INJECTION  = 1'b0;                // Master Enable (1 = Active Faults, 0 = Normal SRAM)
// parameter FAULT_TARGET_ADDR   = {P_ADDR_WIDTH{1'b0}}; // Address/Row targeted for fault injection
// parameter FAULT_VICTIM_ADDR   = FAULT_TARGET_ADDR + 1; // Coupling Fault (CF) Victim Address

// // Enable specific fault types (Set to 1 to activate)
// parameter EN_SAF   = 1'b0;  // Stuck-At Fault
// parameter EN_RDF   = 1'b0;  // Read Destructive Fault
// parameter EN_IRF   = 1'b0;  // Incorrect Read Fault
// parameter EN_TF    = 1'b0;  // Transition Fault
// parameter EN_DRDF  = 1'b0;  // Deceptive Read Destructive Fault
// parameter EN_WDF   = 1'b0;  // Write Destructive Fault
// parameter EN_CFtr  = 1'b0;  // Coupling Fault (Transition-triggered)
// parameter EN_CFdrd = 1'b0;  // Coupling Fault (Read-triggered)
// parameter EN_CFwd  = 1'b0;  // Coupling Fault (Write-triggered)

// // Fault Behavior Values
// parameter [P_DATA_WIDTH-1:0] SAF_VAL = {P_DATA_WIDTH{1'b0}}; // Bitmask value stuck for SAF
// parameter [P_DATA_WIDTH-1:0] TF_TYPE = {P_DATA_WIDTH{1'b1}}; // 1 = Fails 0->1 transition, 0 = Fails 1->0 transition

// // Ports
// input wire  [P_ADDR_WIDTH-1:0]  A_ADDR;
// input wire  [P_DATA_WIDTH-1:0]  A_DIN;
// input wire  [P_DATA_WIDTH-1:0]  A_BM;
// input wire                      A_MEN;
// input wire                      A_WEN;
// input wire                      A_REN;
// input wire                      A_CLK;
// input wire                      A_DLY;
// output wire [P_DATA_WIDTH-1:0]  A_DOUT;

// input wire                      A_BIST_EN;
// input wire  [P_ADDR_WIDTH-1:0]  A_BIST_ADDR;
// input wire  [P_DATA_WIDTH-1:0]  A_BIST_DIN;
// input wire  [P_DATA_WIDTH-1:0]  A_BIST_BM;
// input wire                      A_BIST_MEN;
// input wire                      A_BIST_WEN;
// input wire                      A_BIST_REN;
// input wire                      A_BIST_CLK;

// // Internal Registers & Signals
// reg [P_DATA_WIDTH-1:0] memory [0:2**(P_ADDR_WIDTH)-1];
// reg [P_DATA_WIDTH-1:0] dr_r;

// wire [P_ADDR_WIDTH-1:0] ADDR_MUX;
// wire [P_DATA_WIDTH-1:0] DIN_MUX;
// wire [P_DATA_WIDTH-1:0] BM_MUX;
// wire                    MEN_MUX;
// wire                    WEN_MUX;
// wire                    REN_MUX;
// wire                    CLK_MUX;

// // BIST Multiplexers
// assign ADDR_MUX = (A_BIST_EN == 1'b1) ? A_BIST_ADDR : A_ADDR;
// assign DIN_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_DIN  : A_DIN;
// assign BM_MUX   = (A_BIST_EN == 1'b1) ? A_BIST_BM   : A_BM;
// assign MEN_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_MEN  : A_MEN;
// assign WEN_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_WEN  : A_WEN;
// assign REN_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_REN  : A_REN;
// assign CLK_MUX  = (A_BIST_EN == 1'b1) ? A_BIST_CLK  : A_CLK;

// // Internal helper logic variables
// reg [P_DATA_WIDTH-1:0] write_data;
// reg [P_DATA_WIDTH-1:0] current_mem;
// integer i;

// always @(posedge CLK_MUX) begin
//     if (MEN_MUX == 1'b1) begin
        
//         // -----------------------------------------------------------------
//         // WRITE OPERATION
//         // -----------------------------------------------------------------
//         if (WEN_MUX == 1'b1) begin
//             current_mem = memory[ADDR_MUX];
            
//             // Base byte-masked write data calculation
//             write_data = (current_mem & ~BM_MUX) | (DIN_MUX & BM_MUX);

//             // Fault Injection: Target Row
//             if (EN_FAULT_INJECTION && (ADDR_MUX == FAULT_TARGET_ADDR)) begin
                
//                 // Transition Fault (TF)
//                 if (EN_TF) begin
//                     for (i = 0; i < P_DATA_WIDTH; i = i + 1) begin
//                         if (BM_MUX[i]) begin
//                             if (TF_TYPE[i] && !current_mem[i] && DIN_MUX[i]) 
//                                 write_data[i] = 1'b0; // Block 0 -> 1 transition
//                             else if (!TF_TYPE[i] && current_mem[i] && !DIN_MUX[i]) 
//                                 write_data[i] = 1'b1; // Block 1 -> 0 transition
//                         end
//                     end
//                 end

//                 // Write Destructive Fault (WDF)
//                 if (EN_WDF) begin
//                     write_data = ~write_data; // Inverts memory contents on write operation
//                 end
//             end

//             // Apply Write Data
//             memory[ADDR_MUX] <= write_data;

//             // Fault Injection: Coupling Faults triggered by Write (CFtr / CFwd)
//             if (EN_FAULT_INJECTION && (ADDR_MUX == FAULT_TARGET_ADDR)) begin
//                 if (EN_CFtr || EN_CFwd) begin
//                     memory[FAULT_VICTIM_ADDR] <= ~memory[FAULT_VICTIM_ADDR]; // Flips victim cell
//                 end
//             end

//             // Concurrent Read (Write-Through Mode)
//             if (REN_MUX == 1'b1) begin
//                 dr_r <= write_data;
//             end
//         end

//         // -----------------------------------------------------------------
//         // READ OPERATION
//         // -----------------------------------------------------------------
//         else if (REN_MUX == 1'b1) begin
//             dr_r <= memory[ADDR_MUX];

//             // Fault Injection on Read operations
//             if (EN_FAULT_INJECTION && (ADDR_MUX == FAULT_TARGET_ADDR)) begin

//                 // Incorrect Read Fault (IRF) - Data output read incorrectly, but memory cell preserved
//                 if (EN_IRF) begin
//                     dr_r <= ~memory[ADDR_MUX];
//                 end

//                 // Read Destructive Fault (RDF) - Data in memory cell flips on read access
//                 if (EN_RDF) begin
//                     memory[ADDR_MUX] <= ~memory[ADDR_MUX];
//                     dr_r             <= ~memory[ADDR_MUX];
//                 end

//                 // Deceptive Read Destructive Fault (DRDF) - Correct read value out, cell inverted afterwards
//                 if (EN_DRDF) begin
//                     memory[ADDR_MUX] <= ~memory[ADDR_MUX];
//                     dr_r             <= memory[ADDR_MUX];
//                 end
//             end

//             // Fault Injection: Coupling Read Fault (CFdrd)
//             if (EN_FAULT_INJECTION && (ADDR_MUX == FAULT_TARGET_ADDR) && EN_CFdrd) begin
//                 memory[FAULT_VICTIM_ADDR] <= ~memory[FAULT_VICTIM_ADDR];
//             end
//         end

//         // -----------------------------------------------------------------
//         // CONTINUOUS/STUCK-AT FAULT OVERRIDE (SAF)
//         // -----------------------------------------------------------------
//         if (EN_FAULT_INJECTION && EN_SAF) begin
//             memory[FAULT_TARGET_ADDR] <= SAF_VAL;
//         end
//     end
// end

// assign A_DOUT = dr_r;

// endmodule