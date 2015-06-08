------------------------------------------------------------------------------
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
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library proc_common_v3_00_a;
use proc_common_v3_00_a.proc_common_pkg.all;
-- use proc_common_v3_00_a.srl_fifo_f;

Library UNISIM;
use UNISIM.vcomponents.all;

use work.config.all;

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
    ONCHIP_HEAP_GEN            : integer              := 0;
    ENABLE_INDEX_OF            : integer              := 1;
    ENABLE_ARRAYCOPY           : integer              := 1;
    ENABLE_JAIP_PROFILER : integer               := 0;
    -- Bus protocol parameters, do not add to or delete
    C_SLV_AWIDTH                   : integer              := 32;
    C_SLV_DWIDTH                   : integer              := 32;
    C_MST_AWIDTH                   : integer              := 32;
    C_MST_DWIDTH                   : integer              := 32;
    C_NUM_REG                      : integer              := 4;
    C_NUM_MEM                      : integer              := 1;
    C_NUM_INTR                     : integer              := 1
  );
  port
  (
    -- for debug use
		debug_TOS_A : out std_logic_vector(31 downto 0);
		debug_TOS_B : out std_logic_vector(31 downto 0);
		debug_TOS_C : out std_logic_vector(31 downto 0);
		debug_CTRL_state : out std_logic_vector(5 downto 0);
		debug_current_heap_ptr: out std_logic_vector(31 downto 0);
		debug_AllocSize : out std_logic_vector(15 downto 0);
		debug_jpl_mst_address : out std_logic_vector(31 downto 0);
		debug_fet_instrs_pkg: out std_logic_vector(15 downto 0);
		debug_GC_state: out std_logic_vector(4 downto 0);
		debug_GC_Mstate: out std_logic_vector(3 downto 0);
		debug_GC_ref: out std_logic_vector(21 downto 0);
		debug_GC_outC: out std_logic_vector(4 downto 0);		
		debug_GC_Rcount: out std_logic_vector(6 downto 0);
		debug_GC_M_ref: out std_logic_vector(21 downto 0);
		debug_M_addr: out std_logic_vector(10 downto 0);
		debug_Mthd_Addr: out std_logic_vector(10 downto 0);
		debug_cur_GC_useaddr: out std_logic_vector(10 downto 0);
		

		debug_Alloc_en : out std_logic;
		debug_ext_wr_heap_ptr : out std_logic;
		debug_IP2Bus_MstRd_Req: out std_logic;
		debug_IP2Bus_MstWr_Req: out std_logic;
		debug_stall_all: out std_logic;

		
		debug_GC_fMthd_Enter: out std_logic;
		debug_GC_Mthd_Enter : out std_logic;
		debug_GC_Mthd_Exit : out std_logic;
		debug_rrayAlloc_en: out std_logic;
		debug_areturn: out std_logic;	
		debug_normal_last_sear_flag: out std_logic;

    
    -- for multi-core coordinator use
	JAIP2COOR_cmd			: out std_logic_vector(2 downto 0) ;
     JAIP2COOR_cache_w_en 	: out std_logic ;                --   # DCC_1_w_en_in
     JAIP2COOR_cache_r_en 	: out std_logic ;                -- # DCC_1_r_en_in
     JAIP2COOR_info1       	: out std_logic_vector(0 to 31);    -- # DCC_1_addr_in
     JAIP2COOR_info2 		: out std_logic_vector(0 to 31);   --  # DCC_1_data_in
	 JAIP2COOR_pending_resMsgSent	: out std_logic;
     COOR2JAIP_rd_ack       : in std_logic ;             --# DCC_1_ack_out , 2013.9.25 probably useless if no better methods
     COOR2JAIP_cache_w_en   : in std_logic ;             -- # DCC_1_en_out
     COOR2JAIP_info1		: in std_logic_vector(0 to 31);     --# DCC_1_addr_out
     COOR2JAIP_info2		: in std_logic_vector(0 to 31);     --# DCC_1_data_out
	 COOR2JAIP_response_msg	: in std_logic_vector(15 downto 0);
	 COOR2JAIP_res_newTH_data1	: in std_logic_vector(31 downto 0);
	 COOR2JAIP_res_newTH_data2	: in std_logic_vector(31 downto 0); 
	 
    -- Bus protocol ports, do not add to or delete
    Bus2IP_Clk                     : in  std_logic;
    Bus2IP_Reset                   : in  std_logic;
    Bus2IP_Addr                    : in  std_logic_vector(0 to C_SLV_AWIDTH-1);
    Bus2IP_CS                      : in  std_logic_vector(0 to C_NUM_MEM-1);
    Bus2IP_RNW                     : in  std_logic;
    Bus2IP_Data                    : in  std_logic_vector(0 to C_SLV_DWIDTH-1);
    Bus2IP_BE                      : in  std_logic_vector(0 to C_SLV_DWIDTH/8-1);
	IP2Bus_Mst_Type				   : out std_logic;												-- add
    Bus2IP_RdCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    Bus2IP_WrCE                    : in  std_logic_vector(0 to C_NUM_REG-1);
    IP2Bus_Data                    : out std_logic_vector(0 to C_SLV_DWIDTH-1);
    IP2Bus_RdAck                   : out std_logic;
    IP2Bus_WrAck                   : out std_logic;
    IP2Bus_Error                   : out std_logic;
    IP2Bus_MstRd_Req               : out std_logic;
    IP2Bus_MstWr_Req               : out std_logic;
    IP2Bus_Mst_Addr                : out std_logic_vector(0 to C_MST_AWIDTH-1);
	IP2Bus_Mst_Length          	   : out std_logic_vector(0 to 11);							    -- add 
    IP2Bus_Mst_BE                  : out std_logic_vector(0 to C_MST_DWIDTH/8-1);
    IP2Bus_Mst_Lock                : out std_logic;
    IP2Bus_Mst_Reset               : out std_logic;
    Bus2IP_Mst_CmdAck              : in  std_logic;
    Bus2IP_Mst_Cmplt               : in  std_logic;
    Bus2IP_Mst_Error               : in  std_logic;
    Bus2IP_Mst_Rearbitrate         : in  std_logic;
    Bus2IP_Mst_Cmd_Timeout         : in  std_logic;
    Bus2IP_MstRd_d                 : in  std_logic_vector(0 to C_MST_DWIDTH-1);
    Bus2IP_MstRd_src_rdy_n         : in  std_logic;
	Bus2IP_MstRd_rem           	   : in  std_logic_vector(0 to (C_MST_DWIDTH/8)-1); 			-- add
    Bus2IP_MstRd_sof_n         	   : in  std_logic;												-- add
    Bus2IP_MstRd_eof_n         	   : in  std_logic;												-- add
    IP2Bus_MstWr_d                 : out std_logic_vector(0 to C_MST_DWIDTH-1);
	IP2Bus_MstWr_rem           	   : out std_logic_vector(0 to (C_MST_DWIDTH/8)-1);				-- add 
    IP2Bus_MstWr_sof_n             : out std_logic;												-- add
    IP2Bus_MstWr_eof_n         	   : out std_logic;												-- add			
	Bus2IP_MstRd_src_dsc_n     	   : in  std_logic;											    -- add
    IP2Bus_MstRd_dst_rdy_n     	   : out std_logic;												-- add
    IP2Bus_MstRd_dst_dsc_n         : out std_logic;												-- add
    Bus2IP_MstWr_dst_rdy_n         : in  std_logic;
	IP2Bus_MstWr_src_rdy_n     	   : out std_logic;												-- add
    IP2Bus_MstWr_src_dsc_n     	   : out std_logic;												-- add
	Bus2IP_MstWr_dst_dsc_n     	   : in  std_logic;												-- add
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
  --signal clear_act                  : std_logic;
  signal the_core_act                   : std_logic;
  signal ctrl_reg                   : std_logic_vector(0 to 31);
  signal A, B, C                    : std_logic_vector(0 to 31);
  signal arg1, arg2, arg3           : std_logic_vector(0 to 31); 
  signal arg4, arg5                 : std_logic_vector(0 to 31);
    -- modified by T.H.Wu , 2013.8.10 , for solving critical path issue   
  signal A_dly, B_dly, C_dly     : std_logic_vector(0 to 31);
  signal arg1_dly, arg2_dly, arg3_dly   : std_logic_vector(0 to 31); 
  signal arg4_dly, arg5_dly                      : std_logic_vector(0 to 31); 
  signal interrupt_on, we           : std_logic;
  signal rupt_func                  : std_logic_vector(0 to 3);
  signal write_data                 : std_logic_vector(0 to 31);
  signal interrupt_func             : std_logic_vector(0 to 23);  
  signal ISR_pack_msg             : std_logic_vector(0 to 31);   -- added by T.H.Wu , 2013.9.5
  signal CST_manage                 : std_logic_vector(0 to 31);
  signal mthd_manage                : std_logic_vector(0 to 31);
  signal parser2ER_LUT              : std_logic_vector(0 to 31);
  signal xcptn_en                   : std_logic_vector(0 to 31); 
  signal debug_flag                 : std_logic_vector(0 to 31);
  signal debug_addr                 : std_logic_vector(0 to 31);
  signal debug_data                 : std_logic_vector(0 to 31);

 -- signal debug_in                    : std_logic_vector(0 to 31);
    component soj is
    generic(
        METHOD_AREA_DDR_ADDRESS     : std_logic_vector(31 downto 0) := X"5A000000";
		STACK_AREA_DDR_ADDRESS		: std_logic_vector(13 downto 0) := (X"5BF"&"11"); -- by fox
		Max_Thread_Number			: integer := 16;								 -- by fox
		BURST_LENGTH				: std_logic_vector(7 downto 0)  := X"40";	        -- by fox
        ENABLE_JAIP_PROFILER   : integer               := 0;
        C_MAX_AR_DWIDTH             : integer := 64;
        RAMB_S9_AWIDTH              : integer := 11;
        RAMB_S18_AWIDTH             : integer := 10;
        RAMB_S36_AWIDTH             : integer := 9
    );
    port(
        -- basic signal
        Rst                         : in  std_logic;
        clk                         : in  std_logic; 
		the_core_act				: out	std_logic;
		core_id						: in	std_logic_vector (1 downto 0);
		--GC
		GC_Cmplt_in                 : in  std_logic;
		GC_areturn_flag_out         : out  std_logic;
		anewarray_flag2GC           : out  std_logic;
		Mthod_exit_flag_out         : out  std_logic;
		GC_Clinit_Stop                 : out  std_logic;
		Mthod_enter_flag_out        : out  std_logic;
		Mthod_enter_flag_f_out	    : out  std_logic;	
		GC_arrayAlloc_en_out        : out  std_logic;
		GC_StackCheck_flag          : out  std_logic;
		
		-- enable xcptn          
		xcptn_en                    : in  std_logic;  

        -- (slave) write from external part(power PC) to soj reg
        ex2java_wen                 : in  std_logic;
        ex2java_addr                : in  std_logic_vector(13 downto 0);
        ex2java_data                : in  std_logic_vector(31 downto 0);  

        -- (slave) class profile table
        --ClsProfileTable             : in  std_logic_vector(31 downto 0);
		-- (slave) CST profile table
        CSTProfileTable             : in  std_logic_vector(31 downto 0);
		-- (slave) Mthd profile table
        MthdProfileTable            : in  std_logic_vector(31 downto 0);

		-- (slave) parser to ER_LUT
		parser2ER_LUT               : in  std_logic_vector(31 downto 0);
		-- (master) external memory access
		
		external_MstRd_CmdAck : in  std_logic; -- added by T.H. Wu , 2013.6.20 
		external_MstRd_burst_data_rdy : in std_logic; -- added by T.H. Wu , 2013.6.20 
		external_MstWr_burst_data_rdy : in std_logic;
		external_access_cmplt       : in std_logic;
		external_access_addr        : out std_logic_vector(31 downto 0);
		external_load_req           : out std_logic;
		external_load_data          : in  std_logic_vector(31 downto 0);
		external_store_req          : out std_logic;
		external_store_data         : out std_logic_vector(31 downto 0);
		-- added by T.H.Wu , 2013.8.7 , for changing bus transfer mode in pipeline
		jpl_mst_transfer_Type  : out std_logic;
		IP2Bus_Mst_BE               : out std_logic_vector( 3 downto 0);
		current_heap_ptr			: in std_logic_vector(31 downto 0);
		
		-- class info table
		clsiInternLoadReq					: out std_logic;
		clsiInternStoreReq				: out std_logic;
		clsiAddr					: out std_logic_vector(11 downto 0);
		clsInfo						: in std_logic_vector(31 downto 0);
		clsiCmplt					: in std_logic;
		clsiInternWrData					: out std_logic_vector(31 downto 0); 
		-- for multi-core coordinator , modified since 2014.2.11
		JAIP2COOR_cmd					: out	std_logic_vector(2 downto 0) ;
		JAIP2COOR_info1_pipeline		: out	std_logic_vector(31 downto 0);
		JAIP2COOR_info2_pipeline		: out	std_logic_vector(31 downto 0); 
		JAIP2COOR_pending_resMsgSent	: out	std_logic;
		COOR_res_msg_bak				: in	std_logic_vector(15 downto 0);
		COOR_info1_bak					: in	std_logic_vector(31 downto 0);
		COOR_info2_bak					: in	std_logic_vector(31 downto 0);
		COOR_cmd_cmplt					: out	std_logic;

        -- interrupt
        interrupt_req               : out std_logic;
        interrupt_func              : out std_logic_vector(23 downto 0);

        -- cache up top of stack
        TOS_A                       : out std_logic_vector(31 downto 0);
        TOS_B                       : out std_logic_vector(31 downto 0);
        TOS_C                       : out std_logic_vector(31 downto 0);

        -- parameters of host service
        Host_arg1                   : out std_logic_vector(31 downto 0);
        Host_arg2                   : out std_logic_vector(31 downto 0);
        Host_arg3                   : out std_logic_vector(31 downto 0);
        Host_arg4                   : out std_logic_vector(31 downto 0);
        Host_arg5                   : out std_logic_vector(31 downto 0);
		native_HW_en				: out std_logic;
		-- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
		native_HW_ID				: out std_logic_vector(4 downto 0);
		native_HW_cmplt				: in std_logic;
		
		Alloc_en				: out std_logic;
		AllocSize				: out std_logic_vector(15 downto 0);
		
		-- native HW
		xcptn_thrown_Native_HW		: in  std_logic;
		Native_HW_thrown_ID			: in  std_logic_vector(15 downto 0);	
		
		CTRL_state_out                : out  DynamicResolution_SM_TYPE;
		
		debug_cs_soj        : out  std_logic_vector  (25 downto 0);
        --debug_cs_CSTctrl      : out  std_logic_vector  (35 downto 0);
        debug_cs_MActrl      : out  std_logic_vector  (31 downto 0);
        --debug_cs_fetch         : out std_logic_vector(12 downto 0);
		--debug_cs_exe   : out  std_logic_vector(93 downto 0) ;
		-- debug_cs_xcptn   : out  std_logic_vector(55 downto 0) ;
		--debug_cs_decode       : out std_logic_vector(48 downto 0);
        --debug_cs_4portbank : out std_logic_vector(127 downto 0);
        debug_cs_thread_mgt        : out  std_logic_vector  (47 downto 0);
        debug_cs_stk_mgt              : out std_logic_vector (2 downto 0);  
		
        debug_flag                  : in  std_logic_vector(31 downto 0);
        debug_addr                  : in  std_logic_vector(31 downto 0);
        debug_data                  : out std_logic_vector(31 downto 0);
		--debug for new buffer
		debug_nb_SW                 : in  std_logic_vector(31 downto 0);
		debug_nb_do                 : out std_logic_vector(31 downto 0); 
		
		-- mmes profiler
		prof_invoke_flag			: out std_logic;
		prof_return_flag			: out std_logic;
		prof_DSRU_on				: out std_logic;
		prof_mem_access_on			: out std_logic;
		prof_DR2MA_mgt_mthd_id		: out std_logic_vector(15 downto 0);
		prof_simple_issued_A_D 		: out std_logic;
		prof_simple_issued_B_D 		: out std_logic;
		prof_issued_bytecodes_D		: out std_logic_vector(15 downto 0)
    );
    end component;   

    component heap
    generic(
        RAMB_S18_AWIDTH  : integer := 10
    );
    port(
        Rst              : in  std_logic;
        clk              : in  std_logic;
        address          : in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0);
        heap_data_be     : in  std_logic_vector(3 downto 0);
        heap_data_in     : in  std_logic_vector(31 downto 0);
        heap_data_out    : out std_logic_vector(31 downto 0);
        store_request    : in  std_logic;
        load_request     : in  std_logic;
        heap_complete    : out std_logic
    );
    end component;

    -- reference data - format : global id / offset
    component cross_reference_table
    generic(
        RAMB_S18_AWIDTH  : integer := 9
    );
    port(
        Rst              : in  std_logic;
        clk              : in  std_logic;
        address          : in  std_logic_vector(12 downto 0);
        offset_in        : in  std_logic_vector(31 downto 0);
        offset_out       : out std_logic_vector(31 downto 0);
        load_request     : in  std_logic;
        store_request    : in  std_logic;
        crt_complete     : out std_logic
    );
    end component;
	
	component class_info_table
    generic(
        RAMB_S18_AWIDTH  : integer := 12
    );
    port(
        Rst              : in  std_logic;
        clk              : in  std_logic;
        address          : in  std_logic_vector(8 downto 0);
        offset_in        : in  std_logic_vector(31 downto 0);
        offset_out       : out std_logic_vector(31 downto 0);
        load_request     : in  std_logic;
        store_request    : in  std_logic;
        crt_complete     : out std_logic
    );
	end component;
	
	-- method time profiler
	component mmes_profiler is
	port(
		Clk				: in std_logic;
		Rst				: in std_logic;
			
		HW_time			: in std_logic_vector(31 downto 0);
		Intrpt_time		: in std_logic_vector(31 downto 0);
		DSRU_time		: in std_logic_vector(31 downto 0);
		heap_access_time		: in std_logic_vector(31 downto 0);
		invoke_flag		: in std_logic;
		return_flag		: in std_logic;
		method_ID		: in std_logic_vector(15 downto 0);
		
		profile_sel		: in std_logic_vector(2 downto 0);
		method_profile	: out std_logic_vector(31 downto 0)
	);
	end component;
			
	component bytecode_profiler is
		port(
			Clk                 				      : in  std_logic;
			Rst					                  	  : in  std_logic;
			
			HW_time			: in std_logic_vector(31 downto 0);
			Intrpt_time		: in std_logic_vector(31 downto 0);
			DSRU_time		: in std_logic_vector(31 downto 0);
			heap_access_time		: in std_logic_vector(31 downto 0);
			
			bytecode_1			: in std_logic_vector(7 downto 0);
			bytecode_2			: in std_logic_vector(7 downto 0);
			issued_1			: in std_logic;
			issued_2			: in std_logic;	
			
			profile_sel			: in std_logic_vector(2 downto 0);
			bytecode_profile	: out std_logic_vector(31 downto 0);
				
			-- cs debug	
			debug_bytecode_buf_A : out std_logic_vector(7 downto 0);
			debug_PT_A_WE		: out std_logic;
			debug_buf_A_valid	: out std_logic;
			debug_bytecode_profile_A_out	: out std_logic_vector(159 downto 0)
		
	);
	end component bytecode_profiler;
	
	signal issued_1					   : std_logic;
	signal issued_2					   : std_logic;
	
	component arraycopy_single is
	generic(
		C_MST_AWIDTH                   : integer              := 32;
		C_MST_DWIDTH                   : integer              := 32
    );
	port(
			Clk                 				      : in  std_logic;
			Rst					                  	  : in  std_logic;
			
			-- PLB MST BURST ports --
			AC_IP2Bus_MstRd_Req               : out std_logic;
			AC_IP2Bus_MstWr_Req               : out std_logic;
			AC_IP2Bus_Mst_Addr                : out std_logic_vector(C_MST_AWIDTH-1 downto 0);
			AC_IP2Bus_Mst_BE                  : out std_logic_vector(C_MST_DWIDTH/8-1 downto 0);
			AC_Bus2IP_MstRd_d                 : in  std_logic_vector(0 to C_MST_DWIDTH-1);
			AC_IP2Bus_MstWr_d                 : out std_logic_vector(0 to C_MST_DWIDTH-1);
			AC_Bus2IP_Mst_Cmplt               : in  std_logic;
			
			-- exception
			xcptn_thrown_Native_HW		: out  std_logic;
			Native_HW_thrown_ID			: out  std_logic_vector(15 downto 0);
			
			CTRL_state                  : in   DynamicResolution_SM_TYPE;
			
			-- args & ctrl ports --
			ACEn					   		      : in std_logic;
			ACCmplt				   		  		  : out std_logic;
			src					   		  		  : in std_logic_vector(31 downto 0);
			srcPos						   		  : in std_logic_vector(31 downto 0);
			dst							   		  : in std_logic_vector(31 downto 0);
			dstPos						   		  : in std_logic_vector(31 downto 0);	
			cpyLength                      		  : in std_logic_vector(31 downto 0)
	);
	end component;
	
	component indexOf is
	generic(
			C_MST_AWIDTH                   : integer              := 32;
			C_MST_DWIDTH                   : integer              := 32
	);
	port (
			Clk                 				      : in  std_logic;
			Rst					                  	  : in  std_logic;
			
			-- PLB MST BURST ports --
			IO_IP2Bus_MstRd_Req               : out std_logic;
			IO_IP2Bus_Mst_Addr                : out std_logic_vector(C_MST_AWIDTH-1 downto 0);
			IO_Bus2IP_MstRd_d                 : in  std_logic_vector(C_MST_DWIDTH-1 downto 0);
			IO_Bus2IP_Mst_Cmplt               : in  std_logic;
			
			-- args & ctrl ports --
			IOEn					   		      : in std_logic;
			IOCEn	   							  : in std_logic;
			LIOEn								  : in std_logic;
			VIOEn								  : in std_logic;
			IOCmplt				   		  		  : out std_logic;
			
			textRef				   		  		  : in std_logic_vector(31 downto 0);
			indexof_mthd_arg1	        	   		  : in std_logic_vector(31 downto 0);
			fromIndex					   		  : in std_logic_vector(31 downto 0);
			--strRef						   		  : in std_logic_vector(31 downto 0);
			--ch									  : in std_logic_vector(31 downto 0); 
			res									  : out std_logic_vector(31 downto 0); 
			--cs
			debug_IOSM							  : out std_logic_vector(3 downto 0)
	);
	end component;

	component GC is
	generic (
		Table_bit                   : integer := 9;
		TableS_bit                  : integer := 11; 
        REF_bit                     : integer := 22;
		SIZE_bit                    : integer := 20;
		NEXT_bit                    : integer := 11;
		COUNT_bit                   : integer := 5;
		Meth_col_en                 : integer := 1
	);
	port (
	
        Rst                            : in  std_logic;
        clk                            : in  std_logic;
        GC_Alloc_en                    : in  std_logic;
		GC_Alloc_arr_en                : in  std_logic;	
		GC_StackCheck_f		           : in  std_logic;	
		GC_Null_en                     : in  std_logic;
		GC_areturn_falg                : in  std_logic;
		GC_anewarray_flag              : in  std_logic;
		GC_Clinit_Stop                 : in  std_logic; 
		GC_Mthd_Exit                   : in  std_logic;
		GC_Mthd_Enter                  : in  std_logic;
		GC_Mthd_Enter_f                : in  std_logic;
		GC_ext_wr_heap_ptr             : in  std_logic;
        GC_AllocSize                   : in  std_logic_vector(15 downto 0);
		GC_reference                   : in  std_logic_vector(REF_bit-1 downto 0);
		GC_current_heap_ptr_ext        : in  std_logic_vector(31 downto 0);
		GC_A                           : in  std_logic_vector(31 downto 0);
		
		GC_cmplt                       : out std_logic;
		
		GC_Current_Heap_Addr           : out std_logic_vector(31 downto 0);
        GC_Heap_Addr                   : out std_logic_vector(31 downto 0);
		debug_GC_port                  : out std_logic_vector(98 downto 0)	
	);
	end component;

	
	component Cache_controller is
	generic (
		CPU_DATA_WIDTH	:	integer		:=32;	
		TAG_SIZE		:	integer		:=13;	
		INDEX_SIZE		:	integer		:=8;	
		OFFSET_SIZE		:	integer		:=5;	
		ASSOCIATIVITY	:	positive	:=2;	
		WRITE_STRATEGY	:	integer		:=1 
	);
	port (
	
		clk						      :	in	std_logic;
		rst						      :	in	std_logic;
		cache_mem_flush			      : in	std_logic;
		cache_read				      :	in	std_logic;			
		cache_write 			      :	in	std_logic; 
		cache_address			      :	in	std_logic_vector (TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto 0);
		cache_data_in			      :	in	std_logic_vector (CPU_DATA_WIDTH-1	downto	0);		
		cache_forMst_Type             :	out	std_logic;		
		cache_cmplt				      :	out	std_logic;		
		cache_data_out			      :	out	std_logic_vector (CPU_DATA_WIDTH-1 downto 0);	

--------------------------------------------------------------------------------------
--                     for memory prot use                               -------------
--------------------------------------------------------------------------------------
		Cmem_B2IP_CmdAck		      : in  std_logic;			
		Cmem_B2IP_Wrdst_rdy_n         : in  std_logic;	
        Cmem_ready				      : in  std_logic; 	
		Cmem_complt                   : in  std_logic; 
		Cmem_IP2B_Mst_BE              : in  std_logic_vector (3 downto 0);			
        Cmem_data_in				  : in  std_logic_vector (CPU_DATA_WIDTH-1 downto 0);	
		
		Cmem_IP2B_Wrsof_n             : out std_logic;	
		Cmem_IP2B_Wreof_n		      : out std_logic;
		Cmem_IP2B_Wrsrc_rdy_n         : out std_logic;
        Cmem_write			          : out std_logic; 	
        Cmem_read			 	      : out std_logic;		
        Cmem_write_data               : out std_logic_vector (CPU_DATA_WIDTH-1 downto 0);	
        Cmem_addr				      : out std_logic_vector ( 31 downto 0);
		-- for multicore coordinator , 2013.9.25
		COOR2JAIP_rd_ack              : in  std_logic;
		JAIP2COOR_cache_w_en          : out std_logic;
		JAIP2COOR_cache_r_en          : out std_logic;
		JAIP2COOR_info1_cache         : out std_logic_vector(0 to 31);
		JAIP2COOR_info2_cache         : out std_logic_vector(0 to 31);
		COOR2JAIP_wr_ack              : in  std_logic;
		COOR2JAIP_info1_cache         : in	std_logic_vector(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto 0);
		COOR2JAIP_info2_cache         : in	std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
		-- cs debug 
        --debug_cs_cache_ctrl : out std_logic_vector (97 downto 0);
		debug_cache_controller_data   : out std_logic_vector (35 downto 0)
	);
	end component;
	
--GC
  signal GC_Mthd_Exit_u                 : std_logic;
  signal GC_Mthd_Enter_u                : std_logic;
  signal GC_Mthd_Enter_f_u              : std_logic;
  signal GC_Cmplt_u                     : std_logic;
  signal GC_areturn_u                   : std_logic;
  signal GC_anewarray_flag_u            : std_logic;
  signal GC_Clinit_Stop_u               : std_logic;
  signal GC_arrayAlloc_en_u             : std_logic;
  signal GC_StackCheck_flag_u           : std_logic;
  signal debug_GC_port                  : std_logic_vector(98 downto 0);
  
  
  signal GC_Null_en_u                   : std_logic;
  signal GC_For_Search_Ref              : std_logic_vector(21 downto 0) ;
  signal GC_Current_Heap_Addr_u         : std_logic_vector(31 downto 0) ;
  signal GC_Heap_Addr_u                 : std_logic_vector(31 downto 0) ;	
    -- for multicore JAIP
   -- modified by T.H.Wu , 2013.9.4
   signal core_id     : std_logic_vector(1 downto 0);
  ------------------------------------------
  -- Signals for user logic master model
  ------------------------------------------
  signal jpl_mst_rd_req                 : std_logic;
  signal jpl_mst_wr_req                 : std_logic;
  signal jpl_mst_rd_req_reg             : std_logic;
  signal jpl_mst_wr_req_reg             : std_logic;   
  signal jpl_mst_data_reg                   : std_logic_vector(0 to 31);
  signal jpl_mst_address_reg                : std_logic_vector(0 to 31);
  signal jpl_mst_data                   : std_logic_vector(0 to 31);
  signal jpl_mst_address                : std_logic_vector(0 to 31);
  signal jpl_mst_data_delay             : std_logic_vector(0 to 31);
  signal jpl_mst_address_delay          : std_logic_vector(0 to 31);
  signal jpl_mst_BE                     : std_logic_vector(3 downto 0);
  signal jpl_mst_BE_tmp                 : std_logic_vector(3 downto 0);
  signal jpl_mst_cmplt				    : std_logic; 
  signal jpl_mst_cmplt_dly			    : std_logic; -- modified by T.H.Wu , 2013.8.12 , for solving critical path
  signal jpl_load_data                  : std_logic_vector(31 downto 0) ; 
    -- added by T.H.Wu , 2013.8.7 , for changing bus transfer mode in pipeline
   signal   jpl_mst_transfer_Type  :   std_logic; 
  
  -- no-cache PLB access
  signal mst_rd_req						: std_logic;
  signal mst_wr_req						: std_logic;
  signal mst_addr						: std_logic_vector(31 downto 0);
  signal mst_rd_data					: std_logic_vector(31 downto 0);
  signal mst_wr_data					: std_logic_vector(31 downto 0);
  signal mst_BE							: std_logic_vector(3 downto 0);
  -- PLB 
  signal IP2Bus_Mst_BE_tmp 				: std_logic_vector(3 downto 0);	 
  signal IP2Bus_Mst_Addr_tmp			: std_logic_vector(31 downto 0);
  signal IP2Bus_MstWr_d_tmp				: std_logic_vector(31 downto 0);
  signal IP2Bus_MstRd_Req_tmp			: std_logic;
  signal IP2Bus_MstWr_Req_tmp			: std_logic;
  signal IP2Bus_Mst_Length_tmp			: std_logic_vector(11 downto 0);
  signal IP2Bus_Mst_Type_tmp			: std_logic;
  
  -- ex2java
  signal ex2java_wen           			: std_logic;
  signal ex2java_addr          			: std_logic_vector(13 downto 0);
  signal ex2java_data          			: std_logic_vector(31 downto 0);
  
  ------------------------------------------
  -- Signals for user logic memory space example
  ------------------------------------------
  type BYTE_RAM_TYPE is array (0 to 255) of std_logic_vector(0 to 7);
  type DO_TYPE is array (0 to C_NUM_MEM-1) of std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal mem_data_out                   : DO_TYPE;
  signal mem_address                    : std_logic_vector(0 to 13);
  signal mem_address_2cycle             : std_logic_vector(0 to 13);
  signal mem_select                     : std_logic_vector(0 to 0);
  signal mem_read_enable                : std_logic;
  signal mem_read_enable_dly1           : std_logic;
  signal mem_read_req                   : std_logic;
  signal mem_ip2bus_data                : std_logic_vector(0 to C_SLV_DWIDTH-1);
  signal mem_read_ack_dly1              : std_logic;
  signal mem_read_ack                   : std_logic;
  signal mem_write_ack                  : std_logic;

  ------------------------------------------
  -- Signals for 
  ------------------------------------------ 
  signal Total_time                     : std_logic_vector(0 to 31) ;

  signal time_with_some_interrupt       : std_logic_vector(0 to 31) ;
  
  signal prof_on						: std_logic;
  
  signal rupt_time                      : std_logic_vector(0 to 31);
  signal HW_time                  		: std_logic_vector(0 to 31) ;
  signal DSRU_time						: std_logic_vector(0 to 31) ;
  signal heap_access_time						: std_logic_vector(0 to 31) ;

    signal heap_data_out                  : std_logic_vector(31 downto 0) ;
    signal heap_data_in                   : std_logic_vector(31 downto 0) ;
    signal heap_data_be                   : std_logic_vector(3 downto 0);
    signal heap_address                   : std_logic_vector(0 to 9) ;
    signal heap_load_req                  : std_logic;
    signal heap_store_req                 : std_logic;
    signal heap_complete                  : std_logic;
    signal xrt_load_data                  : std_logic_vector(31 downto 0) ;
    --signal xrt_address                    : std_logic_vector(0 to 11) ; -- modified by T.H.Wu , 2013.8.1
    signal xrt_address                    : std_logic_vector(0 to 12) ;
    signal xrt_complete                   : std_logic;
    signal xrt_load_req                   : std_logic;
	signal xrt_load_req_delay             : std_logic;
    signal xrt_store_req                  : std_logic;
	signal clsi_load_data                 : std_logic_vector(31 downto 0) ;
    signal clsi_address                   : std_logic_vector(0 to 8) ;
    signal clsi_complete                  : std_logic;
    signal clsi_load_req                  : std_logic;
    signal clsi_store_req                 : std_logic;
    signal top_mst_rd_req_delay           : std_logic;
    signal top_mst_wr_req_delay           : std_logic;
    signal top_mst_wr_req_2cycle          : std_logic;
   
	signal we_2cycle                      : std_logic; 
     
	signal current_heap_ptr			      : std_logic_vector(31 downto 0);
	signal current_heap_ptr_ext		      : std_logic_vector(31 downto 0);
	
	-- class info table
	signal clsiInternLoadReq					  : std_logic;
	signal clsiInternStoreReq				      : std_logic;
	signal clsiAddr					      : std_logic_vector(11 downto 0);
	signal clsInfo						  : std_logic_vector(31 downto 0);
	signal clsiCmplt					  : std_logic;
	signal clsiInternWrData					  : std_logic_vector(31 downto 0);
	signal clsi_data_in					  : std_logic_vector(31 downto 0);
	
	signal Alloc_en					  : std_logic;
	signal AllocSize				  : std_logic_vector(15 downto 0);
	signal ext_wr_heap_ptr				  : std_logic;
	
	-- local link
	signal IP2Bus_MstWr_eof_n_reg 		 : std_logic;
	signal IP2Bus_MstWr_sof_n_reg 		 : std_logic;
	signal IP2Bus_MstWr_src_rdy_n_reg 	 : std_logic;
	signal IP2Bus_MstRd_dst_rdy_n_reg 	 : std_logic;
                -- add by T.H. Wu , 2013.6.20
        signal Bus2IP_MstRd_src_rdy_n_reg        : std_logic;
        signal Bus2IP_Mst_CmdAck_reg                  : std_logic;
        
        
	
  -- onchip mempory test signal
  -- =============================================================================
    signal debug_bram_address       : std_logic_vector(31 downto 0);
    signal debug_bram_we            : std_logic;
    signal debug_bram_we_tmp        : std_logic;
    signal debug_bram_we_tmp_reg    : std_logic;
    signal debug_bram_counter       : std_logic_vector(31 downto 0); 
-- =============================================================================

--debug for new buffer
	signal debug_nb_SW              : std_logic_vector(0 to 31);
	signal debug_nb_do              : std_logic_vector(0 to 31); 
	
-- method profiler
	signal profile_sel				: std_logic_vector(2 downto 0);
	signal method_profile			: std_logic_vector(31 downto 0);
	signal method_ID				: std_logic_vector(15 downto 0);
	signal prof_DR2MA_mgt_mthd_id	: std_logic_vector(15 downto 0);
	signal prof_DSRU_on				: std_logic;
	signal prof_mem_access_on		: std_logic;
	signal prof_return_flag			: std_logic;
	signal prof_invoke_flag			: std_logic;
	signal prof_return_flag_in		: std_logic;
	signal prof_invoke_flag_in		: std_logic;
	signal prof_heap_access_on		: std_logic;
	signal prof_heap_access_on_nxt	: std_logic;
	signal prof_onChipHeap_access_on		: std_logic;
	signal prof_onChipHeap_access_on_nxt	: std_logic;
	
	signal bytecode_profile			: std_logic_vector(31 downto 0);
	signal prof_simple_issued_A_D 	: std_logic;
	signal prof_simple_issued_B_D 	: std_logic;
	signal prof_issued_bytecodes_D	: std_logic_vector(15 downto 0);
	signal prof_bytecode_1			: std_logic_vector(7 downto 0);
	signal prof_bytecode_2			: std_logic_vector(7 downto 0);
-- arraycopy
	signal ACEn						: std_logic;
	signal ACCmplt					: std_logic;
	signal AC_IP2Bus_MstRd_Req      : std_logic;
	signal AC_IP2Bus_MstWr_Req      : std_logic;
	signal AC_IP2Bus_Mst_Addr       : std_logic_vector(C_MST_AWIDTH-1 downto 0);
	signal AC_IP2Bus_Mst_BE         : std_logic_vector(C_MST_DWIDTH/8-1 downto 0);
	signal AC_IP2Bus_MstWr_d        : std_logic_vector(0 to C_MST_DWIDTH-1);
	
	signal AC_ACT					: std_logic;
	signal native_HW_en				: std_logic;
	signal native_HW_en_reg			: std_logic; -- for reducing critical path issue.
       -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
	--signal native_HW_ID			: std_logic_vector(7 downto 0);
	signal native_HW_ID				: std_logic_vector(4 downto 0);
	signal native_HW_cmplt			: std_logic;
	signal xcptn_thrown_Native_HW_tmp		: std_logic;
	signal Native_HW_thrown_ID_tmp			: std_logic_vector(15 downto 0);
	signal CTRL_state                       : DynamicResolution_SM_TYPE;
-- indexOf
	signal IO_IP2Bus_MstRd_Req		: std_logic;	
	signal IO_IP2Bus_Mst_Addr		: std_logic_vector(C_MST_AWIDTH-1 downto 0);
	
	signal IO_res					: std_logic_vector(31 downto 0);
	
	signal IOEn						: std_logic;
	signal IOCmplt					: std_logic;
	signal IO_ACT					: std_logic;
	signal IO_ACT_logic				: std_logic;
	
	signal IOCEn					: std_logic;
-- lastIndexOf
	signal LIOEn					: std_logic;
-- Vector.indexof
	signal VIOEn					: std_logic;
-- currentTimeMillis
	signal SCTMEn					: std_logic;
	signal SCTMCmplt				: std_logic;
-- profOn
    signal POEn						: std_logic;
	signal POCmplt					: std_logic;
-- profOff 
	signal POFEn					: std_logic;
	signal POFCmplt					: std_logic;
-- JAIP-cache
	signal cache_write				: std_logic;
	signal cache_read				: std_logic;
	signal cache_address			: std_logic_vector(25 downto 0);
	signal cache_data_in			: std_logic_vector(31 downto 0);
	signal cache_mem_flush				: std_logic;
	signal cache_data_out			: std_logic_vector(C_MST_DWIDTH-1 downto 0);
        -- modified by T.H.Wu , 2013.8.12 , for solving critical path issue.
	signal cache_data_out_dly		: std_logic_vector(C_MST_DWIDTH-1 downto 0);
	signal cache_cmplt				: std_logic;
        -- for cache write back mode (flush) use 
        signal cache_flush_en         : std_logic_vector(0 to 31);
	signal cache_flush_reg         : std_logic;
	signal cache_flush_delay      : std_logic;
	signal flush_cmplt                : std_logic;
	signal flush_cmplt32             :std_logic_vector(0 to 31); 
        -- modified by T.H.Wu , 2013.8.10 , for solving critical path issue 
	signal ACEn_dly             : std_logic;
	signal IOEn_dly             : std_logic;
	signal SCTMEn_dly          : std_logic;
	signal POEn_dly             : std_logic;
	signal POFEn_dly             : std_logic;
	signal IOCEn_dly             : std_logic;
	signal LIOEn_dly             : std_logic;
	signal VIOEn_dly             : std_logic;
---------------------------------------------------
-- multi-core coordinator , added since 2013.9.7
---------------------------------------------------
	-- from JAIP core to coordinator
	signal	JAIP2COOR_info1_pipeline		:  std_logic_vector(31 downto 0);
	signal	JAIP2COOR_info2_pipeline		:  std_logic_vector(31 downto 0); 
    
	-- from coordinator to JAIP core
	------
	signal	COOR_res_msg_bak		:  std_logic_vector(15 downto 0); 
	signal	COOR_res_msg_bak_w		:  std_logic_vector(15 downto 0); 
	signal	COOR_info1_bak			:  std_logic_vector(31 downto 0); 
	signal	COOR_info1_bak_w		:  std_logic_vector(31 downto 0); 
	signal	COOR_info2_bak			:  std_logic_vector(31 downto 0); 
	signal	COOR_info2_bak_w		:  std_logic_vector(31 downto 0); 
				
	signal	COOR_cmd_cmplt			:  std_logic; 
	 
	signal	JAIP2COOR_cache_wr_en_w		:  std_logic;
	signal	JAIP2COOR_cache_rd_en_w		:  std_logic;
	signal	JAIP2COOR_info1_cache		:  std_logic_vector(0 to 31);
	signal	JAIP2COOR_info2_cache		:  std_logic_vector(0 to 31);
-------------------------------------------------------
    
-- cache-PLB
	signal cache_forMst_Type				: std_logic;
	signal IP2Bus_MstWr_sof_nC		: std_logic;
	signal IP2Bus_MstWr_eof_nC		: std_logic;
	signal IP2Bus_MstWr_src_rdy_nC	: std_logic;
	signal Cmem_write				: std_logic;
	signal Cmem_read         		: std_logic;
	signal Cmem_write_data   		: std_logic_vector(C_MST_DWIDTH-1 downto 0);
	signal Cmem_addr        		: std_logic_vector(C_MST_AWIDTH-1 downto 0);
	
	signal Cmem_writing				: std_logic;
    -- for chipscope debug use
    signal debug_chipscope_data_w           :  std_logic_vector(350 downto 0); 
    signal debug_chipscope_trig_port_0_w    :  std_logic_vector(3 downto 0);
    signal debug_chipscope_trig_port_1_w    :  std_logic_vector(15 downto 0); 
    signal debug_chipscope_trig_port_2_w    :  std_logic_vector(15 downto 0); 
    signal debug_chipscope_trig_port_3_w    :  std_logic_vector(7 downto 0); 
    signal debug_chipscope_trig_port_4_w    :  std_logic_vector(15 downto 0); 
    --signal debug_chipscope_trig_port_5_w    :  std_logic_vector(31 downto 0); 
    --signal debug_chipscope_trig_port_6_w    :  std_logic_vector(15 downto 0); 
	signal debug_cnt_last_rdyTH_failock		:	std_logic_vector(23 downto 0); 
    --signal debug_cs_CSTctrl                              :  std_logic_vector(35 downto 0);
    signal  debug_cs_MActrl      :  std_logic_vector  (31 downto 0); 
	--signal debug_cs_decode      : std_logic_vector(48 downto 0);
	signal	debug_cs_soj                                :  std_logic_vector  (25 downto 0);
    --signal  debug_cs_fetch                              :  std_logic_vector(12 downto 0);
       --signal   debug_cs_exe                                :  std_logic_vector(93 downto 0) ;
       -- signal   debug_cs_xcptn                             :  std_logic_vector(55 downto 0) ;
       --signal   debug_cs_4portbank                     : std_logic_vector(127 downto 0);
      signal    debug_cs_thread_mgt                 : std_logic_vector  (47 downto 0);   
       signal  debug_cs_stk_mgt                        : std_logic_vector (2 downto 0);  
       --signal   debug_cs_cache_ctrl : std_logic_vector (97 downto 0); 
	
begin
  ------------------------------------------
  -- Java BEE port-map
  ------------------------------------------
    Java_core : soj
    generic map(
        METHOD_AREA_DDR_ADDRESS     => X"5A000000",
		STACK_AREA_DDR_ADDRESS		=> (X"5BF"&"11"), -- by fox
		Max_Thread_Number			=> 16,			-- by fox
		BURST_LENGTH				=> X"20",		-- by fox , modified by T.H.Wu , 2013.7.19
        ENABLE_JAIP_PROFILER                        => ENABLE_JAIP_PROFILER ,
        C_MAX_AR_DWIDTH             => 64,
        RAMB_S9_AWIDTH              => 11,
        RAMB_S18_AWIDTH             => 10,
        RAMB_S36_AWIDTH             => 9
    )
    port map(
        -- basic signal
        Rst                         => Bus2IP_Reset,
        clk                         => Bus2IP_Clk, 
		the_core_act				=>	the_core_act,
		core_id						=> core_id,

		--GC
		GC_Cmplt_in                 => GC_Cmplt_u,	
		anewarray_flag2GC           => GC_anewarray_flag_u,
		GC_areturn_flag_out         => GC_areturn_u,
		GC_Clinit_Stop              => GC_Clinit_Stop_u,
		Mthod_exit_flag_out         => GC_Mthd_Exit_u,
		Mthod_enter_flag_out        => GC_Mthd_Enter_u,	
		Mthod_enter_flag_f_out		=> GC_Mthd_Enter_f_u,	
		GC_arrayAlloc_en_out        => GC_arrayAlloc_en_u,		
		GC_StackCheck_flag          => GC_StackCheck_flag_u,
		-- enable xcptn          
		xcptn_en                    => xcptn_en(0), 

        -- (slave) write from external part(power PC) to soj reg
        ex2java_wen                 => ex2java_wen,
        ex2java_addr                => ex2java_addr,
        ex2java_data                => ex2java_data, -- data(32 to 63),  
		
        -- (slave) CST profile table
        CSTProfileTable             => CST_manage,
		-- (slave) Mthd profile table
        MthdProfileTable            => mthd_manage,
		
		-- (slave) parser to ER_LUT
		parser2ER_LUT               => parser2ER_LUT,

        -- (master) external memory access 
        external_MstRd_CmdAck => Bus2IP_Mst_CmdAck_reg , -- added by T.H. Wu , 2013.6.20
        external_MstRd_burst_data_rdy => Bus2IP_MstRd_src_rdy_n_reg, -- added by T.H. Wu , 2013.6.20
        external_MstWr_burst_data_rdy =>  Bus2IP_MstWr_dst_rdy_n,
        external_access_cmplt       => jpl_mst_cmplt,
        external_access_addr        => jpl_mst_address_delay,
        external_load_req           => top_mst_rd_req_delay,
        external_load_data          => jpl_load_data,
        external_store_req          => top_mst_wr_req_delay,
        external_store_data         => jpl_mst_data_delay,
        jpl_mst_transfer_Type     => jpl_mst_transfer_Type ,
        IP2Bus_Mst_BE               => jpl_mst_BE_tmp,
		current_heap_ptr			=> GC_Heap_Addr_u,
		
		-- class info table
		clsiInternLoadReq			=> clsiInternLoadReq,
		clsiInternStoreReq			=> clsiInternStoreReq,
		clsiAddr					=> clsiAddr,
		clsInfo						=> clsInfo,
		clsiCmplt					=> clsiCmplt,
		clsiInternWrData			=> clsiInternWrData,
		-- for Data Coherence Controller,	will be modified soon , 2013.9.7 
		JAIP2COOR_cmd				=>	JAIP2COOR_cmd,
		JAIP2COOR_info1_pipeline 	=>	JAIP2COOR_info1_pipeline , 
		JAIP2COOR_info2_pipeline	=> 	JAIP2COOR_info2_pipeline ,	
		JAIP2COOR_pending_resMsgSent=>	JAIP2COOR_pending_resMsgSent ,
		COOR_res_msg_bak			=>	COOR_res_msg_bak ,
		COOR_info1_bak				=>	COOR_info1_bak ,
		COOR_info2_bak				=>	COOR_info2_bak ,
		COOR_cmd_cmplt				=>	COOR_cmd_cmplt ,

        -- interrupt
        interrupt_req               => interrupt_on,
        interrupt_func              => interrupt_func,

        -- cache up top of stack
        TOS_A                       => A,
        TOS_B                       => B,
        TOS_C                       => C,

        -- parameters of host service
        Host_arg1                   => arg1,
        Host_arg2                   => arg2,
        Host_arg3                   => arg3,
        Host_arg4                   => arg4,
        Host_arg5                   => arg5,

		native_HW_en				=> native_HW_en,
		native_HW_ID				=> native_HW_ID,
		native_HW_cmplt				=> native_HW_cmplt,
		
		-- heap alloc
		Alloc_en				=> Alloc_en,
		AllocSize				=> AllocSize,
		
		-- native HW
		xcptn_thrown_Native_HW		=> xcptn_thrown_Native_HW_tmp,
		Native_HW_thrown_ID			=> Native_HW_thrown_ID_tmp,
		
		CTRL_state_out              => CTRL_state,
		
        debug_cs_soj            => debug_cs_soj ,
       -- debug_cs_CSTctrl   => debug_cs_CSTctrl  ,
         debug_cs_MActrl       =>   debug_cs_MActrl    ,
        --debug_cs_fetch         =>    debug_cs_fetch     , 
        --debug_cs_exe             =>    debug_cs_exe ,
        -- debug_cs_xcptn        =>   debug_cs_xcptn  ,
	-- debug_cs_decode     => debug_cs_decode      ,
        --debug_cs_4portbank         =>  debug_cs_4portbank ,
        debug_cs_thread_mgt       =>  debug_cs_thread_mgt ,
        debug_cs_stk_mgt            => debug_cs_stk_mgt    , 
		
        debug_flag                  => debug_flag,
        debug_addr                  => debug_addr,
        debug_data                  => debug_data,
		
		debug_nb_SW                 =>debug_nb_SW,
		debug_nb_do					=>debug_nb_do, 
        
		-- mmes profiler
		prof_invoke_flag			=> prof_invoke_flag,
		prof_return_flag			=> prof_return_flag,
		prof_DSRU_on				=> prof_DSRU_on,
		prof_mem_access_on			=> prof_mem_access_on,
		prof_DR2MA_mgt_mthd_id		=> prof_DR2MA_mgt_mthd_id,
		
		prof_simple_issued_A_D 		=> prof_simple_issued_A_D,
		prof_simple_issued_B_D 		=> prof_simple_issued_B_D,
		prof_issued_bytecodes_D		=> prof_issued_bytecodes_D
        
		
    );
 
	GC1 : GC 
	generic map(
		Table_bit                   => 9,
		TableS_bit                  =>11, 
        REF_bit                     =>22,
		SIZE_bit                    =>20,
		NEXT_bit                    =>11,
		COUNT_bit                   => 5,
		Meth_col_en                 => 1
	)
	port map( 
        Rst                         => Bus2IP_Reset,
        clk                         => Bus2IP_Clk,
        GC_Alloc_en                 => Alloc_en, 
		GC_Alloc_arr_en             => GC_arrayAlloc_en_u,
		GC_StackCheck_f             => GC_StackCheck_flag_u,
		GC_Null_en                  => GC_Null_en_u,  
		GC_Clinit_Stop              => GC_Clinit_Stop_u,
		GC_anewarray_flag           => GC_anewarray_flag_u,
		GC_areturn_falg             => GC_areturn_u,       
		GC_Mthd_Exit                => GC_Mthd_Exit_u,
		GC_Mthd_Enter_f             => GC_Mthd_Enter_f_u,
		GC_Mthd_Enter               => GC_Mthd_Enter_u,
		GC_ext_wr_heap_ptr          => ext_wr_heap_ptr,       
        GC_AllocSize                => AllocSize,   
		GC_reference                => GC_For_Search_Ref,   
		GC_current_heap_ptr_ext     => current_heap_ptr_ext,   
		GC_A                        => A,

		GC_cmplt                    => GC_Cmplt_u,
		GC_Current_Heap_Addr        => GC_Current_Heap_Addr_u,		
        GC_Heap_Addr                => GC_Heap_Addr_u,
		debug_GC_port               => debug_GC_port		

	);
 
	Cache_controller1 : Cache_controller 
	generic map(
		CPU_DATA_WIDTH	=> 32,
		TAG_SIZE		=> 13,
		INDEX_SIZE		=> 8,
		OFFSET_SIZE		=> 5, 
		ASSOCIATIVITY	=> 2,
		WRITE_STRATEGY	=> 1
	)
	port map( 
		-- cs debug
        --debug_cs_cache_ctrl				=>	debug_cs_cache_ctrl ,
        -----
		clk						      => Bus2IP_Clk,
		rst						      => Bus2IP_Reset,
		cache_mem_flush			      => cache_mem_flush,
		cache_read				      => cache_read,
		cache_write 			      => cache_write,
		cache_address			      => cache_address,
		cache_data_in			      => cache_data_in,
		cache_forMst_Type             => cache_forMst_Type,
		cache_cmplt				      => cache_cmplt,
		cache_data_out			      => cache_data_out,

--------------------------------------------------------------------------------------
--                     for memory prot use                               -------------
--------------------------------------------------------------------------------------
		Cmem_B2IP_CmdAck		      => Bus2IP_Mst_CmdAck,
		Cmem_B2IP_Wrdst_rdy_n         => Bus2IP_MstWr_dst_rdy_n,
        Cmem_ready				      => Bus2IP_MstRd_src_rdy_n,
		Cmem_complt                   => Bus2IP_Mst_Cmplt,
		Cmem_IP2B_Mst_BE              => jpl_mst_BE,
        Cmem_data_in				  => Bus2IP_MstRd_d,
		
		Cmem_IP2B_Wrsof_n             => IP2Bus_MstWr_sof_nC,
		Cmem_IP2B_Wreof_n		      => IP2Bus_MstWr_eof_nC,
		Cmem_IP2B_Wrsrc_rdy_n         => IP2Bus_MstWr_src_rdy_nC,
        Cmem_write			          => Cmem_write,
        Cmem_read			 	      => Cmem_read,
        Cmem_write_data               => Cmem_write_data,
        Cmem_addr				      => Cmem_addr,
		-- for multicore coordinator , 2013.10.1
		-- note : it must be completed with at most 3 clocks
		COOR2JAIP_wr_ack              =>	COOR2JAIP_cache_w_en,
		COOR2JAIP_info1_cache         =>	COOR2JAIP_info1 (6 to 31),
		COOR2JAIP_info2_cache         =>	COOR2JAIP_info2,
		-- for multicore coordinator , 2013.9.25
		COOR2JAIP_rd_ack              =>	COOR2JAIP_rd_ack ,
		JAIP2COOR_cache_w_en          =>	JAIP2COOR_cache_wr_en_w,
		JAIP2COOR_cache_r_en          =>	JAIP2COOR_cache_rd_en_w,
		JAIP2COOR_info1_cache         =>	JAIP2COOR_info1_cache,
		JAIP2COOR_info2_cache         =>	JAIP2COOR_info2_cache
		-- cs debug
		--debug_cache_controller_data   => debug_cache_controller_data
	);
	
    labal_enable_arraycopy_0 : if ENABLE_ARRAYCOPY = 1 generate
	HW_acc1	: arraycopy_single
	generic map(
		C_MST_AWIDTH                => 32,
		C_MST_DWIDTH                => 32
	)
	port map(
		Clk                 		=> Bus2IP_Clk,
		Rst					        => Bus2IP_Reset,
			
		-- PLB MST BURST ports --
		AC_IP2Bus_MstRd_Req               => AC_IP2Bus_MstRd_Req,
		AC_IP2Bus_MstWr_Req               => AC_IP2Bus_MstWr_Req,
		AC_IP2Bus_Mst_Addr                => AC_IP2Bus_Mst_Addr,
		AC_IP2Bus_Mst_BE                  => AC_IP2Bus_Mst_BE,
		AC_Bus2IP_MstRd_d                 => cache_data_out_dly, -- cache_data_out,
		AC_IP2Bus_MstWr_d                 => AC_IP2Bus_MstWr_d,
		AC_Bus2IP_Mst_Cmplt             => jpl_mst_cmplt_dly, -- jpl_mst_cmplt,
		
		-- exception 
		xcptn_thrown_Native_HW			  => xcptn_thrown_Native_HW_tmp,
		Native_HW_thrown_ID				  => Native_HW_thrown_ID_tmp,
		
		CTRL_state                   	  => CTRL_state,
		
		-- args & ctrl ports --
		ACEn					   		  => ACEn_dly, -- ACEn,
		ACCmplt				   		  	  => ACCmplt,
			
		src					   		  	  => arg1_dly, -- arg1, 
		srcPos						   	  => arg2_dly, -- arg2, 
		dst							   	  => C_dly, --C,
		dstPos						   	  => B_dly, --B,
		cpyLength                      	                  => A_dly   --A
	);
	end generate;
	
    labal_enable_index_of_0 : if ENABLE_INDEX_OF = 1 generate
	HW_IO1 : indexOf
	generic map(
			C_MST_AWIDTH             	    => 32,
			C_MST_DWIDTH                    => 32
	)
	port map(
			Clk                 			=> Bus2IP_Clk,
			Rst					         => Bus2IP_Reset,    
			
			-- PLB MST BURST ports --
			IO_IP2Bus_MstRd_Req           => IO_IP2Bus_MstRd_Req,
			IO_IP2Bus_Mst_Addr             => IO_IP2Bus_Mst_Addr,
			IO_Bus2IP_MstRd_d               => cache_data_out_dly, -- cache_data_out,
			IO_Bus2IP_Mst_Cmplt           => jpl_mst_cmplt_dly, -- jpl_mst_cmplt,
			
			-- args & ctrl ports --
			IOEn					   		=> IOEn_dly, -- IOEn,
			IOCEn							=> IOCEn_dly, --IOCEn,
			LIOEn							=> LIOEn_dly, -- LIOEn,
			VIOEn							=> VIOEn_dly, -- VIOEn, 
			IOCmplt				   		  	=> IOCmplt,
			
			textRef				   		  	=> C_dly, -- C,
			indexof_mthd_arg1			   	=> B_dly,  --B,
			fromIndex					   	=> A_dly, --A,
			--strRef						   	=> B,
			--ch								=> B, 
			res								=> IO_res
			-- cs
			--debug_IOSM						=> debug_IOSM
	);
    end generate;
	
    label_heap_gen_0 : if ONCHIP_HEAP_GEN = 1 generate
    begin
        heap1 : heap
        generic map(
            RAMB_S18_AWIDTH  => 10
        )
        port map(
            Rst              => Bus2IP_Reset,
            clk              => Bus2IP_Clk,
            heap_data_be     => heap_data_be,
            address          => heap_address,
            heap_data_in     => heap_data_in,
            heap_data_out    => heap_data_out,
            store_request    => heap_store_req,
            load_request     => heap_load_req,
            heap_complete    => heap_complete
        );
    end generate;

    xrt : cross_reference_table
    generic map(
        RAMB_S18_AWIDTH      => 12
    )
    port map(
        Rst              => Bus2IP_Reset,
        clk              => Bus2IP_Clk,
        address          => xrt_address,
        offset_in        => Bus2IP_Data,
        offset_out       => xrt_load_data,
        load_request     => xrt_load_req,
        store_request    => xrt_store_req,
        crt_complete     => xrt_complete
    );

	cls_info_table : class_info_table
    generic map(
        RAMB_S18_AWIDTH      => 12
    )
    port map(
        Rst              => Bus2IP_Reset,
        clk              => Bus2IP_Clk,
        address          => clsi_address,
        offset_in        => clsi_data_in,
        offset_out       => clsi_load_data,
        load_request     => clsi_load_req,
        store_request    => clsi_store_req,
        crt_complete     => clsi_complete
    );
  -- ex2java
  ex2java_wen <= '1' when(IOCmplt = '1' or SCTMCmplt = '1') else
				 we;
  ex2java_addr <= "00000000000100" when(IOCmplt = '1' or SCTMCmplt = '1') else	
				 mem_address;
  ex2java_data <= IO_res when(IOCmplt = '1') else
				  Total_time when(SCTMCmplt = '1') else
				  Bus2IP_Data;
  --------------------------------------------------------------
  -- code to read/write user logic master model
  --------------------------------------------------------------
  -- no-cache PLB access
  process(Bus2IP_Clk) begin
	if(rising_edge(Bus2IP_Clk)) then
	if(Bus2IP_Reset = '1') then
		mst_rd_req <= '0';
		mst_wr_req <= '0';
		mst_rd_data <= (others => '0');
	else
                -- if the read/write address is not in heap backup area (0x5C000000~0x5DFFFFFF) or in JAIP (0x8801xxxx)
		if(jpl_mst_rd_req = '1' and jpl_mst_address(0 to 5) /= "010111" and jpl_mst_address(0 to 15) /= x"8801") then
			mst_rd_req <= '1';
		elsif(Bus2IP_Mst_CmdAck = '1') then
			mst_rd_req <= '0';
		end if;

		if(jpl_mst_wr_req = '1' and jpl_mst_address(0 to 5) /= "010111" and jpl_mst_address(0 to 15) /= x"8801") then
			mst_wr_req <= '1';
		elsif(Bus2IP_Mst_CmdAck = '1') then
			mst_wr_req <= '0';
		end if;
		
		if(Bus2IP_MstRd_src_rdy_n = '0') then
			mst_rd_data <= Bus2IP_MstRd_d;
		end if;
	end if;
	end if;
  end process;
  mst_addr <= jpl_mst_address;
  mst_wr_data <= jpl_mst_data_delay; -- just for master bus write operation with fixed burst-length
  mst_BE <= jpl_mst_BE_tmp;
  
  -- PLB
  IP2Bus_Mst_BE <= IP2Bus_Mst_BE_tmp;
  IP2Bus_Mst_Addr <= IP2Bus_Mst_Addr_tmp;
  IP2Bus_MstWr_d <= IP2Bus_MstWr_d_tmp;
  IP2Bus_MstRd_Req <= IP2Bus_MstRd_Req_tmp;
  IP2Bus_MstWr_Req <= IP2Bus_MstWr_Req_tmp;
  IP2Bus_Mst_Length <= IP2Bus_Mst_Length_tmp;
  IP2Bus_Mst_Type <= IP2Bus_Mst_Type_tmp;
  
  IP2Bus_Mst_BE_tmp    <= jpl_mst_BE;
  IP2Bus_Mst_Addr_tmp  <= Cmem_addr when(jpl_mst_address(0 to 5) = "010111" or cache_flush_reg ='1') else jpl_mst_address;
  IP2Bus_MstWr_d_tmp   <= Cmem_write_data when(jpl_mst_address(0 to 5) = "010111" or cache_flush_reg ='1') else mst_wr_data;
  IP2Bus_MstRd_Req_tmp <= Cmem_read when(jpl_mst_address(0 to 5) = "010111") else mst_rd_req;
  IP2Bus_MstWr_Req_tmp <= Cmem_write when(jpl_mst_address(0 to 5) = "010111" or cache_flush_reg ='1') else mst_wr_req; 
    IP2Bus_Mst_Length_tmp <=
                                                    --x"03C" when IP2Bus_Mst_Type_tmp = '1' and jpl_mst_address(0 to 5) /= "010111" else
                                                    --x"020" when IP2Bus_Mst_Type_tmp = '1' and jpl_mst_address(0 to 5) = "010111" else
                                                    x"020" when IP2Bus_Mst_Type_tmp = '1' else
                                                    -- 2013.7.9 burst length must be 0x20 for Caffine stringAtom ,
													-- otherwise the program may go wrong (stringAtom) 
                                                    -- for test , check whether cache can use 0x40 length , 2013.7.4
                                                    x"004";
  IP2Bus_Mst_Type_tmp <= cache_forMst_Type when(jpl_mst_address(0 to 5) = "010111" or cache_flush_reg ='1' ) else  jpl_mst_transfer_Type;
  --cache
  cache_write <= AC_IP2Bus_MstWr_Req when(AC_ACT = '1') else
				 jpl_mst_wr_req when(jpl_mst_address(0 to 5) = "010111") else '0';
  cache_read <= AC_IP2Bus_MstRd_Req when(AC_ACT = '1') else
				IO_IP2Bus_MstRd_Req when(IO_ACT = '1') else
				jpl_mst_rd_req when(jpl_mst_address(0 to 5) = "010111") else '0'; 
  cache_address <= AC_IP2Bus_Mst_Addr(25 downto 0) when(AC_ACT = '1') else
				   IO_IP2Bus_Mst_Addr(25 downto 0) when(IO_ACT = '1') else
				   jpl_mst_address(6 to 31);
  cache_data_in <= AC_IP2Bus_MstWr_d when(AC_ACT = '1') else
				   jpl_mst_data;	
  -- r/w control state machine
	--jpl_mst_address <= AC_IP2Bus_Mst_Addr when(AC_ACT = '1') else jpl_mst_address_delay;
	--jpl_mst_data <= AC_IP2Bus_MstWr_d when(AC_ACT = '1') else jpl_mst_data_delay;
	jpl_mst_cmplt   <= 
                        -- modified by T.H.Wu , 2013.7.3 , heap_complete is still useful
                        --heap_complete when jpl_mst_address(0 to 17) = (X"8801"&"11") else -- for original heap (on-chip BRAM) 
                      xrt_complete when jpl_mst_address(0 to 16) = (X"8801"&'1') else -- for level-1 XRT
                      cache_cmplt when jpl_mst_address(0 to 5) = "010111" else -- for current heap (cache) 
                     Bus2IP_Mst_Cmplt ; -- for  CST/MA controller/ stack management , added by T.H. Wu , 2013.6.20
	clsiCmplt <= clsi_complete;
    
      -- modified by T.H.Wu , 2013.7.3 , heap_data_in/ heap_load_req / heap_store_req is still useful
    label_heap_gen_1 : if ONCHIP_HEAP_GEN = 1 generate
            heap_load_req  <= jpl_mst_rd_req when jpl_mst_address(0 to 17) = (X"8801"&"11") else '0';
            heap_store_req <= ( Bus2IP_CS(0) ) and not(Bus2IP_RNW) when Bus2IP_Addr(0 to 17) = (X"880"&"0"&core_id&"1"&"11") else
                                    jpl_mst_wr_req when jpl_mst_address(0 to 17) = (X"8801"&"11") else '0';
            heap_data_in   <= jpl_mst_data when jpl_mst_wr_req = '1' or top_mst_wr_req_2cycle = '1' else Bus2IP_Data;
            heap_address   <= jpl_mst_address(20 to 29) when heap_load_req = '1' or -- use for debug
					  jpl_mst_wr_req = '1' or top_mst_wr_req_2cycle = '1'
                                    else mem_address_2cycle(4 to 13)        when we_2cycle = '1'
                                    else mem_address(4 to 13);
    heap_data_be   <= jpl_mst_BE when jpl_mst_wr_req = '1' or top_mst_wr_req_2cycle = '1' else 
					  Bus2IP_BE when (Bus2IP_Addr(0 to 17) = (X"880"&"0"&core_id&"1"&"11") and Bus2IP_CS(0) = '1')else	
					  -- modified by C.C. Hsu
					  "1111";
    end generate;
	clsi_load_req   <= clsiInternLoadReq;
    xrt_load_req   <= jpl_mst_rd_req when jpl_mst_address(0 to 16) = (X"8801"&"1") else '0';
    xrt_store_req  <= ( Bus2IP_CS(0) ) and not(Bus2IP_RNW) when Bus2IP_Addr(0 to 16) = (X"880"&"0"&core_id&"1"&"1") else '0';
	clsi_store_req  <= ( Bus2IP_CS(0) ) and not(Bus2IP_RNW) when Bus2IP_Addr(0 to 17) = (X"880"&"0"&core_id&"1"&"01") else 
					   clsiInternStoreReq;
	jpl_mst_BE	<= AC_IP2Bus_Mst_BE when(AC_ACT = '1') else
				   jpl_mst_BE_tmp;
	clsInfo <= clsi_load_data;
	-- modified by C.C.H. 2013.7.11
    --xrt_address    <= jpl_mst_address(18 to 29) when xrt_load_req = '1'-- use for debug
    --                  else mem_address(2 to 13);
    xrt_address    <= jpl_mst_address(17 to 29) when xrt_load_req = '1'-- use for debug
                      else mem_address(1 to 13);
					  -- modified by T.H.Wu 2013.10.2 
    --clsi_address    <= clsiAddr when (clsi_load_req = '1' or clsiInternStoreReq = '1')
    --                  else mem_address(2 to 13);
    clsi_address    <= clsiAddr (8 downto 0) when (clsi_load_req = '1' or clsiInternStoreReq = '1')
                      else mem_address(5 to 13);
	clsi_data_in    <= clsiInternWrData when(clsiInternStoreReq = '1') else
					   Bus2IP_Data;
    jpl_load_data <= 
                                -- modified by T.H.Wu , 2013.7.3 , heap_data_out is still useful
                                    --heap_data_out when jpl_mst_address(0 to 17) = (X"8801"&"11") else								
                                    xrt_load_data when jpl_mst_address(0 to 16) = (X"8801"&"1") else
                                    cache_data_out when jpl_mst_address(0 to 5) = "010111" else
                                    mst_rd_data   ;   
 
	
	-- native HW
       -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
	--ACEn <= native_HW_en when (  native_HW_ID = x"80") else			'0';
	--IOEn <= native_HW_en when (  native_HW_ID = x"81") else			'0';
	--SCTMEn <= native_HW_en when ( native_HW_ID = x"82") else			  '0';
	--POEn <= native_HW_en when(native_HW_ID = x"83") else			'0';
	--POFEn <= native_HW_en when( native_HW_ID = x"84") else			 '0';
	--IOCEn <= native_HW_en when ( native_HW_ID = x"85") else			   '0';
	--LIOEn <= native_HW_en when(native_HW_ID = x"86") else			 '0';
	--VIOEn <= native_HW_en when(native_HW_ID = x"87") else			 '0';
    
	ACEn <= native_HW_en when (  native_HW_ID = "00000") else			'0';
	IOEn <= native_HW_en when (  native_HW_ID = "00001") else			'0';
	SCTMEn <= native_HW_en when ( native_HW_ID = "00010") else			'0';
	POEn <= native_HW_en when(	native_HW_ID = "00011") else			'0';
	POFEn <= native_HW_en when( native_HW_ID = "00100") else			'0';
	IOCEn <= native_HW_en when( native_HW_ID = "00101") else			'0';
	LIOEn <= native_HW_en when(	native_HW_ID = "00110") else			'0';
	VIOEn <= native_HW_en when(	native_HW_ID = "00111") else			'0';
    
	--native_HW_cmplt <= '1' when(ACCmplt = '1' and native_HW_ID = x"80") else
	--				   '1' when(IOCmplt = '1' and native_HW_ID = x"81") else
	--				   '1' when(SCTMCmplt = '1' and native_HW_ID = x"82") else
	--				   '1' when(POCmplt = '1' and native_HW_ID = x"83") else
	--				   '1' when(POFCmplt = '1' and native_HW_ID = x"84") else
	--				   '1' when(IOCmplt = '1' and native_HW_ID = x"85") else
	--				   '1' when(IOCmplt = '1' and native_HW_ID = x"86") else 
	--				   '1' when(IOCmplt = '1' and native_HW_ID = x"87") else
	--				   '0';
	native_HW_cmplt <= '1' when(ACCmplt = '1' and native_HW_ID		= "00000") else
					   '1' when(IOCmplt = '1' and native_HW_ID		= "00001") else
					   '1' when(SCTMCmplt = '1' and native_HW_ID	= "00010") else
					   '1' when(POCmplt = '1' and native_HW_ID		= "00011") else
					   '1' when(POFCmplt = '1' and native_HW_ID		= "00100") else
					   '1' when(IOCmplt = '1' and native_HW_ID		= "00101") else
					   '1' when(IOCmplt = '1' and native_HW_ID		= "00110") else 
					   '1' when(IOCmplt = '1' and native_HW_ID		= "00111") else
					   '0';
--------for cache flush signal------------------------------------------
-- modified by jeff , 2013.7.11
-- enable write back during ISR 
    -- there's a potential problem , if write back operation (flush to memory) and stack management acquire bus concurrnetly
    -- one of them may probably go wrong (added since 2013.8.2)
  process (Bus2IP_Clk)is begin
	if(rising_edge (Bus2IP_Clk))then
        if(Bus2IP_Reset = '1')then
            cache_flush_reg    <='0';
           cache_flush_delay  <='0';
		   flush_cmplt32        <=(others => '0');
        else
            cache_flush_reg    <= cache_flush_en(31);
			cache_flush_delay <= cache_flush_reg; 
			if(cache_mem_flush = '1') then
				flush_cmplt32 <=x"00000000";
			elsif(cache_cmplt ='1' and cache_flush_reg='1') then
				flush_cmplt32 <=x"00000001";
			end if;
        end if;
    end if;
  end process;
	cache_mem_flush <=cache_flush_en(31) and not cache_flush_delay;

	
    
	process(Bus2IP_Clk) is
	begin 
		if( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
			if(Bus2IP_Reset = '1') then
				AC_ACT <= '0';
			elsif(ACCmplt = '0') then				-- ACCmplt and ACEn may raised at the same cycle.
				if(ACEn = '1') then
					AC_ACT <= '1';
				end if;
			else
				AC_ACT <= '0';
			end if;
			
			if(Bus2IP_Reset = '1') then
				IO_ACT <= '0';
			elsif(ctrl_reg(0) = '0') then -- modified by T.H.Wu , 2013.9.8 , useless now
				IO_ACT <= '0';
			elsif(IOEn = '1' or IOCEn = '1' or LIOEn = '1' or VIOEn = '1') then
				IO_ACT <= not IOCmplt;
			elsif(IOCmplt = '1') then
				IO_ACT <= '0';
			end if;
			
			if(Bus2IP_Reset = '1') then
				SCTMCmplt <= '0';
				POCmplt <= '0';
				POFCmplt <= '0';
			else
				SCTMCmplt <= SCTMEn;
				POCmplt <= POEn;
				POFCmplt <= POFEn;
			end if; 
                    -- modified by T.H.Wu , 2013.8.10 , for solving critical path issue 
                     ACEn_dly    <= ACEn ;
                     IOEn_dly     <= IOEn ; 
                     SCTMEn_dly   <= SCTMEn ;
                     POEn_dly    <= POEn ;
                     POFEn_dly   <= POFEn ;
                     IOCEn_dly   <= IOCEn ;
                     LIOEn_dly    <= LIOEn ;
                     VIOEn_dly    <= VIOEn ;
                    -- modified by T.H.Wu , 2013.8.10 , for solving critical path issue
                    A_dly <= A;
                    B_dly <= B;
                    C_dly <= C;
                    arg1_dly <= arg1;
                    arg2_dly <= arg2;
                    arg3_dly <= arg3;
                    arg4_dly <= arg4;
                    arg5_dly <= arg5;
                    -- modified by T.H.Wu , 2013.8.12 , for solving critical path issue
                    jpl_mst_cmplt_dly <= jpl_mst_cmplt;
                    cache_data_out_dly <= cache_data_out; 
		end if;
	end process;
 
  -- delay one cycle for on-chip memory timing constraint
  process (Bus2IP_Clk)is begin
	if(rising_edge (Bus2IP_Clk))then
        if(Bus2IP_Reset = '1')then 
            xrt_load_req_delay <= '0';
            top_mst_wr_req_2cycle <= '0';
			jpl_mst_address_reg <= (others => '0');
			jpl_mst_data_reg <= (others => '0');
			jpl_mst_wr_req_reg <= '0';
			jpl_mst_rd_req_reg <= '0';
            native_HW_en_reg <=  '0';
        else
            native_HW_en_reg <=  native_HW_en;
            xrt_load_req_delay <= xrt_load_req; 
            
            top_mst_wr_req_2cycle <= top_mst_wr_req_delay;
            mem_address_2cycle    <= mem_address;
            
			if(AC_ACT = '1') then	-- These connection might useless
				jpl_mst_address_reg	      <= AC_IP2Bus_Mst_Addr;
				jpl_mst_data_reg          <= AC_IP2Bus_MstWr_d;
				jpl_mst_rd_req_reg	  <= AC_IP2Bus_MstRd_Req;
				jpl_mst_wr_req_reg	  <= AC_IP2Bus_MstWr_Req;
			elsif(IO_ACT = '1') then
				jpl_mst_address_reg	      <= IO_IP2Bus_Mst_Addr;
				jpl_mst_rd_req_reg	  <= IO_IP2Bus_MstRd_Req;
			else
				jpl_mst_address_reg       <= jpl_mst_address_delay;		
				jpl_mst_data_reg          <= jpl_mst_data_delay;
				jpl_mst_wr_req_reg <= top_mst_wr_req_delay;
				jpl_mst_rd_req_reg <= top_mst_rd_req_delay;
			end if;
        end if;
    end if;
  end process;
  
   
  -- below code style may not met the timing constrain
  jpl_mst_wr_req <= jpl_mst_wr_req_reg;
  jpl_mst_rd_req <= jpl_mst_rd_req_reg;
  jpl_mst_address <= jpl_mst_address_reg;
  jpl_mst_data <= jpl_mst_data_reg;
  
    
    
  
        process( Bus2IP_Clk ) is  begin
            if ( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
                if ( Bus2IP_Reset = '1' ) then
                    core_id <= (others=>'0');
                else
                    core_id <= ctrl_reg (1 to 2);
                end if;
                --  generate user logic interrupts 
                IP2Bus_IntrEvent(0)  <= interrupt_on;
                ISR_pack_msg <= "00000000" & interrupt_func   ; -- added by T.H.Wu , 2013.9.5  
            end if;
        end process;
    
	---------------------------------------------------------------------------------- 
    -- for multicore , data coherence controller use , , modified by T.H.Wu , 2013.9.3
	 JAIP2COOR_cache_w_en    <=	JAIP2COOR_cache_wr_en_w;
	 JAIP2COOR_cache_r_en    <=	JAIP2COOR_cache_rd_en_w;  
	-- modified by T.H.Wu , 2013.9.5, experiment for simultaneous multithreading and synchronization controller 
	process (
		JAIP2COOR_cache_wr_en_w, JAIP2COOR_cache_rd_en_w, JAIP2COOR_info1_cache, JAIP2COOR_info2_cache,
		JAIP2COOR_info1_pipeline, JAIP2COOR_info2_pipeline
	) is begin
		if(JAIP2COOR_cache_wr_en_w='1' or JAIP2COOR_cache_rd_en_w='1') then
			JAIP2COOR_info1 <= JAIP2COOR_info1_cache;
			JAIP2COOR_info2 <= JAIP2COOR_info2_cache;
		else
			JAIP2COOR_info1 <= JAIP2COOR_info1_pipeline;
			JAIP2COOR_info2 <= JAIP2COOR_info2_pipeline;
		end if;
	end process;
	--
	--
	 process( Bus2IP_Clk ) is  begin
		if ( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
			if ( Bus2IP_Reset = '1' ) then  
				COOR_res_msg_bak <= ("111" & "111" & "00" &  x"00");
				COOR_info1_bak <= (others=>'0');
				COOR_info2_bak <= (others=>'0');
			else 
				COOR_res_msg_bak <= COOR_res_msg_bak_w;
				COOR_info1_bak <= COOR_info1_bak_w ;
				COOR_info2_bak <= COOR_info2_bak_w ;
            end if;
		end if;
	end process;
	
	 -- if   sender/receiver of response message is the core , then record it
	process(  
		COOR_info1_bak, COOR_info2_bak, COOR2JAIP_response_msg, core_id,
		COOR2JAIP_res_newTH_data1, COOR2JAIP_res_newTH_data2
		-- , COOR_cmd_cmplt
	) is  begin
		-- modified by T.H.Wu , 2013.9.12, fixing bug while add the first thread and init
		-- detect if taking the message (for Thread.start() , monitorenter/monitorexit , synchronized method)
		COOR_res_msg_bak_w <= COOR2JAIP_response_msg;
		COOR_info1_bak_w <= COOR_info1_bak;
		COOR_info2_bak_w <= COOR_info2_bak;
		if(
			COOR2JAIP_response_msg(15 downto 13)=("0"&core_id) or
			COOR2JAIP_response_msg(12 downto 10)=("0"&core_id)
		)then
			COOR_info1_bak_w <= COOR2JAIP_res_newTH_data1;
			COOR_info2_bak_w <= COOR2JAIP_res_newTH_data2;
		end if;
	end process;
	-- 
	---------------------------------------------------------------------------------- 
     
     
     

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
      mem_data_out(i)(byte_index*8 to byte_index*8+7) <= data_out;

      process(mem_address) is
      begin
      case mem_address is
        when "00000000000000" => data_out <= ctrl_reg(byte_index*8 to byte_index*8+7);
        when "00000000000001" => data_out <= ISR_pack_msg(byte_index*8 to byte_index*8+7);
        
        when "00000000000010" => data_out <= A(byte_index*8 to byte_index*8+7);
        when "00000000000011" => data_out <= B(byte_index*8 to byte_index*8+7);
        when "00000000000100" => data_out <= C(byte_index*8 to byte_index*8+7);
        
        when "00000000000101" => data_out <= arg1(byte_index*8 to byte_index*8+7);
        when "00000000000110" => data_out <= arg2(byte_index*8 to byte_index*8+7);
        when "00000000000111" => data_out <= arg3(byte_index*8 to byte_index*8+7);
        when "00000000001000" => data_out <= arg4(byte_index*8 to byte_index*8+7);  
        when "00000000001001" => data_out <= arg5(byte_index*8 to byte_index*8+7);  
        
        when "00000000001100" => data_out <= CST_manage(byte_index*8 to byte_index*8+7); 
        
        when "00000000010100" => data_out <= Total_time(byte_index*8 to byte_index*8+7);  
        when "00000000010101" => data_out <= HW_time(byte_index*8 to byte_index*8+7); 
        when "00000000010110" => data_out <= rupt_time(byte_index*8 to byte_index*8+7);
        when "00000000010111" => data_out <= time_with_some_interrupt(byte_index*8 to byte_index*8+7); 
		when "00000000100001" => data_out <= GC_Current_Heap_Addr_u((3-byte_index)*8+7 downto (3-byte_index)*8);
        when "00000010000101" => data_out <= flush_cmplt32(byte_index*8 to byte_index*8+7);--add by Jeff , 2013.7.11
	    
        --debug for new buffer
		when "00000000100000" => data_out <= debug_nb_do	(byte_index*8 to byte_index*8+7);    
        when "00000010000000" => data_out <= debug_flag		(byte_index*8 to byte_index*8+7);
        when "00000010000001" => data_out <= debug_addr		(byte_index*8 to byte_index*8+7);
        when "00000010000010" => data_out <= debug_data		(byte_index*8 to byte_index*8+7); 
		
		-- profile , added by C.C.H.
		when "00000010010000" => data_out <= method_profile((3-byte_index)*8+7 downto (3-byte_index)*8);
		when "00000010010001" => data_out <= bytecode_profile((3-byte_index)*8+7 downto (3-byte_index)*8); 
		when others     => data_out <= (others => '1') ;
      end case;
      end process;
     
      write_data(byte_index*8 to byte_index*8+7) <= data_in;

      BYTE_RAM_PROC : process( Bus2IP_Clk ) is
      begin

        if ( Bus2IP_Clk'event and Bus2IP_Clk = '1' ) then
			if ( write_enable = '1' ) then          
        		case mem_address is 
        		  when "00000000000000" => ctrl_reg          (byte_index*8 to byte_index*8+7) <= data_in;  
				  when "00000000001100" => CST_manage        (byte_index*8 to byte_index*8+7) <= data_in;
				  when "00000000001101" => mthd_manage       (byte_index*8 to byte_index*8+7) <= data_in; 
				   
				  --when "00000000011100" => parser2ER_LUT     (byte_index*8 to byte_index*8+7) <= data_in; 
				  when "00000000100001" => current_heap_ptr_ext((3-byte_index)*8+7 downto (3-byte_index)*8) <= data_in;   
				  when "00000000011101" => xcptn_en          (byte_index*8 to byte_index*8+7) <= data_in;   
				  when "00000010000110" => cache_flush_en     (byte_index*8 to byte_index*8+7) <= data_in; --add by Jeff , 2013.7.11
                  when "00000000100000" => debug_nb_SW       (byte_index*8 to byte_index*8+7) <= data_in; 
				  
                  when "00000010000000" => debug_flag        (byte_index*8 to byte_index*8+7) <= data_in;
                  when "00000010000001" => debug_addr        (byte_index*8 to byte_index*8+7) <= data_in;
                     
        			when others	=> null;
        		end case;
			else
				--  ctrl_reg(0) ctrl_reg(8) ctrl_reg(16) ctrl_reg(24) may be reset
				-- not a good way
				ctrl_reg(byte_index*8) <= the_core_act;
			end if;
         -- if (clear_act = '1') then -- modified by T.H.Wu , 2013.9.9 , for multi-core execution
         --if (the_core_act = '0') then -- transferred from soj.vhd
         --     ctrl_reg(byte_index*8) <= '0';
         --end if;
        end if;
      end process BYTE_RAM_PROC;

    end generate BYTE_BRAM_GEN;

  end generate BRAM_GEN;

  process(Bus2IP_Clk) is begin
	if(rising_edge (Bus2IP_Clk))then
		if(Bus2IP_Reset = '1') then
			ext_wr_heap_ptr <= '0';
		else
			
			if(mem_address = "00000000100001" and we = '1') then
				ext_wr_heap_ptr <= '1';
			else
				ext_wr_heap_ptr <= '0';
			end if; 
		end if;
	end if;
  end process;
  
  -- local link
  IP2Bus_MstWr_src_dsc_n <= '1';
  IP2Bus_MstRd_dst_dsc_n <= '1';
  
  IP2Bus_MstWr_eof_n <= IP2Bus_MstWr_eof_n_reg;
  IP2Bus_MstWr_sof_n <= IP2Bus_MstWr_sof_n_reg;
  IP2Bus_MstWr_src_rdy_n <= IP2Bus_MstWr_src_rdy_n_reg;
  IP2Bus_MstRd_dst_rdy_n <= IP2Bus_MstRd_dst_rdy_n_reg;
  
  process(Bus2IP_Clk) is  begin
	if(rising_edge (Bus2IP_Clk))then
	if(Bus2IP_Reset = '1') then
		IP2Bus_MstWr_eof_n_reg <= '1';
		IP2Bus_MstWr_sof_n_reg <= '1';
		IP2Bus_MstWr_src_rdy_n_reg <= '1';
		IP2Bus_MstRd_dst_rdy_n_reg <= '1';
		Bus2IP_MstRd_src_rdy_n_reg <= '1';
		Bus2IP_Mst_CmdAck_reg <= '0';
		Cmem_writing <= '0';
	else
		if(Cmem_read = '1' or mst_rd_req = '1') then
			IP2Bus_MstRd_dst_rdy_n_reg <= '0';
		elsif(Bus2IP_Mst_Cmplt = '1') then
			IP2Bus_MstRd_dst_rdy_n_reg <= '1';
		end if;
		
		if(Cmem_writing = '1') then
			IP2Bus_MstWr_sof_n_reg <= IP2Bus_MstWr_sof_nC;
			IP2Bus_MstWr_eof_n_reg <= IP2Bus_MstWr_eof_nC;
			IP2Bus_MstWr_src_rdy_n_reg <= IP2Bus_MstWr_src_rdy_nC;
		elsif(mst_wr_req = '1') then
			IP2Bus_MstWr_eof_n_reg <= '0';
			IP2Bus_MstWr_sof_n_reg <= '0';
			IP2Bus_MstWr_src_rdy_n_reg <= '0';
		elsif(Bus2IP_Mst_Cmplt = '1') then
			IP2Bus_MstWr_eof_n_reg <= '1';
			IP2Bus_MstWr_sof_n_reg <= '1';
			IP2Bus_MstWr_src_rdy_n_reg <= '1';
		end if;
		-- add by T.H. Wu , 2013.6.20
		Bus2IP_MstRd_src_rdy_n_reg <= Bus2IP_MstRd_src_rdy_n;
		Bus2IP_Mst_CmdAck_reg <= Bus2IP_Mst_CmdAck;
		 -- added by jeff
		if(Cmem_write = '1') then
			Cmem_writing <= '1';
		elsif(Bus2IP_Mst_Cmplt = '1') then
			Cmem_writing <= '0';
		end if;
	end if;
	end if;
	
  end process;
  
  -- implement Block RAM read mux
  MEM_IP2BUS_DATA_PROC : process( mem_data_out, mem_select, Bus2IP_Addr, xrt_load_data, heap_data_out ) is
  begin 
    case mem_select is
       when "1" => if (Bus2IP_Addr(0 to 16) = (X"880"&"0"&core_id&"1"&"1")) then
                        mem_ip2bus_data <= xrt_load_data;
                    elsif (Bus2IP_Addr(0 to 17) = (X"880"&"0"&core_id&"1"&"01")) then
                        mem_ip2bus_data <= clsi_load_data;
                    --elsif (Bus2IP_Addr(0 to 19) = (X"8801"&"1100")) then -- hidden by T.H.Wu , 2013.8.2
                    --    mem_ip2bus_data <= heap_data_out; 
                    else
                        mem_ip2bus_data <= mem_data_out(0);
                    end if;
        when others => mem_ip2bus_data <= (others => '0');
    end case;

  end process MEM_IP2BUS_DATA_PROC;

  ------------------------------------------
  -- drive IP to Bus signals
  ------------------------------------------
  IP2Bus_Data  <= mem_ip2bus_data when mem_read_ack = '1' else
                  (others => '0');

  IP2Bus_WrAck <= mem_write_ack;
  IP2Bus_RdAck <= mem_read_ack;
  IP2Bus_Error <= '0';

  ------------------------------------------
  -- Time tick
  ------------------------------------------
  label_enable_jaip_profiler_1 : if ENABLE_JAIP_PROFILER = 1 generate
  begin
  process(Bus2IP_Clk) is begin
	if(rising_edge (Bus2IP_Clk))then
	if(Bus2IP_Reset = '1') then
		prof_heap_access_on <= '0';
		prof_onChipHeap_access_on <= '0';
	else
		prof_heap_access_on <= prof_heap_access_on_nxt;
		prof_onChipHeap_access_on <= prof_onChipHeap_access_on_nxt;
	end if;
	end if;
  end process;
  
  
  process(prof_heap_access_on, jpl_mst_wr_req, jpl_mst_rd_req, AC_IP2Bus_MstWr_Req, AC_IP2Bus_MstRd_Req, jpl_mst_address, cache_cmplt, prof_onChipHeap_access_on, heap_load_req, heap_store_req, Bus2IP_Mst_Cmplt) is
  begin
	case prof_heap_access_on is
		when '0' =>
			if((jpl_mst_wr_req = '1' or jpl_mst_rd_req = '1' or AC_IP2Bus_MstWr_Req = '1' or AC_IP2Bus_MstRd_Req = '1') and jpl_mst_address(0 to 6) = "0101110") then	-- on-chip heap base addr: 0x8801C000	 
				prof_heap_access_on_nxt  <= '1';																 			
			else
				prof_heap_access_on_nxt <= '0';
			end if;
		when '1' =>
			if(cache_cmplt = '1') then
				prof_heap_access_on_nxt  <= '0';																 			
			else
				prof_heap_access_on_nxt  <= '1';																 			
			end if;
		when others =>
			prof_heap_access_on_nxt  <= '0';																 			
	end case;
	
	case prof_onChipHeap_access_on is	
		when '0' =>
			if((heap_load_req = '1' or heap_store_req = '1') and jpl_mst_address(0 to 17) = x"8801" & "11") then
				prof_onChipHeap_access_on_nxt <= '1';
			else
				prof_onChipHeap_access_on_nxt <= '0';
			end if;
		when '1' =>
			if(Bus2IP_Mst_Cmplt = '1') then
				prof_onChipHeap_access_on_nxt <= '0';
			else
				prof_onChipHeap_access_on_nxt <= '1';
			end if;
		when others =>
			prof_onChipHeap_access_on_nxt <= '0';
	end case;
  end process;
  end generate;
  
	
  process( Bus2IP_Clk ) is
  begin
	if(rising_edge (Bus2IP_Clk))then
    if (Bus2IP_Reset = '1') then
        Total_time <= (others => '0') ;
        rupt_time <= (others => '0') ;
        HW_time <= (others => '0') ;
        time_with_some_interrupt <= (others => '0') ;
		DSRU_time <= (others => '0');
		heap_access_time <= (others => '0');
		prof_on <= '0';
    else
		-- modified by T.H.Wu , 2013.9.8 , useless now
        if( ctrl_reg(0) = '1' ) then
            Total_time <= Total_time + '1' ;
           
            if(interrupt_on = '0' or (interrupt_on = '1' and interrupt_func /= x"070000") )then
                time_with_some_interrupt <= time_with_some_interrupt + '1' ;
            end if;
           
			-- rupt_time, HW_time and DSRU_time are exclusive of each other
            -- modified by T.H.Wu , 2013.8.1  
			--if(prof_on = '1') then 
				if(prof_heap_access_on_nxt = '1' or prof_onChipHeap_access_on_nxt = '1') then
					heap_access_time <= heap_access_time + 1;
				else
					if(interrupt_on = '1') then
						rupt_time <= rupt_time + 1;
					elsif(prof_DSRU_on = '1') then
						if(AC_ACT = '1' or IO_ACT = '1' or ACEn = '1' or IOEn = '1') then
							HW_time <= HW_time + 1;
						else
							DSRU_time <= DSRU_time + 1;
						end if;
					else
						HW_time <= HW_time + 1;
					end if;
				end if;	
			--end if;
        end if;
		
		if(POCmplt = '1') then
			prof_on <= '1';
		elsif(POFCmplt = '1') then
			prof_on <= '0';
		end if;
    end if;
    end if;
  end process;
  
	
        label_enable_jaip_profiler_0 : if ENABLE_JAIP_PROFILER = 1 generate
        begin
-- method time profiler
	MP : mmes_profiler 
	port map(
		Clk				=> Bus2IP_Clk,
		Rst				=> Bus2IP_Reset,
			
		HW_time			=> HW_time,
		Intrpt_time		=> rupt_time,
		DSRU_time		=> DSRU_time,
		heap_access_time		=> heap_access_time,
		invoke_flag		=> prof_invoke_flag_in,
		return_flag		=> prof_return_flag_in,
		method_ID		=> method_ID,
		
		profile_sel		=> profile_sel,
		method_profile	=> method_profile
	);
	prof_invoke_flag_in <= prof_invoke_flag and prof_on;
	prof_return_flag_in <= prof_return_flag and prof_on;
	method_ID <= "0000000" & prof_DR2MA_mgt_mthd_id( 8 downto 0) when (prof_invoke_flag = '1') else
				 debug_addr(11 to 26); 
	profile_sel <= debug_addr(27 to 29); 
	
-- bytecode time profiler
	bp : bytecode_profiler
		port map(
			Clk				=> Bus2IP_Clk,
			Rst				=> Bus2IP_Reset,
			
			HW_time			=> HW_time,
			Intrpt_time		=> rupt_time,
			DSRU_time		=> DSRU_time,
			heap_access_time => heap_access_time,
			
			bytecode_1		=> prof_bytecode_1,
			bytecode_2		=> prof_bytecode_2,
			issued_1		=> issued_1,
			issued_2		=> issued_2,
			
			profile_sel		=> debug_addr(27 to 29),
			bytecode_profile => bytecode_profile
            
			--debug_PT_A_WE		=> debug_PT_A_WE,
			--debug_buf_A_valid	=> debug_buf_A_valid,
			--debug_bytecode_profile_A_out => debug_bytecode_profile_A_out
		);
	issued_1 <= prof_simple_issued_A_D and prof_on;
	issued_2 <= prof_simple_issued_B_D and prof_on;
	prof_bytecode_1 <= prof_issued_bytecodes_D(15 downto 8) when prof_simple_issued_A_D = '1' else
					   debug_addr(19 to 26);
	prof_bytecode_2 <= prof_issued_bytecodes_D(7 downto 0) when prof_simple_issued_B_D = '1' else
					   debug_addr(19 to 26);
                       
         end generate ;
		 
  -- process(Bus2IP_Clk) is
  -- begin
	-- if(Bus2IP_Reset = '1') then
		-- debug_TOS_A <= (others => '0');
		-- debug_TOS_B <= (others => '0');
		-- debug_TOS_C <= (others => '0');
		-- debug_CTRL_state <= (others => '0');
		-- debug_current_heap_ptr<= (others => '0');
		-- debug_AllocSize <=(others => '0');
		-- debug_jpl_mst_address <= (others => '0');
		-- debug_fet_instrs_pkg<= (others => '0');
		-- debug_GC_state<= (others => '0');
		-- debug_GC_Mstate <= (others => '0');
		-- debug_GC_ref<= (others => '0');
		-- debug_GC_outC<= (others => '0');		
		-- debug_GC_Rcount<= (others => '0');
		-- debug_GC_M_ref<= (others => '0');
		-- debug_M_addr<= (others => '0');
		-- debug_Mthd_Addr<= (others => '0');
		-- debug_cur_GC_useaddr<= (others => '0');
		
		-- debug_GC_fMthd_Enter<='0';
		-- debug_GC_Mthd_Enter <='0';
		-- debug_GC_Mthd_Exit <='0';
		-- debug_Alloc_en <='0';
		-- debug_ext_wr_heap_ptr <='0';
		-- debug_IP2Bus_MstRd_Req<='0';
		-- debug_IP2Bus_MstWr_Req<='0';
		-- debug_stall_all<='0';
		-- debug_rrayAlloc_en<='0';
		-- debug_areturn<='0';
		-- debug_normal_last_sear_flag<='0';
		
	-- elsif(rising_edge(Bus2IP_Clk)) then
		-- debug_TOS_A <= A;
		-- debug_TOS_B <= B;
		-- debug_TOS_C <= C;
		-- debug_CTRL_state <=debug_cs_soj(5 downto 0) ;
		-- debug_Alloc_en <=Alloc_en;
		-- debug_current_heap_ptr<=GC_Current_Heap_Addr_u;
		-- debug_ext_wr_heap_ptr<=ext_wr_heap_ptr;
		-- debug_AllocSize <=AllocSize;
		-- debug_IP2Bus_MstRd_Req <= IP2Bus_MstRd_Req_tmp;
		-- debug_IP2Bus_MstWr_Req <= IP2Bus_MstWr_Req_tmp;
		-- debug_jpl_mst_address <= jpl_mst_address;
		-- debug_fet_instrs_pkg<=debug_cs_soj(21 downto 6);
		-- debug_stall_all <=debug_cs_soj(22);

		
		-- GC
		-- debug_GC_Mthd_Enter <=GC_Mthd_Enter_u;
		-- debug_GC_Mthd_Exit  <=GC_Mthd_Exit_u;
		-- debug_GC_fMthd_Enter <=GC_Mthd_Enter_f_u;
		-- debug_GC_state<=debug_GC_port(4 downto 0);
		-- debug_GC_ref<=debug_GC_port(26 downto 5);
		-- debug_GC_outC<=debug_GC_port(31 downto 27);
		-- debug_GC_Mstate<=debug_GC_port(35 downto 32);
		-- debug_GC_Rcount<=debug_GC_port(42 downto 36);
		-- debug_GC_M_ref<=debug_GC_port(64 downto 43);
		-- debug_M_addr<=debug_GC_port(75 downto 65);
        -- debug_rrayAlloc_en<= GC_arrayAlloc_en_u;
        -- debug_areturn<=   GC_areturn_u;
		-- debug_Mthd_Addr<= debug_GC_port(86 downto 76);
		-- debug_cur_GC_useaddr<= debug_GC_port(97 downto 87);	
		-- debug_normal_last_sear_flag<=debug_GC_port(98);
		
		
	-- end if;
  -- end process;			 
                       
        
end IMP;
