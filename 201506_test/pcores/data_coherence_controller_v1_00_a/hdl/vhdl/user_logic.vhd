---------------------
-- user_logic.vhd - entity/architecture pair
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 1995-2007 Xilinx, Inc.  All rights reserved.            **
-- **                                                                       **
-- ** Xilinx, Inc.                                                          **
-- ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"         **
-- ** AS A COURTESY TO YOU, SOLELY FOR USE IN DEVELOPING PROGRAMS AND       **
-- ** SOLUTIONS FOR XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE,        **
-- ** OR INFORMATION AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,        **
-- ** APPLICATION OR STANDARD, XILINX IS MAKING NO REPRESENTATION           **
-- ** THAT THIS IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,     **
-- ** AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE      **
-- ** FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY              **
-- ** WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE               **
-- ** IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR        **
-- ** REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF       **
-- ** INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       **
-- ** FOR A PARTICULAR PURPOSE.                                             **
-- **                                                                       **
-- ***************************************************************************
--
------------------------------------------------------------------------------
-- Filename:          user_logic.vhd
-- Version:           1.00.a
-- Description:       User logic.
-- Date:              Mon Apr 06 11:17:14 2009 (by Create and Import Peripheral Wizard)
-- VHDL Standard:     VHDL'93
------------------------------------------------------------------------------

library ieee;
-- use ieee.std_logic_1164.all;
-- use ieee.std_logic_arith.all;
-- use ieee.std_logic_unsigned.all;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use ieee.std_logic_arith.conv_std_logic_vector;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;
--use proc_common_v3_00_a.srl_fifo_f;

Library UNISIM;
use UNISIM.vcomponents.all;

--libraries added here

------------------------------------------------------------------------------
-- Entity section
------------------------------------------------------------------------------
-- Definition of Generics:
--   C_SLV_AWIDTH                 -- Slave interface address bus width
--   C_SLV_DWIDTH                 -- Slave interface data bus width
--   C_MST_AWIDTH                 -- Master interface address bus width
--   C_MST_DWIDTH                 -- Master interface data bus width
--   C_NUM_REG                    -- Number of software accessible registers
--   C_NUM_MEM                    -- Number of memory spaces
--   C_NUM_INTR                   -- Number of interrupt event
--
-- Definition of Ports:
--   Bus2IP_Clk                   -- Bus to IP clock
--   Bus2IP_Reset                 -- Bus to IP reset
--   Bus2IP_Addr                  -- Bus to IP address bus
--   Bus2IP_CS                    -- Bus to IP chip select for user logic memory selection
--   Bus2IP_RNW                   -- Bus to IP read/not write
--   Bus2IP_Data                  -- Bus to IP data bus
--   Bus2IP_BE                    -- Bus to IP byte enables
--   Bus2IP_RdCE                  -- Bus to IP read chip enable
--   Bus2IP_WrCE                  -- Bus to IP write chip enable
--   IP2Bus_Data                  -- IP to Bus data bus
--   IP2Bus_RdAck                 -- IP to Bus read transfer acknowledgement
--   IP2Bus_WrAck                 -- IP to Bus write transfer acknowledgement
--   IP2Bus_Error                 -- IP to Bus error response
--   IP2Bus_MstRd_Req             -- IP to Bus master read request
--   IP2Bus_MstWr_Req             -- IP to Bus master write request
--   IP2Bus_Mst_Addr              -- IP to Bus master address bus
--   IP2Bus_Mst_BE                -- IP to Bus master byte enables
--   IP2Bus_Mst_Lock              -- IP to Bus master lock
--   IP2Bus_Mst_Reset             -- IP to Bus master reset
--   Bus2IP_Mst_CmdAck            -- Bus to IP master command acknowledgement
--   Bus2IP_Mst_Cmplt             -- Bus to IP master transfer completion
--   Bus2IP_Mst_Error             -- Bus to IP master error response
--   Bus2IP_Mst_Rearbitrate       -- Bus to IP master re-arbitrate
--   Bus2IP_Mst_Cmd_Timeout       -- Bus to IP master command timeout
--   Bus2IP_MstRd_d               -- Bus to IP master read data bus
--   Bus2IP_MstRd_src_rdy_n       -- Bus to IP master read source ready
--   IP2Bus_MstWr_d               -- IP to Bus master write data bus
--   Bus2IP_MstWr_dst_rdy_n       -- Bus to IP master write destination ready
--   IP2Bus_IntrEvent             -- IP to Bus interrupt event
------------------------------------------------------------------------------

entity user_logic is
  generic
  (        
    --generics added here
	SIMULTANEOUS_MULTITHREAD_VER_ENABLE : integer		:= 1;
	FOX_VER_ENABLE 						: integer		:= 0;
	OBJ_LOCK_LIST_SIZE					: integer		:= 4;
	WAIT_LIST_SIZE						: integer		:= 16;
	MAX_TH_NUM_IN_EACH_CORE				: integer		:= 16;
	CORE_NUM							: integer		:= 4;

    -- Bus protocol parameters, do not add to or delete
    C_SLV_AWIDTH                   : integer              := 32;
    C_SLV_DWIDTH                   : integer              := 32;
    C_MST_AWIDTH                   : integer              := 32;
    C_MST_DWIDTH                   : integer              := 32;
    C_NUM_REG                      : integer              := 5;
    C_NUM_MEM                      : integer              := 1;
    C_NUM_INTR                     : integer              := 1
  );
  port
  (

	-- added by T.H.Wu , 2013.9.6
	COOR2JAIP_response_msg			: out std_logic_vector(15 downto 0);
	COOR2JAIP_res_newTH_data1		: out std_logic_vector(31 downto 0);
	COOR2JAIP_res_newTH_data2		: out std_logic_vector(31 downto 0);
	-- in/out port for core 0 
	JAIP2COOR_cmd0					: in std_logic_vector(2 downto 0) ;
	DCC_0_w_en_in                  : in  std_logic;
	DCC_0_r_en_in                  : in  std_logic;
    DCC_0_addr_in                  : in  std_logic_vector(0 to 31);
    DCC_0_data_in                  : in  std_logic_vector(0 to 31);
	JAIP2COOR0_pending_resMsgSent	:in		std_logic;
	DCC_0_ack_out                  : out std_logic;
	DCC_0_en_out                   : out std_logic;
    DCC_0_addr_out                 : out std_logic_vector(0 to 31);
    DCC_0_data_out                 : out std_logic_vector(0 to 31);
	-- in/out port for core 1 
	JAIP2COOR_cmd1					: in std_logic_vector(2 downto 0) ;
	DCC_1_w_en_in                  : in  std_logic;
	DCC_1_r_en_in                  : in  std_logic;
    DCC_1_addr_in                  : in  std_logic_vector(0 to 31);
    DCC_1_data_in                  : in  std_logic_vector(0 to 31);
	JAIP2COOR1_pending_resMsgSent	:in		std_logic;
	DCC_1_ack_out                  : out std_logic;
	DCC_1_en_out                   : out std_logic;
    DCC_1_addr_out                 : out std_logic_vector(0 to 31);
    DCC_1_data_out                 : out std_logic_vector(0 to 31);
	-- in/out port for core 2
	JAIP2COOR_cmd2					: in std_logic_vector(2 downto 0) ;
	DCC_2_w_en_in                  : in  std_logic;
	DCC_2_r_en_in                  : in  std_logic;
    DCC_2_addr_in                  : in  std_logic_vector(0 to 31);
    DCC_2_data_in                  : in  std_logic_vector(0 to 31);
	JAIP2COOR2_pending_resMsgSent	:in		std_logic;
	DCC_2_ack_out                  : out std_logic;
	DCC_2_en_out                   : out std_logic;
    DCC_2_addr_out                 : out std_logic_vector(0 to 31);
    DCC_2_data_out                 : out std_logic_vector(0 to 31);
	-- in/out port for core 3
	JAIP2COOR_cmd3					: in std_logic_vector(2 downto 0) ;
	DCC_3_w_en_in                  : in  std_logic;
	DCC_3_r_en_in                  : in  std_logic;
    DCC_3_addr_in                  : in  std_logic_vector(0 to 31);
    DCC_3_data_in                  : in  std_logic_vector(0 to 31);
	JAIP2COOR3_pending_resMsgSent	:in		std_logic;
	DCC_3_ack_out                  : out std_logic;
	DCC_3_en_out                   : out std_logic;
    DCC_3_addr_out                 : out std_logic_vector(0 to 31);
    DCC_3_data_out                 : out std_logic_vector(0 to 31);

    -- Bus protocol ports, do not add to or delete
    Bus2IP_Clk                     : in  std_logic;
    Bus2IP_Reset                   : in  std_logic;
    Bus2IP_Addr                    : in  std_logic_vector(0 to C_SLV_AWIDTH-1);
    Bus2IP_CS                      : in  std_logic_vector(0 to C_NUM_MEM-1);
    Bus2IP_RNW                     : in  std_logic;
    Bus2IP_Data                    : in  std_logic_vector(0 to C_SLV_DWIDTH-1);
    Bus2IP_BE                      : in  std_logic_vector(0 to C_SLV_DWIDTH/8-1);
    Bus2IP_RdCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    Bus2IP_WrCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    IP2Bus_Data                    : out std_logic_vector(0 to C_SLV_DWIDTH-1);
    IP2Bus_RdAck                   : out std_logic;
    IP2Bus_WrAck                   : out std_logic;
    IP2Bus_Error                   : out std_logic;
    IP2Bus_MstRd_Req               : out std_logic;
    IP2Bus_MstWr_Req               : out std_logic;
    IP2Bus_Mst_Addr                : out std_logic_vector(0 to C_MST_AWIDTH-1);
    IP2Bus_Mst_BE                  : out std_logic_vector(0 to C_MST_DWIDTH/8-1);
    IP2Bus_Mst_Length              : out std_logic_vector(0 to 11);
    IP2Bus_Mst_Type                : out std_logic;
    IP2Bus_Mst_Lock                : out std_logic;
    IP2Bus_Mst_Reset               : out std_logic;
    Bus2IP_Mst_CmdAck              : in  std_logic;
    Bus2IP_Mst_Cmplt               : in  std_logic;
    Bus2IP_Mst_Error               : in  std_logic;
    Bus2IP_Mst_Rearbitrate         : in  std_logic;
    Bus2IP_Mst_Cmd_Timeout         : in  std_logic;
    Bus2IP_MstRd_d                 : in  std_logic_vector(0 to C_MST_DWIDTH-1);
    Bus2IP_MstRd_rem               : in  std_logic_vector(0 to C_MST_DWIDTH/8-1);
    Bus2IP_MstRd_sof_n             : in  std_logic;
    Bus2IP_MstRd_eof_n             : in  std_logic;
    Bus2IP_MstRd_src_rdy_n         : in  std_logic;
    Bus2IP_MstRd_src_dsc_n         : in  std_logic;
    IP2Bus_MstRd_dst_rdy_n         : out std_logic;
    IP2Bus_MstRd_dst_dsc_n         : out std_logic;
    IP2Bus_MstWr_d                 : out std_logic_vector(0 to C_MST_DWIDTH-1);
    IP2Bus_MstWr_rem               : out std_logic_vector(0 to C_MST_DWIDTH/8-1);
    IP2Bus_MstWr_sof_n             : out std_logic;
    IP2Bus_MstWr_eof_n             : out std_logic;
    IP2Bus_MstWr_src_rdy_n         : out std_logic;
    IP2Bus_MstWr_src_dsc_n         : out std_logic;
    Bus2IP_MstWr_dst_rdy_n         : in  std_logic;
    Bus2IP_MstWr_dst_dsc_n         : in  std_logic;
    IP2Bus_IntrEvent               : out std_logic_vector(0 to C_NUM_INTR-1)
  );

  attribute SIGIS : string;
  attribute SIGIS of Bus2IP_Clk    : signal is "CLK";
  attribute SIGIS of Bus2IP_Reset  : signal is "RST";
  attribute SIGIS of IP2Bus_Mst_Reset: signal is "RST";

end entity user_logic;

------------------------------------------------------------------------------
-- Architecture section
------------------------------------------------------------------------------

architecture IMP of user_logic is
 
  ------------------------------------------------------------------------------
  -- Component of Java BEE
  ------------------------------------------------------------------------------ 
  
  signal jaip_set_addr				: std_logic_vector(11 downto 0) := x"404";
  signal jaip_set_data				: std_logic_vector(11 downto 0) := x"408";
  signal jaip_ack_lock_free			: std_logic_vector(11 downto 0) := x"444";
  
  --signal ctrl_reg                   : std_logic_vector(0 to 31);
  signal we           				: std_logic;

  ------------------------------------------
  -- Signals for user logic master model
  ------------------------------------------


  signal mst_rd_tmpreg                  : std_logic_vector(0 to 31);
  signal mst_address_out                : std_logic_vector(0 to 31);
  
  signal jpl_mst_data_delay             : std_logic_vector(0 to 31);
  signal jpl_mst_address_delay          : std_logic_vector(0 to 31);
  signal jpl_mst_BE                     : std_logic_vector(3 downto 0);
  signal jpl_mst_BE_tmp                 : std_logic_vector(3 downto 0);
  signal jpl_mst_ack				    : std_logic;
  signal jpl_mst_cmplt				    : std_logic;
  signal jpl_mst_address_address        : std_logic_vector(8 downto 0);
  signal jpl_load_data                  : std_logic_vector(31 downto 0) ;
  signal jpl_load_data_debug_out        : std_logic_vector(31 downto 0) ;
  signal jpl_comlpete_out               : std_logic_vector(31 downto 0) ;
  signal jpl_comlpete_data_in           : std_logic_vector(31 downto 0) ;

  ------------------------------------------
  -- Signals for user logic memory space example
  ------------------------------------------
  type BYTE_RAM_TYPE is array (0 to 255) of std_logic_vector(0 to 7);
  type DO_TYPE is array (0 to C_NUM_MEM-1) of std_logic_vector(0 to C_SLV_DWIDTH-1);
  --signal mem_data_out                   : DO_TYPE;
  signal mem_address                    : std_logic_vector(0 to 13);
  signal mem_address_2cycle             : std_logic_vector(0 to 13);
  signal mem_select                     : std_logic_vector(0 to 0);
  signal mem_read_enable                : std_logic;
  signal mem_read_enable_dly1           : std_logic;
  signal mem_read_req                   : std_logic;
  --signal mem_ip2bus_data                : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal mem_read_ack_dly1              : std_logic;
  signal mem_read_ack                   : std_logic;
  signal mem_write_ack                  : std_logic;

  ------------------------------------------
  -- Signals for debug
  ------------------------------------------
	-- fox for burst mode
    signal  burst_ctrl_idx_out		: std_logic_vector(0 to 7);
	signal  burst_ctrl_idx_reg		: std_logic_vector(0 to 7);	-- by fox
	-- local link
	signal IP2Bus_MstWr_eof_n_reg 		 : std_logic;
	signal IP2Bus_MstWr_sof_n_reg 		 : std_logic;
	signal IP2Bus_MstWr_src_rdy_n_reg 	 : std_logic;
	signal IP2Bus_MstRd_dst_rdy_n_reg 	 : std_logic;

	
	-- PLB 
	signal IP2Bus_Mst_BE_tmp 			: std_logic_vector(3 downto 0);	 
	signal IP2Bus_Mst_Addr_tmp			: std_logic_vector(31 downto 0);
	signal IP2Bus_MstWr_d_tmp			: std_logic_vector(31 downto 0);
	signal IP2Bus_MstRd_Req_tmp			: std_logic;
	signal IP2Bus_MstWr_Req_tmp			: std_logic;
	signal IP2Bus_Mst_Length_tmp		: std_logic_vector(11 downto 0);
	signal IP2Bus_Mst_Type_tmp			: std_logic;
	signal mst_wr_req					: std_logic;
	signal mst_rd_req					: std_logic;
		
	
	
	
	-- for cache coherence -----------------------------------------------
	signal modify_core_id				: std_logic_vector(3 downto 0);
	signal heap_modify_en				: std_logic;
	signal heap_modify_addr				: std_logic_vector(31 downto 0);
	signal heap_modify_data				: std_logic_vector(31 downto 0);
	
	-- for jaip_0
	signal heap_ack_0					: std_logic;
	signal heap_addr_out_0				: std_logic_vector(31 downto 0);
	signal heap_data_out_0				: std_logic_vector(31 downto 0);
	
	-- for jaip_1
	signal heap_ack_1					: std_logic;
	signal heap_addr_out_1				: std_logic_vector(31 downto 0);
	signal heap_data_out_1				: std_logic_vector(31 downto 0);
	
	-- for jaip_2
	signal heap_ack_2					: std_logic;
	signal heap_addr_out_2				: std_logic_vector(31 downto 0);
	signal heap_data_out_2				: std_logic_vector(31 downto 0);
	
	-- for jaip_3
	signal heap_ack_3					: std_logic;
	signal heap_addr_out_3				: std_logic_vector(31 downto 0);
	signal heap_data_out_3				: std_logic_vector(31 downto 0);
	--
	
	signal	DCC_0_en_out_w             	:	std_logic;
	signal	DCC_1_en_out_w             	:	std_logic;
	signal	DCC_2_en_out_w             	:	std_logic;
	signal	DCC_3_en_out_w             	:	std_logic;
	----------------------------------------------------------------------
	
	
	-- for sync ---------------------------------------------------------------------------------------------
	type critical_section_object is array (integer range 3 downto 0) of std_logic_vector(31 downto 0);
	signal critical_section_wait_lock_object	 : critical_section_object;
	signal critical_section_lock_object : critical_section_object;

	-- for jaip_0
	signal CS_lock_check_0	            : std_logic;
	signal CS_lock_free_0	            : std_logic;
	signal CS_ack_0						: std_logic;
	signal jaip0_free_lock1				: std_logic;
	
	-- for jaip_1
	signal CS_lock_check_1	            : std_logic;
	signal CS_lock_free_1	            : std_logic;
	signal CS_ack_1						: std_logic;
	signal jaip1_free_lock0				: std_logic;
	-----------------------------------------------------------------------------------------------------------
	
	-- for new thread --------------------------------------------------------------
	type jaip_state_info is array (integer range 3 downto 0) of std_logic;
	signal jaip_state		:	jaip_state_info;
	signal main_method		:	std_logic_vector(0 to 31);
	--------------------------------------------------------------------------------
	

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	-- modified by T.H.Wu , 2014.2.13, try to achieve IP optimization
	signal	arbitor_cmd_msg			: std_logic_vector(0 to 5);
	signal	COOR2JAIP_response_msg_reg		:	std_logic_vector(15 downto 0); 
	signal	COOR2JAIP_response_msg_reg_w	:	std_logic_vector(15 downto 0); 
	signal	cmd_sender_coreID_reg			: std_logic_vector(2 downto 0);
	signal	cmd_sender_coreID_reg_w			: std_logic_vector(2 downto 0);
	signal	cmd_sender_TH_slot_idx_reg		: std_logic_vector(3 downto 0);
	signal	cmd_sender_TH_slot_idx_reg_w 	: std_logic_vector(3 downto 0);
	signal	arbitor_data1 			: std_logic_vector(31 downto 0);
	signal	arbitor_data1_w			: std_logic_vector(31 downto 0);
	signal	arbitor_data2			: std_logic_vector(31 downto 0);
	signal	arbitor_data2_w 		: std_logic_vector(31 downto 0);
	
	signal	lock_flag		:	std_logic;
	signal	lock_flag_w		:	std_logic;
	type	MUX_SM_TYPE		is	(IDLE, WAIT_FOR_RES, GEN_RES_MSG, CHECK_JAIP_TCBLIST_RDY, SEND_RES_MSG, WAIT_FOR_CMPLT, TASK_CMPLT);
	signal	mutex_state		:	MUX_SM_TYPE;
	--signal	mutex_state_w	:	MUX_SM_TYPE;
	signal	dly_counter		:	std_logic_vector(3 downto 0);
	signal	dly_counter_w	:	std_logic_vector(3 downto 0);
	
	signal	monEnter_flag			: std_logic;
	signal	monEnter_flag_w			: std_logic;
	signal	monExit_flag			: std_logic;
	signal	monExit_flag_w			: std_logic;
	signal	response_msg_monEnter			: std_logic_vector(15 downto 0);
	signal	response_msg_monEnter_w			: std_logic_vector(15 downto 0);
	signal	response_msg_monExit			: std_logic_vector(15 downto 0);
	signal	response_msg_monExit_w			: std_logic_vector(15 downto 0); 
	
	
	-- for command new thread (including main thread)
	type	jaip_core_state_list_template is array (integer range CORE_NUM-1 downto 0) of std_logic_vector(5 downto 0);
	signal	jaip_core_state_list		: jaip_core_state_list_template;
	signal	jaip_core_state_list_w	: jaip_core_state_list_template; 
	
	signal	assign_new_TH_flag_w		: std_logic;
	signal	assign_new_TH_flag	: std_logic;
	signal	assign_new_TH_flag_dly : std_logic;
	signal	assign_new_TH_flag_dly2 : std_logic;
	signal	assign_new_TH_flag_dly3 : std_logic;
	signal	new_TH_to_coreID 		: std_logic_vector(2 downto 0);
	signal	new_TH_to_coreID_w		: std_logic_vector(2 downto 0);
	signal	new_TH_to_THnum 		: std_logic_vector(4 downto 0);
	signal	new_TH_to_THnum_w		: std_logic_vector(4 downto 0);
	signal	new_TH_to_coreID_tmp0	: std_logic_vector(2 downto 0);
	signal	new_TH_to_coreID_tmp1	: std_logic_vector(2 downto 0);
	signal	new_TH_to_coreID_tmp0_w	: std_logic_vector(2 downto 0);
	signal	new_TH_to_coreID_tmp1_w	: std_logic_vector(2 downto 0);
	signal	new_TH_to_THnum_tmp0	: std_logic_vector(4 downto 0);
	signal	new_TH_to_THnum_tmp1	: std_logic_vector(4 downto 0);
	signal	new_TH_to_THnum_tmp0_w	: std_logic_vector(4 downto 0);
	signal	new_TH_to_THnum_tmp1_w	: std_logic_vector(4 downto 0);
	
	-- modified by T.H.Wu , 2014.2.19, try to achieve IP optimization
	signal	lock_obj_ref_w			: std_logic_vector(23 downto 0);
	signal	the_owner_lock_twice_w	: std_logic;
	signal	the_owner_lock_twice	: std_logic;
	signal	the_owner_release_multi_times_w	: std_logic;
	signal	the_owner_release_multi_times	: std_logic;
	signal	lock_obj_match_flag_w	: std_logic;
	signal	lock_obj_match_flag		: std_logic;
	signal	lock_obj_free_flag_w	: std_logic;
	signal	lock_obj_free_flag		: std_logic;
	signal	resetAllflg_locObjCtrl_w	:	std_logic;
	signal	EO_lockObjAccess_flag_cond1_w	:	std_logic;
	signal	EO_lockObjAccess_flag_cond2_w	:	std_logic;
	signal	EO_lockObjAccess_flag_cond3_w	:	std_logic;
	signal	EO_lockObjAccess_allMix_w		:	std_logic;
	signal	find_emptyEntry_waitTHlist		:	std_logic;
	signal	find_emptyEntry_waitTHlist_w	:	std_logic;
	signal	search_waitLst_flag_dly			:	std_logic;
	signal	search_waitLst_flag				:	std_logic;
	signal	search_waitLst_flag_w			:	std_logic;
	signal	lastNode_lockObj_flag			:	std_logic;
	signal	lastNode_lockObj_flag_w			:	std_logic;
	signal	lastNode_lockObj_flag_dly		:	std_logic;
	signal	is_lock_obj_entry_occupied_w	:	std_logic;
	signal	bram_rd_addr_counter		:	std_logic_vector(6 downto 0);
	signal	bram_rd_addr_counter_w		:	std_logic_vector(6 downto 0); 
	signal	numLock_checked				:	std_logic_vector(6 downto 0);
	signal	numLock_checked_w			:	std_logic_vector(6 downto 0);
	signal	lockObj_currentCount		:	std_logic_vector(6 downto 0);
	signal	lockObj_currentCount_w		:	std_logic_vector(6 downto 0);
	signal	bram_addrB_2lockOwner		:	std_logic_vector(6 downto 0);
	signal	bram_addrB_2lockOwner_w		:	std_logic_vector(6 downto 0);
	signal	bram_addrB_nxtEmptyWaitLst	:	std_logic_vector(6 downto 0);
	signal	bram_addrB_nxtEmptyWaitLst_w:	std_logic_vector(6 downto 0);
	signal	EmptyLockObjEntry_rdy_flag		:	std_logic;
	signal	EmptyLockObjEntry_rdy_flag_w	:	std_logic;
	signal	bram_addrA_nxtEmptyLockObjLst	:	std_logic_vector(6 downto 0);
	signal	bram_addrA_nxtEmptyLockObjLst_w	:	std_logic_vector(6 downto 0);
	signal	nxtLockOwnerInfo				:	std_logic_vector(7 downto 0);
	signal	nxtLockOwnerInfo_w				:	std_logic_vector(7 downto 0);
		
	signal	obj_locked_slot_idx_w	: std_logic_vector(OBJ_LOCK_LIST_SIZE/4 downto 0); 
	signal	obj_locked_slot_idx		: std_logic_vector(OBJ_LOCK_LIST_SIZE/4 downto 0);
	signal	mon_exit_now_owner_release_w		: std_logic;
	signal	mon_exit_now_owner_release			: std_logic;
	signal	mon_exit_next_owner_exist_w			: std_logic;
	signal	mon_exit_next_owner_exist			: std_logic;
	signal	mon_exit_obj_lock_cnt_w				: std_logic_vector(1 downto 0);
	signal	mon_exit_obj_lock_cnt				: std_logic_vector(1 downto 0); 
	signal	empty_slot_idx_obj_lock_list_w		: std_logic_vector(OBJ_LOCK_LIST_SIZE/4 downto 0);
	signal	empty_slot_idx_obj_lock_list		: std_logic_vector(OBJ_LOCK_LIST_SIZE/4 downto 0);
	signal	empty_slot_idx_wait_list_w			: std_logic_vector(WAIT_LIST_SIZE/4-1 downto 0);
	signal	empty_slot_idx_wait_list			: std_logic_vector(WAIT_LIST_SIZE/4-1 downto 0);
	signal	next_owner_slot_idx_wait_list_w		: std_logic_vector(WAIT_LIST_SIZE/4-1 downto 0);
	signal	next_owner_slot_idx_wait_list		: std_logic_vector(WAIT_LIST_SIZE/4-1 downto 0);
	signal	next_owner_core_ID					: std_logic_vector(1 downto 0);
	signal	next_owner_core_ID_w				: std_logic_vector(1 downto 0);
	signal	next_owner_slot_idx_TCB_list		: std_logic_vector(MAX_TH_NUM_IN_EACH_CORE/4-1 downto 0);
	signal	next_owner_slot_idx_TCB_list_w		: std_logic_vector(MAX_TH_NUM_IN_EACH_CORE/4-1 downto 0);
	
	-- for BRAM use
	-- distribution of this BRAM
	-- 00_000_0000 <-- for storing 2^7=128 waiting threads
	-- 01_000_0000 <-- for storing 2^7=128 lock object references
	-- port A
	signal	bram_weA		:	std_logic;
	signal	bram_addrA		:	std_logic_vector(8 downto 0);
	signal	bram_addrA_dly	:	std_logic_vector(8 downto 0);
	signal	bram_DIA		:	std_logic_vector(31 downto 0);
	signal	bram_DOA		:	std_logic_vector(31 downto 0); 
	-- port B
	signal	bram_weB		:	std_logic;
	signal	bram_addrB		:	std_logic_vector(8 downto 0);
	signal	bram_addrB_dly	:	std_logic_vector(8 downto 0);
	signal	bram_DIB		:	std_logic_vector(31 downto 0);
	signal	bram_DOB		:	std_logic_vector(31 downto 0); 
	
	-- modified since 2014.3.12
	signal	monitor_cnt_modified		:	std_logic_vector(5 downto 0);
	signal	monitor_cnt_modified_w		:	std_logic_vector(5 downto 0);
	
	
	-- for ChipScope debug use
	signal	debug_chipscope_data_w			: std_logic_vector(199 downto 0);
	signal	debug_chipscope_trig_port_0_w	: std_logic_vector(7 downto 0);
	signal	debug_chipscope_trig_port_1_w	: std_logic_vector(5 downto 0);
	signal	debug_chipscope_trig_port_2_w	: std_logic_vector(3 downto 0);
	-- modified by T.H.Wu, 2014.3.5,
	--signal	debug_cur_nums_wait_TH_reg		: std_logic_vector(5 downto 0);
	--signal	debug_waitTH_addrB				: std_logic_vector(31 downto 0);
	
	------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------
	------------------------------------------------------------------------------------
	
begin


  --------------------------------------------------------------
  -- code to read/write user logic master model
  -------------------------------------------------------------- 
	-- for cache coherence start ===========================================================================
	
	----------------  heap modify request start-------------------------------------
	
	-- modified by T.H.Wu , 2013.9.26
		DCC_0_ack_out <= heap_ack_0;
		DCC_1_ack_out <= heap_ack_1;
		DCC_2_ack_out <= heap_ack_2;
		DCC_3_ack_out <= heap_ack_3; 
	
	--DCC_0_en_out 	<= '0' when modify_core_id = "0000" else heap_modify_en;
	--heap_addr_out_0	<= (others => '0') when modify_core_id = "0000" else heap_modify_addr;
    --heap_data_out_0	<= (others => '0') when modify_core_id = "0000" else heap_modify_data;
	DCC_0_en_out_w 	<= (not DCC_0_w_en_in) and heap_modify_en;
	DCC_1_en_out_w 	<= (not DCC_1_w_en_in) and heap_modify_en;
	DCC_2_en_out_w 	<= (not DCC_2_w_en_in) and heap_modify_en;
	DCC_3_en_out_w 	<= (not DCC_3_w_en_in) and heap_modify_en;
	
	DCC_0_en_out 	<= DCC_0_en_out_w;
	DCC_1_en_out 	<= DCC_1_en_out_w;
	DCC_2_en_out 	<= DCC_2_en_out_w;
	DCC_3_en_out 	<= DCC_3_en_out_w;
	
	
	
	
	--
	heap_addr_out_0	<= heap_modify_addr;
    heap_data_out_0	<= heap_modify_data; 
	heap_addr_out_1	<= heap_modify_addr;
    heap_data_out_1 <= heap_modify_data;
	heap_addr_out_2	<= heap_modify_addr;
    heap_data_out_2 <= heap_modify_data;
	heap_addr_out_3	<= heap_modify_addr;
    heap_data_out_3 <= heap_modify_data;
	
	heap_modify_en <= DCC_0_w_en_in or DCC_1_w_en_in or DCC_2_w_en_in or DCC_3_w_en_in ;
	
	process(
		DCC_0_w_en_in, DCC_1_w_en_in, DCC_2_w_en_in, DCC_3_w_en_in, DCC_0_addr_in, DCC_0_data_in,
		DCC_1_addr_in, DCC_1_data_in, DCC_2_addr_in, DCC_2_data_in, DCC_3_addr_in, DCC_3_data_in
	) begin
        if(DCC_0_w_en_in = '1') then  
			heap_modify_addr	<= DCC_0_addr_in;
			heap_modify_data	<= DCC_0_data_in;
        elsif(DCC_1_w_en_in = '1') then  
			heap_modify_addr	<= DCC_1_addr_in;
			heap_modify_data	<= DCC_1_data_in;
        elsif(DCC_2_w_en_in = '1') then  
			heap_modify_addr	<= DCC_2_addr_in;
			heap_modify_data	<= DCC_2_data_in;
        elsif(DCC_3_w_en_in = '1') then  
			heap_modify_addr	<= DCC_3_addr_in;
			heap_modify_data	<= DCC_3_data_in;
		else  
			heap_modify_addr	<= (others => '0');
			heap_modify_data	<= (others => '0');
		end if;
    end process; 
	
	----------------  heap modify request end -------------------------------------
	
	----------------  heap read start-------------------------------------
	process(Bus2IP_Clk) begin
		if(rising_edge(Bus2IP_Clk)) then  
        if(Bus2IP_Reset = '1') then
            heap_ack_0   <= '1';
            heap_ack_1   <= '1';
            heap_ack_2   <= '1';
            heap_ack_3   <= '1';
        else
			-- for jaip_0
			if(DCC_0_r_en_in = '1') then
				if(
					(DCC_0_addr_in(6 to 31) = DCC_1_addr_in(6 to 31) and DCC_1_r_en_in = '0') or
					(DCC_0_addr_in(6 to 31) = DCC_2_addr_in(6 to 31) and DCC_2_r_en_in = '0') or
					(DCC_0_addr_in(6 to 31) = DCC_3_addr_in(6 to 31) and DCC_3_r_en_in = '0')
					--(DCC_0_addr_in = DCC_1_addr_in and DCC_1_r_en_in = '0') or
					--(DCC_0_addr_in = DCC_2_addr_in and DCC_2_r_en_in = '0') or
					--(DCC_0_addr_in = DCC_3_addr_in and DCC_3_r_en_in = '0')
				) then
					heap_ack_0	<= '0';
				else
					heap_ack_0	<= '1';
				end if;
			else
				heap_ack_0	<= '1';
			end if;
			-- for jaip_1
			if(DCC_1_r_en_in = '1') then
				if(
					(DCC_1_addr_in(6 to 31) = DCC_0_addr_in(6 to 31) and DCC_0_r_en_in = '0') or
					(DCC_1_addr_in(6 to 31) = DCC_2_addr_in(6 to 31) and DCC_2_r_en_in = '0') or
					(DCC_1_addr_in(6 to 31) = DCC_3_addr_in(6 to 31) and DCC_3_r_en_in = '0')
					--(DCC_1_addr_in = DCC_0_addr_in and DCC_0_r_en_in = '0') or
					--(DCC_1_addr_in = DCC_2_addr_in and DCC_2_r_en_in = '0') or
					--(DCC_1_addr_in = DCC_3_addr_in and DCC_3_r_en_in = '0')
				) then
					heap_ack_1	<= '0';
				else
					heap_ack_1	<= '1';
				end if;
			else
				heap_ack_1	<= '1';
			end if;
			-- for jaip_2
			if(DCC_2_r_en_in = '1') then
				if(
					(DCC_2_addr_in(6 to 31) = DCC_0_addr_in(6 to 31) and DCC_0_r_en_in = '0') or
					(DCC_2_addr_in(6 to 31) = DCC_1_addr_in(6 to 31) and DCC_1_r_en_in = '0') or
					(DCC_2_addr_in(6 to 31) = DCC_3_addr_in(6 to 31) and DCC_3_r_en_in = '0')
					--(DCC_2_addr_in = DCC_0_addr_in and DCC_0_r_en_in = '0') or
					--(DCC_2_addr_in = DCC_1_addr_in and DCC_1_r_en_in = '0') or
					--(DCC_2_addr_in = DCC_3_addr_in and DCC_3_r_en_in = '0')
				) then
					heap_ack_2	<= '0';
				else
					heap_ack_2	<= '1';
				end if;
			else
				heap_ack_2	<= '1';
			end if;
			-- for jaip_3
			if(DCC_3_r_en_in = '1') then
				if(
					(DCC_3_addr_in(6 to 31) = DCC_0_addr_in(6 to 31) and DCC_0_r_en_in = '0') or
					(DCC_3_addr_in(6 to 31) = DCC_1_addr_in(6 to 31) and DCC_1_r_en_in = '0') or
					(DCC_3_addr_in(6 to 31) = DCC_2_addr_in(6 to 31) and DCC_2_r_en_in = '0')
					--(DCC_3_addr_in = DCC_0_addr_in and DCC_0_r_en_in = '0') or
					--(DCC_3_addr_in = DCC_1_addr_in and DCC_1_r_en_in = '0') or
					--(DCC_3_addr_in = DCC_2_addr_in and DCC_2_r_en_in = '0')
				) then
					heap_ack_3	<= '0';
				else
					heap_ack_3	<= '1';
				end if;
			else
				heap_ack_3	<= '1';
			end if;
		end if;
		end if;
    end process; 
	----------------  heap read end-------------------------------------
	
	-- for cache coherence end =============================================================================
	 
	
	
	
	
	
	
	-- for each new thread started (including main thread) , DCC is responsible to assign each thread to a specified core
	-- added by T.H.Wu , 2013.9.6
	simul_mt_label0 : if SIMULTANEOUS_MULTITHREAD_VER_ENABLE = 1 generate
	
	--  cache coherence response , forward  JAIP core
	COOR2JAIP_response_msg <=	COOR2JAIP_response_msg_reg when mutex_state = SEND_RES_MSG else x"FC00";
	COOR2JAIP_res_newTH_data1	<=	arbitor_data1; -- just for assigning new thread use
	COOR2JAIP_res_newTH_data2	<=	arbitor_data2;
	
	
	-- cache coherence response , modified since 2014.2.14
	-- there's probably a problem if Data coherence write signal and new thread flag works simultaneously 
	DCC_0_addr_out	<=  heap_addr_out_0 ;
	DCC_0_data_out	<=  heap_data_out_0 ;
	DCC_1_addr_out	<=  heap_addr_out_1 ;
	DCC_1_data_out	<=  heap_data_out_1 ;
	DCC_2_addr_out	<=  heap_addr_out_2 ;
	DCC_2_data_out	<=  heap_data_out_2 ;
	DCC_3_addr_out	<=	heap_addr_out_3 ;
	DCC_3_data_out	<= 	heap_data_out_3 ;
	
	
				
	
	
	process (Bus2IP_Clk) begin
		if(rising_edge(Bus2IP_Clk)) then
			if(Bus2IP_Reset = '1') then
				for index in 0 to 3 loop
					jaip_core_state_list(index) <= (others=>'0');
				end loop;
				lock_flag					<=	'0';
				--mutex_state					<=	IDLE;
				dly_counter					<=	x"0";
				cmd_sender_coreID_reg		<=	"111";
				cmd_sender_TH_slot_idx_reg	<=	x"0";
				assign_new_TH_flag		<=	'0';
				monEnter_flag <= '0';
				monExit_flag <= '0';
				arbitor_data1 <= (others=>'0');
				arbitor_data2 <= (others=>'0');
				COOR2JAIP_response_msg_reg	<=	("111" & "111" & "00" &  x"00");
				new_TH_to_coreID_tmp0	<=	"111";
				new_TH_to_coreID_tmp1	<=	"111";
				new_TH_to_THnum_tmp0	<=	"00000";
				new_TH_to_THnum_tmp1	<=	"00000";
				new_TH_to_coreID		<= (others=>'1');
				new_TH_to_THnum			<=	"00000";
				response_msg_monEnter	<= "111"& "111" & x"0" & "000000" ;
				response_msg_monExit	<= "111"& "111" & x"0" & "000000" ;
				bram_rd_addr_counter	<=	(others=>'0');
				bram_addrA_dly				<=	(others=>'0');
				bram_addrB_dly				<=	(others=>'0');
				numLock_checked				<=	(others=>'0');
				lockObj_currentCount		<=	(others=>'0');
				bram_addrB_2lockOwner		<=	(others=>'0');
				bram_addrB_nxtEmptyWaitLst	<=	(others=>'0');
				EmptyLockObjEntry_rdy_flag		<=	'0';
				bram_addrA_nxtEmptyLockObjLst	<=	(others=>'0');
				nxtLockOwnerInfo			<=	(others=>'0');
				lock_obj_match_flag			<=	'0' ;
				lock_obj_free_flag			<=	'0' ;
				the_owner_lock_twice		<=	'0' ; 
				the_owner_release_multi_times<=	'0' ; 
				find_emptyEntry_waitTHlist	<=	'0';
				search_waitLst_flag_dly		<=	'0';
				search_waitLst_flag			<=	'0';
				lastNode_lockObj_flag		<=	'0';
				lastNode_lockObj_flag_dly	<=	'0';
				obj_locked_slot_idx			<=	"00";
				mon_exit_now_owner_release	<=	'0';
				mon_exit_next_owner_exist	<=	'0';
				mon_exit_obj_lock_cnt		<=	"00";
				empty_slot_idx_obj_lock_list<=	"00";
				empty_slot_idx_wait_list	<=	x"0";
				next_owner_slot_idx_wait_list<=	x"0";
				next_owner_core_ID			<=	"00";
				next_owner_slot_idx_TCB_list<=	x"0";
				monitor_cnt_modified		<=	"000000";
			else
				for index in 0 to 3 loop
					jaip_core_state_list(index) <= jaip_core_state_list_w(index);
				end loop;
				lock_flag					<=	lock_flag_w;
				--mutex_state					<=	mutex_state_w;
				dly_counter					<=	dly_counter_w;
				cmd_sender_coreID_reg		<=	cmd_sender_coreID_reg_w;
				cmd_sender_TH_slot_idx_reg	<=	cmd_sender_TH_slot_idx_reg_w;
				-- for command new thread (including main thread)
				assign_new_TH_flag 		<= assign_new_TH_flag_w; 
				arbitor_data1 <= arbitor_data1_w;
				arbitor_data2 <= arbitor_data2_w;
				COOR2JAIP_response_msg_reg	<=	COOR2JAIP_response_msg_reg_w;
				new_TH_to_coreID_tmp0	<=	new_TH_to_coreID_tmp0_w;
				new_TH_to_coreID_tmp1	<=	new_TH_to_coreID_tmp1_w;
				new_TH_to_THnum_tmp0	<=	new_TH_to_THnum_tmp0_w;
				new_TH_to_THnum_tmp1	<=	new_TH_to_THnum_tmp1_w;
				new_TH_to_coreID		<=	new_TH_to_coreID_w;
				new_TH_to_THnum			<=	new_TH_to_THnum_w;
				-- for command monitorenter
				monEnter_flag				<=	monEnter_flag_w;
				response_msg_monEnter		<=	response_msg_monEnter_w;
				the_owner_lock_twice		<=	the_owner_lock_twice_w ; 
				the_owner_release_multi_times<=	the_owner_release_multi_times_w;
				find_emptyEntry_waitTHlist	<=	find_emptyEntry_waitTHlist_w;
				search_waitLst_flag			<=	search_waitLst_flag_w;
				search_waitLst_flag_dly		<=	search_waitLst_flag;
				lastNode_lockObj_flag		<=	lastNode_lockObj_flag_w;
				lastNode_lockObj_flag_dly	<=	lastNode_lockObj_flag;
				empty_slot_idx_obj_lock_list<=	empty_slot_idx_obj_lock_list_w;
				empty_slot_idx_wait_list	<=	empty_slot_idx_wait_list_w;
				-- for command monitorexit
				monExit_flag				<= monExit_flag_w;
				response_msg_monExit		<=	response_msg_monExit_w;
				bram_rd_addr_counter		<=	bram_rd_addr_counter_w;
				bram_addrA_dly				<=	bram_addrA;
				bram_addrB_dly				<=	bram_addrB;
				numLock_checked				<=	numLock_checked_w;
				bram_addrB_2lockOwner		<=	bram_addrB_2lockOwner_w;
				bram_addrB_nxtEmptyWaitLst	<=	bram_addrB_nxtEmptyWaitLst_w;
				EmptyLockObjEntry_rdy_flag		<=	EmptyLockObjEntry_rdy_flag_w;
				bram_addrA_nxtEmptyLockObjLst	<=	bram_addrA_nxtEmptyLockObjLst_w	;
				nxtLockOwnerInfo			<=	nxtLockOwnerInfo_w;
				lockObj_currentCount		<=	lockObj_currentCount_w;
				mon_exit_now_owner_release	<=	mon_exit_now_owner_release_w;
				mon_exit_next_owner_exist	<=	mon_exit_next_owner_exist_w;
				mon_exit_obj_lock_cnt		<=	mon_exit_obj_lock_cnt_w;
				next_owner_slot_idx_wait_list	<=	next_owner_slot_idx_wait_list_w;
				next_owner_core_ID			<=	next_owner_core_ID_w;
				next_owner_slot_idx_TCB_list<=	next_owner_slot_idx_TCB_list_w;
				monitor_cnt_modified		<=	monitor_cnt_modified_w;
				-- for both monitorenter / monitorexit
				lock_obj_match_flag			<=	lock_obj_match_flag_w ;
				lock_obj_free_flag			<=	lock_obj_free_flag_w ;
				obj_locked_slot_idx			<=	obj_locked_slot_idx_w;
			end if;
			---------
			assign_new_TH_flag_dly		<= assign_new_TH_flag; 
			assign_new_TH_flag_dly2		<= assign_new_TH_flag_dly;
			assign_new_TH_flag_dly3		<= assign_new_TH_flag_dly2;
		end if;
	end process;
	--  
	
	-- added bby T.H.Wu, 2014.2.13
	process (
		JAIP2COOR_cmd0, JAIP2COOR_cmd1, JAIP2COOR_cmd2, JAIP2COOR_cmd3, lock_flag, 
		we, mem_address, mutex_state
	) begin 
		lock_flag_w	<=	lock_flag;
		if (mutex_state=TASK_CMPLT) then
			lock_flag_w	<=	'0';
		elsif (
			(JAIP2COOR_cmd0 or JAIP2COOR_cmd1 or JAIP2COOR_cmd2 or JAIP2COOR_cmd3) /= "000" or 
			(we = '1' and mem_address = "00000010000001")
		) then
			lock_flag_w	<=	'1';
		end if;
	end process;
	
	
	
	resetAllflg_locObjCtrl_w	<=	'1' when mutex_state/=WAIT_FOR_RES and mutex_state/=GEN_RES_MSG else '0';
	
	EO_lockObjAccess_flag_cond1_w	<=	'1'	when
										(arbitor_cmd_msg(3 to 5)="001" and  mutex_state = WAIT_FOR_RES and
										lock_obj_match_flag='1' and search_waitLst_flag='1'	and bram_DOB(6 downto 0)="1111111")
								else	'0';
	EO_lockObjAccess_flag_cond2_w	<=	'1' when 
										(arbitor_cmd_msg(3 to 5)="001" and  mutex_state = WAIT_FOR_RES and
										find_emptyEntry_waitTHlist='1' and lock_obj_free_flag='1')
								else	'0';
	EO_lockObjAccess_flag_cond3_w	<=	'1' when
										(arbitor_cmd_msg(3 to 5)="010" and  mutex_state = WAIT_FOR_RES and
										search_waitLst_flag_dly='1')
								else	'0';
	EO_lockObjAccess_allMix_w		<=	assign_new_TH_flag_dly3 or EO_lockObjAccess_flag_cond1_w or EO_lockObjAccess_flag_cond2_w or EO_lockObjAccess_flag_cond3_w;
								
								
	-- added bby T.H.Wu, 2014.3.19
	--process (
	--	mutex_state, lock_flag, assign_new_TH_flag_dly3, EO_lockObjAccess_flag_cond1_w, EO_lockObjAccess_flag_cond2_w,
	--	EO_lockObjAccess_flag_cond3_w, dly_counter, arbitor_cmd_msg, COOR2JAIP_response_msg_reg, JAIP2COOR0_pending_resMsgSent,
	--	JAIP2COOR1_pending_resMsgSent,	JAIP2COOR3_pending_resMsgSent, JAIP2COOR2_pending_resMsgSent
	--) begin 
		--mutex_state_w	<=	mutex_state;
	process (Bus2IP_Clk) begin
		if(rising_edge(Bus2IP_Clk)) then
		if(Bus2IP_Reset = '1') then
			mutex_state	<=	IDLE;
		else
			case mutex_state is
			when IDLE =>
				if(lock_flag='1') then
					mutex_state	<=	WAIT_FOR_RES;
				else
					mutex_state	<=	IDLE;
				end if;
				
			when WAIT_FOR_RES =>
				if(EO_lockObjAccess_allMix_w='1') then
					mutex_state	<=	GEN_RES_MSG;
				else
					mutex_state	<=	WAIT_FOR_RES;
				end if;
				
			when GEN_RES_MSG =>
				mutex_state	<=	CHECK_JAIP_TCBLIST_RDY;
				
			when CHECK_JAIP_TCBLIST_RDY =>
				--if (COOR2JAIP_response_msg_reg (15 downto 13)=COOR2JAIP_response_msg_reg (12 downto 10)) then
				--	mutex_state_w	<=	SEND_RES_MSG;
				--else
					case COOR2JAIP_response_msg_reg (15 downto 13) is
						when "000"	=>
							if (JAIP2COOR0_pending_resMsgSent='0') then
								mutex_state	<=	SEND_RES_MSG;
							else
								mutex_state	<=	CHECK_JAIP_TCBLIST_RDY;
							end if;
						when "001"	=>
							if (JAIP2COOR1_pending_resMsgSent='0') then
								mutex_state	<=	SEND_RES_MSG;
							else
								mutex_state	<=	CHECK_JAIP_TCBLIST_RDY;
							end if;
						when "010"	=>
							if (JAIP2COOR2_pending_resMsgSent='0') then
								mutex_state	<=	SEND_RES_MSG;
							else
								mutex_state	<=	CHECK_JAIP_TCBLIST_RDY;
							end if;
						when "011"	=>
							if (JAIP2COOR3_pending_resMsgSent='0') then
								mutex_state	<=	SEND_RES_MSG;
							else
								mutex_state	<=	CHECK_JAIP_TCBLIST_RDY;
							end if;
						when	others =>
							mutex_state	<=	SEND_RES_MSG;
					end case;
				--end if;
				
			when SEND_RES_MSG =>
				mutex_state	<=	WAIT_FOR_CMPLT;
				
			when WAIT_FOR_CMPLT =>
				if(arbitor_cmd_msg(3 to 5)="011") then  -- completion of new thread
					if(dly_counter=x"A") then
						mutex_state	<=	TASK_CMPLT;
					else
						mutex_state	<=	WAIT_FOR_CMPLT;
					end if;
				else
					mutex_state	<=	TASK_CMPLT;
				end if;
				
			when TASK_CMPLT =>
				mutex_state	<=	IDLE;
				
			when others => 
				mutex_state	<=	IDLE;
			end case;
		end if;
		end if;
	end process;
	
	
	-- added bby T.H.Wu, 2014.2.13
	process (mutex_state, dly_counter) begin 
		dly_counter_w	<=	dly_counter;
		if(mutex_state=WAIT_FOR_CMPLT) then
			dly_counter_w	<=	dly_counter + x"1";
		elsif(mutex_state=TASK_CMPLT) then
			dly_counter_w	<=	x"0";
		end if;
	end process;
	
	
	
	-- decode the command , generate all related flags
	process (
		arbitor_cmd_msg, assign_new_TH_flag, we, monEnter_flag, monExit_flag, cmd_sender_coreID_reg,
		cmd_sender_TH_slot_idx_reg, lock_flag, mutex_state, arbitor_data2
	) begin 
		monEnter_flag_w					<=	monEnter_flag ;
		monExit_flag_w					<=	monExit_flag ;
		assign_new_TH_flag_w			<=	assign_new_TH_flag; 
		cmd_sender_coreID_reg_w			<=	cmd_sender_coreID_reg;
		cmd_sender_TH_slot_idx_reg_w	<=	cmd_sender_TH_slot_idx_reg;
		
		--- decode for monitor enter ----------
		if (lock_flag='1' and mutex_state=IDLE) then
			if(arbitor_cmd_msg(3 to 5)="001") then
				monEnter_flag_w <= '1';
			end if;
			--- decode for monitor exit ----------
			if(arbitor_cmd_msg(3 to 5)="010") then
				monExit_flag_w <= '1';
			end if;
			--- decode for new thread ----------
			if(arbitor_cmd_msg(3 to 5)="011") then
				assign_new_TH_flag_w <= '1';
			end if;
		else
			monEnter_flag_w <= '0'; 
			monExit_flag_w <= '0';
			assign_new_TH_flag_w <= '0';
		end if;
		
		
		--- the core ID of the message sender ---
		if(lock_flag='1') then
			cmd_sender_coreID_reg_w <= arbitor_cmd_msg(0 to 2);
		end if;
		-- the slot local index of currnetly running thread in specific Java core.
		if(lock_flag='1') then
		--if(arbitor_cmd_msg(3 to 5)="001" or arbitor_cmd_msg(3 to 5)="010") then
			cmd_sender_TH_slot_idx_reg_w	<=	arbitor_data2(3 downto 0);
		end if;
		-------------  
	end process;
	
	
	----for new thread start (simultaneous multi-thread) -----------------------------------------------------------------
	-- 1.search the core which contains the smallest number of threads
	--   find next proper core if these is a new thread coming (assume only 2 cores are available , 2013.10.6)
	process (
		assign_new_TH_flag, jaip_core_state_list, new_TH_to_coreID, assign_new_TH_flag_dly, new_TH_to_THnum,
		new_TH_to_coreID_tmp0, new_TH_to_coreID_tmp1, new_TH_to_THnum_tmp0, new_TH_to_THnum_tmp1
	) begin
		new_TH_to_coreID_w	<=	new_TH_to_coreID;
		new_TH_to_THnum_w	<=	new_TH_to_THnum;
		new_TH_to_coreID_tmp0_w	<=	new_TH_to_coreID_tmp0;
		new_TH_to_coreID_tmp1_w	<=	new_TH_to_coreID_tmp1;
		new_TH_to_THnum_tmp0_w	<=	new_TH_to_THnum_tmp0;
		new_TH_to_THnum_tmp1_w	<=	new_TH_to_THnum_tmp1;
		
		if(assign_new_TH_flag='1') then
			
			-- if 4 cores are available , reserved 2013.9.6
			-- round 1
			if ( jaip_core_state_list(0)(4 downto 0) > jaip_core_state_list(1)(4 downto 0) ) then
				new_TH_to_coreID_tmp0_w <= "001";
				new_TH_to_THnum_tmp0_w	<= jaip_core_state_list(1)(4 downto 0);
			else
				new_TH_to_coreID_tmp0_w <= "000";
				new_TH_to_THnum_tmp0_w	<= jaip_core_state_list(0)(4 downto 0);
			end if;
			if ( jaip_core_state_list(2)(4 downto 0) > jaip_core_state_list(3)(4 downto 0) ) then
				new_TH_to_coreID_tmp1_w <= "011";
				new_TH_to_THnum_tmp1_w	<= jaip_core_state_list(3)(4 downto 0);
			else
				new_TH_to_coreID_tmp1_w <= "010";
				new_TH_to_THnum_tmp1_w	<= jaip_core_state_list(2)(4 downto 0);
			end if;
		end if;
		
			
		-- round 2
		if(assign_new_TH_flag_dly='1') then
			-- if 1 cores are available ... for test
			new_TH_to_coreID_w	<= "000";
			new_TH_to_THnum_w	<= jaip_core_state_list(0)(4 downto 0);
			-- if 2 cores are available
			--if ( jaip_core_state_list(0)(4 downto 0) > jaip_core_state_list(1)(4 downto 0) ) then
			--	new_TH_to_coreID_w <= "001";
			--else
			--	new_TH_to_coreID_w <= "000";
			--end if;
			-- if 4 cores are available ...
			--if ( new_TH_to_THnum_tmp0 > new_TH_to_THnum_tmp1) then
			--	new_TH_to_coreID_w	<= new_TH_to_coreID_tmp1;
			--	new_TH_to_THnum_w	<= new_TH_to_THnum_tmp1;
			--else
			--	new_TH_to_coreID_w	<= new_TH_to_coreID_tmp0;
			--	new_TH_to_THnum_w	<= new_TH_to_THnum_tmp0;
			--end if;
		end if;
	end process;
	-- 2.	construct response message and prepare starting method id and object ref for target JAIP core 
	process (
		arbitor_data1, arbitor_data2, arbitor_cmd_msg, main_method, DCC_0_addr_in, DCC_0_data_in, DCC_1_addr_in, DCC_1_data_in,
		DCC_2_addr_in, DCC_2_data_in, DCC_3_addr_in, DCC_3_data_in
	) begin
		arbitor_data1_w			<= arbitor_data1;
		arbitor_data2_w			<= arbitor_data2;
		-- 
		-- from specific JAIP core (new thread)
			case arbitor_cmd_msg(0 to 2) is
				when "000" =>
					arbitor_data1_w	<= DCC_0_addr_in;
					arbitor_data2_w	<= DCC_0_data_in; 
				when "001" =>
					arbitor_data1_w	<= DCC_1_addr_in;
					arbitor_data2_w	<= DCC_1_data_in; 
				when "010" =>
					arbitor_data1_w	<= DCC_2_addr_in;
					arbitor_data2_w	<= DCC_2_data_in;
				when "011" =>
					arbitor_data1_w	<= DCC_3_addr_in;
					arbitor_data2_w	<= DCC_3_data_in;
				when "100" =>
					arbitor_data1_w	<= main_method; -- from RISC (main thread)
					arbitor_data2_w	<= (others => '0'); 
				when others =>
					arbitor_data1_w	<= (others => '0');
					arbitor_data2_w	<= (others => '0');
			end case; 
	end process;
	 
	-- 3. update the starting method ID (class ID) and object reference from RISC or particular JAIP core. 
	process (jaip_core_state_list,assign_new_TH_flag_dly2,new_TH_to_coreID, new_TH_to_THnum) begin
		for index in 0 to 3 loop
			jaip_core_state_list_w (index) <= jaip_core_state_list(index);
		end loop;
		--
		if (assign_new_TH_flag_dly2='1') then
			jaip_core_state_list_w(to_integer(unsigned(new_TH_to_coreID)))(5) <= '1';
			jaip_core_state_list_w(to_integer(unsigned(new_TH_to_coreID)))(4 downto 0)	<= new_TH_to_THnum + "01"; 
		end if;
		--  thread dead case ?? , 2013.9.6
	end process;
	----for new thread end (simultaneous multi-thread) -----------------------------------------------------------------
	
	
	----for monitor enter start (simultaneous multi-thread) -----------------------------------------------------------------
	
	
	--
	process (bram_rd_addr_counter, mutex_state) begin
		bram_rd_addr_counter_w	<=	bram_rd_addr_counter;
		if(mutex_state = WAIT_FOR_RES) then
			bram_rd_addr_counter_w	<=	bram_rd_addr_counter + "01";
		else
			bram_rd_addr_counter_w	<=	(others=>'0');
		end if;
	end process;
	--
	-- modified since 2014.3.13
	process (lockObj_currentCount, mutex_state, arbitor_cmd_msg, lock_obj_free_flag, lastNode_lockObj_flag_dly) begin
		lockObj_currentCount_w	<=	lockObj_currentCount;
		if(mutex_state=GEN_RES_MSG) then
			if(arbitor_cmd_msg(3 to 5)="001" and lock_obj_free_flag='1') then -- monitorenter
				lockObj_currentCount_w	<=	lockObj_currentCount + "01";
			elsif(arbitor_cmd_msg(3 to 5)="010" and lastNode_lockObj_flag_dly='1') then -- monitorexit
				lockObj_currentCount_w	<=	lockObj_currentCount - "01";
			end if;
		end if;
	end process;
	--
	process (
		numLock_checked, lock_obj_match_flag, lock_obj_free_flag, mutex_state,
		monEnter_flag, monExit_flag, is_lock_obj_entry_occupied_w
	) begin
		numLock_checked_w	<=	numLock_checked;
		if ( 
			(monEnter_flag='0' and monExit_flag='0') and (lock_obj_match_flag='0' and lock_obj_free_flag='0')
			and mutex_state = WAIT_FOR_RES and is_lock_obj_entry_occupied_w='1'
		) then
			numLock_checked_w	<=	numLock_checked + "01";
		elsif(mutex_state = GEN_RES_MSG) then
			numLock_checked_w	<=	(others=>'0');
		end if;
	end process;
	--
	-- lock_obj_match_flag: both monEnter/monExit will use it
	-- lock_obj_free_flag: only monEnter may use it
	-- bram_addrB_2lockOwner: both monitorenter/monitorexit will use it.
	process (
		lock_obj_match_flag, lock_obj_free_flag, bram_DOA(30 downto 0), arbitor_data1(25 downto 2), numLock_checked,
		lockObj_currentCount, bram_addrB_2lockOwner, monEnter_flag, monExit_flag, mutex_state, resetAllflg_locObjCtrl_w,
		the_owner_lock_twice, arbitor_cmd_msg, search_waitLst_flag, search_waitLst_flag_dly, bram_DOB, the_owner_lock_twice_w,
		cmd_sender_coreID_reg, cmd_sender_TH_slot_idx_reg, the_owner_release_multi_times, monitor_cnt_modified
	) begin
		lock_obj_match_flag_w		<=	lock_obj_match_flag ;
		lock_obj_free_flag_w		<=	lock_obj_free_flag ;
		the_owner_lock_twice_w		<=	the_owner_lock_twice;
		bram_addrB_2lockOwner_w		<=	bram_addrB_2lockOwner;
		the_owner_release_multi_times_w	<=	the_owner_release_multi_times;
		monitor_cnt_modified_w		<=	monitor_cnt_modified;
		
		if (
			monEnter_flag='0' and monExit_flag='0' and bram_DOA(30 downto 7) = arbitor_data1(25 downto 2)  and
			mutex_state = WAIT_FOR_RES
		) then
			lock_obj_match_flag_w		<=	'1' ;
		elsif (resetAllflg_locObjCtrl_w='1') then
			lock_obj_match_flag_w		<=	'0' ;
		end if;
		if (monEnter_flag='0' and numLock_checked = lockObj_currentCount and lock_obj_match_flag='0' and mutex_state = WAIT_FOR_RES) then
			lock_obj_free_flag_w		<=	'1' ;
		elsif (resetAllflg_locObjCtrl_w='1') then
			lock_obj_free_flag_w		<=	'0' ;
		end if;
		-- modified by T.H.Wu, 2014.3.12, for testing
		--if(bram_DOA(30 downto 7) = arbitor_data1(25 downto 2)) then 
		if(bram_DOA(30 downto 7) = arbitor_data1(25 downto 2) and lock_obj_match_flag='0') then
			bram_addrB_2lockOwner_w		<=	bram_DOA (6 downto 0);
		end if;
		-- modified by T.H.Wu, 2014.3.12, for testing
		if(
			arbitor_cmd_msg(3 to 5)="001" and lock_obj_match_flag='1' and search_waitLst_flag='1' and search_waitLst_flag_dly='0' and
			("0"&bram_DOB(30 downto 29))=cmd_sender_coreID_reg and bram_DOB(25 downto 22)=cmd_sender_TH_slot_idx_reg(3 downto 0)
		) then
			the_owner_lock_twice_w	<=	'1';
		elsif (resetAllflg_locObjCtrl_w='1') then
			the_owner_lock_twice_w	<=	'0';
		end if;
		--
		if (
			arbitor_cmd_msg(3 to 5)="010" and search_waitLst_flag='1' and search_waitLst_flag_dly='0' and
			bram_DOB(21 downto 16)/="000001"
		) then
			the_owner_release_multi_times_w	<=	'1';
		elsif (resetAllflg_locObjCtrl_w='1') then
			the_owner_release_multi_times_w	<=	'0';
		end if;
		-- 
		if(the_owner_lock_twice_w='1' and search_waitLst_flag='1' and search_waitLst_flag_dly='0') then
			monitor_cnt_modified_w		<=	bram_DOB(21 downto 16) + "000001";
		elsif(the_owner_release_multi_times_w='1' and search_waitLst_flag='1' and search_waitLst_flag_dly='0') then
			monitor_cnt_modified_w		<=	bram_DOB(21 downto 16) - "000001";
		elsif(resetAllflg_locObjCtrl_w='1') then
			monitor_cnt_modified_w		<=	"000000";
		end if;
		-- -- --
	end process;
	--
	-- find_emptyEntry_waitTHlist, it goes while monEnter is executed. 
	process (
		find_emptyEntry_waitTHlist, bram_DOB(31), mutex_state, monEnter_flag, resetAllflg_locObjCtrl_w
	) begin
		find_emptyEntry_waitTHlist_w	<=	find_emptyEntry_waitTHlist;
		if(monEnter_flag='0' and bram_DOB(31)='0' and mutex_state = WAIT_FOR_RES) then
			find_emptyEntry_waitTHlist_w	<=	'1';
		elsif(resetAllflg_locObjCtrl_w='1') then
			find_emptyEntry_waitTHlist_w	<=	'0';
		end if;
	end process;
	--
	process (
		bram_addrB_nxtEmptyWaitLst, find_emptyEntry_waitTHlist, bram_addrB_dly
	) begin
		bram_addrB_nxtEmptyWaitLst_w	<=	bram_addrB_nxtEmptyWaitLst;
		if(find_emptyEntry_waitTHlist='0') then
			bram_addrB_nxtEmptyWaitLst_w	<=	bram_addrB_dly(6 downto 0);
		end if;
	end process;
	--
	process (
		EmptyLockObjEntry_rdy_flag, bram_addrA_nxtEmptyLockObjLst, mutex_state, resetAllflg_locObjCtrl_w,
		is_lock_obj_entry_occupied_w, bram_addrA_dly, lock_obj_match_flag_w, arbitor_cmd_msg(3 to 5)
	)begin
		EmptyLockObjEntry_rdy_flag_w	<=	EmptyLockObjEntry_rdy_flag;
		bram_addrA_nxtEmptyLockObjLst_w	<=	bram_addrA_nxtEmptyLockObjLst;
		if(
			-- if command monitorenter coming...
			(mutex_state = WAIT_FOR_RES and is_lock_obj_entry_occupied_w='0' and arbitor_cmd_msg(3 to 5)="001")
			or
			-- if command monitorexit coming...
			(lock_obj_match_flag_w='1' and arbitor_cmd_msg(3 to 5)="010")
		) then -- should we add the condition monEnter_flag='0' onto the statement ?
			EmptyLockObjEntry_rdy_flag_w	<=	'1';
		elsif(resetAllflg_locObjCtrl_w='1') then
			EmptyLockObjEntry_rdy_flag_w	<=	'0';
		end if;
		if(EmptyLockObjEntry_rdy_flag='0') then
			bram_addrA_nxtEmptyLockObjLst_w	<=	bram_addrA_dly (6 downto 0);
		end if;
	end process;
	--
	process (
		search_waitLst_flag, find_emptyEntry_waitTHlist, lock_obj_match_flag, arbitor_cmd_msg, resetAllflg_locObjCtrl_w
	) begin
		search_waitLst_flag_w			<=	search_waitLst_flag;
		if(
			(
				(arbitor_cmd_msg(3 to 5)="001" and find_emptyEntry_waitTHlist='1') and lock_obj_match_flag='1'
			)
			--or ((arbitor_cmd_msg(3 to 5)="001" and find_emptyEntry_waitTHlist='1') and lock_obj_free_flag='1')
			or
			(arbitor_cmd_msg(3 to 5)="010" and lock_obj_match_flag='1')
		) then
			search_waitLst_flag_w	<=	'1';
		elsif(resetAllflg_locObjCtrl_w='1') then
			search_waitLst_flag_w	<=	'0';
		end if;
	end process;
	--
	process (
		lastNode_lockObj_flag, search_waitLst_flag, arbitor_cmd_msg(3 to 5), bram_DOB(6 downto 0),
		the_owner_release_multi_times_w
	) begin
		lastNode_lockObj_flag_w <= lastNode_lockObj_flag;
		if(arbitor_cmd_msg(3 to 5)="010" and search_waitLst_flag='1' and bram_DOB(6 downto 0)="1111111" and the_owner_release_multi_times_w='0') then
			lastNode_lockObj_flag_w	<=	'1';
		else
			lastNode_lockObj_flag_w	<=	'0';
		end if;
	end process;
	--
	process (
		nxtLockOwnerInfo, EO_lockObjAccess_flag_cond3_w, lastNode_lockObj_flag, cmd_sender_coreID_reg,
		bram_DOB, the_owner_release_multi_times
	) begin
		nxtLockOwnerInfo_w	<=	nxtLockOwnerInfo;
		if(EO_lockObjAccess_flag_cond3_w='1') then
			if(lastNode_lockObj_flag='1' or the_owner_release_multi_times='1') then
				nxtLockOwnerInfo_w <= cmd_sender_coreID_reg(1 downto 0) & "000000";
			else
				nxtLockOwnerInfo_w <= bram_DOB(30 downto 29) & bram_DOB(27 downto 22);
			end if;
		end if;
	end process;
				
	----for monitor enter end	(simultaneous multi-thread) -----------------------------------------------------------------
	
	is_lock_obj_entry_occupied_w	<=	bram_DOA(31);

	-- modified since 2014.3.12, a thread may acquire lock multiple times. 
	bram_weA	<=	'1'	when	(EO_lockObjAccess_flag_cond1_w or EO_lockObjAccess_flag_cond2_w or (EO_lockObjAccess_flag_cond3_w and not the_owner_release_multi_times))='1'
			else	'0';
	bram_weB	<=	'1'	when	((EO_lockObjAccess_flag_cond1_w and (not the_owner_lock_twice_w)) or EO_lockObjAccess_flag_cond2_w or EO_lockObjAccess_flag_cond3_w)='1'
			else	'0';
	
	bram_addrA	<=	
					"01" & bram_addrA_nxtEmptyLockObjLst	when EO_lockObjAccess_flag_cond2_w = '1' or 
																	(arbitor_cmd_msg(3 to 5)="010" and  mutex_state = WAIT_FOR_RES and search_waitLst_flag='1')
			else	"00" & bram_addrB_dly(6 downto 0)		when EO_lockObjAccess_flag_cond1_w = '1'
			else	"01" & bram_rd_addr_counter;
	bram_addrB	<=	
					"00" & bram_addrB_nxtEmptyWaitLst	when EO_lockObjAccess_flag_cond1_w = '1' or EO_lockObjAccess_flag_cond2_w = '1'
			else	"00" & bram_addrB_2lockOwner		when (search_waitLst_flag_w='1' and search_waitLst_flag='0')
																or the_owner_release_multi_times_w='1' or EO_lockObjAccess_flag_cond3_w = '1'
			else	"00" & bram_DOB(6 downto 0)			when search_waitLst_flag='1'
						-- ok
			--else	debug_waitTH_addrB (8 downto 0)		when debug_waitTH_addrB(31) = '1'
			else	"00" & bram_rd_addr_counter;

			
	bram_DIA	<=	
					--x"7FFFFFFF"	when EO_lockObjAccess_flag_cond3_w = '1' and lastNode_lockObj_flag = '1'
					bram_DOA(31 downto 7) & bram_addrB_dly(6 downto 0)	when EO_lockObjAccess_flag_cond3_w = '1' and lastNode_lockObj_flag = '0'
			else	"1"& arbitor_data1(25 downto 2) & bram_addrB_nxtEmptyWaitLst when EO_lockObjAccess_flag_cond2_w = '1'
			else	bram_DOB(31 downto 7) & bram_addrB_nxtEmptyWaitLst	when EO_lockObjAccess_flag_cond1_w='1' and the_owner_lock_twice_w='0'
			else	bram_DOB(31 downto 22) & monitor_cnt_modified_w & (x"00"&"0") & bram_DOB(6 downto 0)	when EO_lockObjAccess_flag_cond1_w='1' and the_owner_lock_twice_w='1'
			else	x"7FFFFFFF";
	bram_DIB	<=	
					--&"000001"&"000000000"&"1111111";
					"1"& cmd_sender_coreID_reg(1 downto 0)&"000"&cmd_sender_TH_slot_idx_reg(3 downto 0)	&"000001"&x"007F"
								when (EO_lockObjAccess_flag_cond1_w or EO_lockObjAccess_flag_cond2_w) = '1'
			else	bram_DOB(31 downto 22) & monitor_cnt_modified & (x"00"&"0") & bram_DOB(6 downto 0)
								when EO_lockObjAccess_flag_cond3_w = '1' and the_owner_release_multi_times = '1'
			else	x"7FFFFFFF";
	
	-- main storage for lock object, waiting thread list
	-- we divide the block RAM in following way:
	-- [remind] distribution of this BRAM
	-- 00_000_0000 <-- for storing 2^7=128 waiting threads
	-- 01_000_0000 <-- for storing 2^7=128 lock object references
	-- 
		lock_obj_wait_list : RAMB16_S36_S36
		generic map( 
			INIT_00 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_01 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_02 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_03 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_04 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_05 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_06 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_07 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_08 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_09 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_0A => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_0B => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_0C => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_0D => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_0E => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_0F => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_10 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_11 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_12 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_13 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_14 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_15 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_16 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_17 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_18 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_19 => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_1A => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_1B => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_1C => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_1D => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_1E => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INIT_1F => X"7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF7FFFFFFF",
			INITP_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
			INITP_07 => X"0000000000000000000000000000000000000000000000000000000000000000"
		)
		port map(
			-- port A
			ADDRA	=> bram_addrA,
			DIPA	=> (others=>'0') ,
			DIA		=> bram_DIA , 
			DOA		=> bram_DOA ,
			CLKA	=> Bus2IP_Clk,
			SSRA	=> Bus2IP_Reset,
			ENA 	=> '1',
			WEA		=> bram_weA,
			-- port B
			ADDRB	=> bram_addrB, 
			DIPB	=> (others=>'0') ,
			DIB		=> bram_DIB , 
			DOB		=> bram_DOB ,
			CLKB 	=> Bus2IP_Clk,
			SSRB 	=> Bus2IP_Reset,
			ENB		=> '1',
			WEB		=> bram_weB
		);
	
	
	
	-- final response message
	process (
		mutex_state, COOR2JAIP_response_msg_reg, arbitor_cmd_msg, response_msg_monEnter,
		response_msg_monExit, new_TH_to_coreID, cmd_sender_coreID_reg
	) begin
		COOR2JAIP_response_msg_reg_w	<=	COOR2JAIP_response_msg_reg;
		if (mutex_state = GEN_RES_MSG) then
			case arbitor_cmd_msg(3 to 5) is
				when "001" => COOR2JAIP_response_msg_reg_w <=	cmd_sender_coreID_reg & cmd_sender_coreID_reg &
																("010"& (lock_obj_match_flag and not the_owner_lock_twice)) &
																"000000";
				when "010" => COOR2JAIP_response_msg_reg_w <=   ("0" & nxtLockOwnerInfo(7 downto 6)) & cmd_sender_coreID_reg &
																("011"& (lastNode_lockObj_flag_dly or the_owner_release_multi_times)) &	nxtLockOwnerInfo(5 downto 0);
																-- note 2014.2.20, it's not completed because recursive acquiring lock 
																-- is lacked, there are 2 situations for response = 0111 
																-- 1. lock free, 2. 重複 lock!
				when "011" => COOR2JAIP_response_msg_reg_w <= new_TH_to_coreID & cmd_sender_coreID_reg & "0010" & "000000";
				when others => COOR2JAIP_response_msg_reg_w <= ("111" & "111" & "00" &  x"00");
			end case; 
		--else
		--	COOR2JAIP_response_msg_reg_w <= ("111" & "111" & "00" &  x"00");
		end if;
	end process;
								
	end generate;
	
	
	
	
  

  
  -- PLB
  IP2Bus_Mst_BE <= IP2Bus_Mst_BE_tmp;
  IP2Bus_Mst_Addr <= IP2Bus_Mst_Addr_tmp;
  IP2Bus_MstWr_d <= IP2Bus_MstWr_d_tmp;
  IP2Bus_MstRd_Req <= '0';--IP2Bus_MstRd_Req_tmp;
  IP2Bus_MstWr_Req <= IP2Bus_MstWr_Req_tmp;
  IP2Bus_Mst_Length <= IP2Bus_Mst_Length_tmp;
  IP2Bus_Mst_Type <= IP2Bus_Mst_Type_tmp;
  
  IP2Bus_Mst_BE_tmp    <= "1111";
  IP2Bus_Mst_Addr_tmp  <= (others=>'0');
  IP2Bus_MstWr_d_tmp   <= x"00000000";
  -- IP2Bus_MstRd_Req_tmp <= 
  IP2Bus_MstWr_Req_tmp <= '0'; --mst_wr_req;
  IP2Bus_Mst_Length_tmp <= x"004" ;
  IP2Bus_Mst_Type_tmp <= '0';

  
  
  -- local link
  IP2Bus_MstWr_src_dsc_n <= '1';
  IP2Bus_MstRd_dst_dsc_n <= '1';
  
  IP2Bus_MstWr_eof_n <= IP2Bus_MstWr_eof_n_reg;
  IP2Bus_MstWr_sof_n <= IP2Bus_MstWr_sof_n_reg;
  IP2Bus_MstWr_src_rdy_n <= IP2Bus_MstWr_src_rdy_n_reg;
  IP2Bus_MstRd_dst_rdy_n <= IP2Bus_MstRd_dst_rdy_n_reg;
  
	
	
  ------------------------------------------
  --  generate user logic interrupts
  ------------------------------------------
  IP2Bus_IntrEvent(0)  <= '0';

  ------------------------------------------
  -- code to access user logic memory region
  --
  -- Note:
  -- The example code presented here is to show you one way of using
  -- the user logic memory space features. The Bus2IP_Addr, Bus2IP_CS,
  -- and Bus2IP_RNW IPIC signals are dedicated to these user logic
  -- memory spaces. Each user logic memory space has its own address
  -- range and is allocated one bit on the Bus2IP_CS signal to indicated
  -- selection of that memory space. Typically these user logic memory
  -- spaces are used to implement memory controller type cores, but it
  -- can also be used in cores that need to access additional address space
  -- (non C_BASEADDR based), s.t. bridges. This code snippet infers
  -- 1 256x32-bit (byte accessible) single-port Block RAM by XST.
  ------------------------------------------

  mem_select      <= Bus2IP_CS;
  mem_read_enable <= ( Bus2IP_CS(0) ) and Bus2IP_RNW;
  mem_read_ack    <= mem_read_ack_dly1;
  mem_write_ack   <= ( Bus2IP_CS(0) ) and not(Bus2IP_RNW);
  mem_address     <= Bus2IP_Addr(C_SLV_AWIDTH-16 to C_SLV_AWIDTH-3);

  we              <= ( Bus2IP_CS(0) ) and not(Bus2IP_RNW);


  -- implement single clock wide read request
  mem_read_req    <= mem_read_enable and not(mem_read_enable_dly1);
  BRAM_RD_REQ_PROC : process( Bus2IP_Clk ) is
  begin

    if ( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
      if ( Bus2IP_Reset = '1' ) then
        mem_read_enable_dly1 <= '0';
      else
        mem_read_enable_dly1 <= mem_read_enable;
      end if;
    end if;

  end process BRAM_RD_REQ_PROC;

  -- this process generates the read acknowledge 1 clock after read enable
  -- is presented to the BRAM block. The BRAM block has a 1 clock delay
  -- from read enable to data out.
  BRAM_RD_ACK_PROC : process( Bus2IP_Clk ) is
  begin

    if ( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
      if ( Bus2IP_Reset = '1' ) then
        mem_read_ack_dly1 <= '0';
      else
        mem_read_ack_dly1 <= mem_read_req;
      end if;
    end if;

  end process BRAM_RD_ACK_PROC;

  -- implement Block RAM(s)
  BRAM_GEN : for i in 0 to C_NUM_MEM-1 generate               -- C_NUM_MEM    =  1
    constant NUM_BYTE_LANES : integer := (C_SLV_DWIDTH+7)/8;  -- C_SLV_DWIDTH = 32
  begin

    BYTE_BRAM_GEN : for byte_index in 0 to NUM_BYTE_LANES-1 generate
      signal ram           : BYTE_RAM_TYPE;
      signal write_enable  : std_logic;
      signal data_in       : std_logic_vector(0 to 7);
      signal data_out      : std_logic_vector(0 to 7);
      signal read_address  : std_logic_vector(0 to 7);
    begin

      write_enable <= not(Bus2IP_RNW) and
                      Bus2IP_CS(i) and
                      Bus2IP_BE(byte_index);

      data_in <= Bus2IP_Data(byte_index*8 to byte_index*8+7);
      --mem_data_out(i)(byte_index*8 to byte_index*8+7) <= data_out;
		
		-- modified by T.H.Wu, 2014.3.19, try to resolve the mismatch between ML605 and ML507
      --process(mem_address) is
      --begin
      --case mem_address is
        --when "00000010000000" => data_out <= ctrl_reg(byte_index*8 to byte_index*8+7);
        --when "00000010000001" => data_out <= arbitor_cmd_msg(0 to 5) & "00";
        --when "00000010001000" => data_out <= main_method(byte_index*8 to byte_index*8+7);
        --when "00000010001001" => data_out <= bram_DOB ((3-byte_index)*8+7 downto (3-byte_index)*8);
      --  when others    => data_out <= (others => '1') ;
      --end case;
      --end process;

      BYTE_RAM_PROC : process( Bus2IP_Clk ) is
      begin
        if ( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
			if (Bus2IP_Reset='1') then
				--ctrl_reg          	(byte_index*8 to byte_index*8+7) <= (others=>'0');	
				main_method			(byte_index*8 to byte_index*8+7) <= (others=>'0');
				--debug_waitTH_addrB	((3-byte_index)*8+7 downto (3-byte_index)*8)  <= (others=>'0');
			elsif ( write_enable = '1' ) then
				case mem_address is 
        		  --when "00000010000000" => ctrl_reg          	(byte_index*8 to byte_index*8+7) <= data_in;
                  when "00000010001000" => main_method			(byte_index*8 to byte_index*8+7) <= data_in;
                  --when "00000010001001" => debug_waitTH_addrB	((3-byte_index)*8+7 downto (3-byte_index)*8) <= data_in;
        			when others	=> null;
        		end case;
			end if;
        end if;
      end process BYTE_RAM_PROC;
    end generate BYTE_BRAM_GEN;

  end generate BRAM_GEN;
  
  
  
  
  -- modified by T.H.Wu, 2014.2.14
	process (Bus2IP_Clk) begin
		if ( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
		if (Bus2IP_Reset='1') then
			arbitor_cmd_msg(0 to 5)	 <= "000000"; 
		else
			--if ((not(Bus2IP_RNW) and Bus2IP_CS(0) and Bus2IP_BE(0)) = '1') then
			if (we = '1' and mem_address = "00000010000001" ) then
				arbitor_cmd_msg(0 to 5) <= Bus2IP_Data(0 to 5);
			elsif ( lock_flag='0' ) then
				if(JAIP2COOR_cmd0/="000") then
					arbitor_cmd_msg(0 to 5) <= "000" & JAIP2COOR_cmd0;
				elsif (JAIP2COOR_cmd1/="000") then
					arbitor_cmd_msg(0 to 5) <= "001" & JAIP2COOR_cmd1;
				elsif (JAIP2COOR_cmd2/="000") then
					arbitor_cmd_msg(0 to 5) <= "010" & JAIP2COOR_cmd2;
				elsif (JAIP2COOR_cmd3/="000") then
					arbitor_cmd_msg(0 to 5) <= "011" & JAIP2COOR_cmd3; 
				else 
					-- reset mutex holder ID, free the mutex 
					-- modified by T.H.Wu, 2014.1.29, but this part should be further optimized.
					arbitor_cmd_msg(0 to 5) <= "111000";
				end if;
			end if;
		end if;
		end if;
	end process;
  
  
  
  -- note by T.H.Wu , 2013.9.6
  -- ctrl_reg format :
  -- [31]	start the main thread from RISC to DCC
  -- [30]	lock bit , for protecting control registers in one JAIP core which both RISC and one JAIP core may 
  -- 		accessed it concurrently (not used yet)
  -- [29:0]	reserved

  -- implement Block RAM read mux
  --MEM_IP2BUS_DATA_PROC : process( mem_data_out, mem_select) is
  --begin
  --  case mem_select is
  --     when "1" =>  mem_ip2bus_data <= mem_data_out(0);
  --      when others => mem_ip2bus_data <= (others => '0');
  --  end case;
  --end process MEM_IP2BUS_DATA_PROC;
  

  ------------------------------------------
  -- drive IP to Bus signals
  ------------------------------------------
  --IP2Bus_Data  <= mem_ip2bus_data when mem_read_ack = '1' else (others => '0');
  IP2Bus_Data  <= (others => '0');
  IP2Bus_WrAck <= mem_write_ack;
  IP2Bus_RdAck <= mem_read_ack;
  IP2Bus_Error <= '0';
 
 
	-----------------------------------------
	-- for chipscope debug use
	-----------------------------------------

end IMP;
