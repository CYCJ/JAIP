------------------------------------------------------------------------------
-- Filename     :       class_bram.vhd 
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
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------
-- Filename     :       class_bram.vhd 
-- Version      :       2.03
-- Author       :       Kuan-Nian Su
-- Date         :       May 2009
-- VHDL Standard:       VHDL'93
-----------------------------------Update-------------------------------------  
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity class_bram is
    generic(
        RAMB_S18_AWIDTH             : integer := 10
    );
    port(
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        address                     : in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0); 
        methodarea_wr_en            : in  std_logic;
        methodarea_wr_val           : in  std_logic_vector(31 downto 0);            
        bytecodes                   : out std_logic_vector(15 downto 0)
    );
end entity class_bram;

architecture rtl of class_bram is 
    signal bytecodes_tmp            : std_logic_vector(15 downto 0);
    signal methodarea_wr_val_tmp_A    : std_logic_vector(15 downto 0);
    signal methodarea_wr_val_tmp_B    : std_logic_vector(15 downto 0);
    signal address_B : std_logic_vector(9 downto 0);
    signal portB_we : std_logic ;
    signal portB_dataOut : std_logic_vector(15 downto 0);
    begin   

    bytecodes <= bytecodes_tmp(7 downto 0) & bytecodes_tmp(15 downto 8);
    methodarea_wr_val_tmp_A <= methodarea_wr_val(23 downto 16)& methodarea_wr_val(31 downto 24);
    methodarea_wr_val_tmp_B <= methodarea_wr_val(7 downto 0)& methodarea_wr_val(15 downto 8);
    --address_B <= address + '1'; 
    -- for experiment , 2013.7.4
    address_B <= address (RAMB_S18_AWIDTH-1 downto 1)  & "1"; 

    -- class_image : RAMB16_S18
    class_image : RAMB16_S18_S18
    generic map(
        INIT_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_07 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_08 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_09 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_0A => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_0B => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_0C => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_0D => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_0E => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_0F => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_10 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_11 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_12 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_13 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_14 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_15 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_16 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_17 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_18 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_19 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_1A => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_1B => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_1C => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_1D => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_1E => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_1F => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_20 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_21 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_22 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_23 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_24 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_25 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_26 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_27 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_28 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_29 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_2A => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_2B => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_2C => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_2D => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_2E => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_2F => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_30 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_31 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_32 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_33 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_34 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_35 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_36 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_37 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_38 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_39 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_3A => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_3B => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_3C => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_3D => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_3E => X"0000000000000000000000000000000000000000000000000000000000000000",
        INIT_3F => X"0000000000000000000000000000000000000000000000000000000000000000"
    )
    port map (
       -- DI    => methodarea_wr_val_tmp,
       -- DIP   => (others => '0'),
       -- ADDR  => address,
       -- DO    => bytecodes_tmp,
       -- CLK   => clk,   
       -- EN    => '1', 
       -- SSR   => Rst,
       -- WE    => methodarea_wr_en      
        
        DIA    => methodarea_wr_val_tmp_A,
        DIPA   => (others => '0'),
        ADDRA  => address,
        DOA    => bytecodes_tmp,
        CLKA   => clk,   
        ENA    => '1', 
        SSRA   => Rst,
        WEA    => methodarea_wr_en ,
        
        DIB    => methodarea_wr_val_tmp_B,
        DIPB   => (others => '0'),
        ADDRB  => address_B,
        DOB    => portB_dataOut,
        CLKB   => clk,   
        ENB    => '1', 
        SSRB   => Rst,
        WEB    => methodarea_wr_en --portB_we   
    );             

end architecture rtl;
