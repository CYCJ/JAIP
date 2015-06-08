------------------------------------------------------------------------------
-- Filename	:	instruction_buffer.vhd
-- Version	:	1.0
-- Author	:	Cheng_Yang Chen
-- Date		:	Aug 2014
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.							**		
-- ** Multimedia Embedded System Lab, NCTU.								**  
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
-- ***************************************************************************
--
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity instruction_buffer is
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		stall_instruction_buffer	: in  std_logic;
		instruction_buffer_2		: out std_logic_vector(15 downto 0);
		instruction_buffer_1		: out std_logic_vector(15 downto 0);   
		instruction_buffer_0		: out std_logic_vector(15 downto 0);
		
		--method area buffer
		RAM_output				: in std_logic_vector(63 downto 0);
		ram_sel					: in std_logic_vector(1 downto 0);
		
		--  thread management , 2013.7.16
		clear_buffer				: in  std_logic;
		-- xcptn
		xcptn_flush_pipeline		: in  std_logic;
		mask_insr1				: in  std_logic
		
	);
end entity instruction_buffer;

architecture rtl of instruction_buffer is

	
	signal instr_buf_0			: std_logic_vector(15 downto 0);
	signal instr_buf_1			: std_logic_vector(15 downto 0);
	signal instr_buf_2			: std_logic_vector(15 downto 0);
	
	begin
	
	instruction_buffer_1 <= instr_buf_1; 
	instruction_buffer_2 <= instr_buf_2;  
	
	instruction_buffer_controll : process(clk) begin
		if(rising_edge(clk)) then		
		if(Rst = '1') then 
			instr_buf_1 <= (others => '0');
			instr_buf_2 <= (others => '0');
		else 
			if xcptn_flush_pipeline = '1' or clear_buffer='1' then
				instr_buf_1 <= X"0000";
				instr_buf_2 <= X"0000";
			elsif(stall_instruction_buffer = '0') then
				instr_buf_1 <= instr_buf_0;
				instr_buf_2 <= instr_buf_1;
			end if;
		end if;
		end if;
	end process;
	
	
	instruction_buffer_0 <=  
					X"0000"   when xcptn_flush_pipeline = '1' or clear_buffer='1' else
				X"00"& instr_buf_0(7 downto 0)  when mask_insr1 = '1' else  
				instr_buf_0;
	
	instr_buf_0 <= RAM_output((to_integer(unsigned(ram_sel))*16+15) downto (to_integer(unsigned(ram_sel))*16));
	
	
end architecture rtl;
