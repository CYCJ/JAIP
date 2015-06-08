------------------------------------------------------------------------------
-- Filename     :       class_info_table.vhd
-- Version      :       1.00
-- Author       :       Chia Che Hsu
-- Date         :       Dec. 2012
-- VHDL Standard:       VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2012. All rights reserved.                              **
-- ** Multimedia Embedded System Lab, NCTU.                                 **
-- ** Department of Computer Science and Information engineering            **
-- ** National Chiao Tung University, Hsinchu 300, Taiwan                   **
-- ***************************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity class_info_table is
    generic(
        RAMB_S18_AWIDTH  : integer := 12 --12 = 16KB
    );
    port(
        Rst              : in  std_logic;
        clk              : in  std_logic;
        address          : in  std_logic_vector(8 downto 0);
        offset_in        : in  std_logic_vector(31 downto 0);
        offset_out       : out std_logic_vector(31 downto 0);
        load_request     : in  std_logic;
        store_request    : in  std_logic;
        crt_complete     : out std_logic
    );
end entity class_info_table;

architecture rtl of class_info_table is

    component RAMB16_S36 port (
        DO                    : out std_logic_vector(31 downto 0);
        DI                    : in  std_logic_vector(31 downto 0);
        DIP                   : in  std_logic_vector(3 downto 0);
        DOP                   : out std_logic_vector(3 downto 0);
        ADDR                  : in  std_logic_vector(8 downto 0);
        SSR                   : in  std_logic;
        CLK                   : in  std_logic;
        EN                    : in  std_logic;
        WE                    : in  std_logic);
    end component;
    
    signal RAM_output       : std_logic_vector(31 downto 0);
    signal RAM_we_en        : std_logic;
    
begin

    process (clk) begin
		if(rising_edge(clk))then
        if (Rst = '1') then
            crt_complete <= '0';
        else
            if (load_request = '1' or store_request = '1') then
                crt_complete <= '1';
            else
                crt_complete <= '0';
            end if;
        end if;
        end if;
    end process;

    offset_out <= RAM_output;  
    
    RAM_we_en <= store_request;
    
    RAM_array : RAMB16_S36
    port map(
        DI    => offset_in,
        DIP   => (others => '0'),
        ADDR  => address(8 downto 0),
        DO    => RAM_output,
        CLK   => clk,
        EN    => '1',
        SSR   => Rst,
        WE    => RAM_we_en
    );

end architecture rtl;
