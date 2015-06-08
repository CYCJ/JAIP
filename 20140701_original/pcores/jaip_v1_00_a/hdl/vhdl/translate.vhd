------------------------------------------------------------------------------
-- Filename     :       translate.vhd
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
-- Filename     :       translate.vhd
-- Version      :       2.02
-- Author       :       Kuan-Nian Su
-- Date         :       Apr 2009
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Filename     :       translate.vhd
-- Version      :       3.00
-- Author       :       Han-Wen Kuo
-- Date         :       Nov 2010
-- VHDL Standard:       VHDL'93
-- Describe     :       New Architecture
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity Translate is
    generic(
        ENABLE_JAIP_PROFILER   : integer := 0;
        RAMB_S18_AWIDTH             : integer := 10
    );
    port(
        -- ctrl signal
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        stall_translate_stage       : in  std_logic;
        
        -- method area
        bytecodes                   : in  std_logic_vector(15 downto 0);
        instruction_buffer_1        : in  std_logic_vector(15 downto 0);
        
        -- fetch stage
        instr_buf_ctrl              : in  std_logic_vector( 1 downto 0);
        semitranslated_code         : out std_logic_vector(15 downto 0);
        complex                     : out std_logic_vector( 1 downto 0);
        opd_num                     : out std_logic_vector( 7 downto 0);
		
		-- prof
		prof_issued_bytecodes_T		: out std_logic_vector(15 downto 0)
    );
end entity Translate;

architecture rtl of Translate is
    
    component translation_ROM is
        generic(
            RAMB_S18_AWIDTH             : integer := 10
        );
        port(
            Rst                         : in  std_logic;
            clk                         : in  std_logic;
            enable                      : in  std_logic;
            DOA                         : out std_logic_vector(15 downto 0);
            DOB                         : out std_logic_vector(15 downto 0);
            ADDRA                       : in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0);
            ADDRB                       : in  std_logic_vector(RAMB_S18_AWIDTH-1 downto 0)
        );
    end component;

    signal DOA                      : std_logic_vector(15 downto 0);
    signal DOB                      : std_logic_vector(15 downto 0);
    signal ADDRA                    : std_logic_vector(RAMB_S18_AWIDTH-1 downto 0);
    signal ADDRB                    : std_logic_vector(RAMB_S18_AWIDTH-1 downto 0);
    signal enable                   : std_logic;
	
	-- prof
    signal prof_issued_bytecodes	: std_logic_vector(15 downto 0);
	
    begin
    
    semitranslated_code <= DOA(7 downto 0) & DOB(7 downto 0);
    complex             <= DOA(8) & DOB(8);
    opd_num             <= DOA(15 downto 12) & DOB(15 downto 12);
    
    ADDRA          <= "00" & bytecodes(15 downto 8)           when instr_buf_ctrl = "00" else
                      "00" & instruction_buffer_1(7 downto 0) when instr_buf_ctrl = "01" else
                      "00" & instruction_buffer_1(15 downto 8);
                    
    ADDRB          <= "00" & bytecodes( 7 downto 0)           when instr_buf_ctrl = "00" else
                      "00" & bytecodes(15 downto 8)           when instr_buf_ctrl = "01" else 
                      "00" & instruction_buffer_1(7 downto 0);
    
    enable <= not stall_translate_stage;
    
    Translation_ROM_instance : translation_ROM
    generic map(
        RAMB_S18_AWIDTH => RAMB_S18_AWIDTH
    )        
    port map (
        clk    => clk,  
        Rst    => Rst,
        enable => enable,
        ADDRA  => ADDRA,
        DOA    => DOA,
        ADDRB  => ADDRB,  
        DOB    => DOB   
    );
	
	-- prof
        label_enable_jaip_profiler_0 : if ENABLE_JAIP_PROFILER = 1 generate
	process(Clk, Rst) begin
		if(Rst = '1') then
			prof_issued_bytecodes <= (others => '0');
		elsif(rising_edge(Clk)) then
			if(stall_translate_stage = '0') then
				prof_issued_bytecodes <= ADDRA(7 downto 0) & ADDRB(7 downto 0);
			end if;
		end if;
	end process; 
	prof_issued_bytecodes_T <= prof_issued_bytecodes;
        end generate;
                     
end architecture rtl;
