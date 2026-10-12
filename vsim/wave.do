onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_croc_soc/i_croc_soc/i_croc/i_soc_ctrl/mbist_start_d
add wave -noupdate /tb_croc_soc/i_croc_soc/i_croc/i_soc_ctrl/mbist_start_q
add wave -noupdate /tb_croc_soc/i_croc_soc/i_croc/i_soc_ctrl/obi_req_i.req
add wave -noupdate -expand /tb_croc_soc/i_croc_soc/i_croc/i_soc_ctrl/obi_req_i.a
add wave -noupdate /tb_croc_soc/i_croc_soc/i_croc/i_soc_ctrl/mbist_start_q
add wave -noupdate /tb_croc_soc/i_croc_soc/i_croc/i_soc_ctrl/mbist_start_d
add wave -noupdate /tb_croc_soc/i_croc_soc/i_croc/i_soc_ctrl/mbist_resume_or_reset_d
add wave -noupdate /tb_croc_soc/i_croc_soc/i_croc/i_soc_ctrl/mbist_resume_or_reset_q
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/mbist_start_i}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/resume_or_reset_i}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/erraddr_rd_i}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/status_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/bist_en_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/memaddr_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/memwen_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/wdata_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/memren_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/rdata_i}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/memen_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/mbist_erraddr_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/seq_q}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/sub_op_q}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/u_bist_controller/membm_o}
add wave -noupdate {/tb_croc_soc/i_croc_soc/i_croc/gen_sram_bank[0]/i_sram/gen_512x32xBx1/rdata64}
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2066930 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 554
configure wave -valuecolwidth 68
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {2066873 ns} {2066981 ns}
