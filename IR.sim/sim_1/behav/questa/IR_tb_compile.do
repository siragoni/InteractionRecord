######################################################################
#
# File name : IR_tb_compile.do
# Created on: Mon Dec 13 14:14:59 +0100 2021
#
# Auto generated by Vivado for 'behavioral' simulation
#
######################################################################
C:\\questasim64_10.6c\\win64\\vlib questa_lib/work
C:\\questasim64_10.6c\\win64\\vlib questa_lib/msim

C:\\questasim64_10.6c\\win64\\vlib questa_lib/msim/xil_defaultlib

C:\\questasim64_10.6c\\win64\\vmap xil_defaultlib questa_lib/msim/xil_defaultlib

C:\\questasim64_10.6c\\win64\\vlog -64 -incr -work xil_defaultlib  \
"../../../../IR.ip_user_files/ip/ir_fifo/sim/ir_fifo.v" \

C:\\questasim64_10.6c\\win64\\vcom -64 -93 -work xil_defaultlib  \
"../../../../../../CtpReadout/ctp_readout2/ctp_readout2.srcs/sources_1/new/buffer_fifo.vhd" \
"../../../../IR.srcs/sources_1/new/ir_statemachine.vhd" \
"../../../../IR.srcs/sources_1/new/packer_ir2.vhd" \
"../../../../../../WholeCTPfromGitLab/common_logic/RTL/Trigger_class_record/prsg_tcr.vhd" \
"../../../../IR.srcs/sources_1/new/top_ir_statemachine.vhd" \
"../../../../IR.srcs/sim_1/new/IR_tb.vhd" \

# compile glbl module
C:\\questasim64_10.6c\\win64\\vlog -work xil_defaultlib "glbl.v"

quit -force

