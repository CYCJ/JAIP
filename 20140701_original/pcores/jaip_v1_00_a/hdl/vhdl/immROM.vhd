------------------------------------------------------------------------------
-- Filename     :       immROM.vhd
-- Version      :       1.06
-- Author       :       Hou-Jen Ko
-- Date         :       July 2007
-- VHDL Standard:       VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.                              **        
-- ** Multimedia Embedded System Lab, NCTU.                                 **  
-- ** Department of Computer Science and Information engineering            **
-- ** National Chiao Tung University, Hsinchu 300, Taiwan                   **
-- ***************************************************************************
--

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;

entity immROM is
    port(
        index                       : in  std_logic_vector(2 downto 0);
        value                       : out std_logic_vector(31 downto 0)
    );
end entity immROM;

architecture rtl of immROM is 
begin   
    process(index) begin
    		case index is
      			when "000" => value <= "00111111100000000000000000000000";
      			when "001" => value <= "01000000000000000000000000000000";
      			when "010" => value <= "00111111111100000000000000000000";
      			when "011" => value <= "00000000000000001111111111111111";
      			when "100" => value <= "11111111111111111111111111111111";
      			when "101" => value <= "00000000000000000000000000011111";
      			when others => value <= "00000000000000000000000000000000";
    		end case;    
    end process;
end architecture rtl;
