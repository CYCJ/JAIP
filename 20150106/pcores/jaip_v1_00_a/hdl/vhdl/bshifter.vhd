------------------------------------------------------------------------------
-- Filename	:	bshifter.vhd
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
-- Filename	:	bshifter.vhd
-- Version	:	2.00
-- Author	:	Kuan-Nian Su
-- Date		:	June 2008
-- VHDL Standard:	VHDL'93
------------------------------------------------------------------------------
-- Filename	:	bshifter.vhd
-- Version	:	2.00
-- Author	:	Han-Wen Kuo
-- Date		:	Sep 2011
-- VHDL Standard:	VHDL'93
-- Describe	:	debug
-----------------------------------Update-------------------------------------
------------------------------------------------------------------------------

library ieee ;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;
use IEEE.std_logic_unsigned.all;

entity bshifter is
port (
	din			: in std_logic_vector(31 downto 0);
	off			: in std_logic_vector(4 downto 0);
	op		: in std_logic_vector(1 downto 0);
	dout		: out std_logic_vector(31 downto 0)
);
end bshifter;


architecture rtl of bshifter is
signal shlen		: std_logic_vector(4 downto 0);
signal result   : std_logic_vector(31 downto 0);
signal mask		: std_logic_vector(31 downto 0);
begin
--	00	ushr
--	01	shl
--	10	shr

	process(off, op(0)) begin
		if(op(0) = '1') then  -- 01 shl
			shlen <= not off;
		else
			shlen <= off;
		end if;
	end process;
	
	process(shlen, op) 
		variable tmp	: std_logic_vector( 3 downto 0);
		variable mask_tmp : std_logic_vector(31 downto 0);
	begin	
		case shlen(1 downto 0) is
			when "01" => tmp := X"7";
			when "10" => tmp := X"3";
			when "11" => tmp := X"1";
			when others => tmp := X"F";
		end case;
		case shlen(4 downto 2) is
			when "000" =>  mask_tmp := tmp & X"FFFFFFF";
			when "001" =>  mask_tmp := X"0" & tmp & X"FFFFFF";
			when "010" =>  mask_tmp := X"00" & tmp & X"FFFFF";
			when "011" =>  mask_tmp := X"000" & tmp & X"FFFF";
			when "100" =>  mask_tmp := X"0000" & tmp & X"FFF";
			when "101" =>  mask_tmp := X"00000" & tmp & X"FF";
			when "110" =>  mask_tmp := X"000000" & tmp & X"F";
			when others => mask_tmp := X"0000000" & tmp;
		end case;
--		case shlen is
--			when "00001" => mask <= X"7FFFFFFF";
--			when "00010" => mask <= X"3FFFFFFF";
--			when "00011" => mask <= X"1FFFFFFF";
--			when "00100" => mask <= X"0FFFFFFF";
--			when "00101" => mask <= X"07FFFFFF";
--			when "00110" => mask <= X"03FFFFFF";
--			when "00111" => mask <= X"01FFFFFF";
--			when "01000" => mask <= X"00FFFFFF";
--			when "01001" => mask <= X"007FFFFF";
--			when "01010" => mask <= X"003FFFFF";
--			when "01011" => mask <= X"001FFFFF";
--			when "01100" => mask <= X"000FFFFF";
--			when "01101" => mask <= X"0007FFFF";
--			when "01110" => mask <= X"0003FFFF";
--			when "01111" => mask <= X"0001FFFF";
--			when "10000" => mask <= X"0000FFFF";
--			when "10001" => mask <= X"00007FFF";
--			when "10010" => mask <= X"00003FFF";
--			when "10011" => mask <= X"00001FFF";
--			when "10100" => mask <= X"00000FFF";
--			when "10101" => mask <= X"000007FF";
--			when "10110" => mask <= X"000003FF";
--			when "10111" => mask <= X"000001FF";
--			when "11000" => mask <= X"000000FF";
--			when "11001" => mask <= X"0000007F";
--			when "11010" => mask <= X"0000003F";
--			when "11011" => mask <= X"0000001F";
--			when "11100" => mask <= X"0000000F";
--			when "11101" => mask <= X"00000007";
--			when "11110" => mask <= X"00000003";
--			when "11111" => mask <= X"00000001";
--			when others =>  mask <= X"FFFFFFFF";
--		end case;
		
		
		if(op(0) = '1') then
			mask <= '1' & not mask_tmp(31 downto 1);
		else
			mask <= mask_tmp;
		end if;
	end process;
	
	process(din, shlen, mask, op) 
	variable tmp_result : std_logic_vector(31 downto 0);
	begin
		tmp_result := din;
		if((shlen(0) xor op(0)) = '1') then
			tmp_result := tmp_result(0) & tmp_result(31 downto 1);
		end if;
		if((shlen(1) xor (shlen(0) and op(0))) = '1') then
			tmp_result := tmp_result(1 downto 0) & tmp_result(31 downto 2);
		end if;
		if((shlen(2) xor (shlen(1) and shlen(0) and op(0))) = '1') then
			tmp_result := tmp_result(3 downto 0) & tmp_result(31 downto 4);
		end if;
		if((shlen(3) xor (shlen(2) and shlen(1) and shlen(0) and op(0)))= '1') then
			tmp_result := tmp_result(7 downto 0) & tmp_result(31 downto 8);
		end if;
		if((shlen(4) xor (shlen(3) and shlen(2) and shlen(1) and shlen(0) and op(0)))= '1') then
			tmp_result := tmp_result(15 downto 0) & tmp_result(31 downto 16);
		end if;
		result <= mask and tmp_result;
	end process;

	process(op, result, mask, din(31)) 
	variable tmp_mask	: std_logic_vector(31 downto 0);
	begin
		if(din(31) = '1' and op(1) = '1') then
			tmp_mask := not mask;
		else
			tmp_mask := (others => '0');
		end if;
		dout <= tmp_mask or result;
	end process;
end rtl;
