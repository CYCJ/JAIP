------------------------------------------------------------------------------
-- Filename	:	decode.vhd
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
-- Filename	:	decode.vhd
-- Version	:	2.03
-- Author	:	Kuan-Nian Su
-- Date		:	May 2009
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Filename	:	decode.vhd
-- Version	:	3.00
-- Author	:	Han-Wen Kuo
-- Date		:	Jan 2011
-- VHDL Standard:	VHDL'93
-- Describe	:	New Architecture
------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.config.all;

entity decode is
	generic(
		ENABLE_JAIP_PROFILER   : integer := 0;
		RAMB_S18_AWIDTH			: integer := 10;
		RAMB_S36_AWIDTH			: integer := 9
	);
	port(
			-- ctrl signal
		Rst							: in  std_logic;
		clk							: in  std_logic;
		stall_decode_stage			: in  std_logic;
		CTRL_state					: in  DynamicResolution_SM_TYPE;
			-- ldc
		DR_addr						: in  std_logic_vector(31 downto 0);

			-- method area
		instruction_buffer_2			: in  std_logic_vector(15 downto 0);
		instruction_buffer_1			: in  std_logic_vector(15 downto 0);
		instruction_buffer_0			: in  std_logic_vector(15 downto 0);
		now_cls_id					: in  std_logic_vector(15 downto 0);
		now_mthd_id					: in  std_logic_vector(15 downto 0);

			-- jpc CtrlLogic
		branch_destination			: out std_logic_vector(15 downto 0);

			-- fetch stage
		branch_trigger				: in  std_logic_vector(15 downto 0);
		instrs_pkg					: in  std_logic_vector(15 downto 0);
		opd_source					: in  std_logic_vector( 1 downto 0);
		nop_1						: in  std_logic;
		nop_2						: in  std_logic;
		is_switch_instr_start	: in  std_logic;
		switch_instr_revert_code_seq : out std_logic ;

			-- execte stage
		vp							: in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
		sp							: in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
		branch						: in  std_logic;
		reg_valid					: in  std_logic_vector( 3 downto 0);
		load_immediate1				: out std_logic_vector(31 downto 0);
		load_immediate2				: out std_logic_vector(31 downto 0);
		store1_addr					: out std_logic_vector(RAMB_S36_AWIDTH downto 0);
		store2_addr					: out std_logic_vector(RAMB_S36_AWIDTH downto 0);
		W1_RegFlag					: out std_logic;
		W2_RegFlag					: out std_logic;
		MemRead_ctrl					: out Decode2Execute_MemRead_Type;
		ctrl							: out Decode2Execute_ControlSignal_Type;
		mem2LVreg_1_decode			: out std_logic;
		mem2LVreg_2_decode			: out std_logic;
		stsp_s_flag					: out std_logic;
		Long_enable						: out std_logic;

		-- multianewarray
		dim							: out std_logic_vector(7 downto 0);
		mularr_end_flag				: in std_logic;
		multiarray_flag				: out std_logic;
		dim_count_flag				: out std_logic;
		
			-- opd out
		operand0_out					: out std_logic_vector(7 downto 0);
		operand1_out					: out std_logic_vector(7 downto 0);
		operand2_out					: out std_logic_vector(7 downto 0);
		operand3_out					: out std_logic_vector(7 downto 0);

			-- flag & req in
		pop1_flag					: in  std_logic;
		pop2_flag					: in  std_logic;
		push1_flag					: in  std_logic;
		push2_flag					: in  std_logic;
		interrupt_req				: in  std_logic;
		interrupt_cmplt				: in  std_logic;
		external_load_req			: in  std_logic;
		external_store_req			: in  std_logic;
		external_access_cmplt		: in  std_logic;

			-- flag & req out
		DynamicResolution_en			: out std_logic;			
		invoke_flag					: out std_logic;
		new_obj_flag					: out std_logic;
		static_flag					: out std_logic;
		field_wr						: out std_logic;
		ldc_flag						: out std_logic;
		ldc_w_flag						: out std_logic;
		ldc2_w_flag						: out std_logic;
		stjpc_flag					: out std_logic;
		return_flag					: out std_logic;
		ireturn_flag					: out std_logic;
		lreturn_flag					: out std_logic;
		lrtnvalue_flag				: out std_logic;
		larray_flag					: out std_logic;
		larray_lower_flag			: out std_logic;
		newarray_flag					: out std_logic;
		getStatic						: out std_logic;
		interrupt_req_decode			: out std_logic;
		refload_req					: out std_logic;
		refstore_req					: out std_logic;
		refAcs_sel					: out std_logic_vector(1 downto 0);
		interrupt_func_decode		: out std_logic_vector(23 downto 0);
		-- thread management , by fox
		TH_mgt_clean_decode			: in std_logic;
		TH_mgt_clean_execute		: out std_logic;
		TH_mgt_context_switch		: in std_logic;
		TH_mgt_CS_reset_lv			: in std_logic; 
		-- to multi-core coordinator , added by T.H.Wu , 2013.9.7
		JAIP2COOR_cmd_monitor_enter_req : out std_logic;
		JAIP2COOR_cmd_monitor_exit_req : out std_logic;

		-- prof
		prof_simple_issued_A		: in std_logic;
		prof_simple_issued_B		: in std_logic;
		prof_complex_issued			: in std_logic;
		prof_issued_bytecodes_F		: in std_logic_vector(15 downto 0);
		prof_simple_issued_A_D		: out std_logic;
		prof_simple_issued_B_D		: out std_logic;
		prof_complex_issued_D		: out std_logic;
		prof_issued_bytecodes_D		: out std_logic_vector(15 downto 0);
		--xcptn thrown by bytecode
		xcptn_done					: in  std_logic;
		xcptn_thrown_bytecode		: out std_logic
			
	);						
end entity decode;

architecture rtl of decode is	
	component immROM port(
		index : in  std_logic_vector(2 downto 0);
		value : out std_logic_vector(31 downto 0)
	);
	end component;
	
	signal instr1				: std_logic_vector(7 downto 0);
	signal instr2				: std_logic_vector(7 downto 0);
	signal instr_type			: std_logic_vector(3 downto 0);
	signal operand_0				: std_logic_vector(7 downto 0);
	signal operand_1				: std_logic_vector(7 downto 0);
	signal operand_2				: std_logic_vector(7 downto 0);
	signal operand_3				: std_logic_vector(7 downto 0);
	signal special_R1_sel		: std_logic;
	signal special_R2_sel		: std_logic;
	signal special_R1_en			: std_logic;
	signal special_R2_en			: std_logic;
	signal special				: Decode2Execute_ControlSignal_Type;
	signal ctrl_tmp				: Decode2Execute_ControlSignal_Type;
	signal ctrl_nop				: Decode2Execute_ControlSignal_Type :=
									(A		=> A_ALU,
									B		=> B_ALU,
									C		=> C_A,
									Aen		=> disable,
									Ben		=> disable,
									Cen		=> disable,
									ALUopd1_sel => ALU1_A,
									ALUopd2_sel => ALU2_B,
									ALU		=> ALU_nop,
									W1_sel	=> W1_sp,	-- (sp	)
									W2_sel	=> W2_sp,	-- (sp + 1)
									W1_en	=> disable,
									W2_en	=> disable,
									LD1_sel	=> LD1_RD,
									LD2_sel	=> LD2_RD,
									SD1_sel	=> SD1_C,
									SD2_sel	=> SD2_B,
									stvp1	=> disable,
									stvp2	=> disable,
									stsp1	=> disable,
									stsp2	=> disable,
									sp_offset   => "000",
									branch	=> "0111"); 
	signal immROM1_val			: std_logic_vector(31 downto 0);
	signal immROM2_val			: std_logic_vector(31 downto 0);
	signal load_immediate1_reg	: std_logic_vector(31 downto 0);
	signal load_immediate2_reg	: std_logic_vector(31 downto 0);
	signal load_immediate1_reg_w	: std_logic_vector(31 downto 0);
	signal load_immediate2_reg_w	: std_logic_vector(31 downto 0); 
	signal LS1_addr, LS2_addr	: std_logic_vector( 9 downto 0);
	signal RegFlag1, RegFlag2	: std_logic;
	signal LdOpdPlus1Flag		: std_logic;
	signal LdLV4Flag				: std_logic;
	signal StOpdPlus1Flag		: std_logic;
	signal StLV4Flag				: std_logic;
	signal Opd0IsLessThan4		: std_logic;
	signal LocalVariable_1		: std_logic_vector( 1 downto 0);
	signal LocalVariable_2		: std_logic_vector( 1 downto 0);
	signal nop_store_flag		: std_logic;
	signal larray_lower_flag_reg	: std_logic;
	signal BranchDestination_tmp	: std_logic_vector(15 downto 0);
	signal mem2LVreg_1_reg		: std_logic;
	signal mem2LVreg_2_reg		: std_logic;
	signal clear_newarraycopy_flag	: std_logic;
				
		-- for switch instruction use
	signal switch_default_offset	: std_logic_vector(31 downto 0);
	signal switch_npair			: std_logic_vector(31 downto 0);
	signal switch_code_revert	: std_logic;
	--xcptn thrown
	signal xcptn_thrown_bytecode_r  : std_logic;  
	
	-- prof
	signal prof_simple_issued_A_reg			: std_logic;
	signal prof_simple_issued_B_reg			: std_logic;
	signal prof_complex_issued_reg			: std_logic;
	signal prof_issued_bytecodes_reg		: std_logic_vector(15 downto 0);
	
	begin
	
	xcptn_thrown_bytecode <= xcptn_thrown_bytecode_r;
	
	instr1 <= x"78"	when pop1_flag = '1' else
			x"00"	when push1_flag = '1' else
			x"FF"	when push2_flag = '1' else
			x"FF"	when nop_1 = '1' else
			instrs_pkg(15 downto 8);
	instr2 <= x"78"	when pop2_flag = '1' else
			x"00"	when push2_flag = '1' else
			x"FF"	when push1_flag = '1' else
			x"FF"	when nop_2 = '1' else
			instrs_pkg( 7 downto 0);
	instr_type <= instr1(7 downto 6) & instr2(7 downto 6);
	
	-- immediate value indexing by the ROMs   
	immROM1 : immROM port map(
		index => instr1(2 downto 0),
		value => immROM1_val
	);
	immROM2 : immROM port map(
		index => instr2(2 downto 0),
		value => immROM2_val
	);

	--		buf2_U buf2_L buf1_U buf1_L buf0_U buf0_L
	-- ------- \ -----------------------------------------
	-- orthers |   opd0   opd1   opd2   opd3 
	--	01 | opcode   opd0   opd1   opd2   opd3 
	--	10 |		opcode   opd0   opd1   opd2   opd3
	operand_source_CtrlUnit :
	process(opd_source, instruction_buffer_2, instruction_buffer_1, instruction_buffer_0)
	begin
		case opd_source is
			when "01"=>
				operand_0 <= instruction_buffer_2( 7 downto 0);
				operand_1 <= instruction_buffer_1(15 downto 8);
				operand_2 <= instruction_buffer_1( 7 downto 0);
				operand_3 <= instruction_buffer_0(15 downto 8);
			when "10"=>
				operand_0 <= instruction_buffer_1(15 downto 8);
				operand_1 <= instruction_buffer_1( 7 downto 0);
				operand_2 <= instruction_buffer_0(15 downto 8);
				operand_3 <= instruction_buffer_0( 7 downto 0);
			when others =>
				operand_0 <= instruction_buffer_2(15 downto 8);
				operand_1 <= instruction_buffer_2( 7 downto 0);
				operand_2 <= instruction_buffer_1(15 downto 8);
				operand_3 <= instruction_buffer_1( 7 downto 0);
		end case;
	end process;
	operand0_out <= operand_0;
	operand1_out <= operand_1;
	operand2_out <= operand_2;
	operand3_out <= operand_3;
	
	special_DecodeUnit :
	process(instr1) begin
		-- reset special
		special		<= ctrl_nop;
		special_R1_en  <= disable;
		special_R2_en  <= disable;
		special_R1_sel <= R1_sp;
		special_R2_sel <= R2_sp;
		case instr1( 5 downto 3 ) is
			when "000" =>
				-- sp-2   if_cmp<cond> C0-C5
				special.Aen		<= enable;
				special.Ben		<= enable;
				special.Cen		<= enable;
				special.sp_offset  <= "110";	-- sp-2
				special_R1_en	<= enable;
				special_R2_en	<= enable;
				special.ALU		<= "0111";
				special.branch	<= instr1(3 downto 0); -- x"0" ~ x"5"
				special.A		<= A_C;
				special.B		<= B_LD1;
				special.C		<= C_LD2;
				special.ALUopd1_sel <= ALU1_A;
				special.ALUopd2_sel <= ALU2_B; 
				
			when "001" => 
				-- sp-1   if<cond> C8-CD
				special.Aen		<= enable;
				special.Ben		<= enable;
				special.Cen		<= enable;
				special.sp_offset  <= "111";	-- sp-1
				special_R1_en	<= enable;
				special.branch	<= instr1(3 downto 0); -- x"8" ~ x"D"
				special.A		<= A_ALU;
				special.B		<= B_C;
				special.C		<= C_LD1;
				special.ALUopd1_sel <= ALU1_B;
				
			when "010" =>		-- dup
				if(instr1(2 downto 1) = "00") then -- dup_x1 D0 / dup2 D1
					special.Cen		<= enable;
					special.C		<= C_A;
				end if;
				special.W1_en	<= enable;
				if(instr1(2 downto 0) = "001") then -- dup2 D1
					special.W2_en	<= enable;
					special.sp_offset  <= "010";	-- sp+2
				elsif (instr1(2 downto 0) = "110") then -- dup2_x2_part2 D6
					special.SD2_sel   <= SD2_B;
					special.W2_en	<= enable;
					special.sp_offset  <= "001";	-- sp+1
				elsif (instr1(2 downto 0) = "101") then -- dup2_x1 D5
					special.SD1_sel <= SD1_B;
					special.SD2_sel <= SD2_A;
					special.W2_en	<= enable;
					special.sp_offset  <= "010";	-- sp+2
				else -- dup_x1 D0 / dup_x2 D2
					special.sp_offset  <= "001";	-- sp+1
				end if;
				if(instr1(2 downto 0) = "000") then -- dup_x1 D0
					special.SD1_sel <= SD1_C;
				elsif(instr1(2 downto 0) = "010") then -- dup_x2 D2
					special.SD1_sel <= SD1_A;
				end if;
				
			when "011" =>		-- sp-1   ref_load_w  D8 / ref_load_s  D9 / ref_load_b  DA / stjpc DB
								--		ref_store_w DC / ref_store_s DD / ref_store_b DE / ref_store_l DF
				special.Aen		<= enable;
				special.Ben		<= enable;
				special.Cen		<= enable;
				special.A		<= A_ALU;	-- A <= B
				special.B		<= B_C;
				special.C		<= C_LD1;
				special.ALUopd1_sel <= ALU1_B;
				special.sp_offset  <= "111";	-- sp-1
				special_R1_en	<= enable;
				
			when "100" =>
				if (instr1 = x"E1") then --lreturn_off
					special.Aen		<= enable;
					special.Ben		<= enable;
					special.Cen		<= enable;
					special.A		<= A_lrtn;
					special.B		<= B_lrtn;
					special.C		<= C_B;
					special.sp_offset  <= "001";	-- sp+1
					special.SD1_sel   <= SD1_C;
					special.W1_en	<= enable;
				end if;
			when "101" => null;
			
			when "110" =>		-- sp	swap / goto / exchange	
				case instr1(2 downto 0) is
					when "000" =>				-- swap F0
						special.Aen	<= enable;
						special.Ben	<= enable;
						special.A		<= A_ALU;
						special.B		<= B_A;
						special.ALUopd1_sel <= ALU1_B;
					when "001" =>				-- goto F1
						special.branch	<= "1110";
					when "010" =>				-- loop pop for multianewarray F2
						special.Aen	<= enable;
						special.Ben	<= enable;
						special.Cen	<= enable;
						special.A		<= A_ALU;
						special.B		<= B_C;
						special.C		<= C_LD1;
						special.ALUopd1_sel <= ALU1_B;
						special.sp_offset <= "111"; -- sp-1
						special_R1_en   <= enable;
					when "011" =>				-- exchange F3 (for ireturn : A->C B->A C->B)
						special.Aen	<= enable;
						special.Ben	<= enable;
						special.Cen	<= enable;
						special.A		<= A_ALU;
						special.B		<= B_C;
						special.C		<= C_A;
						special.ALUopd1_sel <= ALU1_B;
						special.sp_offset <= "111"; -- sp-1
						special_R1_en   <= enable;
					when "100" =>				-- get field ref back for 64-bits getfield F4
						special.Aen		<= enable;
						special.Ben		<= enable;
						special.Cen		<= enable;
						special.A		<= A_field;
						special.B		<= B_A;
						special.C		<= C_B;
						special.sp_offset  <= "001";	-- sp+1
						special.SD1_sel   <= SD1_C;
						special.W1_en	<= enable;
					when others => null;	
				end case;
				
			when "111" => 
				if (instr1 = x"FB") then -- ref_load_l
					if (larray_lower_flag_reg = '0') then
						special.Aen		<= enable;
						special.Ben		<= enable;
						special.Cen		<= enable;
						special.A		<= A_ALU;	-- A <= B
						special.B		<= B_C;
						special.C		<= C_LD1;
						special.ALUopd1_sel <= ALU1_B;
						special.sp_offset  <= "111";	-- sp-1
						special_R1_en	<= enable;
					else
						special.Cen		<= enable;
						special.C		<= C_LD1;
						special.sp_offset  <= "111";	-- sp-1
						special_R1_en	<= enable;
					end if;
				elsif (instr1 = x"FC") then --get dim-size for multianewarray
					special.Aen		<= enable;
					special.Ben		<= enable;
					special.Cen		<= enable;
					special.A		<= A_dim;
					special.B		<= B_A;
					special.C		<= C_B;
					special.sp_offset  <= "001";
					special.SD1_sel	<= SD1_C;
					special.W1_en	<= enable;
				end if;
			when others => null;
		end case;	
	end process;
	
	normal_DecodeUnit :
	process(instr1, instr2, special, instr_type, special_R1_sel, special_R2_sel, special_R1_en, special_R2_en) begin
		-- reset ctrl_tmp
		ctrl_tmp				<= ctrl_nop;
		MemRead_ctrl.R1_en	<= disable;
		MemRead_ctrl.R2_en	<= disable;
		MemRead_ctrl.R1_sel	<= R1_sp;
		MemRead_ctrl.R2_sel	<= R2_sp;
		nop_store_flag		<= '0';
		
		case instr_type is
			-- load-load
			when "0000" =>
				ctrl_tmp.Aen		<= enable;
				ctrl_tmp.Ben		<= enable;
				ctrl_tmp.Cen		<= enable;
				-- instr1 = dup
				if(instr1(5 downto 0) = "111000" ) then
					ctrl_tmp.ALUopd1_sel   <= ALU1_A;
				else
					ctrl_tmp.ALUopd1_sel   <= ALU1_LD1;
				end if;
				-- instr2 = dup
				if(instr2(5 downto 0) = "111000" ) then
					ctrl_tmp.A		<= A_ALU; 
				else
					ctrl_tmp.A		<= A_LD2; 
				end if;
				ctrl_tmp.B			<= B_ALU;
				ctrl_tmp.C			<= C_A;
				MemRead_ctrl.R1_sel	<= R1_load1_addr;
				MemRead_ctrl.R2_sel	<= R2_load2_addr;
				ctrl_tmp.W1_en		<= enable;
				ctrl_tmp.W2_en		<= enable;
				ctrl_tmp.sp_offset	<= "010";
				-- instr1 = ldval_<n> / ldval_opd
				if(instr1(5 downto 4) = "01") then
					MemRead_ctrl.R1_en <= enable;
				else	-- ldimm<n> / ldopd / ldopd2 / ldjpc / ldvp / ldsp / dup
					ctrl_tmp.LD1_sel   <= LD1_special;
				end if;
				-- instr2 = ldval_<n> / ldval_opd
				if(instr2(5 downto 4) = "01") then
					MemRead_ctrl.R2_en <= enable;
				else	-- ldimm<n> / ldopd / ldopd2 / ldjpc / ldvp / ldsp / dup
					ctrl_tmp.LD2_sel   <= LD2_special;
				end if;
				
			-- load-store	
			when "0001" =>
				-- instr1 = dup
				if(instr1(5 downto 0) = "111000") then  
					ctrl_tmp.ALUopd1_sel   <= ALU1_A;
				else
					ctrl_tmp.ALUopd1_sel   <= ALU1_LD1;
				end if;
				MemRead_ctrl.R1_sel	<= R1_load1_addr;
				ctrl_tmp.W2_sel		<= W2_store2_addr;
				ctrl_tmp.SD2_sel	<= SD2_ALU;
				-- instr1 = ldval_<n> / ldval_opd
				if(instr1(5 downto 4) = "01") then
					MemRead_ctrl.R1_en <= enable;
				else	-- ldimm<n> / ldopd / ldopd2 / ldjpc / ldvp / ldsp / dup
					ctrl_tmp.LD1_sel   <= LD1_special;
				end if;
				-- instr2 = store_<n> or store + opd
				if(instr2(5 downto 4) = "01") then
					ctrl_tmp.W2_en	<= enable;
				end if;
				-- instr2 = stvp or stsp
				if(instr2(5 downto 1) = "11000") then
					if(instr2(0) = '0') then -- stvp 70
						ctrl_tmp.stvp2 <= enable;
					else					-- stsp 71
						ctrl_tmp.stsp2 <= enable;
					end if;
				end if;
				
			-- load-ALU
			when "0010" =>
			
				ctrl_tmp.ALU		<= instr2(3 downto 0);	
				ctrl_tmp.Aen		<= enable;
				ctrl_tmp.A			<= A_ALU;
				MemRead_ctrl.R1_sel	<= R1_load1_addr;
				
				-- instr1 = dup
				if(instr1(5 downto 0) = "111000") then
					ctrl_tmp.ALUopd1_sel <= ALU1_A;
				else
					ctrl_tmp.ALUopd1_sel <= ALU1_LD1;
				end if;
				ctrl_tmp.ALUopd2_sel   <= ALU2_A;
				
				-- instr1 = ldval_<n> / ldval_opd
				if(instr1(5 downto 4) = "01") then
					MemRead_ctrl.R1_en <= enable;
				else	-- ldimm<n> / ldopd / ldopd2 / ldjpc / ldvp / ldsp / dup
					ctrl_tmp.LD1_sel   <= LD1_special;
				end if;
				
			-- load-nop
			-- load-special	blocked in fetch
			when "0011" =>
				-- instr1 = dup
				if(instr1(5 downto 0) = "111000") then
					ctrl_tmp.Aen	<= disable;
				else
					ctrl_tmp.Aen	<= enable;
				end if;
				ctrl_tmp.Ben		<= enable;
				ctrl_tmp.Cen		<= enable;
				ctrl_tmp.A			<= A_LD1;
				ctrl_tmp.B			<= B_A;
				ctrl_tmp.C			<= C_B;
				MemRead_ctrl.R1_sel	<= R1_load1_addr;
				ctrl_tmp.SD1_sel	<= SD1_C;
				ctrl_tmp.W1_en		<= enable;
				ctrl_tmp.sp_offset	<= "001";
				-- instr1 = ldval_<n> / ldval_opd
				if(instr1(5 downto 4) = "01") then
					MemRead_ctrl.R1_en <= enable;
				else	-- ldimm<n> / ldopd / ldopd2 / ldjpc / ldvp / ldsp / dup
					ctrl_tmp.LD1_sel   <= LD1_special;
				end if;
				
			-- store-load
			when "0100" =>
				-- instr2 = dup
				if(instr2(5 downto 0) = "111000") then
					ctrl_tmp.A		<= A_ALU;
				else
					ctrl_tmp.A		<= A_LD2;
				end if;
				-- same addr
				if(instr1(5 downto 0) = instr2(5 downto 0)) then
					ctrl_tmp.Aen	<= disable;
				else
					ctrl_tmp.Aen	<= enable;
				end if;
				ctrl_tmp.ALUopd1_sel   <= ALU1_B;
				-- MemRead_ctrl.R1_en	<= enable;
				MemRead_ctrl.R2_sel	<= R2_load2_addr;
				ctrl_tmp.W1_sel		<= W1_store1_addr;
				ctrl_tmp.SD1_sel	<= SD1_A;
				-- instr1 = store_<n> or store + opd
				if(instr1(5 downto 4) = "01") then
					ctrl_tmp.W1_en	<= enable;
				end if;
				-- instr1 = stvp or stsp
				if(instr1(5 downto 1) = "11000") then
					if(instr1(0) = '0') then -- stvp
						ctrl_tmp.stvp1 <= enable;
					else					-- stsp
						ctrl_tmp.stsp1 <= enable;
					end if;
				end if;
				-- instr2 = ldval_<n> / ldval_opd
				if(instr2(5 downto 4) = "01") then
					MemRead_ctrl.R2_en <= enable;
				else	-- ldimm<n> / ldopd / ldopd2 / ldjpc / ldvp / ldsp / dup
					ctrl_tmp.LD2_sel   <= LD2_special;
				end if;
				
			-- store-store
			when "0101" =>
				ctrl_tmp.Aen		<= enable;
				ctrl_tmp.Ben		<= enable;
				ctrl_tmp.Cen		<= enable;
				ctrl_tmp.A			<= A_C;
				ctrl_tmp.B			<= B_LD1;
				ctrl_tmp.C			<= C_LD2;
				ctrl_tmp.W1_sel		<= W1_store1_addr;
				ctrl_tmp.W2_sel		<= W2_store2_addr;
				ctrl_tmp.SD1_sel	<= SD1_A;
				ctrl_tmp.SD2_sel	<= SD2_B;
				ctrl_tmp.sp_offset	<= "110";
				MemRead_ctrl.R1_en	<= enable;
				MemRead_ctrl.R2_en	<= enable;
				-- instr1 = store_<n> or store + opd
				if(instr1(5 downto 4) = "01") then
					ctrl_tmp.W1_en	<= enable;
				end if;
				-- instr1 = stvp or stsp
				if(instr1(5 downto 1) = "11000") then
					if(instr1(0) = '0') then -- stvp
						ctrl_tmp.stvp1 <= enable;
					else					-- stsp
						ctrl_tmp.stsp1 <= enable;
					end if;
				end if;
				-- instr2 = store_<n> or store + opd
				if(instr2(5 downto 4) = "01") then
					ctrl_tmp.W2_en	<= enable;
				end if;
				-- instr2 = stvp or stsp
				if(instr2(5 downto 1) = "11000") then
					if(instr2(0) = '0') then -- stvp
						ctrl_tmp.stvp2 <= enable;
					else					-- stsp
						ctrl_tmp.stsp2 <= enable;
					end if;
				end if;
				
			-- store-ALU
			when "0110" =>
			
				ctrl_tmp.W1_sel		<= W1_store1_addr;
				MemRead_ctrl.R1_en	<= enable;
				ctrl_tmp.ALU		<= instr2(3 downto 0);
				ctrl_tmp.ALUopd1_sel   <= ALU1_B;
				ctrl_tmp.SD1_sel	<= SD1_A;
				ctrl_tmp.A			<= A_ALU;
				ctrl_tmp.Aen		<= enable;
				ctrl_tmp.Ben		<= enable;
				ctrl_tmp.Cen		<= enable;
				
				ctrl_tmp.B			<= B_LD1;
				ctrl_tmp.C			<= C_LD2;
				ctrl_tmp.ALUopd2_sel   <= ALU2_C;
				ctrl_tmp.sp_offset	<= "110";
				MemRead_ctrl.R2_en	<= enable; -- <= 2011_10_04 add
				
				-- instr1 = store_< n> or store + opd
				if(instr1(5 downto 4) = "01") then
					ctrl_tmp.W1_en	<= enable;
				end if;
				-- instr1 = stvp or stsp
				if(instr1(5 downto 1) = "11000") then
					if(instr1(0) = '0') then -- stvp
						ctrl_tmp.stvp1 <= enable;
					else					-- stsp
						ctrl_tmp.stsp1 <= enable;
					end if;
				end if;

				
			-- store-nop
			-- store-special	blocked in fetch
			when "0111" =>
				ctrl_tmp.Aen		<= enable;
				ctrl_tmp.Ben		<= enable;
				ctrl_tmp.Cen		<= enable;			
				ctrl_tmp.A			<= A_ALU;
				ctrl_tmp.B			<= B_C;
				ctrl_tmp.C			<= C_LD1;
				ctrl_tmp.ALUopd1_sel   <= ALU1_B;
				ctrl_tmp.SD1_sel	<= SD1_A;
				ctrl_tmp.W1_sel		<= W1_store1_addr;
				ctrl_tmp.sp_offset	<= "111";
				MemRead_ctrl.R1_en	<= enable;
				-- instr1 = store_<n> or store + opd
				if(instr1(5 downto 4) = "01") then
					ctrl_tmp.W1_en	<= enable;
				end if;
				-- instr1 = stvp or stsp
				if(instr1(5 downto 1) = "11000") then
					if(instr1(0) = '0') then -- stvp
						ctrl_tmp.stvp1 <= enable;
					else					-- stsp
						ctrl_tmp.stsp1 <= enable;
					end if;
				end if;
				
			-- ALU-load
			when "1000" =>
				ctrl_tmp.Aen		<= enable;
				ctrl_tmp.Ben		<= enable;
				ctrl_tmp.B			<= B_ALU;
				ctrl_tmp.ALUopd1_sel   <= ALU1_A;
				ctrl_tmp.ALU		<= instr1(3 downto 0);
				MemRead_ctrl.R2_sel	<= R2_load2_addr;
				-- instr2 = ldval_<n> / ldval_opd
				if(instr2(5 downto 4) = "01") then
					MemRead_ctrl.R2_en <= enable;
				else	-- ldimm<n> / ldopd / ldopd2 / ldjpc / ldvp / ldsp / dup
					ctrl_tmp.LD2_sel   <= LD2_special;
				end if;
				
				-- instr2 = dup
				if(instr2(5 downto 0) = "111000" ) then
					ctrl_tmp.A		<= A_ALU; 
				else
					ctrl_tmp.A		<= A_LD2; 
				end if;
				ctrl_tmp.ALUopd2_sel   <= ALU2_B;
				
			-- ALU-store
			when "1001" =>
			
				ctrl_tmp.Aen		<= enable;
				ctrl_tmp.Ben		<= enable;
				ctrl_tmp.Cen		<= enable; 
				ctrl_tmp.ALU		<= instr1(3 downto 0); 
				ctrl_tmp.ALUopd1_sel   <= ALU1_A;
				ctrl_tmp.SD2_sel	<= SD2_ALU;
				ctrl_tmp.W2_sel		<= W2_store2_addr;
				MemRead_ctrl.R1_en	<= enable;	
						
				ctrl_tmp.A			<= A_C;
				ctrl_tmp.B			<= B_LD1;
				ctrl_tmp.C			<= C_LD2;
				ctrl_tmp.ALUopd2_sel   <= ALU2_B;
				ctrl_tmp.sp_offset	<= "110";
				MemRead_ctrl.R2_en	<= enable;
				-- instr2 = store_<n> or store + opd
				if(instr2(5 downto 4) = "01") then
					ctrl_tmp.W2_en	<= enable;
				end if;
				-- instr2 = stvp or stsp
				if(instr2(5 downto 1) = "11000") then
					if(instr2(0) = '0') then -- stvp
						ctrl_tmp.stvp2 <= enable;
					else					-- stsp
						ctrl_tmp.stsp2 <= enable;
					end if;
				end if;
				
			-- ALU-ALU
			when "1010" => 
				-- not supported
				
			-- ALU-nop or ALU-special
			when "1011" =>
				
				ctrl_tmp.Aen		<= enable;
				ctrl_tmp.A			<= A_ALU;
				ctrl_tmp.ALUopd1_sel   <= ALU1_A;
				ctrl_tmp.ALU		<= instr1(3 downto 0);
				
				ctrl_tmp.Ben		<= enable;
				ctrl_tmp.Cen		<= enable; 
				ctrl_tmp.B			<= B_C;
				ctrl_tmp.C			<= C_LD1;
				ctrl_tmp.ALUopd2_sel   <= ALU2_B;
				ctrl_tmp.sp_offset	<= "111";
				MemRead_ctrl.R1_en	<= enable;
				
			-- nop-load or special-load
			when "1100" =>			
				if(instr1(5 downto 0) = "111111") then	
					-- instr2 = dup
					if(instr2(5 downto 0) = "111000") then
						ctrl_tmp.Aen	<= disable;
					else
						ctrl_tmp.Aen	<= enable;
					end if;
					ctrl_tmp.Ben		<= enable;
					ctrl_tmp.Cen		<= enable;
					ctrl_tmp.A			<= A_LD2;
					ctrl_tmp.B			<= B_A;
					ctrl_tmp.C			<= C_B;
					MemRead_ctrl.R2_sel	<= R2_load2_addr;
					ctrl_tmp.SD1_sel	<= SD1_C;
					ctrl_tmp.W1_en		<= enable;
					ctrl_tmp.sp_offset	<= "001";
					-- instr2 = ldval_<n> / ldval_opd
					if(instr2(5 downto 4) = "01") then
						MemRead_ctrl.R2_en <= enable;
					else	-- ldimm<n> / ldopd / ldopd2 / ldjpc / ldvp / ldsp / dup
						ctrl_tmp.LD2_sel   <= LD2_special;
					end if;
				else
					ctrl_tmp			<= special;
					MemRead_ctrl.R1_sel	<= special_R1_sel;
					MemRead_ctrl.R2_sel	<= special_R2_sel;
					MemRead_ctrl.R1_en	<= special_R1_en;
					MemRead_ctrl.R2_en	<= special_R2_en;
				end if;
				
			-- nop-store or special-store	
			when "1101" =>
				if(instr1(5 downto 0) = "111111") then
					ctrl_tmp.Aen		<= enable;
					ctrl_tmp.Ben		<= enable;
					ctrl_tmp.Cen		<= enable;			
					ctrl_tmp.A			<= A_ALU;
					ctrl_tmp.B			<= B_C;
					ctrl_tmp.C			<= C_LD1;
					ctrl_tmp.ALUopd1_sel   <= ALU1_B;
					ctrl_tmp.SD1_sel	<= SD1_A;
					ctrl_tmp.W1_sel		<= W1_store1_addr;
					nop_store_flag		<= '1';
					ctrl_tmp.sp_offset	<= "111";
					MemRead_ctrl.R1_en	<= enable;
					-- instr2 = store_<n> or store + opd
					if(instr2(5 downto 4) = "01") then
						ctrl_tmp.W1_en	<= enable;
					end if;
					-- instr2 = stvp or stsp
					if(instr2(5 downto 1) = "11000") then
						if(instr2(0) = '0') then -- stvp
							ctrl_tmp.stvp1 <= enable;
						else					-- stsp
							ctrl_tmp.stsp1 <= enable;
						end if;
					end if;
				else
					ctrl_tmp			<= special;
					MemRead_ctrl.R1_sel	<= special_R1_sel;
					MemRead_ctrl.R2_sel	<= special_R2_sel;
					MemRead_ctrl.R1_en	<= special_R1_en;
					MemRead_ctrl.R2_en	<= special_R2_en;
				end if; 
				
			-- nop-ALU or special-ALU
			when "1110" =>
				if (instr1 = X"D4") then --long ALU
					ctrl_tmp.Aen		<= enable;
					ctrl_tmp.Ben		<= enable;
					ctrl_tmp.Cen		<= enable;
					ctrl_tmp.ALU		<= instr2(3 downto 0);
					case instr2(3 downto 0) is
						when "1100" =>
							ctrl_tmp.sp_offset <= "111";
							ctrl_tmp.C			<= C_LD1;
							ctrl_tmp.ALUopd2_sel   <= ALU2_C;
						when "1101" =>
							ctrl_tmp.sp_offset <= "111";
							ctrl_tmp.C			<= C_LD1;
							ctrl_tmp.ALUopd2_sel   <= ALU2_C;
						when "1110" =>
							ctrl_tmp.sp_offset <= "111";
							ctrl_tmp.C			<= C_LD1;
							ctrl_tmp.ALUopd2_sel   <= ALU2_C;
						when others =>
							ctrl_tmp.sp_offset <= "110";
							ctrl_tmp.C			<= C_LD2;
							ctrl_tmp.ALUopd2_sel   <= ALU2_B;
					end case;
					MemRead_ctrl.R1_en	<= enable;
					MemRead_ctrl.R2_en	<= enable;
				else
					if(instr1(5 downto 0) = "111111") then 
						ctrl_tmp.Aen		<= enable;
						ctrl_tmp.ALU		<= instr2(3 downto 0);
						ctrl_tmp.A			<= A_ALU;
						ctrl_tmp.ALUopd1_sel   <= ALU1_A;
						
						ctrl_tmp.Ben		<= enable;
						ctrl_tmp.Cen		<= enable; 
						ctrl_tmp.B			<= B_C;
						ctrl_tmp.C			<= C_LD1;
						ctrl_tmp.ALUopd2_sel   <= ALU2_B;
						ctrl_tmp.sp_offset	<= "111";
						MemRead_ctrl.R1_en	<= enable;
					else
						ctrl_tmp			<= special;
						MemRead_ctrl.R1_sel	<= special_R1_sel;
						MemRead_ctrl.R2_sel	<= special_R2_sel;
						MemRead_ctrl.R1_en	<= special_R1_en;
						MemRead_ctrl.R2_en	<= special_R2_en;
					end if;
				end if;
			-- nop-nop or nop-special or special-nop or special-special
			when others =>
				if(instr1(5 downto 0) /= "111111") then	
					ctrl_tmp			<= special;
					MemRead_ctrl.R1_sel	<= special_R1_sel;
					MemRead_ctrl.R2_sel	<= special_R2_sel;
					MemRead_ctrl.R1_en	<= special_R1_en;
					MemRead_ctrl.R2_en	<= special_R2_en;
				end if;				
		end case;
	end process;
	
	
	load_immediate1_CtrlLogic :
	process(instr1, immROM1_val, operand_0, operand_1, operand_2, operand_3,now_mthd_id,  
			load_immediate1_reg, branch_trigger, vp, sp, instruction_buffer_0, now_cls_id, reg_valid,
			DR_addr, stall_decode_stage) begin
		load_immediate1_reg_w <= load_immediate1_reg ;
		if(stall_decode_stage = '0') then
			case instr1(5 downto 4) is
				when "00" =>
					if(instr1(3) = '0') then -- ldimm 0 1 2 3 4 5
						load_immediate1_reg_w <= X"0000000" & instr1(3 downto 0);
					else					-- immROM result ldimm 8 9 10 12
						load_immediate1_reg_w <= immROM1_val;
					end if;
				when "10" =>
					if(instr1(3 downto 2) = "00") then -- ldopd   --fox
						case instr1(1 downto 0) is
							when "00" =>
								if(operand_0(7) = '0') then
									load_immediate1_reg_w <= X"000000" & operand_0;
								else
									load_immediate1_reg_w <= X"FFFFFF" & operand_0;
								end if;
							when "01" =>
								if(operand_1(7) = '0') then
									load_immediate1_reg_w <= X"000000" & operand_1;
								else
									load_immediate1_reg_w <= X"FFFFFF" & operand_1;
								end if;
							when "10" =>
								load_immediate1_reg_w <= X"000000" & operand_2;
							when "11" =>
								load_immediate1_reg_w <= X"000000" & operand_3;
							when others =>
						end case;
					elsif(instr1(3 downto 2) = "10")  then   -- ldopd2   --fox
						if(operand_0(7) = '0') then
							load_immediate1_reg_w <= X"0000" & operand_0 & operand_1;
						else
							load_immediate1_reg_w <= X"FFFF" & operand_0 & operand_1;
						end if;
					else -- ldopd4 , for tableswitch/lookupswitch   --fox
						load_immediate1_reg_w <= operand_0 & operand_1 & operand_2 & operand_3;
					end if;
				when "11" =>
					case instr1(2 downto 0) is
						when "000" =>		-- ldjpc
							load_immediate1_reg_w <= now_mthd_id & branch_trigger;	-- might be bug
						when "001" =>		-- ldvp
							load_immediate1_reg_w <= now_cls_id & reg_valid & "00" & vp;
						when "010" =>		-- ldsp
							load_immediate1_reg_w <= X"0000" & "000000" & sp;
						when "100" =>		-- ldc
							load_immediate1_reg_w <= DR_addr;
						-- modified by T.H.Wu , 2013.8.20 , a bug about clinit 
						--when "101" =>		-- ldjpc-clinit	
				--load_immediate1_reg_w <= now_mthd_id & (branch_trigger - 3);	-- the position just before the bytecode getStatic 
						when others => null;
					end case;
				when others => null;
			end case;
		end if;
	end process;
	
	load_immediate2_CtrlLogic :
	process(instr2, immROM2_val, operand_0, operand_1, operand_2, operand_3,now_mthd_id, 
			branch_trigger, vp, sp, instruction_buffer_0, now_cls_id, reg_valid,DR_addr, 
			load_immediate2_reg, stall_decode_stage
	) begin
		load_immediate2_reg_w <= load_immediate2_reg;
		if(stall_decode_stage = '0') then
		case instr2(5 downto 4) is
			when "00" =>
				if(instr2(3) = '0') then -- ldimm 0 1 2 3 4 5
					load_immediate2_reg_w <= X"0000000" & instr2(3 downto 0);
				else					-- immROM result  ldimm 8 9 12
					load_immediate2_reg_w <= immROM2_val;
				end if;
			when "10" =>
				if(instr2(3) = '0') then -- ldopd
					case instr2(1 downto 0) is
						when "00" =>
							if(operand_0(7) = '0') then
								load_immediate2_reg_w <= X"000000" & operand_0;
							else
								load_immediate2_reg_w <= X"FFFFFF" & operand_0;
							end if;
						when "01" =>
							if(operand_1(7) = '0') then
								load_immediate2_reg_w <= X"000000" & operand_1;
							else
								load_immediate2_reg_w <= X"FFFFFF" & operand_1;
							end if;
						when "10" =>
							load_immediate2_reg_w <= X"000000" & operand_2;
						when "11" =>
							load_immediate2_reg_w <= X"000000" & operand_3;
						when others =>
					end case;
				elsif(instr2(3 downto 2) = "10")   then  --ldopd2
					if(operand_0(7) = '0') then
						load_immediate2_reg_w <= X"0000" & operand_0 & operand_1;
					else
						load_immediate2_reg_w <= X"FFFF" & operand_0 & operand_1;
					end if;
				else -- ldopd4
					load_immediate2_reg_w <= operand_0 & operand_1 & operand_2 & operand_3;
				end if;
			when "11" =>
				case instr2(2 downto 0) is
					when "000" =>		-- ldjpc
						load_immediate2_reg_w <= now_mthd_id & branch_trigger;	-- might be bug
					when "001" =>		-- ldvp
						load_immediate2_reg_w <= now_cls_id & reg_valid & "00" & vp;
					when "010" =>		-- ldsp
						load_immediate2_reg_w <= X"0000" & "000000" & sp;
					when "100" =>		-- ldc
						load_immediate2_reg_w <= DR_addr;
					-- modified by T.H.Wu , 2013.8.20 , a bug about clinit 
					--when "101" => -- ldjpc-clinit 
					--	load_immediate2_reg_w <= now_mthd_id & (branch_trigger - 3);	-- the position just before the bytecode getStatic
					when others => null;
				end case;
			when others => null;
		end case;
		end if;
	end process;
	
	-- modified by T.H.Wu , 2013.9.18
	load_immediate1  <= load_immediate1_reg;
	load_immediate2  <= load_immediate2_reg;

	
	LocalVariable_1 <= instr1   (1 downto 0) when instr1(3) = '1' else
					operand_0(1 downto 0);
	LocalVariable_2 <= instr2   (1 downto 0) when instr2(3) = '1' else
					operand_0(1 downto 0);
	
	Opd0IsLessThan4 <= not(operand_0(7) or operand_0(6) or operand_0(5) or operand_0(4) or operand_0(3) or operand_0(2));
	RegFlag1 <= instr1(3) or  Opd0IsLessThan4;
	RegFlag2 <= instr2(3) or  Opd0IsLessThan4;
	StLV4Flag <= '1' when instr1 = X"5C" or (instr1 = X"51" and Operand_0 = X"03") else '0';  -- for dstore, lstore, dstore_3, lstore_3
	LdLV4Flag <= '1' when instr2 = X"1C" or (instr2 = X"11" and Operand_0 = X"03") else '0';  -- for dload, lload, dload_3, lload_3
	StOpdPlus1Flag <= '1' when instr1 = X"51" else '0';  -- for dstore, lstore
	LdOpdPlus1Flag <= '1' when instr2 = X"11" else '0';  -- for dload, lload
	
	LS1_addr <= vp + "100" when StLV4Flag = '1' else
				vp + operand_0 + '1' when StOpdPlus1Flag = '1' else
				x"00" & LocalVariable_1 when RegFlag1 = '1' else
				vp + operand_0;
	LS2_addr <= vp + "100" when LdLV4Flag = '1' else
				vp + operand_0 + '1' when LdOpdPlus1Flag = '1' else
				x"00" & LocalVariable_2 when RegFlag2 = '1' else
				vp + operand_0;
			
	MemRead_ctrl.load1_addr <= LS1_addr;
	MemRead_ctrl.load2_addr <= LS2_addr;
	MemRead_ctrl.R1_RegFlag <= RegFlag1 when instr1(7 downto 4) = x"1" else '0';
	MemRead_ctrl.R2_RegFlag <= RegFlag2 when instr2(7 downto 4) = x"1" else '0';
	
	branch_destination   <= BranchDestination_tmp;
	switch_instr_revert_code_seq <= '1' when (switch_code_revert = '1' and switch_npair /= x"00000000") else '0';
	
	mem2LVreg_1_decode	<= mem2LVreg_1_reg or TH_mgt_CS_reset_lv; -- by fox
	mem2LVreg_2_decode	<= mem2LVreg_2_reg;
	
	signal_flag_CtrlUnit :
	process(clk, Rst, TH_mgt_context_switch)
		variable RegFlag1_tmp, RegFlag2_tmp : std_logic;
	begin
		if(Rst = '1' or TH_mgt_context_switch='1') then -- by fox , reset all signal at one clock ??
			DynamicResolution_en  <= '0';
			new_obj_flag		<= '0';
			invoke_flag		<= '0';
			static_flag		<= '0';
			field_wr			<= '0';
			ldc_flag			<= '0';
			ldc_w_flag			<= '0';
			ldc2_w_flag			<= '0';
			stjpc_flag			<= '0';
			return_flag		<= '0';
			ireturn_flag		<= '0';
			lreturn_flag		<= '0';
			lrtnvalue_flag		<= '0';
			larray_flag				<= '0';
			larray_lower_flag		<= '0';
			larray_lower_flag_reg	<= '0';
			refload_req		<= '0';
			refstore_req		<= '0';
			interrupt_req_decode  <= '0';
			interrupt_func_decode <= (others => '0');
			load_immediate1_reg   <= (others => '0');
			load_immediate2_reg   <= (others => '0');
			ctrl				<= ctrl_nop;
			store1_addr		<= (others => '0');
			store2_addr		<= (others => '0');
			W1_RegFlag			<= '0';
			W2_RegFlag			<= '0';
			BranchDestination_tmp <= (others => '0');
			mem2LVreg_1_reg	<= '0';
			mem2LVreg_2_reg	<= '0';
			stsp_s_flag		<= '0';
			refAcs_sel		<= (others => '1');
			xcptn_thrown_bytecode_r <= '0';
			getStatic			<= '0';
			newarray_flag 		<= '0';
			clear_newarraycopy_flag <= '0';  
			JAIP2COOR_cmd_monitor_enter_req <= '0';
			JAIP2COOR_cmd_monitor_exit_req  <= '0';
			Long_enable <= '0';
			multiarray_flag <= '0';
		elsif(rising_edge(clk)) then
		
			--0x5X:store
			if(instr1(7 downto 4) = x"5") then
				RegFlag1_tmp := RegFlag1;
			else
				RegFlag1_tmp := '0';
			end if;
			if(instr2(7 downto 4) = x"5") then
				RegFlag2_tmp := RegFlag2;
			else
				RegFlag2_tmp := '0';
			end if;
			if(stall_decode_stage = '0') then
				if(nop_store_flag = '0') then
					store1_addr <= LS1_addr;
					W1_RegFlag  <= RegFlag1_tmp;
				else
					store1_addr <= LS2_addr;
					W1_RegFlag  <= RegFlag2_tmp;
				end if;
				store2_addr <= LS2_addr;
				W2_RegFlag  <= RegFlag2_tmp;
			end if;
	-------- instr1 flag start
				-- modified by T.H.Wu, 2014.2.11, for monitorenter / monitorexit
			if(instr1(7 downto 1)="1111100") then 
				JAIP2COOR_cmd_monitor_enter_req	<= not instr1(0); 
				JAIP2COOR_cmd_monitor_exit_req	<= instr1(0); 
			else
				JAIP2COOR_cmd_monitor_enter_req <= '0'; 
				JAIP2COOR_cmd_monitor_exit_req <= '0';
			end if;
				
			if (instr1 = X"D4") then
				Long_enable <= '1';
			elsif (instr1 /= X"FF") then
				Long_enable <= '0';
			end if;
			
			if (instr1(7 downto 3) = "11011") then
				-- D8 - DE
				if(((instr1(2) = '0' or instr1(1) = '0' or instr1(0) = '0')) and stall_decode_stage = '0')then
					refAcs_sel <= instr1(1 downto 0);
				else -- DF
					refAcs_sel <= "00";
				end if;
			elsif (instr1 = x"FB") then
				refAcs_sel <= "00";
			elsif(external_access_cmplt = '1') then
				--refAcs_sel <= (others => '0'); -- modified by T.H.Wu , 2013.9.5 , this may go wrong if executing in multicore JAIP
				refAcs_sel <= (others => '1');
			end if;
			
			-- D8~DA refload
			if (instr1(7 downto 2) = "110110" and external_load_req = '0' and stall_decode_stage = '0')then
				refload_req <= not (instr1(0) and instr1(1));
			elsif(external_access_cmplt = '1') then
				refload_req <= '0';
			end if;
			
			-- DC~DE refstore
			if (instr1(7 downto 2) = "110111" and external_store_req = '0' and stall_decode_stage = '0')then
				refstore_req <= not (instr1(0) and instr1(1));
			elsif(external_access_cmplt = '1') then
				refstore_req <= '0';
			end if;
			
			-- FB refload_l
			if (instr1 = x"FB" and external_load_req = '0' and stall_decode_stage = '0') then
				refload_req <= '1';
				larray_flag <= '1';
				larray_lower_flag <= not larray_lower_flag_reg;
				larray_lower_flag_reg <= not larray_lower_flag_reg;
			-- DF refstore_l
			elsif (instr1 = x"DF" and external_store_req = '0' and stall_decode_stage = '0') then
				refstore_req <= '1';
				larray_flag <= '1';
				larray_lower_flag <= not larray_lower_flag_reg;
				larray_lower_flag_reg <= not larray_lower_flag_reg;
			elsif(external_access_cmplt = '1') then
				larray_flag	<= '0';
			end if;
	
			--store jpc
			if(instr1 = x"DB") then
				stjpc_flag <= '1';
			else
				stjpc_flag <= '0';
			end if;
			
			--multianewarray   trigger flag
			if(instr1 = x"F7") then
				dim_count_flag <= '1';
				dim <= operand_2;
				multiarray_flag <= '1';
			elsif(instr1 /= x"F2") then
				dim_count_flag <= '0';
				if(mularr_end_flag = '1') then
					multiarray_flag <= '0';
				end if;
			end if;
			
			--newarray / anewarray
			if(instr2 = x"FA") then
				newarray_flag <= '1';
			elsif(external_access_cmplt = '1') then
				clear_newarraycopy_flag <= '1';
				if(clear_newarraycopy_flag = '1') then		-- clear newarray_flag just after 2 complt
					newarray_flag <= '0';
					clear_newarraycopy_flag <= '0';
				end if;
			end if;
				
			--return
			if(instr1 = x"E5") then
				stsp_s_flag <= '1';
			else
				stsp_s_flag <= '0';
			end if;
	
			--invoke / return / clinit
			if(instr1 = x"E6") then
				mem2LVreg_1_reg <= '1';
			else
				mem2LVreg_1_reg <= '0';
			end if;
			
			--athrow
			if(instr1 = x"E7") then
				xcptn_thrown_bytecode_r <= '1';
			elsif xcptn_done = '1' then
				xcptn_thrown_bytecode_r <= '0';
			end if;
			
			--mem2LVreg_2_reg <= mem2LVreg_1_reg; -- by fox
			mem2LVreg_2_reg <= mem2LVreg_1_reg or TH_mgt_CS_reset_lv;
			
			-- 2013.7.23 , multi-newarray need a special case , so interrupts is triggered here. 
			--if(instr1 = x"EB" and interrupt_req = '0' and stall_decode_stage = '0') then -- by fox
			--	interrupt_req_decode  <= '1';
			--	interrupt_func_decode <= x"0B" & x"00" & instr2;
			--elsif(interrupt_cmplt = '1')then
			--	interrupt_req_decode  <= '0';
			--	interrupt_func_decode <= (others => '0');
			--end if;
	-------- instr1 flag end
			
	-------- instr2 flag start	
	
			if (instr1 = x"78" and instr2 = x"78") then
				lrtnvalue_flag <= '0';
			end if;
	
			-- E2 return / E3 ireturn freturn areturn
			if((instr2(7 downto 1) = "1110001") and xcptn_thrown_bytecode_r = '0') then
				return_flag  <= not(interrupt_req or branch);
				ireturn_flag <= instr2(0);
			-- F5 lreturn dreturn
			elsif ((instr2 = X"F5") and xcptn_thrown_bytecode_r = '0') then
				lrtnvalue_flag <= '1';
			-- E1 return_off
			elsif((instr2 = x"E1" or instr1 = x"E1") and stall_decode_stage = '0') then
				return_flag  <= '0';
			else
				ireturn_flag <= '0';
			end if;
			
			-- E8 field_load / E9 field_store / EA staticfield_load / EB staticfield_store
			-- EC new obj / ED invoke_objref / EE ldc / EF invokestatic
			if((instr2(7 downto 3) = "11101") and xcptn_thrown_bytecode_r = '0') then	
				DynamicResolution_en <= '1';
				new_obj_flag		<= instr2(2) and (not instr2(1)) and (not instr2(0)); -- EC	
				invoke_flag		<= instr2(2) and instr2(0); -- ED / EF
				static_flag		<= instr2(1); -- EA / EB / EE / EF
				field_wr			<= instr2(0); -- E9 / EB / ED?? / EF??
				ldc_flag				<= instr2(2) and instr2(1) and (not instr2(0)); -- EE
				getStatic				<= (not instr2(2)) and instr2(1) and (not instr2(0)); -- EA getStatic
			elsif(instr2 = x"E4") then
				static_flag <= '1';
				DynamicResolution_en <= '1';
				ldc_w_flag 				<= '1';
			elsif (instr2 = x"F6") then
				static_flag <= '1';
				DynamicResolution_en <= '1';
				ldc2_w_flag 				<= '1';
			elsif(CTRL_state = HeapAlloc) then
				new_obj_flag	<= '0';
			elsif(CTRL_state = Enable_MA_management or CTRL_state = Native_start) then
				invoke_flag	<= '0';
			elsif(CTRL_state = Get_LV1_XRT_ref) then
				ldc_flag			<= '0';
				ldc_w_flag			<= '0';
				ldc2_w_flag			<= '0';
			else
				DynamicResolution_en	<= '0';
			end if;
			-------- instr2 flag end
			
			load_immediate1_reg  <= load_immediate1_reg_w;
			load_immediate2_reg  <= load_immediate2_reg_w;

		-- might be bug
			if(stall_decode_stage = '0') then
				if(branch = '1' and is_switch_instr_start='0') then
						ctrl  <= ctrl_nop;
				else
						ctrl  <= ctrl_tmp;
				end if;
					-- tableswitch / lookupswitch
				if(is_switch_instr_start='1' and instr2= x"10") then  --fox
					BranchDestination_tmp <= conv_std_logic_vector(unsigned(branch_trigger) + unsigned(switch_default_offset(15 downto 0)), 16);
				elsif((instr1(7 downto 4) = x"C" and instr1( 2 downto 1 ) /= "11") or instr1 = x"F1") then
					-- if / goto / tableswitch / lookupswitch
					if(is_switch_instr_start = '0') then			
						BranchDestination_tmp <= conv_std_logic_vector(unsigned(branch_trigger) + signed(operand_0 & operand_1), 16);
					-- tableswitch / lookupswitch
					else
						BranchDestination_tmp <= conv_std_logic_vector(unsigned(branch_trigger) + signed(operand_2 & operand_3), 16);
					end if;
				else
					BranchDestination_tmp <= BranchDestination_tmp;
				end if;
					--
				if(is_switch_instr_start = '1' and instr1 = x"E0") then	--fox
					if(instr2= x"01") then					-- get trigger and default_offset
						switch_default_offset <= operand_0 & operand_1 & operand_2 & operand_3;
					elsif(instr2= x"02") then					-- get lookupswitch's #pair
						switch_npair <= operand_0 & operand_1 & operand_2 & operand_3;
					elsif(instr2= x"03") then					-- compute #pair
						switch_npair <= switch_npair - '1';
						switch_code_revert <= '1';				
					end if;
				else
					switch_code_revert <= '0';
				end if;
					--
					-- by fox
				if( stall_decode_stage = '0') then 
					TH_mgt_clean_execute <= TH_mgt_clean_decode;
				end if; 
					--
			end if;
		end if;
	end process;
	
	-- prof
	label_enable_jaip_profiler_0 : if ENABLE_JAIP_PROFILER = 1 generate
	process(Clk, Rst) begin
		if(Rst = '1') then
			prof_simple_issued_A_reg <= '0';
			prof_simple_issued_B_reg <= '0';
			prof_complex_issued_reg <= '0';
			prof_issued_bytecodes_reg <= (others => '0');
		elsif(rising_edge(Clk)) then
			if(stall_decode_stage = '0') then
				prof_simple_issued_A_reg <= prof_simple_issued_A;
				prof_simple_issued_B_reg <= prof_simple_issued_B;
				prof_complex_issued_reg <= prof_complex_issued;
			else
				prof_simple_issued_A_reg <= '0';
				prof_simple_issued_B_reg <= '0';
				prof_complex_issued_reg <= '0';
			end if;			
			prof_issued_bytecodes_reg <= prof_issued_bytecodes_F;
		end if;
	end process;
	
	prof_simple_issued_A_D <= prof_simple_issued_A_reg ;
	prof_simple_issued_B_D <= prof_simple_issued_B_reg;
	prof_complex_issued_D <= prof_complex_issued_reg;
	prof_issued_bytecodes_D <= prof_issued_bytecodes_reg;
	end generate;
	
end architecture rtl;