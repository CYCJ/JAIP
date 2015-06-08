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
-- Version	:	4.0
-- Author	:	Cheng-Yang Chen
-- Date		:	Aug 2014
-- VHDL Standard:	VHDL'93
-- Describe	:	split instruction buffer out
-----------------------------------Update-------------------------------------   
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity method_image_buffer is
	generic(
		RAMB_S18_AWIDTH			: integer := 10
	);
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		--act						:  in std_logic;
		address					: in  std_logic_vector(11 downto 0);
		block_select_base		: in  std_logic_vector( 4 downto 0);  
		methodarea_wr_en			: in  std_logic;
		methodarea_wr_val		: in  std_logic_vector(31 downto 0);
	
		--instruction buffer
		RAM_output				: out std_logic_vector(63 downto 0); --16*4
		ram_sel_for_out			: out std_logic_vector(1 downto 0)
		
	);
end entity method_image_buffer;

architecture rtl of method_image_buffer is

	component class_bram
	generic(
		RAMB_S18_AWIDTH			: integer := 10
	);
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		address					: in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0); 
		methodarea_wr_en			: in  std_logic;
		methodarea_wr_val		: in  std_logic_vector(31 downto 0);
		bytecodes				: out std_logic_vector(15 downto 0)
	);
	end component;

	signal ram_sel				: std_logic_vector( 1 downto 0);
	signal block_sel				: std_logic_vector( 4 downto 0);
	signal block_offset_inram	: std_logic_vector( 2 downto 0);
	signal two_byte_offset		: std_logic_vector( 6 downto 0);
	
	type methodarea_we_en_array is array (integer range 0 to 3) of std_logic;
	
	signal RAM_addr				: std_logic_vector( 9 downto 0);
	signal RAM_we_en				: methodarea_we_en_array;
	
	begin   
	
	ram_selector : process(clk) begin
		if(rising_edge(clk)) then		
			if(Rst = '1') then 
				ram_sel_for_out <= (others => '0');
			else 
				ram_sel_for_out <= ram_sel;
			end if;
		end if;
	end process;
	
	
	block_sel <= block_select_base + address(11 downto 7);
	
	block_offset_inram <= block_sel(2 downto 0);
	two_byte_offset	<= address(6 downto 0);
	RAM_addr		<= block_offset_inram( 2 downto 0 ) & two_byte_offset(6 downto 0);
	
	ram_sel	<= block_sel(4 downto 3);
	
	RAM_we_en_signal : process(ram_sel, methodarea_wr_en) begin
		for idx in 0 to 3 loop
			RAM_we_en(idx) <= '0';
		end loop;
		RAM_we_en(to_integer(unsigned(ram_sel))) <= methodarea_wr_en;
	end process;
	
	G1 : for idx in 0 to 3 generate
		RAM_array : class_bram
		generic map(
			RAMB_S18_AWIDTH => RAMB_S18_AWIDTH
		)
		port map(	
			Rst			=> Rst, 
			clk			=> clk,
			address		=> RAM_addr, 
			methodarea_wr_en  => RAM_we_en(idx),
			methodarea_wr_val => methodarea_wr_val,
			bytecodes		=> RAM_output((idx*16+15) downto (idx*16))
		);
	end generate G1;
	
end architecture rtl;
