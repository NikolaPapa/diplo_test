quit -sim
file delete -force work

vlib work
vlog -f files_rtl.f

vsim rf_processor_tb
log -r /*



add wave -position insertpoint  \
sim:/rf_processor_tb/HCLK \
sim:/rf_processor_tb/HRESETn
add wave -position insertpoint  \
sim:/rf_processor_tb/instruction \
sim:/rf_processor_tb/if_id_IR \
sim:/rf_processor_tb/id_rf_IR
add wave -position insertpoint  \
sim:/rf_processor_tb/if_valid_inst_out \
sim:/rf_processor_tb/if_id_valid_inst \
sim:/rf_processor_tb/id_rf_valid_inst
add wave -position insertpoint  \
sim:/rf_processor_tb/proc_module/rf_valid_inst
add wave -position insertpoint  \
sim:/rf_processor_tb/proc_module/id_rf_decode_addr

add wave -position insertpoint  \
sim:/rf_processor_tb/proc_module/TopRF/RF/dut/debug_all_regs

add wave -position insertpoint  \
sim:/rf_processor_tb/DM/mem

add wave -position insertpoint  \
sim:/rf_processor_tb/HADDR \
sim:/rf_processor_tb/HWRITE \
sim:/rf_processor_tb/HWDATA \
sim:/rf_processor_tb/HRDATA \
sim:/rf_processor_tb/HTRANS

radix hex

run -all