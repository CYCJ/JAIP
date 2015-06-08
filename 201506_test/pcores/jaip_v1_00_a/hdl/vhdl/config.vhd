------------------------------------------------------------------------------
-- Filename	:	config.vhd
-- Version	:	1.06
-- Author	:	Hou-Jen Ko
-- Date		:	July 2007
-- VHDL Standard:	VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.							**		
-- ** Multimedia Embedded System Lab, NCTU.								**  
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------
-- Filename	:	config.vhd
-- Version	:	2.02
-- Author	:	Kuan-Nian Su
-- Date		:	Apr 2009
-- VHDL Standard:	VHDL'93
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Filename	:	config.vhd
-- Version	:	3.00
-- Author	:	Han-Wen Kuo
-- Date		:	Jan 2011
-- VHDL Standard:	VHDL'93
-- Describe	:	New Architecture
------------------------------------------------------------------------------

library IEEE;
use IEEE.Std_Logic_1164.all;

package config is

	type XCPTN_HDLR_SM_TYPE is
	(
	IDLE, GET_THROWN_EID, COMPARE_EID, COMPARE_START, COMPARE_END,
	UPDATE_JPC_TOSBC, UPDATE_LV0, UPDATE_LV1, CHECK_ER_CNT, LOAD_LV_CNT , GET_RETURN_FRM, UPDATE_RTRN_REGS,
	GET_ER_CNT, GET_ER_CNT_DELAY, CHECK_CST_MA,New_OBJ,POP1,COMPARE_PARENT_EID,GET_PARENT_EID_STATE
	); 

	type DynamicResolution_SM_TYPE is
	(
	Upper_addr, Lower_addr, 
	Normal, Get_LV1_XRT_ref, Offset_access, IllegalOffset,Wait4GC ,HeapAlloc, ClinitRetFrm1, ClinitRetFrm2, ClinitRetFrm3,
	Enable_MA_management, CLassLoading, Method_entry, Method_flag, arg_size, 
	max_stack, max_local, Method_exit, Field_store, Field_load, Field_exit,
	
	Get_ArgSize, Get_ObjClsID, invoke_objref_ListClsID, invoke_objref_next,Save_objref_fm_heap,
	NewThread1, NewThread2, -- by fox
	Wait_monEnter_succeed, -- added by T.H.Wu, 2014.1.24, for invoking sync method.
	
	Native_start,
	Native_StackAdjusting1, Native_StackAdjusting2, Native_StackAdjusting3,
	Native_ArgExporting_Reg, Native_ArgExporting_DDR,
	Native_interrupt, Native_HW, Native_SpAdjusting,
	Native_StackAdjustingReturn1, Native_StackAdjustingReturn2,
	Native_exit	
	);
	
	type CST_Controller_SM_TYPE is
	(
	Wait_enable, Get_Offset, Check_Offset, Offset_Ready, CST_Loading, 
	Wait_Ack, WAIT_RD_VALID, WR_2_CSTCB, WAIT_MST_RD_CMPLT, Update, Wait_monExit_cmplt
		-- added by T.H.Wu, 2014.1.24, for invoking sync method.
	);  
	
	type Multiarray_SM_TYPE is (Normal, PopSize, PushSize, PushIndex, NewArray, RefStore);  
		-- added by CYC, 2014.12.23, for Multianewarray.
	
	type MA_management_SM_TYPE is
	(
	Wait_enable, Get_Offset, Check_Offset, Offset_Ready, Mthd_Loading,
	Wait_Ack, WAIT_RD_VALID , WR_2_MACB, WAIT_MST_RD_CMPLT, Update, Wait_monExit_cmplt
		-- added by T.H.Wu, 2014.1.24, for invoking sync method.
	); 
	
	
	type Thread_management_SM_TYPE is
	(
	Idle, Backup_Previous_Stack, 
	Backup_previous_thread_TCBinfo, Prepare_next_thread_TCB_info, -- added by T.H.Wu , 2013.7.18
	Check_Timeout, ContextSwitch, AllThreadsWait, Prepare_Next_thread
	);
								
	type Decode2Execute_ControlSignal_Type is
	record
		-- regABC & ALU
		A,B				: std_logic_vector(2 downto 0);
		C					: std_logic_vector(1 downto 0);
		Aen, Ben, Cen	: std_logic;
		ALUopd1_sel		: std_logic_vector(1 downto 0);
		ALUopd2_sel		: std_logic_vector(1 downto 0);
		ALU				: std_logic_vector(3 downto 0);
		-- RAMs & reg0123
		W1_sel  , W2_sel	: std_logic;
		SD1_sel				: std_logic_vector(1 downto 0);
		SD2_sel				: std_logic_vector(1 downto 0);
		W1_en   , W2_en	: std_logic;
		LD1_sel , LD2_sel   : std_logic;
		sp_offset		: std_logic_vector(2 downto 0);
		branch			: std_logic_vector(3 downto 0);
		stvp1, stvp2		: std_logic;
		stsp1, stsp2		: std_logic;
	end record;
	
	type Decode2Execute_MemRead_Type is
	record
		R1_RegFlag		: std_logic;
		R2_RegFlag		: std_logic;
		R1_en, R2_en		: std_logic;
		load1_addr		: std_logic_vector(9 downto 0);
		load2_addr		: std_logic_vector(9 downto 0);
		R1_sel, R2_sel	: std_logic;
	end record;
	
	type write_ABC_type is
	record
		data				: std_logic_vector(31 downto 0);
		Aen				: std_logic;
		Ben				: std_logic;
		Cen				: std_logic;
	end record;

	TYPE ArrayAllocType is (normal, wrIDReq, wrID, wrLenReq, wrLen,wrArr2Hp);
	
	-- constants for A_sel
	constant A_ALU		: std_logic_vector(2 downto 0) := "000";
	constant A_C		: std_logic_vector(2 downto 0) := "001";
	constant A_LD1		: std_logic_vector(2 downto 0) := "010";
	constant A_LD2		: std_logic_vector(2 downto 0) := "011";
	constant A_B		: std_logic_vector(2 downto 0) := "100";
	constant A_lrtn		: std_logic_vector(2 downto 0) := "101";
	constant A_field	: std_logic_vector(2 downto 0) := "110";
	constant A_dim		: std_logic_vector(2 downto 0) := "111";

	-- constants for B_sel
	constant B_ALU		: std_logic_vector(2 downto 0) := "000";
	constant B_A			: std_logic_vector(2 downto 0) := "001";
	constant B_C			: std_logic_vector(2 downto 0) := "010";
	constant B_LD1		: std_logic_vector(2 downto 0) := "011";
	constant B_lrtn		: std_logic_vector(2 downto 0) := "100";
	
	
	-- constants for C_sel
	constant C_A			: std_logic_vector(1 downto 0) := "00";
	constant C_B			: std_logic_vector(1 downto 0) := "01";
	constant C_LD1		: std_logic_vector(1 downto 0) := "10";
	constant C_LD2		: std_logic_vector(1 downto 0) := "11";
	
	-- constants for ALUopd1_sel
	constant ALU1_A		: std_logic_vector(1 downto 0) := "00";
	constant ALU1_B		: std_logic_vector(1 downto 0) := "01";
	constant ALU1_LD1	: std_logic_vector(1 downto 0) := "10";

	-- constants for ALUopd2_sel
	constant ALU2_A		: std_logic_vector(1 downto 0) := "00";
	constant ALU2_B		: std_logic_vector(1 downto 0) := "01";
	constant ALU2_C		: std_logic_vector(1 downto 0) := "10";
	
	-- constants for ALU_sel
	constant ALU_nop		: std_logic_vector(3 downto 0) := X"0";
	constant ALU_or		: std_logic_vector(3 downto 0) := X"1";
	constant ALU_xor		: std_logic_vector(3 downto 0) := X"2";
	constant ALU_and		: std_logic_vector(3 downto 0) := X"3";
	constant ALU_add		: std_logic_vector(3 downto 0) := X"4";
	constant ALU_cmp		: std_logic_vector(3 downto 0) := X"5";
	constant ALU_sub		: std_logic_vector(3 downto 0) := X"7";
	constant ALU_sub_r	: std_logic_vector(3 downto 0) := X"8";
	constant ALU_mul		: std_logic_vector(3 downto 0) := X"9";
	constant ALU_div		: std_logic_vector(3 downto 0) := X"A";
	constant ALU_rem		: std_logic_vector(3 downto 0) := X"B";
	constant ALU_ushr	: std_logic_vector(3 downto 0) := X"C";  
	constant ALU_shl		: std_logic_vector(3 downto 0) := X"D";
	constant ALU_shr		: std_logic_vector(3 downto 0) := X"E";
	
	
	-- constants for ALU_sel
	constant I2B		: std_logic_vector(3 downto 0) := X"0";
	constant I2C		: std_logic_vector(3 downto 0) := X"1";
	constant I2S		: std_logic_vector(3 downto 0) := X"2";
	constant I2F		: std_logic_vector(3 downto 0) := X"3";
	constant I2L		: std_logic_vector(3 downto 0) := X"4";
	constant I2D		: std_logic_vector(3 downto 0) := X"5";
	constant F2D		: std_logic_vector(3 downto 0) := X"6";
	constant F2I		: std_logic_vector(3 downto 0) := X"7";
	constant F2L		: std_logic_vector(3 downto 0) := X"8";
	constant D2I		: std_logic_vector(3 downto 0) := X"9";
	constant D2F		: std_logic_vector(3 downto 0) := X"A";  
	constant D2L		: std_logic_vector(3 downto 0) := X"B";
	constant L2D		: std_logic_vector(3 downto 0) := X"C";
	constant L2F		: std_logic_vector(3 downto 0) := X"D";
	constant L2I		: std_logic_vector(3 downto 0) := X"E";
	
	
	-- constants for SD1_sel
	constant SD1_A		: std_logic_vector(1 downto 0) := "00";
	constant SD1_B		: std_logic_vector(1 downto 0) := "01";
	constant SD1_C		: std_logic_vector(1 downto 0) := "10"; 
	constant SD1_ALU		: std_logic_vector(1 downto 0) := "11"; 
	
	-- constants for SD2_sel
	constant SD2_A		: std_logic_vector(1 downto 0) := "00";
	constant SD2_B		: std_logic_vector(1 downto 0) := "01";
	constant SD2_LD1		: std_logic_vector(1 downto 0) := "10";
	constant SD2_ALU		: std_logic_vector(1 downto 0) := "11"; 

	-- constants for R1_sel
	constant R1_load1_addr  : std_logic := '0';
	constant R1_sp		: std_logic := '1'; 

	-- constants for R2_sel
	constant R2_load2_addr  : std_logic := '0';
	constant R2_sp		: std_logic := '1';

	-- constants for W1_sel
	constant W1_store1_addr : std_logic := '0';
	constant W1_sp		: std_logic := '1'; 

	-- constants for W2_sel
	constant W2_store2_addr : std_logic := '0';
	constant W2_sp		: std_logic := '1';
	
	-- constants for LD1_sel
	constant LD1_RD		: std_logic := '0';
	constant LD1_special	: std_logic := '1';
	
	-- constants for LD2_sel
	constant LD2_RD		: std_logic := '0';
	constant LD2_special	: std_logic := '1';

	constant enable		: std_logic := '1';
	constant disable		: std_logic := '0';	
	
	-- constants for thread state
	constant TH_STATE_IDLE  : std_logic_vector(1 downto 0) := "00";  
	constant TH_STATE_WAIT  : std_logic_vector(1 downto 0) := "01";  
	constant TH_STATE_READY  : std_logic_vector(1 downto 0):= "10";  
	
	-- constants for multicore coordinator
	constant ALL_CORES	: std_logic_vector(2 downto 0) := "101";
	constant RISC_ID		: std_logic_vector(2 downto 0) := "100";
	constant CORE0_ID		: std_logic_vector(2 downto 0) := "000";
	constant CORE1_ID		: std_logic_vector(2 downto 0) := "001";
	constant CORE2_ID		: std_logic_vector(2 downto 0) := "010";
	constant CORE3_ID		: std_logic_vector(2 downto 0) := "011";

end config;
