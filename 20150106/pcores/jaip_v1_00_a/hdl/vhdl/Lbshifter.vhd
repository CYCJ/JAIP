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
-- Filename	:	Lbshifter.vhd
-- Version	:	1.00
-- Author	:	Jen-Fu Wang
-- Date		:	Aug 2013
-- VHDL Standard:	VHDL'93
-- Describe	:	Long support
------------------------------------------------------------------------------

library ieee ;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;
use IEEE.std_logic_unsigned.all;

entity Lbshifter is
port (
	din			: in std_logic_vector(63 downto 0);
	off			: in std_logic_vector(5 downto 0);
	op		: in std_logic_vector(1 downto 0);
	dout		: out std_logic_vector(63 downto 0)
);
end Lbshifter;


architecture rtl of Lbshifter is
signal shlen		: std_logic_vector(5 downto 0);
signal result   	: std_logic_vector(63 downto 0);
signal mask		: std_logic_vector(63 downto 0);
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
		variable mask_tmp : std_logic_vector(63 downto 0);
	begin	
		case shlen(1 downto 0) is
			when "01" => tmp := X"7";
			when "10" => tmp := X"3";
			when "11" => tmp := X"1";
			when others => tmp := X"F";
		end case;
		case shlen(5 downto 2) is
			when "0000" =>  mask_tmp := tmp & X"FFFFFFF"&X"FFFFFFFF";
			when "0001" =>  mask_tmp := X"0" & tmp & X"FFFFFF"&X"FFFFFFFF";
			when "0010" =>  mask_tmp := X"00" & tmp & X"FFFFF"&X"FFFFFFFF";
			when "0011" =>  mask_tmp := X"000" & tmp & X"FFFF"&X"FFFFFFFF";
			when "0100" =>  mask_tmp := X"0000" & tmp & X"FFF"&X"FFFFFFFF";
			when "0101" =>  mask_tmp := X"00000" & tmp & X"FF"&X"FFFFFFFF";
			when "0110" =>  mask_tmp := X"000000" & tmp & X"F"&X"FFFFFFFF";
			when "0111" =>  mask_tmp := X"0000000" & tmp & X"FFFFFFFF";			
			when "1000" =>  mask_tmp := X"00000000" & tmp & X"FFFFFFF";
			when "1001" =>  mask_tmp := X"000000000" & tmp & X"FFFFFF";
			when "1010" =>  mask_tmp := X"0000000000" & tmp & X"FFFFF";
			when "1011" =>  mask_tmp := X"00000000000" & tmp & X"FFFF";
			when "1100" =>  mask_tmp := X"000000000000" & tmp & X"FFF";
			when "1101" =>  mask_tmp := X"0000000000000" & tmp & X"FF";
			when "1110" =>  mask_tmp := X"00000000000000" & tmp & X"F";		
			when others =>  mask_tmp := X"000000000000000" & tmp;
		end case;
		
		if(op(0) = '1') then
			mask <= '1' & not mask_tmp(63 downto 1);
		else
			mask <= mask_tmp;
		end if;
	end process;
	
	process(din, shlen, mask, op) 
	variable tmp_result : std_logic_vector(63 downto 0);
	begin
		tmp_result := din;
		if((shlen(0) xor op(0)) = '1') then
			tmp_result := tmp_result(0) & tmp_result(63 downto 1);
		end if;
		if((shlen(1) xor (shlen(0) and op(0))) = '1') then
			tmp_result := tmp_result(1 downto 0) & tmp_result(63 downto 2);
		end if;
		if((shlen(2) xor (shlen(1) and shlen(0) and op(0))) = '1') then
			tmp_result := tmp_result(3 downto 0) & tmp_result(63 downto 4);
		end if;
		if((shlen(3) xor (shlen(2) and shlen(1) and shlen(0) and op(0)))= '1') then
			tmp_result := tmp_result(7 downto 0) & tmp_result(63 downto 8);
		end if;
		if((shlen(4) xor (shlen(3) and shlen(2) and shlen(1) and shlen(0) and op(0)))= '1') then
			tmp_result := tmp_result(15 downto 0) & tmp_result(63 downto 16);
		end if;
		if((shlen(5) xor (shlen(4) and shlen(3) and shlen(2) and shlen(1) and shlen(0) and op(0)))= '1') then
			tmp_result := tmp_result(31 downto 0) & tmp_result(63 downto 32);
		end if;		
		result <= mask and tmp_result;
	end process;

	process(op, result, mask, din(63)) 
	variable tmp_mask	: std_logic_vector(63 downto 0);
	begin
		if(din(63) = '1' and op(1) = '1') then
			tmp_mask := not mask;
		else
			tmp_mask := (others => '0');
		end if;
		dout <= tmp_mask or result;
	end process;
end rtl;
