------------------------------------------------------------------------------
-- Filename	:	cross_reference_table.vhd
-- Version	:	1.00
-- Author	:	Zi-Gang Lin
-- Date		:	July 2010
-- VHDL Standard:	VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.							**
-- ** Multimedia Embedded System Lab, NCTU.								**
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
-- ***************************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity cross_reference_table is
	generic(
		RAMB_S18_AWIDTH  : integer := 12 --12 = 16KB
	);
	port(
		Rst			: in  std_logic;
		clk			: in  std_logic;
		--address		: in  std_logic_vector(11 downto 0);
		address		: in  std_logic_vector(12 downto 0); -- modified by C.C.H. 2013.7.11
		offset_in		: in  std_logic_vector(31 downto 0);
		offset_out	: out std_logic_vector(31 downto 0);
		load_request	: in  std_logic;
		store_request	: in  std_logic;
		crt_complete	: out std_logic
	);
end entity cross_reference_table;

architecture rtl of cross_reference_table is

	component RAMB16_S36 port (
		DO					: out std_logic_vector(31 downto 0);
		DI					: in  std_logic_vector(31 downto 0);
		DIP				: in  std_logic_vector(3 downto 0);
		DOP				: out std_logic_vector(3 downto 0);
		ADDR				: in  std_logic_vector(8 downto 0);
		SSR				: in  std_logic;
		CLK				: in  std_logic;
		EN					: in  std_logic;
		WE					: in  std_logic);
	end component;
	
	-- modified by C.C.H. 2013.7.11
	--type offset_array	is array (integer range 0 to 7) of std_logic_vector(31 downto 0);
	--type xrt_we_en_array is array (integer range 0 to 7) of std_logic;
	type offset_array	is array (integer range 0 to 15) of std_logic_vector(31 downto 0);
	type xrt_we_en_array is array (integer range 0 to 15) of std_logic;

	-- modified by C.C.H. 2013.7.11
	signal RAM_select	: std_logic_vector(3 downto 0);
	--signal RAM_select	: std_logic_vector(2 downto 0);
	-- modified by C.C.H. 2013.7.11
	signal RAM_select_delay : std_logic_vector(3 downto 0);
	--signal RAM_select_delay : std_logic_vector(2 downto 0);
	signal RAM_output	: offset_array;
	signal RAM_we_en		: xrt_we_en_array;
	
begin 

	offset_out <= RAM_output(to_integer(unsigned(RAM_select)));  
	
	-- modified by C.C.H. 2013.7.11
	--RAM_select <= address(11 downto 9) when store_request = '1' else RAM_select_delay;
	RAM_select <= address(12 downto 9) when store_request = '1' else RAM_select_delay;	
	
	process (clk)is
	begin
		if(rising_edge (clk))then
			if(Rst = '1')then
				crt_complete <= '0';
				RAM_select_delay <= (others => '0');
			else
				--RAM_select_delay <= address(11 downto 9); -- modified by C.C.H. 2013.7.11
				RAM_select_delay <= address(12 downto 9); 
				if (load_request = '1') then
					crt_complete <= '1';
				else
					crt_complete <= '0';
				end if;
			end if;
		end if;
	end process;
	
	RAM_we_en_signal : process(RAM_select, store_request) begin
		--for idx in 0 to 7 loop -- modified by C.C.H. 2013.7.11
		for idx in 0 to 15 loop
			RAM_we_en(idx) <= '0';
		end loop;
		RAM_we_en(to_integer(unsigned(RAM_select))) <= store_request;
	end process;
	
	-- modified by C.C.H. 2013.7.11
	G1 : for idx in 0 to 11 generate
	--G1 : for idx in 0 to 7 generate
		RAM_array : RAMB16_S36
		port map(
			DI	=> offset_in,
			DIP   => (others => '0'),
			ADDR  => address(8 downto 0),
			DO	=> RAM_output(idx),
			CLK   => clk,
			EN	=> '1',
			SSR   => Rst,
			WE	=> RAM_we_en(idx)
		);
	end generate G1;

end architecture rtl;
