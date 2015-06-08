------------------------------------------------------------------------------
-- Filename	:	DynamicResolution_management.vhd
-- Version	:	3.00
-- Author	:	Han-Wen Kuo
-- Date		:	Feb 2011
-- VHDL Standard:	VHDL'93
-- Describe	:	New Architecture
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2011. All rights reserved.								**		
-- ** Multimedia Embedded System Lab, NCTU.									**  
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan					**
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.config.all;

entity DynamicResolution_management is
	generic(
		ENABLE_JAIP_PROFILER	: integer := 0;
		RAMB_S18_AWIDTH			: integer := 10
	); 
	port(
		-- ctrl signal
		Rst						: in  std_logic;
		clk						: in  std_logic;
		--GC
		GC_Cmplt_in				: in  std_logic;	
		-- (slave) write from external part(power PC) to DynamicResolution_management
		DR_reg_en				: in  std_logic;
		ex2java_data			: in  std_logic_vector(31 downto 0);
		
		-- (master) external memory access
		external_access_cmplt	: in  std_logic;
		external_load_req		: in  std_logic;
		external_store_req		: in  std_logic;
		external_load_data		: in  std_logic_vector(31 downto 0);
		DynamicResolution		: out std_logic_vector(31 downto 0);
		DR_addr					: out std_logic_vector(31 downto 0);
		DynamicResolution_load_req  : out std_logic;
		DynamicResolution_store_req : out std_logic;
		
		-- class info table
		clsiInternLoadReq		: out std_logic;
		clsiInternStoreReq		: out std_logic;
		clsiAddr				: out std_logic_vector(11 downto 0);
		clsInfo_in				: in std_logic_vector(31 downto 0);
		clsiCmplt				: in std_logic;
		clsiInternWrData		: out std_logic_vector(31 downto 0);
		
		-- clinit
		clinitClsID				: out std_logic_vector(15 downto 0);
		clinitMthdID			: out std_logic_vector(15 downto 0);
		clinitEN				: out std_logic;
		
		-- method area
		CST_entry				: in  std_logic_vector(31 downto 0);
		operand0				: in  std_logic_vector( 7 downto 0);
		operand1				: in  std_logic_vector( 7 downto 0);
		search_ptr_out			: out std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
		
		-- interrupt 
		interrupt_cmplt			: in  std_logic;
		interrupt_req_DR		: out std_logic;
		interrupt_func_DR		: out std_logic_vector(23 downto 0);
		
		-- invoke
		invoke_objref_from_exe_stage	: in  std_logic_vector(31 downto 0); 
		ArgSize					: out std_logic_vector( 4 downto 0);
		-- thread mgt -- by fox
		
		invoke_objref_reg_2_TH_mgt	: out std_logic_vector(31 downto 0);
		new_thread_execute			: in  std_logic;
		TH_mgt_ready_thread_cls_id_mthd_id	: in  std_logic_vector(31 downto 0); 
		-- added by T.H. Wu , for invoking sync method use. , 2014.1.22 
		invoke_sync_mthd_flag		: out	std_logic;
		sync_mthd_invoke_rtn_cmplt	: in	std_logic;
			
		-- flag in
		ClsLoading_stall		: in  std_logic;		
		invoke_flag				: in  std_logic;
		static_flag				: in  std_logic;
		field_wr				: in  std_logic;
		field_flag				: in  std_logic;
		new_obj_flag			: in  std_logic;
		ldc_flag				: in  std_logic;
		ldc_w_flag				: in  std_logic;
		ldc2_w_flag				: in  std_logic;
		getStatic				: in  std_logic;
		
		DynamicResolution_en	: in  std_logic;
		CTRL_state_out			: out DynamicResolution_SM_TYPE;
		
		-- Native
		Native_ArgCnt			: out std_logic_vector( 4 downto 0);
		Native_CycCnt			: out std_logic_vector( 1 downto 0);
		native_flag				: out std_logic;
		pop1_flag				: out std_logic;
		pop2_flag				: out std_logic;
		set_jcodePC				: out std_logic;
		native_HW_en			: out std_logic;
		native_HW_ID			: out std_logic_vector(4 downto 0);
		native_HW_cmplt			: in std_logic;
		
		-- prof
		prof_native_mthd_id		: out std_logic_vector(15 downto 0);
		
		--field flag
		long_field_2nd_flag		: in std_logic;
		long_field_flag			: out std_logic
	);
end entity DynamicResolution_management;

architecture rtl of DynamicResolution_management is

	signal CTRL_state			: DynamicResolution_SM_TYPE;
	signal CTRL_state_nxt		: DynamicResolution_SM_TYPE;
	signal search_ptr			: std_logic_vector(15 downto 0);
	signal search_ptr_reg		: std_logic_vector(15 downto 0);
	signal DynamicResolution_reg: std_logic_vector(31 downto 0);
	signal XRT_ref_reg			: std_logic_vector(31 downto 0);
	signal IllegalOffset_flag	: std_logic;
	
	signal ArgSize_reg			: std_logic_vector(4 downto 0);
	signal invoke_objref_reg	: std_logic_vector(31 downto 0);
	signal invoke_objref_hit	: std_logic;
	
	signal native_flag_reg		: std_logic;
	signal Native_CycCnt_reg	: std_logic_vector( 1 downto 0);
	signal Native_ArgCnt_reg	: std_logic_vector( 4 downto 0);
	signal Native_ReturnNum		: std_logic_vector( 1 downto 0);
	signal ArgCnt_reg_S			: std_logic;
	signal native_HW_flag		: std_logic;
	signal native_HW_flag_reg	: std_logic;
	signal native_HW_act		: std_logic;
	
	signal first_objref_clsid	: std_logic_vector(16 downto 0);
	signal first_mthd_info_addr	: std_logic_vector(14 downto 0);
	
	signal XRT_ref				: std_logic_vector(31 downto 0);
	signal clsiID				: std_logic_vector(10 downto 0);
	signal clsiID_reg			: std_logic_vector(10 downto 0);
	signal clsiLoadReq_tmp		: std_logic;
	signal isClinit				: std_logic;
	signal clinitEN_tmp			: std_logic;
	signal clinitEN_reg			: std_logic;
	signal clsInfo				: std_logic_vector(31 downto 0);
	signal clsInfo_reg			: std_logic_vector(31 downto 0);
	signal clsiInternWrData_reg	: std_logic_vector(31 downto 0); 
	-- added by T.H. Wu , for invoking sync method use. , 2014.1.22
	signal invoke_sync_mthd_flag_reg: std_logic;
	
begin
	
	CTRL_state_out	<= CTRL_state;
	search_ptr_out	<= search_ptr(14 downto 0);
	DynamicResolution <= DynamicResolution_reg;
	DR_addr		<= invoke_objref_reg when CTRL_state = Get_ObjClsID else
						XRT_ref_reg;
						
	clsiAddr <= clsiID & "0"	when(CTRL_state = Get_LV1_XRT_ref) else	
				clsiID_reg  & "0";
	clsiID <= CST_entry(10 downto 0) when (new_obj_flag = '1') else	-- cls ID of the new obj
			CST_entry(26 downto 16) when (static_flag = '1') else	-- cls ID of the field
			(others => '0'); 
	clsiLoadReq_tmp <=	'1' when(CTRL_state = Get_LV1_XRT_ref) else
						'0';
	clsiInternLoadReq <= clsiLoadReq_tmp;
	clinitMthdID <= clsInfo(15 downto 0);
	clinitClsID  <= "00000" & clsiID_reg;
		-- is clinit ... can it be optimized ??  , 2013.7.5
	isClinit <= clsInfo(30);
	clinitEN <= clinitEN_tmp when(CTRL_state = Offset_access and external_access_cmplt = '1') else
				clinitEN_tmp when(CTRL_state = IllegalOffset and interrupt_cmplt = '1') else
				clinitEN_reg;
	clsInfo <=	clsInfo_in when(clsiCmplt = '1') else
				clsInfo_reg;
	clinitEN_tmp <= '1' when (isClinit = '0' and getStatic = '1' and clsInfo(15 downto 0) /= x"0000") else '0';
	clsiInternWrData <= clsiInternWrData_reg;
	clsiInternStoreReq <= '1' when (CTRL_state = ClinitRetFrm1) else   '0';
	
	XRT_ref <=  x"8801" & "1" & (CST_entry(14 downto 0) + x"4") when(static_flag = '1' and invoke_flag = '1') else -- invokestatic
				CST_entry when (ldc_flag = '1' or ldc_w_flag = '1' or ldc2_w_flag = '1') else			-- ldc data
				x"8801" & "1" & CST_entry(14 downto 0);		-- field & instance methods
				
	native_flag	<= '1' when CTRL_state = Native_start else '0';
	--  Native_ArgCnt is used to fetch object reference on stack BRAM when invoking a native method.
	Native_ArgCnt	<= Native_ArgCnt_reg;
	Native_CycCnt	<= Native_CycCnt_reg;
	-- arg size is used for object reference when invoking a normal method ,
		-- recall that argSize-1 is indicated the object reference of invoke method.
	ArgSize		<= ArgSize_reg ;
	
	ArgCnt_reg_S <= ArgSize_reg(4) or ArgSize_reg(3) or ArgSize_reg(2);
	
	pop1_flag		<=	'1' when CTRL_state = Native_StackAdjusting1 or
								CTRL_state = Native_StackAdjusting2 or
								CTRL_state = Native_StackAdjustingReturn1 or
								CTRL_state = Native_StackAdjustingReturn2 else
						'0';
						
	pop2_flag		<=	'1' when (CTRL_state = Native_StackAdjusting1 and (ArgCnt_reg_S or Native_ArgCnt_reg(1)) = '1') or 
								(CTRL_state = Native_StackAdjustingReturn1 and Native_ReturnNum(1) = '0') else
						'0';
						
	set_jcodePC	<=	'1' when (CTRL_state = Native_StackAdjustingReturn1 and (Native_ReturnNum(0) or Native_ReturnNum(1)) = '1') or 
							CTRL_state = Native_StackAdjustingReturn2 else
					'0';
							
	IllegalOffset_flag <= '1' when	CTRL_state = Offset_access and
							(( new_obj_flag = '1' and clsInfo(31) = '0' ) or (new_obj_flag = '0' and external_load_data(15 downto 0) = x"0000"))
						else '0' ;
							
	-- [2][2][2][2] = [native ID x"FF"][arg num][return value num][ISR ID]
	native_flag_reg	<= '1' when (CTRL_state = Offset_access and external_load_data(31) = '1')or
								(CTRL_state = IllegalOffset and DynamicResolution_reg(31) = '1') else
						'0' ;
						
	native_HW_flag <= '1' when (CTRL_state = Offset_access and external_load_data(30) = '1')or
							(CTRL_state = IllegalOffset and DynamicResolution_reg(30) = '1') else
					native_HW_flag_reg; 
					
	invoke_objref_hit  <=	'1' when CTRL_state = Get_ObjClsID and  (first_objref_clsid(15 downto 0) = external_load_data(15 downto 0) or first_objref_clsid(16) = '1') else
							'1' when CTRL_state = invoke_objref_ListClsID and  (first_objref_clsid(15 downto 0) = external_load_data(15 downto 0) or external_load_data(31) = '1') else
							'0';

	-- fox , for getting object reference of that new thread while Thread.start() is invoked .
	invoke_objref_reg_2_TH_mgt	<=	invoke_objref_reg;
	invoke_sync_mthd_flag		<=	invoke_sync_mthd_flag_reg;
	
	Field_Flag_CtrlLogic:
	process(clk,Rst,CST_entry) begin
		if(rising_edge(clk)) then
			if(Rst = '1') then
				long_field_flag			<=	'0';
			else
				if (field_flag = '1' and CST_entry(27) = '1' and long_field_2nd_flag = '0') then
					long_field_flag		<=	'1';
				else
					long_field_flag		<=	'0';
				end if;
			end if;
		end if;
	end process;
		
	search_ptr_CtrlLogic :
	process(CTRL_state, DynamicResolution_en, search_ptr_reg,ldc_flag)
	begin
		
		search_ptr <= search_ptr_reg;
		case(CTRL_state)is
			when Normal =>
				if(DynamicResolution_en = '1' ) then
					if(ldc_flag = '1') then
						search_ptr <= (x"00" & operand0) + x"1";
					elsif (ldc2_w_flag = '1') then
						search_ptr <= (operand0 & operand1) + x"2";
					else
						search_ptr <= (operand0 & operand1) + x"1";
					end if; 
				end if;
			when others => 
				search_ptr <= search_ptr_reg;
		end case;
	end process;
	
	DR_reg :
	process(clk) begin
		if(rising_edge(clk)) then
			if(Rst = '1') then
				CTRL_state	<= Normal;
			else
				CTRL_state	<= CTRL_state_nxt;
			end if;
		end if;
	end process;
	
	DynamicResolution_CtrlLogic :
	process(CTRL_state,DynamicResolution_en,invoke_flag,static_flag,new_obj_flag,external_access_cmplt, sync_mthd_invoke_rtn_cmplt,
			IllegalOffset_flag,native_flag_reg,field_wr,interrupt_cmplt,ClsLoading_stall,invoke_objref_hit, new_thread_execute,
			DynamicResolution_reg,ArgCnt_reg_S,Native_ArgCnt_reg,Native_CycCnt_reg,Native_ReturnNum, clsiCmplt, ldc_flag, ldc_w_flag, ldc2_w_flag, native_HW_flag,
					native_HW_cmplt, getStatic, clinitEN_tmp) 
		begin
		CTRL_state_nxt <= CTRL_state;
			case CTRL_state is
				when Normal =>
					if(DynamicResolution_en = '1') then
							CTRL_state_nxt <= Get_LV1_XRT_ref; -- other jcode needed Dynamic Resolution 
					elsif (new_thread_execute='1') then
						CTRL_state_nxt <= Enable_MA_management;
					end if;
								
				when Get_LV1_XRT_ref =>
					if(invoke_flag = '1' and static_flag = '0') then
						CTRL_state_nxt <= Get_ArgSize;
					elsif(ldc_flag = '1' or ldc_w_flag = '1' or ldc2_w_flag = '1') then
						CTRL_state_nxt <= Normal;
					else
						CTRL_state_nxt <= Offset_access;
					end if;
					
				when Offset_access=>
					if(new_obj_flag = '0') then
						if(external_access_cmplt = '1') then
							if(IllegalOffset_flag = '1')then
								CTRL_state_nxt <= IllegalOffset;
							elsif(invoke_flag = '1') then
								if(native_flag_reg = '1')then
									CTRL_state_nxt <= Native_start;
								else
									CTRL_state_nxt <= Enable_MA_management;
								end if;
							elsif(getStatic = '1') then	-- getStatic
								if(clinitEN_tmp = '1') then
									CTRL_state_nxt <= ClinitRetFrm1;
								else
									CTRL_state_nxt <= Field_load;
								end if;
							else
								if(field_wr = '1')then
									CTRL_state_nxt <= Field_store;
								else
									CTRL_state_nxt <= Field_load;
								end if;
							end if;
						else
							CTRL_state_nxt <= Offset_access;
						end if;
					else
						if(clsiCmplt = '1') then
							if(IllegalOffset_flag = '1')then
								CTRL_state_nxt <= IllegalOffset;
							else
								CTRL_state_nxt <= Wait4GC;
							end if;
						else
							CTRL_state_nxt <= Offset_access;
						end if;
					end if;
					
				when IllegalOffset=>
					if(interrupt_cmplt = '1') then
						if(invoke_flag = '1') then
							if(native_flag_reg = '1')then
								CTRL_state_nxt <= Native_start;
							else
								CTRL_state_nxt <= Enable_MA_management;
							end if;
						elsif(new_obj_flag = '1') then
							CTRL_state_nxt <= Wait4GC;
						elsif(getStatic = '1') then	-- getStatic
							if(clinitEN_tmp = '1') then
								CTRL_state_nxt <= ClinitRetFrm1;
							else
								CTRL_state_nxt <= Field_load;
							end if;
						else
							if(field_wr = '1')then
								CTRL_state_nxt <= Field_store;
							else
								CTRL_state_nxt <= Field_load;
							end if;
						end if;
					else
						CTRL_state_nxt <= IllegalOffset;
					end if ;
					
				when ClinitRetFrm1 =>
					CTRL_state_nxt <= ClinitRetFrm2;
					
				when ClinitRetFrm2 =>
					CTRL_state_nxt <= ClinitRetFrm3;
					
				when ClinitRetFrm3 =>
					CTRL_state_nxt <= Enable_MA_management;
				when Wait4GC =>
					if(GC_Cmplt_in='1') then
						CTRL_state_nxt <= HeapAlloc;
					else
						CTRL_state_nxt <= CTRL_state;
					end if;					
				when HeapAlloc =>
					if(external_access_cmplt = '1') then
						CTRL_state_nxt <= Normal;
					else
						CTRL_state_nxt <= HeapAlloc;
					end if;
					
				when Enable_MA_management=>
					CTRL_state_nxt <= CLassLoading;
				
				when CLassLoading=>
					if(ClsLoading_stall = '0') then
						CTRL_state_nxt <= Method_entry;
					else
						CTRL_state_nxt <= CLassLoading;
					end if ;
								
				when Method_entry =>
					CTRL_state_nxt <= Method_flag;
					
				when Method_flag =>
					CTRL_state_nxt <= arg_size;
					
				when arg_size =>
					CTRL_state_nxt <= max_stack;
					
				when max_stack =>
					CTRL_state_nxt <= max_local;
					
				when max_local =>
					CTRL_state_nxt <= Method_exit; 
					
				when Method_exit =>
					-- modified by T.H.Wu, 2014.1.8, determine whether executing monitor enter
					if(DynamicResolution_reg(29)='1')then
						CTRL_state_nxt <= Wait_monEnter_succeed;
					else
						CTRL_state_nxt <= Normal;
					end if;
					
				when Wait_monEnter_succeed =>
					if(sync_mthd_invoke_rtn_cmplt = '1') then
						CTRL_state_nxt <= Normal;
					end if;
				
				when Field_store => -- putfield 
					if (external_access_cmplt = '1') then
						CTRL_state_nxt <= Normal;
					else
						CTRL_state_nxt <= Field_store;
					end if ;
					
				when Field_load => -- getfield 
					if (external_access_cmplt = '1') then
						CTRL_state_nxt <= Normal;
					else
						CTRL_state_nxt <= Field_load;
					end if ;
					
				when Field_exit =>
					CTRL_state_nxt <= Normal;

				when Get_ArgSize =>
					if (external_access_cmplt = '1') then
						CTRL_state_nxt <= Save_objref_fm_heap;
					else
						CTRL_state_nxt <= Get_ArgSize;
					end if ;   
					
				when Save_objref_fm_heap =>
						CTRL_state_nxt <= Get_ObjClsID; 	
					
				when Get_ObjClsID =>
					if(external_access_cmplt = '1') then
						if(invoke_objref_hit = '0') then
							CTRL_state_nxt <= invoke_objref_ListClsID;
						else
							CTRL_state_nxt <= Offset_access;
						end if;
					else
						CTRL_state_nxt <= Get_ObjClsID;
					end if;
					
				when invoke_objref_ListClsID =>
					if(external_access_cmplt = '1') then
						if(invoke_objref_hit = '0') then
							CTRL_state_nxt <= invoke_objref_ListClsID;
						else
							CTRL_state_nxt <= Offset_access;
						end if;
					else
						CTRL_state_nxt <= invoke_objref_ListClsID;
					end if;
					
				
				
				when Native_start =>
					if( Native_ArgCnt_reg = "00000") then
						if(native_HW_flag = '0') then
							CTRL_state_nxt <= Native_interrupt;
						else
							CTRL_state_nxt <= Native_HW;
						end if;
					else
						CTRL_state_nxt <= Native_StackAdjusting1;
					end if;

				when Native_StackAdjusting1 =>
					if((ArgCnt_reg_S or (Native_ArgCnt_reg(1) and Native_ArgCnt_reg(0))) = '1') then
						CTRL_state_nxt <= Native_StackAdjusting2;
					else
						if(native_HW_flag = '0') then
							CTRL_state_nxt <= Native_interrupt;
						else
							CTRL_state_nxt <= Native_HW;
						end if;
					end if;
						
				when Native_StackAdjusting2 =>
					if(ArgCnt_reg_S = '1') then
						CTRL_state_nxt <= Native_StackAdjusting3;
					else
						if(native_HW_flag = '0') then
							CTRL_state_nxt <= Native_interrupt;
						else
							CTRL_state_nxt <= Native_HW;
						end if;
					end if;

				when Native_StackAdjusting3 =>
					CTRL_state_nxt <= Native_ArgExporting_Reg;
					
				when Native_ArgExporting_Reg =>
					if(Native_ArgCnt_reg = "00000" or Native_ArgCnt_reg(4) = '1') then
						if(native_HW_flag = '0') then
							CTRL_state_nxt <= Native_interrupt;
						else
							CTRL_state_nxt <= Native_HW;
						end if;
					elsif(Native_CycCnt_reg = "11") then
						CTRL_state_nxt <= Native_ArgExporting_DDR;
					else
						CTRL_state_nxt <= Native_ArgExporting_Reg;
					end if;
					
				when Native_ArgExporting_DDR =>
					if(Native_ArgCnt_reg = "00000" or Native_ArgCnt_reg(4) = '1') then
						if(native_HW_flag = '0') then
							CTRL_state_nxt <= Native_interrupt;
						else
							CTRL_state_nxt <= Native_HW;
						end if;
					else
						CTRL_state_nxt <= Native_ArgExporting_DDR;
					end if;
					
				when Native_interrupt =>
					if(interrupt_cmplt = '1') then
						if(ArgCnt_reg_S = '1') then
							CTRL_state_nxt <= Native_SpAdjusting;
						else
							CTRL_state_nxt <= Native_StackAdjustingReturn1;
						end if;	
					else
						CTRL_state_nxt <= Native_interrupt;
					end if;
					
				when Native_HW =>
					if(native_HW_cmplt = '1') then
						if(ArgCnt_reg_S = '1') then
							CTRL_state_nxt <= Native_SpAdjusting;
						else
							CTRL_state_nxt <= Native_StackAdjustingReturn1;
						end if;	
					else
						CTRL_state_nxt <= Native_HW;
					end if;
					
				when Native_SpAdjusting =>
					CTRL_state_nxt <= Native_StackAdjustingReturn1; 
					
				when Native_StackAdjustingReturn1 =>
					if(Native_ReturnNum = "00" ) then
						CTRL_state_nxt <= Native_StackAdjustingReturn2;
					else
						CTRL_state_nxt <= Native_exit;
					end if;
						
				when Native_StackAdjustingReturn2 =>
						CTRL_state_nxt <= Native_exit;
					
				when Native_exit =>
					CTRL_state_nxt <= Normal;
					
				when others =>
					CTRL_state_nxt <= Normal;
					
			end case;
	end process;

	reg_CtrlLogic :
	process(clk) begin
		if(rising_edge(clk)) then
		if(Rst = '1') then
			interrupt_req_DR			<= '0';
			interrupt_func_DR		<= (others => '0');
			search_ptr_reg			<= (others => '0');
			DynamicResolution_reg	<= (others => '0');
			XRT_ref_reg				<= (others => '0');
			DynamicResolution_load_req  <= '0';
			DynamicResolution_store_req <= '0';
			invoke_objref_reg		<= (others => '0');
			Native_CycCnt_reg		<= (others => '0');
			Native_ArgCnt_reg		<= (others => '0'); 
			Native_ReturnNum			<= "00";
			ArgSize_reg				<= (others => '0');
			first_objref_clsid		<= (others => '0');
			first_mthd_info_addr		<= (others => '0');
			clsiID_reg					<= (others => '0');
			clinitEN_reg					<= '0';
			clsiInternWrData_reg		<= (others => '0');
			native_HW_flag_reg			<= '0';
			native_HW_en 				<= '0';
			native_HW_act				<= '0';
			native_HW_ID				<= (others => '0');
			invoke_sync_mthd_flag_reg	<=	'0';
		else
			search_ptr_reg		<= search_ptr;
				
			if(clsiCmplt = '1') then
				clsInfo_reg <= clsInfo_in;
			end if;
			
			if((CTRL_state = Offset_access and external_access_cmplt = '1') or
				(CTRL_state = IllegalOffset and interrupt_cmplt = '1')) then
				clsiInternWrData_reg <= clsInfo_reg(31) & "1" & clsInfo_reg(29 downto 0); -- set the clinit flag on
				clinitEN_reg <= clinitEN_tmp;
			elsif(CTRL_state = method_exit) then
				clinitEN_reg <= '0';
			end if;
			
			if(CTRL_state = Get_LV1_XRT_ref) then
				ArgSize_reg <= CST_entry(20 downto 16);
				Native_ReturnNum  <= CST_entry(25 downto 24);
			end if; 
			-- note by T.H.Wu , 2013.9.23 , while state=Get_ObjClsID , the field is updated for invoked object reference
			if( (CTRL_state = Get_ArgSize or CTRL_state = Get_ObjClsID) and external_access_cmplt = '1') then
				first_objref_clsid (15 downto 0) <= external_load_data(15 downto 0);
			end if;
			if( CTRL_state = Get_ArgSize and external_access_cmplt = '1') then
				first_mthd_info_addr(14 downto 0)	<= external_load_data(30 downto 16); 
				first_objref_clsid (16)				<= external_load_data(31);  
			end if;
			
			if(CTRL_state = Save_objref_fm_heap) then
				invoke_objref_reg <= invoke_objref_from_exe_stage;
			end if;
			
			if(CTRL_state = Native_ArgExporting_Reg or Native_CycCnt_reg /= "00") then
				Native_CycCnt_reg <= Native_CycCnt_reg + '1';
			end if;
			
			-- [2][2][2][2] = [native ID x"FF"][arg num][return value num][ISR ID]
			if(native_flag_reg = '1') then
				Native_ArgCnt_reg <= ArgSize_reg ;
			elsif(CTRL_state = Native_StackAdjusting2) then 
				Native_ArgCnt_reg <= Native_ArgCnt_reg - "00011"; 
			elsif(CTRL_state = Native_ArgExporting_Reg or CTRL_state = Native_ArgExporting_DDR) then 
				Native_ArgCnt_reg <= Native_ArgCnt_reg - "00010";
			elsif(CTRL_state = Native_interrupt or CTRL_state = Native_HW) then  
				Native_ArgCnt_reg <= ArgSize_reg - "00011";
			end if;
			
			
			if(IllegalOffset_flag = '1' and (
			(external_access_cmplt = '1' and new_obj_flag = '0') or 
			(clsiCmplt = '1' 			and new_obj_flag = '1')
			))then
				interrupt_req_DR  <= '1';
				interrupt_func_DR <= x"02" & x"0000";
			elsif(interrupt_cmplt = '1')then
				interrupt_req_DR  <= '0';
				interrupt_func_DR <= (others => '0');
			elsif(CTRL_state = Native_interrupt) then
				interrupt_req_DR  <= '1';
				interrupt_func_DR <= x"01" & x"0" & DynamicResolution_reg(11 downto 0);
			end if;
			
			if(CTRL_state = Get_LV1_XRT_ref) then
				clsiID_reg <= clsiID;
			end if;
			
			if(CTRL_state = Get_LV1_XRT_ref) then
				XRT_ref_reg <= XRT_ref;
			elsif(CTRL_state = Get_ObjClsID and external_access_cmplt = '1') then
				if(invoke_objref_hit = '0')then
					XRT_ref_reg <= (x"8801" & "1" & first_mthd_info_addr(14 downto 0));
				else
					XRT_ref_reg <= (x"8801" & "1" & XRT_ref_reg(14 downto 0)) + x"4";
				end if;			
			elsif(CTRL_state = invoke_objref_ListClsID and external_access_cmplt = '1') then
				if(invoke_objref_hit = '0')then
					XRT_ref_reg <= (x"8801" & "1" & external_load_data(30 downto 16));
				else
					XRT_ref_reg <= (x"8801" & "1" & XRT_ref_reg(14 downto 0)) + x"4";
				end if;			
			end if;
			
			if(CTRL_state = Offset_access and new_obj_flag = '0' and external_access_cmplt = '1') then
				DynamicResolution_reg <= external_load_data;
			elsif(CTRL_state = Offset_access and new_obj_flag = '1' and clsiCmplt = '1') then
				DynamicResolution_reg <= clsInfo;
			elsif(new_thread_execute='1' ) then -- by fox , modified by T.H.Wu , 2013.7.21
				-- it will be accessed while each thread is executed at first time
				DynamicResolution_reg <= TH_mgt_ready_thread_cls_id_mthd_id;
			elsif(DR_reg_en = '1') then
				DynamicResolution_reg <= ex2java_data;
			end if;

			if(external_load_req = '0' and
				((CTRL_state_nxt = Offset_access and new_obj_flag = '0') or
				CTRL_state_nxt = Field_load or
				CTRL_state_nxt = Get_ObjClsID or
				CTRL_state_nxt = invoke_objref_ListClsID or
				CTRL_state_nxt = Get_ArgSize
				))then
				DynamicResolution_load_req <= '1';
			elsif(external_access_cmplt = '1') then
				DynamicResolution_load_req <= '0';
			end if;
			
			if(external_store_req = '0' and (CTRL_state_nxt = Field_store or CTRL_state_nxt = HeapAlloc))then
				DynamicResolution_store_req <= '1';
			elsif(external_access_cmplt = '1') then
				DynamicResolution_store_req <= '0';
			end if;		
			
			if(CTRL_state = Offset_access and external_access_cmplt = '1') then
				native_HW_flag_reg <= external_load_data(30);
			elsif(CTRL_state = IllegalOffset and DR_reg_en = '1') then
				native_HW_flag_reg <= ex2java_data(30);
			elsif(CTRL_state = Native_exit) then
				native_HW_flag_reg <= '0';
			end if;
			
			if(CTRL_state = Native_HW and native_HW_cmplt = '0') then
				if(native_HW_act = '0') then
					native_HW_en <= '1';
					native_HW_act <= '1';
					native_HW_ID <= "0" & DynamicResolution_reg(15 downto 12);
				else
					native_HW_en <= '0';								-- rising only 1 cycle
				end if;
			elsif(CTRL_state = Native_HW and native_HW_cmplt = '1') then
				native_HW_en <= '0';									-- Fixing the bug during NullPointerException
				native_HW_act <= '0';
				native_HW_ID <= (others => '0');
			end if;
			-- modified by T.H.Wu, 2014.1.22, for invoking sync method.
			if(CTRL_state=max_stack and DynamicResolution_reg(29)='1') then
				invoke_sync_mthd_flag_reg	<=	'1';
			else
				invoke_sync_mthd_flag_reg	<=	'0';
			end if;
			--
			--
		end if;
		end if;
	end process;

	
	-- prof
		label_enable_jaip_profiler_0 : if ENABLE_JAIP_PROFILER = 1 generate
	process(Clk, Rst)
	begin
		if(Rst = '1') then
			prof_native_mthd_id <= (others => '0');
		elsif(rising_edge(Clk)) then
			if(native_HW_flag = '1') then
				if(CTRL_state = Offset_access) then 
					prof_native_mthd_id <=  x"0" & external_load_data(11 downto 0);
				elsif(CTRL_state = IllegalOffset) then
					prof_native_mthd_id <= x"0" & DynamicResolution_reg(11 downto 0);
				end if;
			end if;
		end if;
	end process;
		end generate;
	
end architecture rtl;