------------------------------------------------------------------------------
-- Filename	:	mmes_profiler.vhd
-- Version	:	1.00
-- Author	:	Chia-Che Hsu
-- Date		:	Dec 2012
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2012. All rights reserved.							**		
-- ** Multimedia Embedded System Lab, NCTU.								**  
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
-- ***************************************************************************
------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity mmes_profiler is
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
end entity;

architecture rtl of mmes_profiler is

component my_bram
		port(CLK						: in std_logic; 
			----------------------------------------------------------------
			-- port A
			----------------------------------------------------------------
			Addr_A					: in std_logic_vector(0 to 7);
			WE_A						: in std_logic; -- read/write control
			Data_In_A				: in std_logic_vector(0 to 159);
			Data_Out_A				: out std_logic_vector(0 to 159)
		);
end component;
--------------------------------------------------------------------
-- prof_pack_PS:
--
--  offset	|127	96|95		64|63	32|31			0|
--   			----------------------------------------------------
--	profile	| HW time | Intrpt time | DSRU time |	method ID   |
--   			----------------------------------------------------
--------------------------------------------------------------------
--------------------------------------------------------------------
-- prof_pack_PT:
--
--  offset	|127	96|95		64|63	32|31			0|
--   			----------------------------------------------------
--	profile	| HW time | Intrpt time | DSRU time |  Num_of_calls  |
--   			----------------------------------------------------
--------------------------------------------------------------------
signal prof_pack_PSI :	std_logic_vector(159 downto 0);
signal PS_top		:	std_logic_vector(7 downto 0) := x"00";
signal prof_pack_PSO :	std_logic_vector(159 downto 0);

signal PT_WE		:	std_logic;
signal PT_ADDR		: std_logic_vector(7 downto 0);
signal prof_pack_PTI :	std_logic_vector(159 downto 0);
signal prof_pack_PTO :	std_logic_vector(159 downto 0);

TYPE MP_SM_TYPE	is (normal, load_time_stmp, load_time_accm, update_prof);
signal MP_SM 		:	MP_SM_TYPE;
signal MP_SM_NEXT	:	MP_SM_TYPE;

signal HW_time_interval 		: std_logic_vector(31 downto 0);
signal Intrpt_time_interval 	: std_logic_vector(31 downto 0);
signal DSRU_time_interval		: std_logic_vector(31 downto 0);
signal Mem_time_interval		: std_logic_vector(31 downto 0);

signal HW_time_accum			: std_logic_vector(31 downto 0);
signal Intrpt_time_accum		: std_logic_vector(31 downto 0);
signal DSRU_time_accum			: std_logic_vector(31 downto 0);
signal Mem_time_accum			: std_logic_vector(31 downto 0);

signal Num_of_calls				: std_logic_vector(31 downto 0);
signal method_ID_PS				: std_logic_vector(15 downto 0);

signal HW_time_stmp_return		: std_logic_vector(31 downto 0);
signal Intrpt_time_stmp_return	: std_logic_vector(31 downto 0);
signal DSRU_time_stmp_return	: std_logic_vector(31 downto 0);
signal Mem_time_stmp_return		: std_logic_vector(31 downto 0);

signal HW_time_stmp_invoke		: std_logic_vector(31 downto 0);
signal Intrpt_time_stmp_invoke	: std_logic_vector(31 downto 0);
signal DSRU_time_stmp_invoke	: std_logic_vector(31 downto 0);
signal Mem_time_stmp_invoke		: std_logic_vector(31 downto 0);

begin

	Prof_Stack : my_bram
	port map(	
		Clk				=> Clk,
		Addr_A			=> PS_top,
		WE_A  				=> invoke_flag,
		Data_In_A 			=> prof_pack_PSI,
		Data_Out_A			=> prof_pack_PSO
	);
	
	prof_pack_PSI <= HW_time & Intrpt_time & DSRU_time & heap_access_time & x"000000" & method_ID(7 downto 0);	
	
	process (Clk, Rst)
	begin
		if(Rst = '1') then
			PS_top <= (others => '0');
		elsif(rising_edge(Clk)) then
			
			if(invoke_flag = '1') then
				PS_top <= PS_top + 1;
			elsif(return_flag = '1') then
				PS_top <= PS_top - 1;
			end if;
			
		end if;
	end process;
	

	Prof_Table : my_bram
	port map(	
		Clk				=> Clk,
		Addr_A			=> PT_ADDR,
		WE_A  				=> PT_WE,
		Data_In_A 			=> prof_pack_PTI,
		Data_Out_A			=> prof_pack_PTO
	);
	
	HW_time_stmp_invoke <= prof_pack_PSO(159 downto 128);
	Intrpt_time_stmp_invoke <= prof_pack_PSO(127 downto 96);
	DSRU_time_stmp_invoke <= prof_pack_PSO(95 downto 64);
	Mem_time_stmp_invoke <= prof_pack_PSO(63 downto 32);
	method_ID_PS <= prof_pack_PSO(15 downto 0);
	
	PT_ADDR	<= method_ID_PS(7 downto 0) when (MP_SM = load_time_accm or MP_SM = update_prof) else
			method_ID(7 downto 0);
	
	method_profile <= prof_pack_PTO(159 downto 128) when (profile_sel = "000") else
					prof_pack_PTO(127 downto 96) when (profile_sel = "001") else
					prof_pack_PTO(95 downto 64)  when (profile_sel = "010") else
					prof_pack_PTO(63 downto 32)  when (profile_sel = "011") else
					prof_pack_PTO(31 downto 0)   when (profile_sel = "100") else
					x"00000000";
	
	HW_time_interval <= HW_time_stmp_return - HW_time_stmp_invoke;
	Intrpt_time_interval <= Intrpt_time_stmp_return - Intrpt_time_stmp_invoke;
	DSRU_time_interval <= DSRU_time_stmp_return - DSRU_time_stmp_invoke;
	Mem_time_interval <= Mem_time_stmp_return - Mem_time_stmp_invoke;
	
	HW_time_accum	<= HW_time_interval + prof_pack_PTO(159 downto 128);
	Intrpt_time_accum <= Intrpt_time_interval + prof_pack_PTO(127 downto 96);
	DSRU_time_accum	<= DSRU_time_interval + prof_pack_PTO(95 downto 64);
	Mem_time_accum	<= Mem_time_interval + prof_pack_PTO(63 downto 32);
	Num_of_calls <= prof_pack_PTO(31 downto 0) + 1;
	
	prof_pack_PTI <= HW_time_accum & Intrpt_time_accum & DSRU_time_accum & Mem_time_accum & Num_of_calls;
	
	PT_WE <= '1' when (MP_SM = update_prof) else
			'0';
	
	process (Clk, Rst)
	begin
		if(Rst = '1') then
			MP_SM <= normal;
		elsif(rising_edge(Clk)) then
			MP_SM <= MP_SM_NEXT;
		end if;
	end process;
	
	process (MP_SM, return_flag)
	begin
		case MP_SM is
			when normal =>
				if(return_flag = '1') then
					MP_SM_NEXT <= load_time_stmp;
				else
					MP_SM_NEXT <= normal;
				end if;
			
			when load_time_stmp =>
				MP_SM_NEXT <= load_time_accm;
			
			when load_time_accm =>
				MP_SM_NEXT <= update_prof;
			
			when update_prof =>
				MP_SM_NEXT <= normal;
							
			when others =>
				MP_SM_NEXT <= normal;
				
		end case;
	end process;
	
	process(Clk, Rst)
	begin
		if(Rst = '1') then
			HW_time_stmp_return <= (others => '0');
			Intrpt_time_stmp_return <= (others => '0');
			DSRU_time_stmp_return <= (others => '0');
			Mem_time_stmp_return <= (others => '0');
		elsif(rising_edge(Clk)) then
			if(return_flag = '1') then
				HW_time_stmp_return <= HW_time;
				Intrpt_time_stmp_return <= Intrpt_time;
				DSRU_time_stmp_return <= DSRU_time;
				Mem_time_stmp_return <= heap_access_time;
			end if;
		end if;
	end process;
	
end rtl;