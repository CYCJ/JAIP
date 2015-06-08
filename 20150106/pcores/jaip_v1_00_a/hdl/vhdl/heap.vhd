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

entity heap is
	generic(
		RAMB_S18_AWIDTH  : integer := 10
	);
	port(
		Rst			: in  std_logic;
		clk			: in  std_logic;
		heap_data_be	: in  std_logic_vector(3 downto 0);
		address		: in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0);
		heap_data_in	: in  std_logic_vector(31 downto 0);
		heap_data_out	: out std_logic_vector(31 downto 0);
		store_request	: in  std_logic;
		load_request	: in  std_logic;
		heap_complete	: out std_logic
	);
end entity heap;

architecture rtl of heap is

	type data_out_array   is array (integer range 0 to RAMB_S18_AWIDTH-9) of std_logic_vector(31 downto 0);
	type heap_we_en_array is array (integer range 0 to RAMB_S18_AWIDTH-9) of std_logic;

	signal RAM_select		: std_logic_vector(RAMB_S18_AWIDTH-10 downto 0);
	signal RAM_select_delay	: std_logic_vector(RAMB_S18_AWIDTH-10 downto 0); 
	signal RAM_output		: data_out_array;
	signal RAM_we_en			: heap_we_en_array;
	signal counter			: std_logic_vector(10 downto 0);
	signal store_request_delay  : std_logic;					-- write back
	signal heap_data_in_delay   : std_logic_vector(31 downto 0); -- write back
	signal heap_data_be_delay	: std_logic_vector(3 downto 0);
	signal heap_data			: std_logic_vector(31 downto 0);

begin

	process (clk,Rst) begin
		if (Rst = '1') then
			--counter <= (others => '0');
			heap_complete <= '0';
		elsif(rising_edge(clk))then
			if (load_request = '1' or store_request_delay = '1') then
				--counter <= "00000000001";
				heap_complete <= '1';
			else
				--counter <= counter(9 downto 0) & "0";
				heap_complete <= '0';
			end if;
		end if;
	end process;

	process (clk,Rst) begin
		if (Rst = '1') then   
			store_request_delay <= '0';
		elsif(rising_edge(clk))then	
			store_request_delay <= store_request;
		end if;
	end process;
	--heap_complete <= counter(10);
	
	
	RAM_select <= address(RAMB_S18_AWIDTH-1 downto 9) when store_request = '1' or
														store_request_delay = '1'
													else RAM_select_delay;	
	
	process (clk)is
	begin
		if(Rst = '1')then
			RAM_select_delay <= (others => '0');
		elsif(rising_edge (clk))then
			RAM_select_delay <= address(RAMB_S18_AWIDTH-1 downto 9);
		end if;
	end process;
	
	process (clk) is								-- process add by C.C. Hsu
	begin
		if(Rst = '1') then
			heap_data_be_delay <= (others => '0');
		elsif(rising_edge(clk))then
			heap_data_be_delay <= heap_data_be;
		end if;
	end process;
	
	heap_data_out <= heap_data;
	heap_data	<= RAM_output(to_integer(unsigned(RAM_select)));

	heap_data_in_delay(31 downto 24) <= heap_data(31 downto 24) when heap_data_be_delay(3) = '0' else
										heap_data_in(31 downto 24);
	heap_data_in_delay(23 downto 16) <= heap_data(23 downto 16) when heap_data_be_delay(2) = '0' else
										heap_data_in(23 downto 16);
	heap_data_in_delay(15 downto 8)  <= heap_data(15 downto 8)  when heap_data_be_delay(1) = '0' else
										heap_data_in(15 downto 8);
	heap_data_in_delay( 7 downto 0)  <= heap_data(7 downto 0)   when heap_data_be_delay(0) = '0' else
										heap_data_in(7 downto 0);

	RAM_we_en_signal : process(RAM_select, store_request_delay) begin
		for idx in 0 to 1 loop
			RAM_we_en(idx) <= '0';
		end loop;
		RAM_we_en(to_integer(unsigned(RAM_select))) <= store_request_delay;
	end process;

	G1 : for idx in 0 to 1 generate
		RAM_array : RAMB16_S36
		port map(
			DI	=> heap_data_in_delay,
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