module obi_jtag_top #(
        /// The OBI configuration.
    parameter obi_pkg::obi_cfg_t ObiCfg             = obi_pkg::ObiDefaultConfig,
    /// The request struct for the subordinate ports (input ports).
    parameter type               sbr_port_obi_req_t = logic,
    /// The A channel struct for the subordinate ports (input ports).
    parameter type               sbr_port_a_chan_t  = logic,
    /// The response struct for the subordinate ports (input ports).
    parameter type               sbr_port_obi_rsp_t = logic,
    /// The R channel struct for the subordinate ports (input ports).
    parameter type               sbr_port_r_chan_t  = logic,
    /// The request struct for the manager ports (output ports).
    parameter type               mgr_port_obi_req_t = sbr_port_obi_req_t,
    /// The response struct for the manager ports (output ports).
    parameter type               mgr_port_obi_rsp_t = sbr_port_obi_rsp_t,
    /// The number of subordinate ports (input ports).
    parameter int unsigned       NumSbrPorts        = 32'd0,
    /// The number of manager ports (output ports).
    parameter int unsigned       NumMgrPorts        = 32'd0,
      /// The maximum number of outstanding transactions.
    parameter int unsigned       NumMaxTrans        = 32'd0,
    /// The number of address rules.
    parameter int unsigned       NumAddrRules       = 32'd0,
    /// The address map rule type.
    parameter type               addr_map_rule_t    = logic,
    /// Bypass enable for request side cuts.
    parameter bit [NumSbrPorts-1:0] BypassReqSbr    = '0,
    /// Bypass enable for response side cuts.
    parameter bit [NumSbrPorts-1:0] BypassRspSbr    = '0,
    /// Bypass enable for manager side requests.
    parameter bit [NumMgrPorts-1:0] BypassReqMgr    = '0,
    /// Bypass enable for manager side responses.
    parameter bit [NumMgrPorts-1:0] BypassRspMgr    = '0
) (
    input  logic clk_i,
    input  logic rst_ni,
    input  logic testmode_i,

    // JTAG Interface 
    input  logic tclk_i,
    input  logic trst_ni,
    input  logic tdi_i,
    input  logic tms_i,
    output logic tdo_o,

    // Subordinate Side Signals facing the Managers
    input  sbr_port_obi_req_t [NumSbrPorts-1:0] mst_cut_sbr_ports_req_i, // From Master to xbar
    input  sbr_port_obi_rsp_t [NumSbrPorts-1:0] xbar_cut_sbr_ports_rsp_i, // From xbar to Master

    output sbr_port_obi_req_t [NumSbrPorts-1:0] cut_xbar_sbr_ports_req_o,
    output sbr_port_obi_rsp_t [NumSbrPorts-1:0] cut_mst_sbr_ports_rsp_o,

    // Manager Side Signals facing the Subordinates
    input   mgr_port_obi_req_t [NumMgrPorts-1:0] xbar_cut_mgr_ports_req_i, // From xbar to slave
    input   mgr_port_obi_rsp_t [NumMgrPorts-1:0] slv_cut_mgr_ports_rsp_i, // From slave to xbar

    output  mgr_port_obi_req_t [NumMgrPorts-1:0] cut_slv_mgr_ports_req_o,
    output  mgr_port_obi_rsp_t [NumMgrPorts-1:0] cut_xbar_mgr_ports_rsp_o,

    // Miscellaneous Signals
    input  addr_map_rule_t [NumAddrRules-1:0]   addr_map_i,
    input  logic [NumSbrPorts-1:0]              en_default_idx_i,
    input  logic [NumSbrPorts-1:0][cf_math_pkg::idx_width(NumMgrPorts)-1:0] default_idx_i

);


    //Controller Instantiated
    logic run_test_idle, test_logic_reset, capture_dr, select_dr_scan, 
          exit1_dr, shift_dr, exit2_dr, pause_dr, select_ir_scan,
          update_dr, shift_ir, capture_ir, pause_ir, exit1_ir, update_ir, exit2_ir;

    jtag_tap_controller i_tap_fsm (
                                    .tclk_i,
                                    .tms_i,
                                    .trst_ni,
                                    .run_test_idle_o(run_test_idle),   
                                    .test_logic_reset_o(test_logic_reset),
                                    .capture_dr_o(capture_dr),      
                                    .select_dr_scan_o(select_dr_scan),  
                                    .exit1_dr_o(exit1_dr),        
                                    .shift_dr_o(shift_dr),        
                                    .exit2_dr_o(exit2_dr),        
                                    .pause_dr_o(pause_dr),        
                                    .select_ir_scan_o(select_ir_scan),  
                                    .update_dr_o(update_dr),       
                                    .shift_ir_o(shift_ir),        
                                    .capture_ir_o(capture_ir),      
                                    .pause_ir_o(pause_ir),        
                                    .exit1_ir_o(exit1_ir),        
                                    .update_ir_o(update_ir),       
                                    .exit2_ir_o(exit2_ir)        
                                  );
                                  
endmodule