------------------------------------------------------------------------------
-- Filename	:	xcptn_hdlr.vhd
-- Version	:	1.0
-- Author	:	zi-jing guo
-- Date		:	2012/6/1
------------------------------------------------------------------------------
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity xcptn_hdlr is
	generic(
		PROFILE_LOGIC_ENABLE			: integer := 0
	); 
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		xcptn_en					: in  std_logic;
		--act						: in  std_logic;
		
		xcptn_thrown_ALU   			: in  std_logic;					--divided by zero
		xcptn_thrown_bytecode	: in  std_logic;					--bytecode"athrow"
		xcptn_stall				: out std_logic;
		xcptn_flush_pipeline		: out std_logic;
		-- external memory access
		external_access_cmplt	: in  std_logic;
		external_load_data		: in  std_logic_vector(31 downto 0);
		external_load_EID_req	: out std_logic;
		external_load_LVcnt_req	: out std_logic;
		-- parser to ER_LUT 
		prsr2ER_LUT_di   			: in  std_logic_vector(15 downto 0);
		prsr2ER_LUT_addr			: in  std_logic_vector(9 downto 0);
		prsr2ER_LUT_wen			: in  std_logic;	
		--to execute 
		get_return_frame			: out std_logic;
		update_return_regs			: out std_logic;
		update_TOS_BC			: out std_logic;
		LV_cnt_wen				: out std_logic;
		get_top2_stack			: out std_logic;
		mem2LVreg_1_xcptn		: out std_logic;
		mem2LVreg_2_xcptn		: out std_logic;
		pop1_addr_en				: out std_logic;
		pop1_BC_reg_wen			: out std_logic;
		--to mthd ctrlr
		now_mthd_id				: in  std_logic_vector(15 downto 0);
		ER_info					: in  std_logic_vector(15 downto 0);
		ER_info_wen_MA_ctrlr		: in  std_logic;
		check_CST_MA_done			: in  std_logic;
		ret_frm_regs_wen			: out std_logic;
		ER_info_addr_rdy			: out std_logic;
		MA_base_mem_addr_wen		: out std_logic;
	
		--to jpc ctrlr
		stall_jpc				: in  std_logic; 
		JPC						: in  std_logic_vector(14 downto 0);
		ER_JPC					: out std_logic_vector(15 downto 0);
		ER_JPC2JPC_wen				: out std_logic;
		adjust_jpc2xcptn_instr	: out std_logic;
		--xcptn_jpc				: out std_logic_vector(15 downto 0);
		--to cst_controller
		now_cls_id				: in  std_logic_vector(15 downto 0);
		parent_EID				: in  std_logic_vector(15 downto 0);
		xcptn_cst_mthd_check_en  	: out std_logic;
		xcptn_cst_mthd_check_IDs_en	: out std_logic;
		get_parent_EID			: out std_logic;
		compared_EID				: out  std_logic_vector(15 downto 0);
		--to instr buffer		
		xcptn_clean_buffer		: out std_logic;
		mask_insr1				: out std_logic;
		--to decode
		xcptn_done				: out std_logic;
		push1_flag				: out std_logic;
		push2_flag				: out std_logic;
		-- interrupt req
		interrupt_cmplt			: in  std_logic; 
		interrupt_req_xcptn			: out std_logic;
		interrupt_func_xcptn		: out std_logic_vector(23 downto 0);
		-- native HW
		xcptn_thrown_Native_HW		: in  std_logic;
		Native_HW_thrown_ID			: in  std_logic_vector(15 downto 0)
	);
end entity xcptn_hdlr;

architecture rtl of xcptn_hdlr is
	signal XCPTN_HDLR_state			: XCPTN_HDLR_SM_TYPE;  
	signal next_XCPTN_HDLR_state	: XCPTN_HDLR_SM_TYPE; 
	
	-- flip-flop
	signal thrown_EID			: std_logic_vector(15 downto 0);
	signal ER_cnt				: std_logic_vector( 7 downto 0);
	signal compared_ER_cnt		: std_logic_vector( 7 downto 0);
	signal ER_LUT_base_addr	: std_logic_vector( 7 downto 0);
	signal mask_insr1_r		: std_logic;
	signal buffer_no_change	: std_logic;
	signal xcptn_handling_cycles  : std_logic_vector(31 downto 0);
	signal catch_search_cnt	: std_logic_vector(31 downto 0);
	signal method_search_cnt	: std_logic_vector(31 downto 0);
	signal mem_access_cycle	: std_logic_vector(31 downto 0);
	signal xcptn_handling_cnt	: std_logic_vector(31 downto 0);
	signal ER_cnt_record		: std_logic_vector(31 downto 0);
	signal new_obj_time		: std_logic_vector(31 downto 0);
	signal compared_EID_r		: std_logic_vector(15 downto 0);
	
	-- wires
	signal ER_cnt_zero			: std_logic;
	signal ER_cnt_reach_compare_cnt: std_logic;
	signal EID_match			: std_logic;
	signal ER_JPC_match			: std_logic;
	signal ER_info_wen			: std_logic;
	signal Parent_is_Object		: std_logic;
	signal Parent_EID_match		: std_logic;
	
	

	
	--ER_LUT
	--signal ER_LUT_di			: std_logic_vector(15 downto 0);
	signal ER_LUT_do			: std_logic_vector(15 downto 0);
	signal ER_LUT_addr			: std_logic_vector( 9 downto 0);
	--signal ER_LUT_wen			: std_logic;
	signal ER_item_sel			: std_logic_vector( 1 downto 0);
	signal ER_sel				: std_logic_vector( 7 downto 0);
	
	
	begin
	
	push1_flag <= '1' when (xcptn_thrown_Native_HW = '1' and XCPTN_HDLR_state = IDLE) else
				'0';
	push2_flag <= '0';
	
	xcptn_stall <= '1' when  XCPTN_HDLR_state /= IDLE else -- or xcptn_thrown_ALU = '1' else --when ( XCPTN_HDLR_state = IDLE and next_XCPTN_HDLR_state = IDLE ) or return_flag = '1' or invoke_flag = '1' or CTRL_state /= Normal  else
				'0';  --and xcptn_thrown_bytecode = '0' and xcptn_thrown_ALU = '0'
	
	external_load_EID_req   <= '1' when XCPTN_HDLR_state = GET_THROWN_EID else
							'0';
	external_load_LVcnt_req <= '1' when XCPTN_HDLR_state = LOAD_LV_CNT else
							'0';
	LV_cnt_wen <= 			'1' when XCPTN_HDLR_state = LOAD_LV_CNT and external_access_cmplt = '1' else
							'0';
				
	ER_JPC2JPC_wen <= '1' when XCPTN_HDLR_state = UPDATE_JPC_TOSBC else
					'0';
	ER_JPC		<= ER_LUT_do(15 downto 0);	
	-- 2013.8.7 by T.H.Wu ,  why jpc minus 4 ?? 
	adjust_jpc2xcptn_instr <= '1' when (XCPTN_HDLR_state = GET_THROWN_EID or XCPTN_HDLR_state = New_OBJ) and next_XCPTN_HDLR_state = CHECK_ER_CNT else
							'0';

	--to execute 
	get_return_frame	<= '1' when XCPTN_HDLR_state = GET_RETURN_FRM else
						'0';
	update_return_regs  <= '1' when XCPTN_HDLR_state = UPDATE_RTRN_REGS else
						'0';   
	update_TOS_BC	<= '1' when XCPTN_HDLR_state = UPDATE_JPC_TOSBC and buffer_no_change = '0' else
						'0';
				
	ret_frm_regs_wen	<= '1' when XCPTN_HDLR_state = UPDATE_RTRN_REGS else
							'0';	
	ER_info_addr_rdy	<= '1' when XCPTN_HDLR_state = GET_ER_CNT else--or XCPTN_HDLR_state = GET_THROWN_EID  else
							'0';		
	MA_base_mem_addr_wen <= '1' when XCPTN_HDLR_state = GET_ER_CNT_DELAY else
									--or (XCPTN_HDLR_state = GET_THROWN_EID and next_XCPTN_HDLR_state <= CHECK_ER_CNT )else
							'0';						
							
	get_top2_stack	<= '1' when (XCPTN_HDLR_state = COMPARE_EID or XCPTN_HDLR_state = COMPARE_PARENT_EID )
								and next_XCPTN_HDLR_state = UPDATE_JPC_TOSBC 
								and buffer_no_change = '0' else
						'0';	
	mem2LVreg_1_xcptn <= '1' when XCPTN_HDLR_state = UPDATE_LV0 and buffer_no_change = '0' else
						'0';	
	mem2LVreg_2_xcptn <= '1' when XCPTN_HDLR_state = UPDATE_LV1 and buffer_no_change = '0' else
						'0';	
						
	pop1_addr_en	<= '1' when XCPTN_HDLR_state = IDLE and xcptn_thrown_ALU = '1' else
						'0';	
	pop1_BC_reg_wen   <= '1' when XCPTN_HDLR_state = POP1 else
						'0';	
	-- CST MA check
	xcptn_cst_mthd_check_en		<= '1' when XCPTN_HDLR_state = UPDATE_LV0 and buffer_no_change = '0' else
								'0';
	xcptn_cst_mthd_check_IDs_en <= '1' when buffer_no_change = '0' and 
											(XCPTN_HDLR_state = UPDATE_JPC_TOSBC or XCPTN_HDLR_state = UPDATE_LV0 or 
											XCPTN_HDLR_state = UPDATE_LV1 or XCPTN_HDLR_state = CHECK_CST_MA)	else
								'0'; 	
	
	get_parent_EID <= '1' when XCPTN_HDLR_state = GET_PARENT_EID_STATE or XCPTN_HDLR_state = COMPARE_EID else
					'0';

	--to decode
	xcptn_done				<= '1' when XCPTN_HDLR_state = UPDATE_JPC_TOSBC else
								'0';		
	
	-- interrupt req "new"	ArithmeticException for thrown ALU exception event 
	interrupt_req_xcptn  <= '1' when XCPTN_HDLR_state = New_OBJ else
							'0';	
	interrupt_func_xcptn <= x"03" & thrown_EID;
	
	XCPTN_HDLR_FSM_reg :
	process(clk, Rst) begin
		if Rst = '1'  then
			XCPTN_HDLR_state		<= IDLE;
		elsif(rising_edge(clk)) then
			--if act = '1' and xcptn_en = '1' then
			if xcptn_en = '1' then
				XCPTN_HDLR_state	<= next_XCPTN_HDLR_state;
			end if;
		end if;
	end process;			
	
	XCPTN_HDLR_FSM_logic :
	process(XCPTN_HDLR_state,xcptn_thrown_bytecode,external_access_cmplt,ER_cnt_zero,ER_cnt_reach_compare_cnt,
			EID_match,Parent_is_Object,Parent_EID_match,ER_JPC_match,check_CST_MA_done,xcptn_thrown_ALU,interrupt_cmplt,buffer_no_change, xcptn_thrown_Native_HW) begin
		case XCPTN_HDLR_state is
			when IDLE =>
				if xcptn_thrown_bytecode = '1' then
					next_XCPTN_HDLR_state <= GET_THROWN_EID;
				elsif xcptn_thrown_ALU = '1' then
					next_XCPTN_HDLR_state <= POP1;
				elsif xcptn_thrown_Native_HW = '1' then				
					next_XCPTN_HDLR_state <= New_OBJ;
				else
					next_XCPTN_HDLR_state <= XCPTN_HDLR_state;   
				end if;
			when GET_THROWN_EID =>
				if external_access_cmplt = '1' then
					next_XCPTN_HDLR_state <= CHECK_ER_CNT;
				else
					next_XCPTN_HDLR_state <= XCPTN_HDLR_state;   
				end if;	
			when POP1 =>
				next_XCPTN_HDLR_state <= New_OBJ;	
			when New_OBJ =>
				if interrupt_cmplt = '1' then
					next_XCPTN_HDLR_state <= CHECK_ER_CNT;
				else
					next_XCPTN_HDLR_state <= XCPTN_HDLR_state;   
				end if;		
			when CHECK_ER_CNT =>
				if ER_cnt_reach_compare_cnt = '1' then
					next_XCPTN_HDLR_state <= LOAD_LV_CNT;
				else
					next_XCPTN_HDLR_state <= COMPARE_START;   
				end if;	
			when LOAD_LV_CNT =>
				if external_access_cmplt = '1' then
					next_XCPTN_HDLR_state <= GET_RETURN_FRM;
				else
					next_XCPTN_HDLR_state <= XCPTN_HDLR_state;   
				end if;	
			when GET_RETURN_FRM =>
				next_XCPTN_HDLR_state <= UPDATE_RTRN_REGS;
			when UPDATE_RTRN_REGS =>
				next_XCPTN_HDLR_state <= GET_ER_CNT;	
			when GET_ER_CNT =>
				next_XCPTN_HDLR_state <= GET_ER_CNT_DELAY;	
			when GET_ER_CNT_DELAY =>
				next_XCPTN_HDLR_state <= CHECK_ER_CNT;	
				
				
			when COMPARE_START =>
				if ER_JPC_match = '1' then
					next_XCPTN_HDLR_state <= COMPARE_END;
				else
					next_XCPTN_HDLR_state <= CHECK_ER_CNT;   
				end if;	
			when COMPARE_END =>
				if ER_JPC_match = '1' then
					next_XCPTN_HDLR_state <= COMPARE_EID;
				else
					next_XCPTN_HDLR_state <= CHECK_ER_CNT;   
				end if;	
			when COMPARE_EID =>
				if EID_match = '1' then
					next_XCPTN_HDLR_state <= UPDATE_JPC_TOSBC;
				else
					next_XCPTN_HDLR_state <= COMPARE_PARENT_EID;   
				end if;		
			when COMPARE_PARENT_EID =>
				if Parent_is_Object = '1' then
					next_XCPTN_HDLR_state <= CHECK_ER_CNT;
				elsif Parent_EID_match = '1' then
					next_XCPTN_HDLR_state <= UPDATE_JPC_TOSBC;
				else
					next_XCPTN_HDLR_state <= GET_PARENT_EID_STATE;   
				end if;	
			when GET_PARENT_EID_STATE =>
				next_XCPTN_HDLR_state <= COMPARE_PARENT_EID;	
				
			
			when UPDATE_JPC_TOSBC =>
				next_XCPTN_HDLR_state <= UPDATE_LV0;	
			when UPDATE_LV0 =>
				next_XCPTN_HDLR_state <= UPDATE_LV1;	
			when UPDATE_LV1 =>
			-- if buffer_no_change = '1' then
					--next_XCPTN_HDLR_state <= IDLE;	
				--else
					next_XCPTN_HDLR_state <= CHECK_CST_MA;	
				--end if;  
			when CHECK_CST_MA =>
				if check_CST_MA_done = '1' or buffer_no_change = '1' then
					next_XCPTN_HDLR_state <= IDLE;
				else
					next_XCPTN_HDLR_state <= XCPTN_HDLR_state;   
				end if;	
			when others =>
				next_XCPTN_HDLR_state <= XCPTN_HDLR_state;			
		end case;
	end process;
	
	--ER_cnt_zero <= '1' when ER_cnt = X"00" else
	--			'0';
	
	ER_cnt_reach_compare_cnt <= '1' when ER_cnt = compared_ER_cnt else
								'0';
	
	EID_match <= '1' when thrown_EID = ER_LUT_do else
				'0';
	
	
	compared_EID <= compared_EID_r;
	
	
	
	thrown_EID_reg :	
	process(clk, Rst) begin
		if(Rst = '1') then
			thrown_EID 	<= X"0000";
			compared_EID_r <= X"0000"; 
		elsif(rising_edge(clk)) then
			if XCPTN_HDLR_state = IDLE and xcptn_thrown_ALU = '1' then
				thrown_EID <= X"0000";
			elsif XCPTN_HDLR_state = IDLE and xcptn_thrown_Native_HW = '1' then
				thrown_EID <= Native_HW_thrown_ID;
			elsif XCPTN_HDLR_state = GET_THROWN_EID and external_access_cmplt = '1' then
				thrown_EID <= external_load_data(15 downto 0);
			end if;
			
			if XCPTN_HDLR_state = IDLE and xcptn_thrown_ALU = '1' then
				compared_EID_r <= X"0000";
			elsif XCPTN_HDLR_state = IDLE and xcptn_thrown_Native_HW = '1' then
				compared_EID_r <= Native_HW_thrown_ID;
			elsif XCPTN_HDLR_state = GET_THROWN_EID and external_access_cmplt = '1' then
				compared_EID_r <= external_load_data(15 downto 0);
			elsif XCPTN_HDLR_state = COMPARE_PARENT_EID then
				compared_EID_r <= parent_EID;
			end if;
		end if;
	end process;	
	
	buffer_no_change_logic :
	process(clk, Rst) begin
		if(Rst = '1') then
			buffer_no_change 	<= '0';
		elsif(rising_edge(clk)) then
			if XCPTN_HDLR_state = IDLE and (xcptn_thrown_bytecode = '1' or xcptn_thrown_ALU = '1' or xcptn_thrown_Native_HW = '1') then
				buffer_no_change <= '1';
			elsif XCPTN_HDLR_state = UPDATE_RTRN_REGS then
				buffer_no_change <= '0';
			end if;
		end if;
	end process;
	
	ER_JPC_match_logic :	
	process(XCPTN_HDLR_state,JPC,ER_LUT_do) begin
		if XCPTN_HDLR_state = COMPARE_START then
			if JPC >= ER_LUT_do(15 downto 1) then 
				ER_JPC_match <= '1';
			else
				ER_JPC_match <= '0';
			end if;
		else--if XCPTN_HDLR_state = COMPARE_END then
			if JPC <= ER_LUT_do(15 downto 1) then 
				ER_JPC_match <= '1';
			else
				ER_JPC_match <= '0';
			end if;
		end if;
	end process;	

	Parent_is_Object <= '1' when parent_EID = X"0004" else
						'0';
	Parent_EID_match <= '1' when parent_EID = ER_LUT_do else
						'0';					

	ER_info_wen <= '1' when ER_info_wen_MA_ctrlr = '1' or -- updated when normal invoke/return check
							--( XCPTN_HDLR_state = GET_THROWN_EID and next_XCPTN_HDLR_state = CHECK_ER_CNT ) or
							XCPTN_HDLR_state = GET_ER_CNT_DELAY else
				'0';
	
	ER_info_reg :	
	process(clk, Rst) begin
		if(Rst = '1') then
			ER_cnt 			<= X"00";
			ER_LUT_base_addr <= X"00";
			compared_ER_cnt  <= X"00";
		elsif(rising_edge(clk)) then
			if ER_info_wen = '1'  then
				ER_cnt <= ER_info(7 downto 0);
			end if;	
			--elsif (XCPTN_HDLR_state = COMPARE_EID and next_XCPTN_HDLR_state = CHECK_ER_CNT ) or
			--	( (XCPTN_HDLR_state = COMPARE_START or XCPTN_HDLR_state = COMPARE_END)  and ER_JPC_match = '0' ) then
			--	ER_cnt <= ER_cnt - X"01";
			--end if;
			
			if ER_info_wen = '1'  then
				compared_ER_cnt <= X"00";
			elsif (XCPTN_HDLR_state = COMPARE_PARENT_EID and next_XCPTN_HDLR_state = CHECK_ER_CNT ) or
				( (XCPTN_HDLR_state = COMPARE_START or XCPTN_HDLR_state = COMPARE_END)  and ER_JPC_match = '0' ) then
				compared_ER_cnt <= compared_ER_cnt + X"01";
			end if;
			
			if ER_info_wen = '1'  then
				ER_LUT_base_addr <= ER_info(15 downto 8);
			end if;
					
		end if;
	end process;
	
	Exception_Routine_Lookup_Table : RAMB16_S18
	generic map(
		INIT_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_07 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_08 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_09 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_0A => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_0B => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_0C => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_0D => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_0E => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_0F => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_10 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_11 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_12 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_13 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_14 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_15 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_16 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_17 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_18 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_19 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_1A => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_1B => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_1C => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_1D => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_1E => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_1F => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_20 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_21 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_22 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_23 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_24 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_25 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_26 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_27 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_28 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_29 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_2A => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_2B => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_2C => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_2D => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_2E => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_2F => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_30 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_31 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_32 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_33 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_34 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_35 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_36 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_37 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_38 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_39 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_3A => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_3B => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_3C => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_3D => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_3E => X"0000000000000000000000000000000000000000000000000000000000000000",
		INIT_3F => X"0000000000000000000000000000000000000000000000000000000000000000"
	)
	port map (
		DI	=> prsr2ER_LUT_di,
		DIP   => (others => '0'),
		ADDR  => ER_LUT_addr,
		DO	=> ER_LUT_do,
		CLK   => clk,   
		EN	=> '1', 
		SSR   => Rst,
		WE	=> prsr2ER_LUT_wen	
	); 
	
	ER_LUT_addr <= prsr2ER_LUT_addr	when prsr2ER_LUT_wen = '1'	else
				ER_sel & ER_item_sel;
	ER_item_sel <= "00" when XCPTN_HDLR_state = CHECK_ER_CNT  else --ER_START
				"01" when XCPTN_HDLR_state = COMPARE_START else --ER_END
				"10" when (XCPTN_HDLR_state = COMPARE_EID or XCPTN_HDLR_state = COMPARE_PARENT_EID) 
							and next_XCPTN_HDLR_state = UPDATE_JPC_TOSBC else --ER_ADDR
				
				"11"; --ER_EID
	
	--ER_sel	<= ER_LUT_base_addr + ER_cnt - "01";
	ER_sel	<= ER_LUT_base_addr + compared_ER_cnt ;
	
	------------------------------------------------------------


	xcptn_clean_buffer   <= '1' when (XCPTN_HDLR_state = COMPARE_EID or XCPTN_HDLR_state = COMPARE_PARENT_EID) 
									and next_XCPTN_HDLR_state = UPDATE_JPC_TOSBC  else
							'0';
	
	mask_insr1		<= mask_insr1_r;
	
	xcptn_flush_pipeline <= '1' when XCPTN_HDLR_state = UPDATE_JPC_TOSBC or XCPTN_HDLR_state = UPDATE_LV0 or XCPTN_HDLR_state = UPDATE_LV1 or XCPTN_HDLR_state = CHECK_CST_MA else
							'0';
							
	-- if jump jpc is an odd number , the intr1 should  be masked
	mask_insr1_reg :	
	process(clk, Rst) begin
		if(Rst = '1') then
			mask_insr1_r <= '0';
		elsif(rising_edge(clk)) then
			if XCPTN_HDLR_state = UPDATE_JPC_TOSBC and ER_LUT_do(0) = '1' then
				mask_insr1_r <= '1';
			elsif stall_jpc = '0' then
				mask_insr1_r <= '0';
			end if;
		end if;
	end process;		

	profile_logic_enable_0 : if PROFILE_LOGIC_ENABLE = 1 generate
   -- records cycles of exception handling	
	exception_handling_cycles :	
	process(clk, Rst) begin
		if(Rst = '1') then
			xcptn_handling_cycles <= X"00000000";
			catch_search_cnt	<= X"00000000";   
			method_search_cnt	<= X"00000000";  
			mem_access_cycle	<= X"00000000";  
			xcptn_handling_cnt	<= X"00000000";  
			ER_cnt_record		<= X"00000000";  
			new_obj_time		<= X"00000000";  
		elsif(rising_edge(clk)) then
			if XCPTN_HDLR_state /= IDLE then
				xcptn_handling_cycles <= xcptn_handling_cycles + "01";
			end if;
			
			if XCPTN_HDLR_state = COMPARE_START then
				catch_search_cnt <= catch_search_cnt + "01";
			end if;
			
			if XCPTN_HDLR_state = GET_RETURN_FRM then
				method_search_cnt <= method_search_cnt + "01";
			end if;
			
			if XCPTN_HDLR_state = LOAD_LV_CNT then
				mem_access_cycle <= mem_access_cycle + "01";
			end if;
			
			if XCPTN_HDLR_state = UPDATE_JPC_TOSBC then
				xcptn_handling_cnt <= xcptn_handling_cnt + "01";
			end if;
			
			if ER_info_wen = '1' and XCPTN_HDLR_state = GET_ER_CNT_DELAY then
				ER_cnt_record   <= X"0000" & ER_info(15 downto 0);
			end if;
			
			if XCPTN_HDLR_state = New_OBJ then
				new_obj_time   <= new_obj_time + "01";
			end if;
--thrown_eid
		end if;
	end process;
	end generate;
	
end architecture rtl;
