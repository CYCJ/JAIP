------------------------------------------------------------------------------
-- Filename     :       method_area.vhd
-- Version      :       2.02
-- Author       :       Kuan-Nian Su
-- Date         :       Dec 2008
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
-- Filename     :       method_area.vhd
-- Version      :       2.03
-- Author       :       Kuan-Nian Su
-- Date         :       May 2009
-- VHDL Standard:       VHDL'93
-----------------------------------Update------------------------------------- 
-- Version      :       3.0
-- Author       :       Han-Wen kuo
-- Date         :       Nov 2010
-- VHDL Standard:       VHDL'93
-- Describe     :       cleaning up
-----------------------------------Update-------------------------------------  
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity method_area_buffer is
    generic(
        RAMB_S18_AWIDTH             : integer := 10
    );
    port(
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        --act                         :  in std_logic;
        address                     : in  std_logic_vector(11 downto 0);
        block_select_base           : in  std_logic_vector( 4 downto 0);  
        methodarea_wr_en            : in  std_logic;
        methodarea_wr_val           : in  std_logic_vector(31 downto 0);
        stall_instruction_buffer    : in  std_logic;
        instruction_buffer_2        : out std_logic_vector(15 downto 0);
        instruction_buffer_1        : out std_logic_vector(15 downto 0);   
        bytecodes                   : out std_logic_vector(15 downto 0);
            --  thread management , 2013.7.16
            clear_buffer   : in  std_logic;
		-- xcptn
		xcptn_flush_pipeline        : in  std_logic;
		mask_insr1                  : in  std_logic;
        -- debug
        debug_flag                  : in  std_logic_vector(31 downto 0);
        debug_addr                  : in  std_logic_vector(31 downto 0);
        debug_data                  : out std_logic_vector(31 downto 0);
		--cs debug
		debug_block_select_base		: out std_logic_vector(4 downto 0);
		debug_MA_address			: out std_logic_vector(11 downto 0);
		debug_RAM_addr				: out std_logic_vector(9 downto 0);
		debug_RAM_we_en				: out std_logic_vector(3 downto 0)
		
    );
end entity method_area_buffer;

architecture rtl of method_area_buffer is

    component class_bram
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
    end component;

    type bytecodes_array        is array (integer range 0 to 3) of std_logic_vector(15 downto 0);
    type methodarea_we_en_array is array (integer range 0 to 3) of std_logic;
	
	signal ram_sel                  : std_logic_vector( 1 downto 0);
    signal block_sel                : std_logic_vector( 4 downto 0);
	signal block_offset_inram       : std_logic_vector( 2 downto 0);
	signal two_byte_offset          : std_logic_vector( 6 downto 0);
	
    signal RAM_addr                 : std_logic_vector( 9 downto 0);
    signal RAM_output               : bytecodes_array;
    signal RAM_we_en                : methodarea_we_en_array;
    
    signal bytecodes_tmp            : std_logic_vector(15 downto 0);
    signal instr_buf_1              : std_logic_vector(15 downto 0);
    signal instr_buf_2              : std_logic_vector(15 downto 0);
	
	signal ram_sel_for_out          : std_logic_vector(1 downto 0); 
    
    begin
    
    instruction_buffer_1 <= instr_buf_1; 
    instruction_buffer_2 <= instr_buf_2;    
    
    instruction_buffer_controll : process(clk) begin
        if(rising_edge(clk)) then        
        if(Rst = '1') then 
            instr_buf_1 <= (others => '0');
            instr_buf_2 <= (others => '0');
            ram_sel_for_out <= (others => '0');
        else 
            if xcptn_flush_pipeline = '1' or clear_buffer='1' then
		instr_buf_1 <= X"0000";
                instr_buf_2 <= X"0000";
            elsif(stall_instruction_buffer = '0') then
                instr_buf_1 <= bytecodes_tmp;
                instr_buf_2 <= instr_buf_1;
            end if;
            --if(stall_instruction_buffer = '0') then
		 ram_sel_for_out <= ram_sel;
            --   end if;
        end if;
        end if;
    end process;
	 
    
    bytecodes <=  
                    X"0000"   when xcptn_flush_pipeline = '1' or clear_buffer='1' else
	             X"00"& bytecodes_tmp(7 downto 0)  when mask_insr1 = '1' else  
				 bytecodes_tmp;
    
    block_sel <= block_select_base + address(11 downto 7);
	
	block_offset_inram <= block_sel(2 downto 0);
	two_byte_offset    <= address(6 downto 0);
    RAM_addr           <= block_offset_inram( 2 downto 0 ) & two_byte_offset(6 downto 0);
	
	ram_sel      <= block_sel(4 downto 3);
	
    bytecodes_tmp <= RAM_output(to_integer(unsigned(ram_sel_for_out)));
    --debug_data    <= x"0000" & RAM_output(to_integer(unsigned(debug_addr(14 downto 10))));
                    
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
             Rst               => Rst, 
             clk               => clk,
             address           => RAM_addr, 
             methodarea_wr_en  => RAM_we_en(idx),
             methodarea_wr_val => methodarea_wr_val,
             bytecodes         => RAM_output(idx)
         );
     end generate G1;
	 
	 --cs debug
	-- debug_RAM_addr <= RAM_addr;
	-- debug_block_select_base <= block_select_base;
	-- debug_MA_address <= address;
	-- debug_RAM_we_en <= RAM_we_en(0)&RAM_we_en(1)&RAM_we_en(2)&RAM_we_en(3);
end architecture rtl;
