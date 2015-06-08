------------------------------------------------------------------------------
-- Filename	:	fetch.vhd
-- Version		:	1.06
-- Author	:	Hou-Jen Ko
-- Date		:	July 2007
-- VHDL Standard:	VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.								**
-- ** Multimedia Embedded System Lab, NCTU.								**
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------
-- Filename	:	fetch.vhd
-- Version		:	2.03
-- Author	:	Kuan-Nian Su
-- Date		:	May 2009
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Filename	:	fetch.vhd
-- Version		:	3.00
-- Author	:	Han-Wen Kuo
-- Date		:	Nov 2010
-- VHDL Standard:	VHDL'93
-- Describe	:	New Architecture
------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity Fetch is
	generic(
		HIDE_MODULE					: integer := 0;
		ENABLE_JAIP_PROFILER   : integer := 0;
		C_MAX_AR_DWIDTH			: integer := 32;
		RAMB_S9_AWIDTH				: integer := 11;
		RAMB_S18_AWIDTH			: integer := 10

	);
	port(
		-- ctrl signal
		Rst							: in  std_logic;
		clk							: in  std_logic;		
		stall_fetch_stage			: in  std_logic;		
		CTRL_state					: in  DynamicResolution_SM_TYPE;
		set_jcodePC					: in  std_logic;
		native_flag					: in  std_logic;
		
		switch_instr_branch 		: out std_logic; -- just for tableswitch / lookupswitch branch use
		ISFrom_ROM					: out std_logic;
		
		-- 64-bits field flag
		long_field_flag				: in  std_logic;
		long_field_2nd_flag			: out std_logic;
		field_flag					: out std_logic;
		
		-- multiarray flag
		multiarray_flag				: in std_logic;
		dim_count_flag				: in std_logic;
		dim_count					: in std_logic_vector(7 downto 0);
		mularr_end_flag				: in std_logic;
		sizeofdims					: in std_logic_vector(79 downto 0);
		mularr_loadindex_flag		: out std_logic;
		mularrstore_flag			: in std_logic;
		mularrstore_begun_flag		: out std_logic;
		
		--for GC invoke
		Mthod_enter_flag			: out std_logic;
		Mthod_enter_flag_f			: out std_logic;
		
		-- method area
		jpc_reg						: in  std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
		stall_jpc					: out std_logic;
				
		-- translate stage
		semitranslated_code			: in  std_logic_vector(15 downto 0);
		complex						: in  std_logic_vector( 1 downto 0);
		opd_num						: in  std_logic_vector( 7 downto 0); 
		instr_buf_ctrl				: out std_logic_vector( 1 downto 0);
		
		-- decode stage
		stjpc_flag					: in  std_logic;
		invoke_flag					: in  std_logic;
		return_flag					: in  std_logic;
		branch_trigger				: out std_logic_vector(15 downto 0); 
		instrs_pkg					: out std_logic_vector(15 downto 0);
		opd_source					: out std_logic_vector( 1 downto 0);
		nop_1						: out std_logic;
		nop_2						: out std_logic;
		clinitEN					: in  std_logic;
		is_switch_instr_start		: out  std_logic;
		switch_instr_revert_code_seq : in std_logic ;

		-- execute stage
		RegA_0						: in  std_logic;
		RegB_0						: in  std_logic;
		branch_destination			: in  std_logic_vector(15 downto 0);
		branch						: in  std_logic; 
		-- thread management 	-- by fox
		TH_mgt_context_switch		: in std_logic; 
		TH_mgt_clean_pipeline		: in std_logic;
		TH_mgt_clean_decode			: out std_logic;
		TH_mgt_new_thread_execute	: in  std_logic;
		TH_mgt_thread_jpc			: in  std_logic_vector(15 downto 0);
		TH_mgt_thread_trigger		: out std_logic_vector(15 downto 0);
		TH_mgt_simple_mode			: out std_logic;
		TH_mgt_reset_mode			: in  std_logic;
		-- modified by T.H.Wu , 2014.1.22, for invoking/returning sync method.
		invoke_sync_mthd_flag_dly	: in  std_logic;
		rtn_frm_sync_mthd_flag		: in  std_logic;
		COOR_cmd_cmplt_reg			: in  std_logic;
		-- xcptn
		xcptn_flush_pipeline		: in std_logic;
		-- debug
		debug_flag					: in  std_logic_vector(7 downto 0);
		debug_addr					: in  std_logic_vector(7 downto 0);
		debug_data					: out std_logic_vector(31 downto 0);
		
		-- prof
		prof_simple_issued_A		: out std_logic;
		prof_simple_issued_B		: out std_logic;
		prof_complex_issued			: out std_logic;
		prof_issued_bytecodes_T		: in std_logic_vector(15 downto 0);
		prof_issued_bytecodes_F		: out std_logic_vector(15 downto 0)
	);
end entity Fetch;

architecture rtl of Fetch is

	signal complex_1_tmp			: std_logic ;
	signal complex_2_tmp			: std_logic ;
	signal complex_1, complex_2	: std_logic;
	signal semi_code1			: std_logic_vector( 7 downto 0) ;
	signal semi_code2			: std_logic_vector( 7 downto 0) ;

	signal opd_reg					: std_logic_vector( 3 downto 0);
	-- opd_reg(0)=0 when S+X or C+X, =1 when opd+X
	signal opdnum_1				: std_logic_vector( 3 downto 0) ;
	signal opdnum_2				: std_logic_vector( 3 downto 0) ;
	signal opd_source_reg		: std_logic_vector( 1 downto 0);
	
	signal instr_buf_ctrl_tmp	: std_logic_vector( 1 downto 0);
	signal instr_buf_ctrl_reg	: std_logic_vector( 1 downto 0);
	signal not_stall_jpc_signal	: std_logic;
	
	signal hazard_structure		: std_logic;
	signal hazard_potential		: std_logic;
	signal instr_type			: std_logic_vector(3 downto 0);
  
	-- added by T.H.Wu , 2014.1.22 for returning sync method, restoring the j-code pc to go on the rest of j-code
	signal jcode_addr_restore_for_rtn_sync_mthd : std_logic_vector( 7 downto 0);
	signal jcode_addr			: std_logic_vector( 7 downto 0);
	signal jcodeaddr_semicode	: std_logic_vector( 7 downto 0);
	signal jcodeaddr_tmp			: std_logic_vector( 7 downto 0);
	signal jcode_counter			: std_logic_vector( 7 downto 0);
	signal nxt						: std_logic; 
	signal nxt_reg					: std_logic;
	signal ROM_instr				: std_logic_vector(15 downto 0);
	type   mode_type				is  (from_ROM, from_translate);
	signal mode					: mode_type;
	signal mode_reg				: mode_type;
	
	signal semitranslated_code_reg  : std_logic_vector(15 downto 0);

	signal branch_reg			: std_logic;
	signal stjpc_flag_reg		: std_logic;
	signal branch_trigger_reg	: std_logic_vector(15 downto 0);
	-- add tableswitch / lookupswitch , fox
	signal is_switch_instr_start_reg : std_logic;
	signal is_switch_instr_start_w : std_logic;
	signal switch_instr_branch_reg : std_logic;
	signal stall_jpc_for_switch_instr : std_logic;
	signal stall_jpc_w : std_logic;
	signal instrs_pkg_w   : std_logic_vector(15 downto 0);
	-- add for thread management , fox
	signal TH_mgt_clean_fetch		: std_logic ;
	-- for timing constraint issue, modified by T.H.Wu , 2013.7.25
	signal Disable_semicode_during_context_switch :  std_logic; 
	-- modified by T.H.Wu, 2014.1.23, for retuning from sync method.
	signal rtn_frm_sync_mthd_flag_dly		:	std_logic;
	signal rtn_frm_sync_mthd_active_hold	:	std_logic;
	
	signal jcode_counter_privious	: std_logic_vector(7 downto 0);
	signal opd_reg_1_reg			: std_logic;
	signal complex_2_reg			: std_logic;
	signal opd_reg_2_reg			: std_logic;
	signal opd_1_reg				: std_logic;
	signal hazard_structure_reg	: std_logic;
	signal native_flag1			: std_logic;
	signal stjpc_flag1				: std_logic;
	signal branch1					: std_logic;
	signal FFFF_branch_counting_flag: std_logic;
	signal invoke				: std_logic;
	signal invoke_reg			: std_logic;
	
	signal branch_numreg			: std_logic_vector(31 downto 0);
	signal cplx_mode				: std_logic_vector(31 downto 0);
	signal FFXX_opd				: std_logic_vector(31 downto 0);
	signal XXFF_opd				: std_logic_vector(31 downto 0);
	signal XXFF_c				: std_logic_vector(31 downto 0);
	signal XXFF_s				: std_logic_vector(31 downto 0);
	signal XXFF_h				: std_logic_vector(31 downto 0);
	signal FFFF_opdopd				: std_logic_vector(31 downto 0);
	signal FFFF_opds				: std_logic_vector(31 downto 0);
	signal FFFF_ROM				: std_logic_vector(31 downto 0);
	signal XXFF_ROM				: std_logic_vector(31 downto 0);
	signal FFXX_ROM				: std_logic_vector(31 downto 0);
	signal invoke_numreg			: std_logic_vector(31 downto 0);
	signal FFXX_branch				: std_logic_vector(31 downto 0);
	signal FFFF_branch				: std_logic_vector(31 downto 0);
	signal FFFF_brs				: std_logic_vector(31 downto 0);
	signal single_issue			: std_logic_vector(31 downto 0);
	signal nop_flag_reg			: std_logic_vector(31 downto 0);
	signal counter					: std_logic_vector(31 downto 0);
	signal prof_simple_issued_A_reg : std_logic;
	signal prof_simple_issued_B_reg	: std_logic;
	signal prof_complex_issued_reg	: std_logic;
	signal nop_1_tmp				: std_logic;
	signal nop_2_tmp				: std_logic;
	signal prof_issued_bytecodes	: std_logic_vector(15 downto 0);
	
	begin
--==================================================================
	labal_hide_module_0 : if HIDE_MODULE = 0 generate
	debug_data <= branch_numreg when debug_addr = x"00" else
					cplx_mode	when debug_addr = x"01" else
					FFXX_opd		when debug_addr = x"02" else
					XXFF_opd		when debug_addr = x"03" else
					XXFF_c		when debug_addr = x"04" else
					XXFF_s		when debug_addr = x"05" else
					XXFF_h		when debug_addr = x"06" else
					FFFF_opdopd   when debug_addr = x"07" else
					FFFF_opds	when debug_addr = x"08" else
					FFFF_ROM		when debug_addr = x"0A" else
					XXFF_ROM		when debug_addr = x"0B" else
					FFXX_ROM		when debug_addr = x"0C" else
					invoke_numreg when debug_addr = x"0D" else
					FFXX_branch   when debug_addr = x"0E" else
					FFFF_branch   when debug_addr = x"0F" else
					FFFF_brs		when debug_addr = x"10" else
					single_issue  when debug_addr = x"11" else
					nop_flag_reg  when debug_addr = x"12" else
					counter	when debug_addr = x"13" else
					x"FF000000";
					
	ISFrom_ROM <= '0' when mode_reg = from_translate else '1';
	
	
	process(clk, Rst) begin
		if(Rst = '1') or xcptn_flush_pipeline = '1' then
			branch_numreg <= (others => '0');
			cplx_mode <= (others => '0');
			FFXX_opd <= (others => '0');
			XXFF_opd <= (others => '0');
			XXFF_c <= (others => '0');
			XXFF_s <= (others => '0');
			XXFF_h <= (others => '0');
			FFFF_opdopd <= (others => '0');
			FFFF_opds <= (others => '0');
			FFFF_ROM <= (others => '0');
			XXFF_ROM <= (others => '0');
			FFXX_ROM <= (others => '0');
			invoke_numreg <= (others => '0');
			FFXX_branch <= (others => '0');
			FFFF_branch <= (others => '0');
			FFFF_brs <= (others => '0');
			single_issue <= (others => '0');
			nop_flag_reg <= (others => '0');
			FFFF_branch_counting_flag <= '0';
			invoke   <= '0';
			invoke_reg  <= '0';
			counter <= (others => '0');
		elsif(rising_edge(clk)) then
			opd_reg_1_reg <= opd_reg(0);
			complex_2_reg <= complex_2;
			opd_reg_2_reg <= opd_reg(1);
			opd_1_reg <= (not opd_reg(0) and opdnum_1(0));
			hazard_structure_reg <= hazard_structure;
			invoke <= invoke_flag;
			invoke_reg <= invoke;
			
			if(branch = '1') then
				branch_numreg <= branch_numreg + 1;
				FFFF_branch_counting_flag <= '1';
			end if;
			if(nxt_reg = '1' and mode_reg = from_translate) then
				cplx_mode <= cplx_mode + 1;
			end if;
			if(invoke = '1' and invoke_reg = '0') then
				invoke_numreg <= invoke_numreg + 1;
			end if;
			
			if(native_flag = '1') then
				native_flag1 <= RegB_0;
			elsif(stjpc_flag = '1') then
				stjpc_flag1 <= RegA_0;
			elsif(branch = '1') then
				branch1 <= branch_destination(0);
			end if;
			
			if(stall_fetch_stage = '0') then
				if(branch = '1' or (nxt_reg = '1' and mode_reg = from_translate))then
					nop_flag_reg <= nop_flag_reg + 1;
				elsif(semitranslated_code_reg(15 downto 8) = x"FF" and semitranslated_code_reg( 7 downto 0) /= x"FF" and mode_reg = from_translate) then
					if((native_flag1 or stjpc_flag1 or branch1)= '1' ) then
						FFXX_branch  <= FFXX_branch +1;
						native_flag1 <= '0';
						stjpc_flag1  <= '0';
						branch1		<= '0';
					elsif(opd_reg_1_reg = '1') then
						FFXX_opd <= FFXX_opd + 1;
					end if;
					single_issue <= single_issue + 1;
				elsif(semitranslated_code_reg(15 downto 8) /= x"FF" and semitranslated_code_reg( 7 downto 0) = x"FF" and mode_reg = from_translate) then
					if(opd_1_reg = '1') then
						XXFF_opd <= XXFF_opd + 1;
					elsif(complex_2_reg = '1') then
						XXFF_c <= XXFF_c + 1;
					elsif(hazard_structure_reg = '1') then
						XXFF_h <= XXFF_h + 1;
					end if;
					single_issue <= single_issue + 1;
				end if;
				
				if(branch = '1' or (nxt_reg = '1' and mode_reg = from_translate))then
					counter <= counter + 1;
				elsif(semitranslated_code_reg = x"FFFF" and mode_reg = from_translate) then  
					if(FFFF_branch_counting_flag = '1') then
						FFFF_branch  <= FFFF_branch + 1;
						FFFF_branch_counting_flag		<= '0';
					else
						if(opd_reg_2_reg = '1') then
							FFFF_opdopd <= FFFF_opdopd + 1;
						end if;
					end if;
				end if;
				
				if(mode_reg = from_ROM) then
					if(ROM_instr = x"FFFF") then
						FFFF_ROM <= FFFF_ROM + 1;
					elsif(ROM_instr(15 downto 8) /= x"FF" and ROM_instr( 7 downto 0) = x"FF") then
						XXFF_ROM <= XXFF_ROM + 1;
					elsif(ROM_instr(15 downto 8) = x"FF" and ROM_instr( 7 downto 0) /= x"FF") then
						FFXX_ROM <= FFXX_ROM + 1;
					end if;
				end if;
			end if;
		end if;
	end process;
	end generate ;
--==================================================================
	-- modified by T.H.Wu , 2013.7.25 
	complex_1_tmp	<= complex(1)  when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else '0';
	complex_2_tmp	<= complex(0) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else '0';
	semi_code1	<= semitranslated_code(15 downto 8) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else x"FF";
	semi_code2	<= semitranslated_code( 7 downto 0) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else x"FF";
	opdnum_1		<= opd_num(7 downto 4) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else x"0";
	opdnum_2		<= opd_num(3 downto 0) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else x"0";
	TH_mgt_simple_mode <= '1' when mode = from_translate and mode_reg = from_translate else '0';
	
	
	complex_1 <= '0' when opd_reg(0) = '1' else complex_1_tmp;
	
	complex_2 <= '0' when((opd_reg(0) = '0' and opdnum_1(0) = '1')or(opd_reg(1) = '1'))else
				complex_2_tmp;
	
	
	-- added tableswitch / lookupswitch , 2013.7.1 , fox
	
	is_switch_instr_start <= is_switch_instr_start_reg;
	switch_instr_branch <= switch_instr_branch_reg;
	
	process (clk) begin
		if(rising_edge(clk)) then
			-- 2013.7.9 , debug for lookupswitch/tableswitch stringAtom
			-- modified since 2013.7.24 
			if(Rst='1') then 
				is_switch_instr_start_reg <= '0';
				switch_instr_branch_reg <= '0'; 
				stall_jpc_for_switch_instr <= '0';
			else
				--if (branch = '1' and switch_instr_branch_reg = '0') or TH_mgt_context_switch='1'  then
				if ((branch = '1' and switch_instr_branch_reg = '0') or Disable_semicode_during_context_switch='1')  then
					is_switch_instr_start_reg <= '0';
				elsif (is_switch_instr_start_w='1') then
					is_switch_instr_start_reg <= '1';
				end if;
				
				if(is_switch_instr_start_reg = '1' and instrs_pkg_w(7 downto 0) = x"E0") then --fox
					switch_instr_branch_reg  <= '1';
			elsif(branch = '1') then
					switch_instr_branch_reg <= '0'; 
				end if;
				
				if(instrs_pkg_w(7 downto 0) = x"D3") then
					stall_jpc_for_switch_instr <= '1';
				elsif(branch = '1') then
					stall_jpc_for_switch_instr <= '0';
				end if;
			end if;
		end if;
		--
	end process;
	
	process (semi_code1,semi_code2, mode_reg, complex_1, complex_2, opd_reg(0) ) begin 
		if( mode_reg = from_translate) then
			--tableswitch:60  lookupswitch:80
			if( semi_code1=x"60" or  semi_code1=x"80" ) then
				is_switch_instr_start_w <=  complex_1;
			elsif( semi_code2=x"60" or  semi_code2=x"80" ) then
				is_switch_instr_start_w <=  complex_2 and opd_reg(0);
			else
				is_switch_instr_start_w <= '0';
			end if;
		else 
			is_switch_instr_start_w <=  '0';
		end if;
	end process;
	
	stall_jpc <= stall_jpc_w or stall_jpc_for_switch_instr;
	stall_jpc_w <= (not not_stall_jpc_signal) and not (is_switch_instr_start_reg) when mode = from_ROM or instr_buf_ctrl_tmp(1) = '1' else
				'0' ;
				
	not_stall_jpc_signal_ctrl :
	process(mode_reg, mode, opd_reg, instr_buf_ctrl_reg, opdnum_1, opdnum_2) begin
		if(mode_reg = from_translate and mode = from_ROM) then
			if(opd_reg(0) = '1') then -- opd + C
				not_stall_jpc_signal <= opdnum_2(0);
			else					-- C + X
				not_stall_jpc_signal <= opdnum_1(0) and not instr_buf_ctrl_reg(0);
			end if;
		else
			not_stall_jpc_signal <= '0';
		end if;		
	end process;
	
	-- if semi_code1 and semi_code2 both are simple instruction
	hazard_potential <= not (opd_reg(0) or complex_1 or complex_2 or opdnum_1(0));
	instr_type	<= semi_code1(7 downto 6) & semi_code2(7 downto 6);
	--00 for load   01 for store   10 for ALU   11 for special or nop
	-- hazard occurs when ALU-ALU
	hazard_structure <= hazard_potential when (instr_type = "1010") else '0'; 
												
	instr_buf_ctrl <= instr_buf_ctrl_tmp;
	
	--   buf2 buf1 buf0
	--   [XX] [XX] [XX]
	-- 0  XX   XX  {XX}
	-- 1  XX  X{X  X}X
	-- 2  XX  {XX}  XX 
	instr_buf_ctrl_logic :
	process(instr_buf_ctrl_reg, opd_reg, opdnum_1, opdnum_2, complex_1, complex_2,
					stall_fetch_stage, hazard_structure, mode_reg, -- special_2,
						branch_reg, stjpc_flag_reg, invoke_flag, return_flag, clinitEN)
		variable instr_buf_ctrl_type0   : std_logic_vector(1 downto 0);
		variable instr_buf_ctrl_type1   : std_logic_vector(1 downto 0);
		variable instr_buf_ctrl_type2   : std_logic_vector(1 downto 0);
		variable instr_buf_ctrl_type3   : std_logic_vector(1 downto 0);
		variable instr_buf_ctrl_CX		: std_logic_vector(1 downto 0);
		variable instr_buf_ctrl_XC		: std_logic_vector(1 downto 0);
		variable instr_buf_ctrl_SX		: std_logic_vector(1 downto 0);
		variable instr_buf_ctrl_special : std_logic_vector(1 downto 0);
		variable instr_buf_ctrl_normal  : std_logic_vector(1 downto 0);
	begin
		-- C + X
		case opdnum_1 is
			when x"0"   => instr_buf_ctrl_type0 := "01";
			when x"1"   => instr_buf_ctrl_type0 := "10";
			when x"3"   => instr_buf_ctrl_type0 := "01";
			when others => instr_buf_ctrl_type0 := "00";
		end case;
		case opdnum_1 is
			when x"0"   => instr_buf_ctrl_type1 := "10";
			when x"1"   => instr_buf_ctrl_type1 := "01";
			when others => instr_buf_ctrl_type1 := "00";
		end case;
		-- opd + C
		case opdnum_2 is
			when x"1"   => instr_buf_ctrl_type2 := "01";
			when others => instr_buf_ctrl_type2 := "00";
		end case;
		case opdnum_2 is
			when x"0"   => instr_buf_ctrl_type3 := "01";
			when x"1"   => instr_buf_ctrl_type3 := "10";
			when x"3"   => instr_buf_ctrl_type3 := "01";
			when others => instr_buf_ctrl_type3 := "00";
		end case;
		if(instr_buf_ctrl_reg(0) = '0') then
			instr_buf_ctrl_SX := "01";
			instr_buf_ctrl_CX := instr_buf_ctrl_type0;
			instr_buf_ctrl_XC := instr_buf_ctrl_type2;
		else  --01
			instr_buf_ctrl_SX := "10";
			instr_buf_ctrl_CX := instr_buf_ctrl_type1;
			instr_buf_ctrl_XC := instr_buf_ctrl_type3;
		end if;
		if(instr_buf_ctrl_reg(1) = '1') then 
			instr_buf_ctrl_special := "00";
		else
			instr_buf_ctrl_special := instr_buf_ctrl_reg;
		end if;
		
		-- for normal
		if(opd_reg(0) = '0') then -- semicodes are valid
			if(complex_1 = '0') then -- S + X
				if((complex_2 or hazard_structure) = '1') then -- S + S/C
					instr_buf_ctrl_normal := instr_buf_ctrl_SX;
				else										-- S + S normal
					instr_buf_ctrl_normal := instr_buf_ctrl_special;
				end if;
			else					-- C + X
				instr_buf_ctrl_normal   := instr_buf_ctrl_CX;
			end if;
		else
			if(complex_2 = '0') then -- opd + S/opd
				instr_buf_ctrl_normal := instr_buf_ctrl_special;
			else					-- opd + C
				instr_buf_ctrl_normal   := instr_buf_ctrl_XC;
			end if;
		end if;
		if((branch_reg or stjpc_flag_reg or invoke_flag or return_flag or native_flag or clinitEN or TH_mgt_context_switch) = '1') then -- fox
			instr_buf_ctrl_tmp <= "00";
		elsif(stall_fetch_stage = '1' or mode_reg = from_ROM or ((opd_reg(0) and opd_reg(1)) = '1') or TH_mgt_clean_fetch='1') then
			instr_buf_ctrl_tmp <= instr_buf_ctrl_reg;
		else
			instr_buf_ctrl_tmp <= instr_buf_ctrl_normal;
		end if;
	end process;
	
	instr_buf_ctrl_reg_logic :
	process(Rst,clk) begin
		if(Rst = '1') or xcptn_flush_pipeline = '1'then
			instr_buf_ctrl_reg <= "00";
		elsif(rising_edge(clk)) then
			instr_buf_ctrl_reg <= instr_buf_ctrl_tmp;
			branch_reg		<= branch;
			stjpc_flag_reg	<= stjpc_flag;
		end if;		
	end process;

	opd_ctrl :
	process(Rst,clk)
		variable opd_reg_complex : std_logic_vector(3 downto 0);
		variable opd_reg_simple  : std_logic_vector(3 downto 0);
		variable opdnum_1or2	: std_logic_vector(1 downto 0);
		variable opdnum_2_tmp	: std_logic_vector(3 downto 0);
		variable opd_reg_type0   : std_logic_vector(3 downto 0);
		variable opd_reg_type1   : std_logic_vector(3 downto 0);
		variable opd_reg_type_CX : std_logic_vector(3 downto 0);
		variable opd_reg_type_XC : std_logic_vector(3 downto 0);
	begin
		--  for complex  start
		if(opd_reg(0) = '0') then -- C + X
			opdnum_1or2 := opdnum_1(3 downto 2);
		else						-- opd + C
			opdnum_1or2 := opdnum_2(3 downto 2);
		end if;
			-- might be timing issue here
		case opdnum_1or2 is		-- C + X
			when "11"   => opd_reg_type0 := "0001"; -- opd  = 4
			when others => opd_reg_type0 := "0000";
		end case;
		case opdnum_1or2 is		-- opd + C
			when "01"   => opd_reg_type1 := "0001"; -- opd  = 3
			when "11"   => opd_reg_type1 := "0011"; -- opd  = 4
			when others => opd_reg_type1 := "0000";
		end case;
		if(instr_buf_ctrl_reg(0) = '0') then -- 00 10
			opd_reg_type_CX := opd_reg_type0;
			opd_reg_type_XC := opd_reg_type1;
		else									-- 01
			opd_reg_type_CX := opd_reg_type1;
			opd_reg_type_XC := opd_reg_type0;
		end if;
		if(opd_reg(0) = '0') then -- C + X
			opd_reg_complex := opd_reg_type_CX;
		else						-- opd + C
			opd_reg_complex := opd_reg_type_XC;
		end if;
		--  for complex  end
		--  for simple   start
		if((complex_2 or hazard_structure) = '1') then
			opdnum_2_tmp := "0000";
		else
			opdnum_2_tmp := opdnum_2;
		end if;
		if(opd_reg(0) = '0') then	-- opd_reg = 00
			if(opdnum_1(0) = '0') then	-- S + S
				opd_reg_simple := opdnum_2_tmp;
			else						-- S + opd
				opd_reg_simple := '0' & opdnum_1(3 downto 1);
			end if;
		else 
			if(opd_reg(1) = '0') then -- opd_reg = 01
				opd_reg_simple := opdnum_2_tmp;
			else		-- opd_reg = 11
				opd_reg_simple(1 downto 0) := opd_reg(3 downto 2);
				opd_reg_simple(3 downto 2) := "00";
			end if;
		end if;
		--  for simple   end
		if((Rst = '1') or xcptn_flush_pipeline = '1') then
			opd_reg   <= "0011";
		elsif(rising_edge(clk)) then
			if(native_flag = '1') then
				opd_reg <= "000" & RegB_0;
			elsif(invoke_flag = '1' or clinitEN = '1' or TH_mgt_new_thread_execute='1')then
				opd_reg <= "0011";
			elsif(stjpc_flag = '1') then
				opd_reg <= "000" & RegA_0;
			elsif(TH_mgt_context_switch = '1') then -- by fox
				opd_reg <= "0" &  TH_mgt_thread_jpc(0) & "11";
			elsif(branch = '1') then
				-- 2013.7.9 , why switch_instr_branch_reg should be here ??
				if(switch_instr_branch_reg = '1') then --fox
						opd_reg <= "0011";
					else
						opd_reg <= '0' & branch_destination(0) & "11";
				end if;
			elsif(TH_mgt_clean_fetch='1') then -- by fox
				if(branch_reg = '1') then
					opd_reg	<= "00" & opd_reg(3 downto 2);
				else
					opd_reg <= opd_reg;
				end if;
			elsif(stall_fetch_stage = '1') then
				opd_reg <= opd_reg;
			elsif(mode_reg = from_translate) then
				if(mode = from_translate) then -- normal 
					opd_reg <= opd_reg_simple;
				else						-- complex
					opd_reg <= opd_reg_complex;
				end if;
			end if;
		end if;		
	end process;
	
	opd_source <= opd_source_reg;
	
	--   buf2 buf1 buf0
	--   [XX] [XX] [XX]
	-- 0  OO   OO   XX
	-- 1  XO   OO   OX
	-- 2  XX   OO   OO
	--
	-- X => instruction
	-- O => operand
	opd_source_ctrl :
	process(clk, Rst) begin
		if(Rst = '1')or xcptn_flush_pipeline = '1' then
			opd_source_reg <= "00";
		elsif(rising_edge(clk)) then
			if(stall_fetch_stage = '0' and mode_reg = from_translate) then
				if (is_switch_instr_start_w='1') then
					opd_source_reg <= "10";
				elsif(opd_reg(0) = '0' and opdnum_1(0) = '1') then
					opd_source_reg <= (instr_buf_ctrl_reg(0) and complex_1) & not instr_buf_ctrl_reg(0);
				else
					opd_source_reg <= not instr_buf_ctrl_reg(0) & instr_buf_ctrl_reg(0);
				end if;
			end if;
		end if;
	end process;
	
	branch_trigger <= branch_trigger_reg;
	
	-- need simplified, cause only inst1 can be branch instruction
	branch_addr_ctrl :
	process(clk, Rst)
		variable br_addr1			: std_logic_vector(15 downto 0);
		variable br_addr2			: std_logic_vector(15 downto 0);
		variable br_addr3			: std_logic_vector(15 downto 0);
		variable br_semicode1		: std_logic_vector(15 downto 0); --  
		variable br_semicode2		: std_logic_vector(15 downto 0); --  
		variable jpc_reg_tmp1		: std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
		variable jpc_reg_tmp2		: std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
	begin
		
		if(Rst = '1')or xcptn_flush_pipeline = '1' then
			branch_trigger_reg <= (others => '0');
		elsif(rising_edge(clk)) then
			jpc_reg_tmp1 := jpc_reg -  '1';
			jpc_reg_tmp2 := jpc_reg - "10";
			br_addr1	:= jpc_reg_tmp1 & '0';
			br_addr3	:= jpc_reg_tmp1 & '1';
			br_addr2	:= jpc_reg_tmp2 & '1';
			if(instr_buf_ctrl_reg(0) = '0') then -- 00 10
				br_semicode1 := br_addr1;
				br_semicode2 := br_addr3;
			else								-- 01
				br_semicode1 := br_addr2;
				br_semicode2 := br_addr1;
			end if;
			-- for chipscope debug
			--debug_cs_fetch (19 downto 8) <=		br_semicode1 (11 downto 0); 
			--debug_cs_fetch (31 downto 20) <=   br_semicode2 (11 downto 0);
			if(stall_fetch_stage = '0' and mode_reg = from_translate) then
				-- modified by T.H.Wu , 2013.8.19 , for changing logic to determine branch destination of each related bytecode
				if(complex_1 = '1') then 
					if(semi_code1(7 downto 4) = x"C" and opdnum_1 = x"F") then-- invokeinterface					
						branch_trigger_reg <= br_semicode1 + "101";
					elsif (semi_code1(7 downto 4) = x"D" or semi_code1(7 downto 4) = x"B" or semi_code1(7 downto 4) = x"A") then -- invokevirtual 
						branch_trigger_reg <= br_semicode1 + "011";			
					else
						branch_trigger_reg <= br_semicode1 ;						
					end if;
				else
					if(semi_code2(7 downto 4) = x"C" and opdnum_2 = x"F") then -- invokeinterface
						branch_trigger_reg <= br_semicode2 + "101";
					elsif(semi_code2(7 downto 4) = x"D" or semi_code2(7 downto 4) = x"B" or semi_code2(7 downto 4) = x"A")then  -- invokevirtual 
						branch_trigger_reg <= br_semicode2 + "011";	
					else
						branch_trigger_reg <= br_semicode2 ;						
					end if;
				end if;
				--
		-- by fox ,
		-- usage ?? why don't we use branch_trigger_reg instead of TH_mgt_thread_trigger ?? 2013.7.16
		if(opd_reg(1 downto 0) = "11") then
			TH_mgt_thread_trigger	<= br_semicode1 + "010";
		elsif(opd_reg(0) = '0') then	
			TH_mgt_thread_trigger	<= br_semicode1;
		else
			TH_mgt_thread_trigger	<= br_semicode2;
		end if;
				--
			end if;
		end if;
	end process;

	-- might be bug in complex-complex combination
	j_code_ctrl : -- by fox
	process(mode_reg, complex_1, complex_2, nxt, branch, opd_reg, invoke_sync_mthd_flag_dly,
				TH_mgt_new_thread_execute, TH_mgt_reset_mode,switch_instr_branch_reg) begin
		if(mode_reg = from_translate) then
			if ((complex_1 or (complex_2 and opd_reg(0))) = '1' or TH_mgt_new_thread_execute='1')then -- by fox
				mode <= from_ROM;
			else
				mode <= from_translate;
			end if;
		else -- what do reset mode and simple mode mean in  thread manager ?? 2013.7.16
			if(((nxt or branch) = '1' and switch_instr_branch_reg='0' and invoke_sync_mthd_flag_dly='0') or TH_mgt_reset_mode='1') then -- by fox
				mode <= from_translate;
			else
				mode <= from_ROM;
			end if;
		end if;
	end process;
	
	jcodeaddr_semicode <= semi_code1 when (complex_1 = '1') else semi_code2 ;
	--fox
	-- for skip switch padding bytes
	jcodeaddr_tmp   <=  jcodeaddr_semicode + 1 when(is_switch_instr_start_w = '1' and (instr_buf_ctrl_reg(0) = jpc_reg(0))) else  
										jcodeaddr_semicode;
	
	jcode_addr <=			x"FF"	when set_jcodePC = '1' or TH_mgt_reset_mode='1' -- by fox
							-- by fox , modified by T.H.Wu , 2013.7.16 , for
							-- might be a problem , j-code of starting a new thread is part of invokevirtual ??
					else	x"D9"	when TH_mgt_new_thread_execute = '1' --modify by Jeff for GC
					else	jcode_counter		when (stall_fetch_stage = '1')
					else	x"93"	when invoke_sync_mthd_flag_dly='1'	-- for invoking sync method. 2014.2.6, this will be modified if we find out better way to change address of ROM
					else	x"98"	when rtn_frm_sync_mthd_flag='1' 	-- for returning sync method. critical path, the hardest part
					else	jcodeaddr_tmp	when (mode_reg = from_translate and mode = from_ROM)
					else	x"B9"	when (CTRL_state = ClinitRetFrm1) -- for clinit
					else	jcode_counter - "011"   when switch_instr_revert_code_seq = '1' -- for lookupswitch
					else	x"28"	when (long_field_flag = '1' and jcode_counter = x"2B") --for 64-bits putstatic 2nd round
					else	x"20"	when (long_field_flag = '1' and jcode_counter = x"23") --for 64-bits getstatic 2nd round
					else	x"45"	when (jcode_counter = x"8D") --for 64-bits putfield 2nd round
					else	x"8D"	when (long_field_flag = '1' and jcode_counter = x"48") --pop for 64-bits putfield
					else	x"24"	when (jcode_counter = x"8E") --for 64-bits getfield 2nd round
					else	x"8E"	when (long_field_flag = '1' and jcode_counter = x"27") --get field ref back for 64-bits getfield
					-- for multinewarray start
							--it means:  dim_count   times_of_doing_jcode_91	(n is dim, n>=2)   by CYC
							--				0				1
							--				n				2
							--
							--				2				n
					else	x"91"	when (dim_count /= x"02" and jcode_counter = x"91")
					else	x"18"	when (jcode_counter = x"92")
					else	x"92"	when (jcode_counter = x"9E")
					else	x"9C"	when (multiarray_flag = '1' and mularrstore_flag = '1' and (jcode_counter = x"1C" or jcode_counter = x"9D"))
					else	x"9E"	when (multiarray_flag = '1' and (jcode_counter = x"1C" or jcode_counter = x"9D"))
					-- for multinewarray end
					else	jcode_counter + '1' ;
		
	invoke_GC_ctrl:
	process(clk,Rst) begin
		if(rising_edge(clk)) then
			if(Rst = '1') then
				Mthod_enter_flag	<=	'0';
				Mthod_enter_flag_f	<=	'0';
			else  
				if (jcode_counter = x"B2" or jcode_counter = x"C2" or CTRL_state = ClinitRetFrm2) then
					Mthod_enter_flag_f	<=	'1';
				else
					Mthod_enter_flag_f	<=	'0';
				end if;
				
				if (jcode_counter = x"A2" or jcode_counter = x"D2") then
					Mthod_enter_flag	<=	'1';
				else
					Mthod_enter_flag	<=	'0';
				end if;
			end if;
		end if;
	end process;
		
	dim_fetch_ctrl:
	process(clk,Rst) begin
		if(rising_edge(clk)) then
			if(Rst = '1') then
				mularr_loadindex_flag	<=	'0';
				mularrstore_begun_flag	<=	'0';
			else  
				if (jcode_counter = x"9E") then
					mularr_loadindex_flag	<=	'1';
				else
					mularr_loadindex_flag	<=	'0';
				end if;
				
				if (jcode_counter = x"9C") then
					mularrstore_begun_flag	<=	'1';
				else
					mularrstore_begun_flag	<=	'0';
				end if;
					
			end if;
		end if;
	end process;
				
	long_field_2nd_ctrl:
	process(clk,Rst) begin
		if(rising_edge(clk)) then
			if(Rst = '1') then
				long_field_2nd_flag			<=	'0';
				field_flag					<=	'0';
				jcode_counter_privious		<=	x"00";
			else
				jcode_counter_privious		<=	jcode_counter;
				if (jcode_counter = x"8D" or jcode_counter = x"8E" or
					(jcode_counter /= x"23" and jcode_counter_privious = x"23" and long_field_flag = '1') or
					(jcode_counter /= x"2B" and jcode_counter_privious = x"2B" and long_field_flag = '1')) then
					long_field_2nd_flag		<=	'1';
				elsif (long_field_flag = '0' and
						((jcode_counter /= x"49" and jcode_counter_privious = x"49") or
						(jcode_counter /= x"27" and jcode_counter_privious = x"27") or
						(jcode_counter /= x"23" and jcode_counter_privious = x"23") or
						(jcode_counter /= x"2B" and jcode_counter_privious = x"2B"))) then
					long_field_2nd_flag		<=	'0';
				end if;
				-- getfield putfield getstatic putstatic
				if (((jcode_counter > x"1F" and jcode_counter < x"2C") or (jcode_counter > x"44" and jcode_counter < x"4A"))) then
					field_flag				<=	'1';
				else
					field_flag				<=	'0';
				end if;
			end if;
		end if;
	end process;
					
	j_code_reg_ctrl :
	process(clk, Rst) begin
		if(Rst = '1' or xcptn_flush_pipeline = '1' ) then
			mode_reg <= from_translate;
			jcode_counter	<= (others => '0');
			nxt_reg  <= '0';
			jcode_addr_restore_for_rtn_sync_mthd <= (others=>'0');
			rtn_frm_sync_mthd_flag_dly		<=	'0';
			rtn_frm_sync_mthd_active_hold	<=	'0';
		elsif(rising_edge(clk)) then
			if(mode = from_ROM) then
				-- modified by T.H.Wu , 2014.1.23, for returning from sync method.
				if(rtn_frm_sync_mthd_active_hold='1' and COOR_cmd_cmplt_reg='1') then 
					jcode_counter	<=	jcode_addr_restore_for_rtn_sync_mthd ;
				else
					jcode_counter	<=	jcode_addr; 
				end if;	
			end if;
			--
			if((branch = '1' and switch_instr_branch_reg='0') or TH_mgt_reset_mode='1') then -- fox
				mode_reg <= from_translate;
			elsif(stall_fetch_stage = '0') then
				mode_reg <= mode;
			end if;
			--
			if(stall_fetch_stage = '0') then
				if(mode_reg = from_ROM) then
					nxt_reg  <= nxt;
				elsif(is_switch_instr_start_reg = '1' and branch = '1') then   --fox
					nxt_reg <= '1';	
				else
					nxt_reg  <= '0';
				end if;
			end if;
			-- modified by T.H.Wu , 2014.1.23, for returning from sync method.
			if(rtn_frm_sync_mthd_flag='1') then
				jcode_addr_restore_for_rtn_sync_mthd <= jcode_counter;
			end if;
			--
			rtn_frm_sync_mthd_flag_dly	<=	rtn_frm_sync_mthd_flag;
			--
			if(rtn_frm_sync_mthd_flag_dly='1') then
				rtn_frm_sync_mthd_active_hold	<=	'1';
			elsif(COOR_cmd_cmplt_reg='1') then
				rtn_frm_sync_mthd_active_hold	<=	'0';
			end if;
			
		end if;
	end process;
	
	instrs_pkg <= instrs_pkg_w;
	instrs_pkg_w <=	x"FFFF"	when TH_mgt_context_switch = '1' else -- by fox
	--instrs_pkg_w <=	x"FFFF"	when Disable_semicode_during_context_switch = '1' else -- modified by T.H.Wu , 2013.7.25
									semitranslated_code_reg when mode_reg = from_translate else
									ROM_instr;
	
	-- for next instr is normal or nop
	semitranslated_code_reg_ctrl :
	process(clk, Rst, xcptn_flush_pipeline, TH_mgt_context_switch) begin
		if(Rst = '1') or xcptn_flush_pipeline = '1' or TH_mgt_context_switch = '1'  then -- by fox , is it essential ?
			semitranslated_code_reg <= (others => '1');
		elsif(rising_edge(clk)) then
			if(stall_fetch_stage = '0') then
				if((complex_1 or opd_reg(0) or branch) = '1') then
						if(is_switch_instr_start_reg = '1') then   --fox
							semitranslated_code_reg(15 downto 8) <= x"78";
						else
							semitranslated_code_reg(15 downto 8) <= x"FF";
						end if;
				else
					semitranslated_code_reg(15 downto 8) <= semi_code1;
				end if;
				-- modifed by T.H. Wu , 2013.8.22 , reducing the logic for fetching specail-type opcode (at bytecode level)
				if((opd_reg(1) or complex_2 or hazard_structure or (not opd_reg(0) and opdnum_1(0)) or branch) = '1') then
					semitranslated_code_reg( 7 downto 0) <= x"FF";
				else
					semitranslated_code_reg( 7 downto 0) <= semi_code2;
				end if;
			end if;
		end if;
	end process;
	
	------------------------------------------------- start of jaip profiler -----------------------------------------------------------
		label_enable_jaip_profiler_4 : if ENABLE_JAIP_PROFILER = 1 generate
		process(clk, Rst, xcptn_flush_pipeline, TH_mgt_context_switch) begin
		if(Rst = '1') or xcptn_flush_pipeline = '1' or TH_mgt_context_switch = '1'  then -- by fox , is it essential ?
		prof_simple_issued_A_reg <= '0';
		prof_simple_issued_B_reg <= '0';
		elsif(rising_edge(clk)) then
			if(stall_fetch_stage = '0') then
				if((complex_1 or opd_reg(0) or branch) = '1') then
									-------------------------- start of jaip profiler -------------------------
									--label_enable_jaip_profiler_0 : if ENABLE_JAIP_PROFILER = 1 generate
					prof_simple_issued_A_reg <= '0';
					if(mode_reg = from_translate and complex_1 = '1' and branch = '0') then
						prof_simple_issued_A_reg <= '1';
					else
						prof_simple_issued_A_reg <= '0';
					end if;
									--end generate;
				else
									-------------------------- start of jaip profiler -------------------------
									--label_enable_jaip_profiler_1 : if ENABLE_JAIP_PROFILER = 1 generate
					if(mode = from_translate) then
						prof_simple_issued_A_reg <= '1';
					else
						prof_simple_issued_A_reg <= '0';
					end if;
									--end generate;
				end if;
				-- modifed by T.H. Wu , 2013.8.22 , reducing the logic for fetching specail-type opcode (at bytecode level)
			-- if((opd_reg(1) or complex_2 or hazard_structure or special_2 or (not opd_reg(0) and opdnum_1(0)) or branch) = '1') then
				if((opd_reg(1) or complex_2 or hazard_structure or (not opd_reg(0) and opdnum_1(0)) or branch) = '1') then
									-------------------------- start of jaip profiler -------------------------
									--label_enable_jaip_profiler_2 : if ENABLE_JAIP_PROFILER = 1 generate
					prof_simple_issued_B_reg <= '0';
					if(mode_reg = from_translate and complex_2 = '1' and opd_reg(0) = '1'  and branch = '0') then
						prof_simple_issued_B_reg <= '1';
					else
						prof_simple_issued_B_reg <= '0';
					end if;
									--end generate;
				else
									-------------------------- start of jaip profiler -------------------------
									--label_enable_jaip_profiler_3 : if ENABLE_JAIP_PROFILER = 1 generate
					if(mode = from_translate) then
						prof_simple_issued_B_reg <= '1';
					else
						prof_simple_issued_B_reg <= '0';
					end if;
									--end generate;
				end if;
			end if;
		end if;
	end process;
	
	process(Clk, Rst) begin
		if(Rst = '1') then
			prof_complex_issued_reg <= '0';
		elsif(rising_edge(Clk)) then
			if(mode_reg = from_translate and mode = from_ROM and branch = '0') then
				prof_complex_issued_reg <= '1';
			else
				prof_complex_issued_reg <= '0';
			end if;
			if(stall_fetch_stage = '0') then
				prof_issued_bytecodes <= prof_issued_bytecodes_T;
			end if;
		end if;
	end process;
	
	prof_issued_bytecodes_F <= prof_issued_bytecodes;
	
	prof_simple_issued_A <= prof_simple_issued_A_reg when(nop_1_tmp = '0') else
							'0';
	prof_simple_issued_B <= prof_simple_issued_B_reg when(nop_2_tmp = '0') else
							'0';
	prof_complex_issued <= prof_complex_issued_reg;
	end generate;
	----------------------------------------------- end of jaip profiler ---------------------------------------------------
	
	-- for immediate nop
	nop_ctrl :
	process(stall_fetch_stage, branch, nxt_reg, mode_reg, switch_instr_branch_reg) begin
		if(((stall_fetch_stage or branch) = '1' or (nxt_reg = '1' and mode_reg = from_translate)) and switch_instr_branch_reg='0' ) then
			nop_1_tmp <='1';
			nop_2_tmp <='1';
		else
			nop_1_tmp <='0';
			nop_2_tmp <='0';
		end if; 
	end process;
	nop_1 <= nop_1_tmp;
	nop_2 <= nop_2_tmp;

	-- modified J-code ROM by T.H.Wu , 2013.8.14 , for removing special J-code
	j_code_ROM : RAMB16_S18
	generic map(
		INIT_00 =>
				x"0088" &		-- x"0F" =>  idimm_0  isub_reverse 
				-- ineg
				x"7878" &		-- x"0E" => 	pop			pop
				-- pop2
				
				x"C1FF" &		-- x"0D" =>	if_acmpne	=> if_cmpne
				x"C0FF" &		-- x"0C" =>	if_acmpeq	=> if_cmpeq
				x"C5FF" &		-- x"0B" =>	if_icmple	=> if_cmple
				x"C4FF" &		-- x"0A" =>	if_icmpgt	=> if_cmpgt
				x"C3FF" &		-- x"09" =>	if_icmpge	=> if_cmpge
				x"C2FF" &		-- x"08" =>	if_icmplt	=> if_cmplt
				x"C1FF" &		-- x"07" =>	if_icmpne	=> if_cmpne
				x"C0FF" &		-- x"06" =>	if_icmpeq	=> if_cmpeq
				x"CDFF" &		-- x"05" =>	ifle
				x"CCFF" &		-- x"04" =>	ifgt
				x"CBFF" &		-- x"03" =>	ifge
				x"CAFF" &		-- x"02" =>	iflt
				x"C9FF" &		-- x"01" =>	ifne
				x"C8FF",		-- x"00" =>	ifeq					
		INIT_01 => 
					--   newarray	end --
				X"78FF" &		-- X"1F" =>
				X"FFFF" &		-- X"1E" =>
				X"20FA" &		-- X"1D" =>
				--   newarray	start -- 
				--   anewarray end   --
				X"78FF" &		-- X"1C" =>
				X"FFFF" &		-- X"1B" =>							Normal
				X"34FA" &		-- X"1A" =>	ldc_load			get_L1_XRT_ref
				X"FFFF" &		-- X"19" =>							Normal
				X"FFE4" &		-- X"18" =>				ldc_w
				--   anewarray start -- 
				--	ldc_w  end
				X"FFFF" &		-- X"17" => 
				X"34FF" &		-- X"16" =>	ldc_load
				X"FFFF" &		-- X"15" => 
				X"FFE4" &		-- X"14" =>				ldc_w
				--	ldc_w  start	--
				--	ldc end	--
				X"FFFF" &		-- X"13" =>	
				X"34FF" &		-- X"12" =>	ldc_load
				X"FFFF" &		-- X"11" =>
				X"FFEE" ,		-- X"10" =>				ldc
				--	ldc start	--

		INIT_02 =>  
				--   arraylength	end -- ... modified by T.H.Wu  2013.8.16
				X"D8FF" &		-- X"2F" =>   ref_load_w
				X"0CFF" &		-- X"2E" =>   ldimm_12 
				--   arraylength	start --
				--   iinc			end --
				x"8450" &		-- x"2D" =>  iadd   		stval_opd
				x"1021" &		-- x"2C" =>  ldval_opd	ldopd<1>
				--   iinc		start --
				--   putstatic end   --
				X"78FF" &		-- X"2B" =>	pop  					Normal
									--									Offset_access
									--									Lower_addr
									--									Up_address
				X"FFFF" &		-- X"2A" =>						Get_entry2
				X"FFFF" &		-- X"29" =>						Get_entry 
				X"FFEB" &		-- X"28" =>			putstatic
				--   putstatic start   --
		--   getfield end   --	
				X"FFFF" &		-- X"27" =>							Field_load
									--								Offset_access
									--									Lower_addr
									--																			
				X"FFFF" &		-- X"26" =>							
				X"FFFF" &		-- X"25" =>								Normal
				X"FFE8" &		-- X"24" =>  				getfield
				--   getfield start   --
			--   getstatic end   --
				X"FFFF" &		-- X"23" =>						Normal
									--									Offset_access
									--									Lower_addr
									--									Up_address
				X"FFFF" &		-- X"22" =>						Get_entry2
				X"FFFF" &		-- X"21" =>						Get_entry 
				X"00EA",		-- X"20" =>	ldopd2	getstatic
				--   getstatic start   --
				
		INIT_03 => --CYC
				X"D5FF" &		-- X"3F" =>	dup2_x1
				
				--dup2_x2 end
				X"D6FF" &		-- X"3E" =>	dup2_x2
				X"F4FF" &		-- X"3D" =>	exchange2
				--dup2_x2 start
				
				X"5C5B" &		-- X"3C" =>	stval_4		stval_3
				--lstore_3, dstore_3
				X"5B5A" &		-- X"3B" =>	stval_3		stval_2
				--lstore_2, dstore_2
				X"5A59" &		-- X"3A" =>	stval_2		stval_1
				--lstore_1, dstore_1
				X"5958" &		-- X"39" =>	stval_1		stval_0
				--lstore_0, dstore_0
				X"5150" &		-- X"38" => stval_opdPlus1 stval_opd
				--lstore, dstore
				X"1B1C" &		-- X"37" =>	ldval_3		ldval_4
				--lload_3, dload_3
				X"1A1B" &		-- X"36" =>	ldval_2		ldval_3
				--lload_2, dload_2
				X"191A" &		-- X"35" =>	ldval_1		ldval_2
				--lload_1, dload_1
				X"1819" &		-- X"34" =>	ldval_0		ldval_1
				--lload_0, dload_0
				X"1011" &		-- X"33" =>	ldval_opd	ldval_opdPlus1
				--lload, dload
				X"0A00" &		-- X"32" =>	ldimm_10	ldimm_0
				--dconst_1
				X"0000" &		-- X"31" =>	ldimm_0		ldimm_0
				--lconst_0, dconst_0
				X"0001" ,		-- X"30" =>   ldimm_0		ldimm_1
				--lconst_1
				
		INIT_04 => 
				--  bastore end   --
				X"7878" &		-- X"4F" =>	pop2
				X"DEFF" &		-- X"4E" =>	ref_store_b
				--  bastore  start --
				--  sastore/castore end   --
				X"7878" &		-- X"4D" =>	pop2
				X"DDFF" &		-- X"4C" =>	ref_store_s
				--  sastore/castore/fastore	start --
				--  iastore/aastore end   --
				X"7878" &		-- X"4B" =>	pop2
				X"DCFF" &		-- X"4A" =>	ref_store_w
				--  iastore/aastore  start --
				--  putfield end   --
				X"7878" &		-- X"49" =>	pop2					Normal
				X"FFFF" &		-- X"48" =>						Field_store
									--									Offset_access
									--									Lower_addr
									--									Up_address
				X"FFFF" &		-- X"47" =>						Get_entry2
				X"FFFF" &		-- X"46" =>						Get_entry 
				X"FFE9" &		-- X"45" =>   		putfield
					--  putfield start   --
					--  new		end  --
				X"FFFF" &		-- X"44" =>
				X"FFFF" &		-- X"43" =>								Normal
									--									Lower_addr
									--									Up_address
				X"FFFF" &		-- X"42" =>						Get_entry2 
				X"FFFF" &		-- X"41" =>						Normal
				X"28EC",		-- X"40" =>	ldopd2		new			
				--   new	start --
				
		INIT_05 => 
				--laload/daload end
				X"FBFF" &		-- X"5F" =>	laload_lower
				X"FBFF" &		-- X"5E" =>	laload_upper
				X"D1FF" &		-- X"5D" =>	dup2
				--laload/daload start
				--lneg end
				X"D488" &		-- X"5C" =>	LALU		isub_reverse
				X"0000" &		-- X"5B" =>	idimm_0		idimm_0
				--lneg start
				X"D482" &		-- X"5A" =>	lxor
				X"D481" &		-- X"59" =>	lor
				X"D483" &		-- X"58" =>	land
				X"D48C" &		-- X"57" =>	lushr
				X"D48E" &		-- X"56" =>	lshr
				X"D48D" &		-- X"55" =>	lshl
				X"D48B" &		-- X"54" =>	lrem
				X"D48A" &		-- X"53" =>	ldiv
				X"D489" &		-- X"52" =>	lmul
				X"D487" &		-- X"51" =>	lsub
				X"D484" ,		-- X"50" =>	ladd 
		INIT_06 =>
				X"F1FF" &		-- X"6F" =>  -- goto
				X"C9FF" &		-- X"6E" =>  -- ifnonnull
				X"C8FF" &		-- X"6D" =>  -- ifnull
				X"E7FF" &		-- X"6C" =>  -- athrow
				--   tableswitch end --
				X"F1FF" &		-- X"6B" =>   goto case 
				X"78FF" &		-- X"6A" =>   pop
				X"F1E0" &		-- X"69" =>   goto index_offset
				X"CA10" &		-- X"68" =>   iflt
				X"38FF" &		-- X"67" =>   dup 
				X"CC10" &		-- X"66" =>   ifgt
				X"2C87" &		-- X"65" =>   ldopd4 		sub
				X"F0D3" &		-- X"64" =>   swap 	stall_jpc				
				X"2C87" &		-- X"63" =>   ldopd4 		sub
				X"38FF" &		-- X"62" =>   dup
				X"E001" &		-- X"61" =>   switch get_default_offset   
				X"FFFF" ,		-- X"60" =>   nop for padding bytes
				--   tableswitch start   --
				
		INIT_07 =>
				--lcmp end
				X"78FF" &		-- X"7F" =>	pop
				X"D485" &		-- X"7E" =>	longALU		ALU_cmp
				--lcmp start
				--   ireturn/freturn	end   --
				X"FFFF" &		-- X"7D" =>	mem2reg_2
				X"E6FF" &		-- X"7C" =>	mem2reg_1
				X"DBE1" &		-- X"7B" =>	stjpc		ireturn_off
				X"70FF" &		-- X"7A" =>	stvp
				X"FFFF" &		-- X"79" =>
				X"E5FF" &		-- X"78" =>	stsp_s
				X"F3E3" &		-- X"77" =>	exchange	ireturn_on
				--   ireturn/freturn  start   --
				--   return	end   --
				X"FFFF" &		-- X"76" =>	mem2reg_2
				X"E6FF" &		-- X"75" =>	mem2reg_1
				X"78E1" &		-- X"74" =>	pop			return_off
				X"DBFF" &		-- X"73" =>	stjpc
				X"70FF" &		-- X"72" =>	stvp
				X"FFFF" &		-- X"71" =>
				X"E5E2" ,		-- X"70" =>	stsp_s		return_on
				--   return  start   --

		INIT_08 =>
				X"FFFF" &		-- X"8F" =>
				X"F4FF" &		-- X"8E" => get field ref back for 64-bits getfield
				X"78FF" &		-- X"8D" =>	pop for putfield
				-- lastore/dastore end
				X"7878" &		-- X"8C" =>	pop2
				X"DFFF" &		-- X"8B" => lastore_upper
				X"DFFF" &		-- X"8A" =>	lastore_lower
				-- lastore/dastore start
				--   lookupswitch end	--
				X"F110" &		-- X"89" =>	goto default_offset
				X"78FF" &		-- X"88" =>	pop nop 
				X"C8FF" &		-- X"87" =>	ifqe
				X"E003" &		-- X"86" =>	compute npair
				X"2C87" &		-- X"85" =>	ldopd4 sub
				X"38FF" &		-- X"84" =>	dup
				X"E002" &		-- X"83" =>	get_npair
				X"FFFF" &		-- X"82" =>	
				X"E001" &		-- X"81" =>	switch_on  get_default_offset
				X"FFFF",		-- X"80" =>
				--   lookupswitch start  --
					
		INIT_09 =>
				X"FFFF" &		-- X"9F" =>	
				X"FCFF" &		-- X"9E" =>	load index for mulanewarray
				--  aastore for multianewarray end   --
				X"78FF" &		-- X"9D" =>	pop
				X"DCFF" &		-- X"9C" =>	ref_store_w
				--  aastore for multianewarray  start --
					-- monitorexit end, returning sync method end --
				X"78FF" &		-- X"9B" =>
				X"FFFF" &		-- X"9A" =>
				X"F9FF" &		-- X"99" =>
				--  monitorexit start --
				X"18FF" &		-- X"98" => 
					-- returning sync method start --
				X"FFFF" &		-- X"97" =>
				X"FFFF" &		-- X"96" =>
					-- monitorenter end, invoking sync method end --  
				X"78FF" &		-- X"95" => 
				X"F8FF" &		-- X"94" => 
					-- monitorenter start --
				X"18FF" &		-- X"93" =>
					-- invoking sync method start --  
		--   multianewarray end	--
				X"FCFF" &		-- X"92" =>	load size
				X"F2FF" &		-- X"91" =>   
				X"F7FF",		-- X"90" =>
				--   multianewarray start  --
				
		INIT_0A => 
				X"FFFF" &		-- X"AF" =>
				X"FFFF" &		-- X"AE" =>
				X"FFFF" &		-- X"AD" =>
				X"FFFF" &		-- X"AC" =>
				X"FFFF" &		-- X"AB" =>
				X"FFFF" &		-- X"AA" =>
				X"FFFF" &		-- X"A9" => 
				--   invokestatic	end	--
				X"FFFF" &		-- X"A8" =>	mem2reg_2		Method_exit
				X"E6FF" &		-- X"A7" =>	mem2reg_1		max_local
				X"FFFF" &		-- X"A6" =>						max_stack
				X"FFFF" &		-- X"A5" =>						arg_size				Native_exit
				X"FFFF" &		-- X"A4" =>						Method_flag				Native_StackAdjusting1
				X"FFFF" &		-- X"A3" =>						Method_entry			Native_SpAdjusting
				X"FFFF" &		-- X"A2" =>						Get_entry2
				X"3031" &		-- X"A1" =>	ldjpc	ldvp	Normal
				X"00EF",		-- X"A0" =>	ldimm_0	invoke static
				--   invokestatic!!!!!!!

		INIT_0B => 
		-- clinit end 
				X"FFFF" &		-- X"BF" =>   Method_exit
				X"E6FF" &		-- X"BE" =>   max_local
				X"FFFF" &		-- X"BD" =>	max_stack
				X"FFFF" &		-- X"BC" =>	arg_size
				X"FFFF" &		-- X"BB" =>	Method_flag
				X"FFFF" &		-- X"BA" =>	Method_entry
																-- pipeline stall
				--									ClinitRetFrm3
				--									ClinitRetFrm2 
				X"3031"&		-- X"B9" =>		ClinitRetFrm1   
				-- modified by T.H.Wu , 2013.8.20 , a bug about clinit 
				-- clinit start 
				--   invokespecial   end	--
				X"FFFF" &		-- X"B8" =>	mem2reg_2		Method_exit
				X"E6FF" &		-- X"B7" =>	mem2reg_1		max_local
				X"FFFF" &		-- X"B6" =>				max_stack
				X"FFFF" &		-- X"B5" =>					arg_size				Native_exit
				X"FFFF" &		-- X"B4" =>						Method_flag				Native_StackAdjusting1
				X"FFFF" &		-- X"B3" =>						Method_entry			Native_SpAdjusting
									--								Enable_MA_management
									--								IllegalOffset
									--								Offset_access
									--								Lower_addr 
				X"FFFF" &		-- X"B2" =>	nop		nop	Get_entry
				X"3031" &		-- X"B1" =>	ldjpc	ldvp	Normal
				X"00EF",		-- X"B0" =>	ldimm_0	invoke static
				--   invokespecial  start   --  !!!!!!!

		INIT_0C => 
				X"F0FF" &		-- X"CF" => -- swap --
				X"D1FF" &		-- X"CE" => -- dup2 --
				X"D2FF" &		-- X"CD" => -- dup_x2 --
				X"D0FF" &		-- X"CC" => -- dup_x1 --
				X"D9FF" &		-- X"CB" => -- caload , saload --
				X"DAFF" &		-- X"CA" => -- baload --
				X"D8FF" &		-- X"C9" => -- iaload , aaload , faload --
				--   invokeinterface end   --
				X"FFFF" &		-- X"C8" =>	mem2reg_2		Method_exit
				X"E6FF" &		-- X"C7" =>	mem2reg_1		max_local
				X"FFFF" &		-- X"C6" =>						max_stack
				X"FFFF" &		-- X"C5" =>						arg_size
				X"FFFF" &		-- X"C4" =>						Method_flag
				X"FFFF" &		-- X"C3" =>						Method_entry
									--								Enable_MA_management
									--								Offset_access
									--								...
									--								invoke_objref_next
									--								invoke_objref_ListClsID
									--								Get_ObjClsID
									--								Lower_addr
									--								Get_ArgSize
				X"FFFF" &		-- X"C2" =>						
				X"3031" &		-- X"C1" =>	ldjpc,	ldvp		Normal
				X"00ED",		-- X"C0" =>	ldjpc,	invoke
				--   invokeinterface start   --

		INIT_0D =>
				X"FFFF" & 		--for GC
				X"E6FF" &		-- X"DE" =>
				X"FFFF" &		-- X"DD" =>
				X"FFFF" &		-- X"DC" =>
				X"FFFF" &		-- X"DB" =>  
				X"FFFF" &		-- X"DA" =>	
				X"FFFF" &		-- X"D9" =>--for GC
				--   invokevirtual  end   --
				X"FFFF" &		-- X"D8" =>	mem2reg_2		Method_exit
				X"E6FF" &		-- X"D7" =>	mem2reg_1		max_local
				X"FFFF" &		-- X"D6" =>						max_stack
				X"FFFF" &		-- X"D5" =>						arg_size
				X"FFFF" &		-- X"D4" =>						Method_flag
				X"FFFF" &		-- X"D3" =>						Method_entry
				X"FFFF" &		-- X"D2" =>						Get_entry2
				X"3031" &		-- X"D1" =>	ldjpc,	ldvp		Normal
				X"00ED",		-- X"D0" =>	ldjpc,	invoke
				--   invokevirtual  start   -- 
				
		INIT_0E => 
				X"FFFF" &		-- X"EF" =>
				X"FFFF" &		-- X"EE" =>  
				X"FFFF" &		-- X"ED" =>  
				X"FFFF" &		-- X"EC" =>  
				X"FFFF" &		-- X"EB" =>  
				X"FFFF" &		-- X"EA" =>  
				
				-- lreturn/dreturn  end
				X"FFFF" &		-- X"E9" =>
				X"E6FF" &		-- X"E8" =>	mem2LV
				X"E1FF" &		-- X"E7" =>	lreturn-off	pop
				X"DBFF" &		-- X"E6" =>	stjpc		
				X"70FF" &		-- X"E5" =>	stvp
				X"FFFF" &		-- X"E4" =>	
				X"E5E2" &		-- X"E3" =>	stsp_s
				X"FFFF" &		-- X"E2" =>				
				X"7878" &		-- X"E1" =>	pop2 
				X"FFF5",		-- X"E0" =>				lreturn
				-- lreturn/dreturn  start
				
		
		INIT_0F =>
				X"FFFF" &		--X"FF" =>
				X"FFFF" &		--X"FE" =>
				X"FFFF" &		--X"FD" =>
				X"FFFF" &		--X"FC" =>
				X"FFFF" &		--X"FB" =>
				X"FFFF" &		--X"FA" =>
				X"FFFF" &		--X"F9" =>
				X"FFFF" &		--X"F8" =>
				-- ldc2_w  end
				X"FFFF" &		--X"F7" =>
				X"34FF" &		--X"F6" =>	ldc_load
				X"FFFF" &		--X"F5" =>
				X"FFF6" &		--X"F4" =>				ldc2_w
				X"FFFF" &		--X"F3" =>
				X"34FF" &		--X"F2" =>	ldc_load
				X"FFFF" &		--X"F1" =>
				X"FFE4",		--X"F0" =>				ldc_w
				-- ldc2_w  start
		INIT_10 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
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
		INIT_3F => X"0000000000000000000000000000000000000000000000000000000000000000",
		INITP_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INITP_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INITP_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INITP_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INITP_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INITP_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INITP_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
		INITP_07 => X"0000000000000000000000000000000000000000000000000000000000000000"
	)
	port map (
		ADDR(9 downto 8) => "00",
		ADDR(7 downto 0) => jcode_addr,
		DI  => (others => '0'),
		DIP => "00",
		DO  => ROM_instr,
		CLK => clk,
		EN  => '1',
		SSR => Rst,
		WE  => '0'
	);
 
		-- modified by T.H.Wu , 2013.8.14  
	TransAddr_ctrl :
	process(jcode_counter, rtn_frm_sync_mthd_active_hold) begin
		--  TransAddr LSB = 0 --
		case jcode_counter is 
			when x"00" => nxt <= '1';  -- ifeq  
			when x"01" => nxt <= '1';  -- ifne
			when x"02" => nxt <= '1';  -- iflt
			when x"03" => nxt <= '1';  -- ifge
			when x"04" => nxt <= '1';  -- ifgt
			when x"05" => nxt <= '1';  -- ifle
			when x"06" => nxt <= '1';  -- if_icmpeq
			when x"07" => nxt <= '1';  -- if_icmpne
			when x"08" => nxt <= '1';  -- if_cmplt
			when x"09" => nxt <= '1';  -- if_cmpge
			when x"0A" => nxt <= '1';  -- if_cmpgt
			when x"0B" => nxt <= '1';  -- if_cmple
			when x"0C" => nxt <= '1';  -- if_acmpeq
			when x"0D" => nxt <= '1';  -- if_acmpne
			when X"0E" => nxt <= '1';  -- pop2
			when X"0F" => nxt <= '1';  -- ineg
			when X"13" => nxt <= '1';  -- ldc
			when X"17" => nxt <= '1';  -- ldc_w
			when X"1C" => nxt <= not multiarray_flag;  -- anewarray
			when X"1F" => nxt <= '1';  -- newarray
			when X"23" => nxt <= not long_field_flag;  -- getstatic
			when X"27" => nxt <= not long_field_flag;  -- getfield
			when X"2B" => nxt <= not long_field_flag;  -- putstatic
			when X"2D" => nxt <= '1';  -- iinc
			when X"2F" => nxt <= '1';  -- arraylength
			when X"30" => nxt <= '1';  -- lconst_1
			when X"31" => nxt <= '1';  -- lconst_0, dconst_0
			when X"32" => nxt <= '1';  -- dconst_1
			when X"33" => nxt <= '1';  -- lload, dload
			when X"34" => nxt <= '1';  -- lload_0, dload_0
			when X"35" => nxt <= '1';  -- lload_1, dload_1
			when X"36" => nxt <= '1';  -- lload_2, dload_2
			when X"37" => nxt <= '1';  -- lload_3, dload_3
			when X"38" => nxt <= '1';  -- lstore, dstore
			when X"39" => nxt <= '1';  -- lstore_0, dstore_0
			when X"3A" => nxt <= '1';  -- lstore_1, dstore_1
			when X"3B" => nxt <= '1';  -- lstore_2, dstore_2
			when X"3C" => nxt <= '1';  -- lstore_3, dstore_3
			when X"3E" => nxt <= '1';  -- dup2_x2
			when X"3F" => nxt <= '1';  -- dup2_x1
			when X"44" => nxt <= '1';  -- new
			when X"49" => nxt <= '1';  -- putfield
			when X"4B" => nxt <= '1';  -- iastore aastore
			when X"4D" => nxt <= '1';  -- sastore castore
			when X"4F" => nxt <= '1';  -- bastore  
			when X"50" => nxt <= '1';  -- ladd 
			when X"51" => nxt <= '1';  -- lsub
			when X"52" => nxt <= '1';  -- lmul
			when X"53" => nxt <= '1';  -- ldiv
			when X"54" => nxt <= '1';  -- lrem
			when X"55" => nxt <= '1';  -- lshl
			when X"56" => nxt <= '1';  -- lshr
			when X"57" => nxt <= '1';  -- lushr
			when X"58" => nxt <= '1';  -- land
			when X"59" => nxt <= '1';  -- lor
			when X"5A" => nxt <= '1';  -- lxor
			when X"5C" => nxt <= '1';  -- lneg
			when X"5F" => nxt <= '1';  -- laload
			when X"6B" => nxt <= '1';  -- tableswitch 
			when X"6C" => nxt <= '1';  -- athrow
			when X"6D" => nxt <= '1';  -- ifnull
			when X"6E" => nxt <= '1';  -- ifnonnull
			when X"6F" => nxt <= '1';  -- goto
			when X"76" => nxt <= '1';  -- return
			when X"7D" => nxt <= '1';  -- ireturn  dreturn freturn lreturn
			when X"7F" => nxt <= '1';  -- lcmp
			when X"89" => nxt <= '1';  -- lookupswitch 
			when X"8C" => nxt <= '1';  -- lstore 
			--when X"92" => nxt <= '1';  -- multinewarray 
			when X"95" => nxt <= '1';  -- monitorenter 
			when X"9B" => nxt <= not rtn_frm_sync_mthd_active_hold; -- monitorexit  
			when X"9D" => nxt <= not multiarray_flag; -- aastore for multianewarray
			when X"A8" => nxt <= '1';  -- invokestatic
			when X"B8" => nxt <= '1';  -- invokespecial 
			when X"BF" => nxt <= '1';  -- clinit		
			when X"C8" => nxt <= '1';  -- invokeinterface 
			when X"C9" => nxt <= '1';  -- iaload , aaload , laload , faload , daload
			when X"CA" => nxt <= '1';  -- baload
			when X"CB" => nxt <= '1';  -- caload , saload
			when X"CC" => nxt <= '1';  -- dup_x1
			when X"CD" => nxt <= '1';  -- dup_x2
			when X"CE" => nxt <= '1';  -- dup2
			when X"CF" => nxt <= '1';  -- swap
			when X"D8" => nxt <= '1';  -- invokevirtual
			when X"DF" => nxt <= '1';  -- GC
			when X"E9" => nxt <= '1';  -- lreturn
			when X"F7" => nxt <= '1';  -- ldc2_w
			
			-- this is essential , can not be deleted , 2013.8.14
			when X"FF" => nxt <= '1';  -- end 
			
			when others => nxt <= '0';
		end case;
	end process;
	
	
	-- fox , for thread management , 2013.7.11 
	process(clk) begin
		if(rising_edge(clk)) then
			if(Rst = '1' ) then
				TH_mgt_clean_fetch <= '0';
				TH_mgt_clean_decode <= '0'; 
				Disable_semicode_during_context_switch <= '0';
			else
				TH_mgt_clean_fetch	<= TH_mgt_clean_pipeline;
				if(stall_fetch_stage = '0') then 
				TH_mgt_clean_decode <= TH_mgt_clean_fetch; 
				end if;
				-- modified by T.H.Wu , 2013.7.25
				if(TH_mgt_clean_fetch='1') then
					Disable_semicode_during_context_switch <= '1';
				elsif (TH_mgt_context_switch='1') then
					Disable_semicode_during_context_switch <= '0';
				end if;
			end if;
		end if;
	end process;
	
end architecture rtl;