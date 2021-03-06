#################################################################
# Makefile generated by Xilinx Platform Studio 
# Project:C:\JAIP\JAIP\201506_test\system.xmp
#
# WARNING : This file will be re-generated every time a command
# to run a make target is invoked. So, any changes made to this  
# file manually, will be lost when make is invoked next. 
#################################################################

SHELL = CMD

XILINX_EDK_DIR = C:/Xilinx/13.4/ISE_DS/EDK

SYSTEM = system

MHSFILE = system.mhs

FPGA_ARCH = virtex5

DEVICE = xc5vfx70tff1136-1

INTSTYLE = default

LANGUAGE = vhdl
GLOBAL_SEARCHPATHOPT = 
PROJECT_SEARCHPATHOPT =  -lp C:/

SEARCHPATHOPT = $(PROJECT_SEARCHPATHOPT) $(GLOBAL_SEARCHPATHOPT)

SUBMODULE_OPT = 

PLATGEN_OPTIONS = -p $(DEVICE) -lang $(LANGUAGE) -intstyle $(INTSTYLE) $(SEARCHPATHOPT) $(SUBMODULE_OPT) -msg __xps/ise/xmsgprops.lst -parallel yes

OBSERVE_PAR_OPTIONS = -error no

MICROBLAZE_BOOTLOOP = $(XILINX_EDK_DIR)/sw/lib/microblaze/mb_bootloop.elf
MICROBLAZE_BOOTLOOP_LE = $(XILINX_EDK_DIR)/sw/lib/microblaze/mb_bootloop_le.elf
PPC405_BOOTLOOP = $(XILINX_EDK_DIR)/sw/lib/ppc405/ppc_bootloop.elf
PPC440_BOOTLOOP = $(XILINX_EDK_DIR)/sw/lib/ppc440/ppc440_bootloop.elf
BOOTLOOP_DIR = bootloops

MICROBLAZE_0_BOOTLOOP = $(BOOTLOOP_DIR)/microblaze_0.elf

BRAMINIT_ELF_IMP_FILES = $(MICROBLAZE_0_BOOTLOOP)
BRAMINIT_ELF_IMP_FILE_ARGS = -pe microblaze_0 $(MICROBLAZE_0_BOOTLOOP)

BRAMINIT_ELF_SIM_FILES = $(MICROBLAZE_0_BOOTLOOP)
BRAMINIT_ELF_SIM_FILE_ARGS = -pe microblaze_0 $(MICROBLAZE_0_BOOTLOOP)

SIM_CMD = isim_system

BEHAVIORAL_SIM_SCRIPT = simulation/behavioral/$(SYSTEM)_setup.tcl

STRUCTURAL_SIM_SCRIPT = simulation/structural/$(SYSTEM)_setup.tcl

TIMING_SIM_SCRIPT = simulation/timing/$(SYSTEM)_setup.tcl

DEFAULT_SIM_SCRIPT = $(BEHAVIORAL_SIM_SCRIPT)

SIMGEN_OPTIONS = -p $(DEVICE) -lang $(LANGUAGE) -intstyle $(INTSTYLE) $(SEARCHPATHOPT) $(BRAMINIT_ELF_SIM_FILE_ARGS) -msg __xps/ise/xmsgprops.lst -s isim


CORE_STATE_DEVELOPMENT_FILES = pcores/jaip_v1_00_a/netlist/divider.ngc \
pcores/jaip_v1_00_a/netlist/multiplier.ngc \
pcores/jaip_v1_00_a/netlist/mulu32.ngc \
pcores/jaip_v1_00_a/netlist/divver1.ngc \
pcores/jaip_v1_00_a/netlist/divider_64.ngc \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/family.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/family_support.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/coregen_comp_defs.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/common_types_pkg.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/proc_common_pkg.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/conv_funs_pkg.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/ipif_pkg.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/async_fifo_fg.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/sync_fifo_fg.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/basic_sfifo_fg.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/blk_mem_gen_wrapper.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/addsub.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/counter_bit.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/counter.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/direct_path_cntr.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/direct_path_cntr_ai.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/down_counter.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/eval_timer.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/inferred_lut4.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/ipif_steer.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/ipif_steer128.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/ipif_mirror128.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/ld_arith_reg.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/ld_arith_reg2.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/mux_onehot.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/or_bits.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/or_muxcy.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/or_gate.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/or_gate128.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pf_adder_bit.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pf_adder.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pf_counter_bit.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pf_counter.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pf_counter_top.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pf_occ_counter.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pf_occ_counter_top.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pf_dpram_select.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pselect.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pselect_mask.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/srl16_fifo.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/srl_fifo.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/srl_fifo2.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/srl_fifo3.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/srl_fifo_rbu.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/valid_be.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/or_with_enable_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/muxf_struct_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/cntr_incr_decr_addn_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/dynshreg_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/dynshreg_i_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/mux_onehot_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/srl_fifo_rbu_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/srl_fifo_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/compare_vectors_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/pselect_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/counter_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/or_muxcy_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/or_gate_f.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/proc_common_v3_00_a/hdl/vhdl/soft_reset.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_slave_single_v1_01_a/hdl/vhdl/plb_address_decoder.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_slave_single_v1_01_a/hdl/vhdl/plb_slave_attachment.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_slave_single_v1_01_a/hdl/vhdl/plbv46_slave_single.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/plb_mstr_addr_gen.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/rd_wr_calc_burst.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/rd_wr_controller.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/llink_rd_backend_no_fifo.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/llink_wr_backend_no_fifo.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/data_width_adapter.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/data_mirror_128.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/cc_brst_exp_adptr.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/plbv46_master_burst_v1_01_a/hdl/vhdl/plbv46_master_burst.vhd \
pcores/data_coherence_controller_v1_00_a/hdl/vhdl/user_logic.vhd \
pcores/data_coherence_controller_v1_00_a/hdl/vhdl/data_coherence_controller.vhd \
C:/Xilinx/13.4/ISE_DS/EDK/hw/XilinxProcessorIPLib/pcores/interrupt_control_v2_01_a/hdl/vhdl/interrupt_control.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/config.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/immROM.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/xcptn_hdlr.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/jpc_ctrl.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/class_bram.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/class_symbol_table_buffer.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/class_symbol_table_controller.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/method_image_buffer.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/method_image_controller.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/DynamicResolution_management.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/instruction_buffer.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/four_port_bank.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/bshifter.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/ALU.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/Lbshifter.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/LALU.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/execute.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/decode.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/fetch.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/translation_ROM.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/translate.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/soj.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/mmes_profiler.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/my_bram.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/class_info_table.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/cross_reference_table.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/heap.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/user_logic.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/jaip.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/arraycopy.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/arraycopy_single.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/bytecode_profiler.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/Cache_controller.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/cache_storage.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/GC_table.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/GC.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/indexOf.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/my_bram_as_rd.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/thread_management.vhd \
pcores/jaip_v1_00_a/hdl/vhdl/stack_access_management.vhd

WRAPPER_NGC_FILES = implementation/microblaze_0_wrapper.ngc \
implementation/mb_plb_wrapper.ngc \
implementation/ilmb_wrapper.ngc \
implementation/dlmb_wrapper.ngc \
implementation/dlmb_cntlr_wrapper.ngc \
implementation/ilmb_cntlr_wrapper.ngc \
implementation/lmb_bram_wrapper.ngc \
implementation/rs232_uart_1_wrapper.ngc \
implementation/rs232_uart_2_wrapper.ngc \
implementation/sram_wrapper.ngc \
implementation/ddr2_sdram_wrapper.ngc \
implementation/sysace_compactflash_wrapper.ngc \
implementation/clock_generator_0_wrapper.ngc \
implementation/mdm_0_wrapper.ngc \
implementation/proc_sys_reset_0_wrapper.ngc \
implementation/xps_intc_0_wrapper.ngc \
implementation/data_coherence_controller_0_wrapper.ngc \
implementation/jaip_0_wrapper.ngc \
implementation/chipscope_ila_0_wrapper.ngc \
implementation/chipscope_icon_0_wrapper.ngc

POSTSYN_NETLIST = implementation/$(SYSTEM).ngc

SYSTEM_BIT = implementation/$(SYSTEM).bit

DOWNLOAD_BIT = implementation/download.bit

SYSTEM_ACE = implementation/$(SYSTEM).ace

UCF_FILE = data\system.ucf

BMM_FILE = implementation/$(SYSTEM).bmm

BITGEN_UT_FILE = etc/bitgen.ut

XFLOW_OPT_FILE = etc/fast_runtime.opt
XFLOW_DEPENDENCY = __xps/xpsxflow.opt $(XFLOW_OPT_FILE)

XPLORER_DEPENDENCY = __xps/xplorer.opt
XPLORER_OPTIONS = -p $(DEVICE) -uc $(SYSTEM).ucf -bm $(SYSTEM).bmm -max_runs 7

FPGA_IMP_DEPENDENCY = $(BMM_FILE) $(POSTSYN_NETLIST) $(UCF_FILE) $(XFLOW_DEPENDENCY)

SDK_EXPORT_DIR = SDK\SDK_Export\hw
SYSTEM_HW_HANDOFF = $(SDK_EXPORT_DIR)/$(SYSTEM).xml
SYSTEM_HW_HANDOFF_BIT = $(SDK_EXPORT_DIR)/$(SYSTEM).bit
SYSTEM_HW_HANDOFF_BMM = $(SDK_EXPORT_DIR)/$(SYSTEM)_bd.bmm
SYSTEM_HW_HANDOFF_DEP = $(SYSTEM_HW_HANDOFF) $(SYSTEM_HW_HANDOFF_BIT) $(SYSTEM_HW_HANDOFF_BMM)
