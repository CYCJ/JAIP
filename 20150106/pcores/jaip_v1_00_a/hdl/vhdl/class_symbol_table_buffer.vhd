------------------------------------------------------------------------------
-- Filename	:	method_area.vhd
-- Version	:	2.02
-- Author	:	Kuan-Nian Su
-- Date		:	Dec 2008
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
-- Filename	:	method_area.vhd
-- Version	:	2.03
-- Author	:	Kuan-Nian Su
-- Date		:	May 2009
-- VHDL Standard:	VHDL'93
-----------------------------------Update------------------------------------- 
-- Version	:	3.0
-- Author	:	Han-Wen kuo
-- Date		:	Nov 2010
-- VHDL Standard:	VHDL'93
-- Describe	:	cleaning up
-----------------------------------Update-------------------------------------  
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity class_symbol_table_buffer is
	generic(
		RAMB_S18_AWIDTH			: integer := 10
	);
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		address					: in  std_logic_vector(11 downto 0);
		block_select_base		: in  std_logic_vector( 4 downto 0); 
		CST_buffer_wen			: in  std_logic;
		CST_buffer_wr_data		: in  std_logic_vector(31 downto 0);  
		CST_entry				: out std_logic_vector(31 downto 0)
	);
end entity class_symbol_table_buffer;

architecture rtl of class_symbol_table_buffer is

	component class_bram
	generic(
		RAMB_S18_AWIDTH			: integer := 10
	);
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		address					: in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0);
		methodarea_wr_en			: in  std_logic;
		methodarea_wr_val		: in  std_logic_vector(15 downto 0);
		bytecodes				: out std_logic_vector(15 downto 0)
	);
	end component;

	type RAM_output_array	is array (integer range 0 to 3) of std_logic_vector(31 downto 0);
	type RAM_wen_array		is array (integer range 0 to 3) of std_logic;
	
	signal ram_sel				: std_logic_vector( 1 downto 0);
	signal block_sel				: std_logic_vector( 4 downto 0);
	signal block_offset_inram	: std_logic_vector( 2 downto 0);
	signal word_offset			: std_logic_vector( 5 downto 0);
	
	signal RAM_addr				: std_logic_vector( 8 downto 0);
	signal RAM_output			: RAM_output_array;
	signal RAM_we_en				: RAM_wen_array;
	
	signal ram_sel_for_out		: std_logic_vector(1 downto 0);
	
	begin
	
	block_sel <= block_select_base + address(10 downto 6);
	
	block_offset_inram <= block_sel(2 downto 0);
	word_offset		<= address(5 downto 0);
	RAM_addr		<= block_offset_inram( 2 downto 0 ) & word_offset(5 downto 0);
	
	ram_sel	<= block_sel(4 downto 3);
	
	RAM_sel_for_output : process(clk) begin
		if(rising_edge(clk)) then
		if(Rst = '1') then
			ram_sel_for_out <= (others => '0');
		else
			--if(stall_instruction_buffer = '0') then
				ram_sel_for_out <= ram_sel;
			--   end if;
		end if;
		end if;
	end process;

	CST_entry	<= RAM_output(to_integer(unsigned(ram_sel_for_out)));
					
	RAM_we_en_signal : process(ram_sel, CST_buffer_wen) begin
		for idx in 0 to 3 loop
			RAM_we_en(idx) <= '0';
		end loop;
		RAM_we_en(to_integer(unsigned(ram_sel))) <= CST_buffer_wen;
	end process;
	
	G1 : for idx in 0 to 3 generate
		RAM_array : RAMB16_S36
		port map(	
			DI	=> CST_buffer_wr_data,
			DIP   => (others => '0'),
			ADDR  => RAM_addr,
			DO	=> RAM_output(idx),
			CLK   => clk,
			EN	=> '1',
			SSR   => Rst,
			WE	=> RAM_we_en(idx)
			--Rst			=> Rst, 
			-- clk			=> clk,
			--  address		=> RAM_addr,
			--  methodarea_wr_en  => RAM_we_en(idx),
			-- methodarea_wr_val => CST_buffer_wr_data,
			-- bytecodes		=> RAM_output(idx)
		);
	end generate G1;

end architecture rtl;
