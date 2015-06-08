------------------------------------------------------------------------------
-- Filename     :       bytecode_profiler.vhd
-- Version      :       1.00
-- Author       :       Chia-Che Hsu
-- Date         :       Mar. 2013
-- VHDL Standard:       VHDL'93
-- Describe     :       
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2012. All rights reserved.                              **        
-- ** Multimedia Embedded System Lab, NCTU.                                 **  
-- ** Department of Computer Science and Information engineering            **
-- ** National Chiao Tung University, Hsinchu 300, Taiwan                   **
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.config.all;

entity bytecode_profiler is
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

end entity bytecode_profiler;

architecture rtl of bytecode_profiler is

component my_bram_as_rd
		port(
			----------------------------------------------------------------
			-- port A
			----------------------------------------------------------------
			CLK_A					: in std_logic; 
			EN_A					: in std_logic;
			WE_A					: in std_logic; -- read/write control
			Addr_A					: in std_logic_vector(0 to 7);
			Data_In_A				: in std_logic_vector(0 to 159);
			Data_Out_A				: out std_logic_vector(0 to 159);
			
			----------------------------------------------------------------
			-- port B
			----------------------------------------------------------------
			CLK_B					: in std_logic; 
			EN_B					: in std_logic;
			WE_B					: in std_logic; -- read/write control
			Addr_B					: in std_logic_vector(0 to 7);
			Data_In_B				: in std_logic_vector(0 to 159);
			Data_Out_B				: out std_logic_vector(0 to 159)
		);
end component;
	
	signal time_stmp_A		: std_logic_vector(127 downto 0);
	signal bytecode_buf_A	: std_logic_vector(7 downto 0); 
	signal time_stmp_B		: std_logic_vector(127 downto 0);
	signal bytecode_buf_B	: std_logic_vector(7 downto 0); 
	signal buf_A_valid 		: std_logic;
	signal buf_B_valid 		: std_logic;
	signal rd_A_finished	: std_logic;
	signal rd_B_finished	: std_logic;

	signal PT_A_WE					: std_logic;
	signal bytecode_profile_A_out	: std_logic_vector(159 downto 0);
	signal bytecode_profile_A_in	: std_logic_vector(159 downto 0);
	signal PT_B_WE 					: std_logic;
	signal bytecode_profile_B_out 	: std_logic_vector(159 downto 0);
	signal bytecode_profile_B_in	: std_logic_vector(159 downto 0);
	signal bytecode_profile_A_intern : std_logic_vector(159 downto 0);
	signal bytecode_profile_B_intern : std_logic_vector(159 downto 0);
	signal bytecode_profile_A_out_reg	: std_logic_vector(159 downto 0);
	signal bytecode_profile_B_out_reg	: std_logic_vector(159 downto 0);
	
	signal HW_time_interval_A			: std_logic_vector(31 downto 0);
	signal Intrpt_time_interval_A		: std_logic_vector(31 downto 0);
	signal DSRU_time_interval_A			: std_logic_vector(31 downto 0);
	signal heap_access_time_interval_A	: std_logic_vector(31 downto 0);
	signal HW_time_interval_B			: std_logic_vector(31 downto 0);
	signal Intrpt_time_interval_B		: std_logic_vector(31 downto 0);
	signal DSRU_time_interval_B			: std_logic_vector(31 downto 0);
	signal heap_access_time_interval_B	: std_logic_vector(31 downto 0);
	
	signal HW_time_accum_A			: std_logic_vector(31 downto 0);
	signal Intrpt_time_accum_A		: std_logic_vector(31 downto 0);
	signal DSRU_time_accum_A			: std_logic_vector(31 downto 0);
	signal heap_access_time_accum_A	: std_logic_vector(31 downto 0);
	signal HW_time_accum_B			: std_logic_vector(31 downto 0);
	signal Intrpt_time_accum_B		: std_logic_vector(31 downto 0);
	signal DSRU_time_accum_B			: std_logic_vector(31 downto 0);
	signal heap_access_time_accum_B	: std_logic_vector(31 downto 0);
begin
	
	bytecode_profile <= bytecode_profile_A_out(159 downto 128) + bytecode_profile_B_out(159 downto 128) when (profile_sel = "000") else
						bytecode_profile_A_out(127 downto 96) + bytecode_profile_B_out(127 downto 96) when (profile_sel = "001") else
						bytecode_profile_A_out(95 downto 64) + bytecode_profile_B_out(95 downto 64) when (profile_sel = "010") else
						bytecode_profile_A_out(63 downto 32) + bytecode_profile_B_out(63 downto 32) when (profile_sel = "011") else
						bytecode_profile_A_out(31 downto 0) + bytecode_profile_B_out(31 downto 0) when (profile_sel = "100") else
						x"66666666";
	
    Profile_Table_A : my_bram_as_rd
    port map(     
       		----------------------------------------------------------------
			-- port A
			----------------------------------------------------------------
			CLK_A					=> Clk, 
			EN_A					=> '1',
			WE_A					=> PT_A_WE,
			Addr_A					=> bytecode_buf_A,
			Data_In_A				=> bytecode_profile_A_in,
			
			----------------------------------------------------------------
			-- port B
			----------------------------------------------------------------
			CLK_B					=> Clk,
			EN_B					=> '1',
			WE_B					=> '0',
			Addr_B					=> bytecode_1,
			Data_In_B				=> (others => '0'),
			Data_Out_B				=> bytecode_profile_A_out
    );
	
	process(Clk, Rst) begin
		if(Rst = '1') then
			time_stmp_A <= (others => '0');
			bytecode_buf_A <= (others => '0');
		elsif(rising_edge(Clk)) then
			if(issued_1 = '1') then
				time_stmp_A <= HW_time & Intrpt_time & DSRU_time & heap_access_time;
				bytecode_buf_A <= bytecode_1;
				buf_A_valid <= '1';
			elsif(issued_2 = '1') then
				buf_A_valid <= '0';
			end if;			
			
			rd_A_finished <= issued_1;
			
			if(rd_A_finished = '1') then
				bytecode_profile_A_out_reg <= bytecode_profile_A_out;
			end if;
		end if;
	end process;
	
	HW_time_interval_A <= HW_time - time_stmp_A(127 downto 96);
	Intrpt_time_interval_A <= Intrpt_time - time_stmp_A(95 downto 64);
	DSRU_time_interval_A <= DSRU_time - time_stmp_A(63 downto 32);
	heap_access_time_interval_A <= heap_access_time - time_stmp_A(31 downto 0);
	
	bytecode_profile_A_intern <= bytecode_profile_A_out when(rd_A_finished = '1') else
								 bytecode_profile_A_out_reg;
	
	HW_time_accum_A <= HW_time_interval_A + bytecode_profile_A_intern(159 downto 128);
	Intrpt_time_accum_A <= Intrpt_time_interval_A + bytecode_profile_A_intern(127 downto 96);
	DSRU_time_accum_A <= DSRU_time_interval_A + bytecode_profile_A_intern(95 downto 64);
	heap_access_time_accum_A <= heap_access_time_interval_A + bytecode_profile_A_intern(63 downto 32);
	
	bytecode_profile_A_in <= HW_time_accum_A & Intrpt_time_accum_A & DSRU_time_accum_A & heap_access_time_accum_A & (bytecode_profile_A_intern(31 downto 0) + x"00000001");
	PT_A_WE <= '1' when((issued_1 = '1' or issued_2 = '1') and buf_A_valid = '1') else
			   '0';
	
	Profile_Table_B : my_bram_as_rd
    port map(     
       		----------------------------------------------------------------
			-- port A
			----------------------------------------------------------------
			CLK_A					=> Clk, 
			EN_A					=> '1',
			WE_A					=> PT_B_WE,
			Addr_A					=> bytecode_buf_B,
			Data_In_A				=> bytecode_profile_B_in,
			
			----------------------------------------------------------------
			-- port B
			----------------------------------------------------------------
			CLK_B					=> Clk,
			EN_B					=> '1',
			WE_B					=> '0',
			Addr_B					=> bytecode_2,
			Data_In_B				=> (others => '0'),
			Data_Out_B				=> bytecode_profile_B_out
    );

	process(Clk, Rst) begin
		if(Rst = '1') then
			time_stmp_B <= (others => '0');
			bytecode_buf_B <= (others => '0');
		elsif(rising_edge(Clk)) then
			if(issued_2 = '1') then
				time_stmp_B <= HW_time & Intrpt_time & DSRU_time & heap_access_time;
				bytecode_buf_B <= bytecode_2;
				buf_B_valid <= '1';
			elsif(issued_1 = '1') then
				buf_B_valid <= '0';	
			end if;
			
			rd_B_finished <= issued_2;
			
			if(rd_B_finished = '1') then
				bytecode_profile_B_out_reg <= bytecode_profile_B_out;
			end if;
		end if;
	end process;
	
	HW_time_interval_B <= HW_time - time_stmp_B(127 downto 96);
	Intrpt_time_interval_B <= Intrpt_time - time_stmp_B(95 downto 64);
	DSRU_time_interval_B <= DSRU_time - time_stmp_B(63 downto 32);
	heap_access_time_interval_B <= heap_access_time - time_stmp_B(31 downto 0);
	
	bytecode_profile_B_intern <= bytecode_profile_B_out when(rd_B_finished = '1') else
								 bytecode_profile_B_out_reg;
	
	HW_time_accum_B <= HW_time_interval_B + bytecode_profile_B_intern(159 downto 128);
	Intrpt_time_accum_B <= Intrpt_time_interval_B + bytecode_profile_B_intern(127 downto 96);
	DSRU_time_accum_B <= DSRU_time_interval_B + bytecode_profile_B_intern(95 downto 64);
	heap_access_time_accum_B <= heap_access_time_interval_B + bytecode_profile_B_intern(63 downto 32);
	
	bytecode_profile_B_in <= HW_time_accum_B & Intrpt_time_accum_B & DSRU_time_accum_B & heap_access_time_accum_B & (bytecode_profile_B_intern(31 downto 0) + x"00000001");
	PT_B_WE <= '1' when((issued_1 = '1' or issued_2 = '1') and buf_B_valid = '1') else
			   '0';

   -- cs debug
	debug_bytecode_buf_A <= bytecode_buf_A;
	debug_PT_A_WE <= PT_A_WE;
	debug_buf_A_valid <= buf_A_valid;
	debug_bytecode_profile_A_out <= bytecode_profile_A_out;
end architecture rtl;