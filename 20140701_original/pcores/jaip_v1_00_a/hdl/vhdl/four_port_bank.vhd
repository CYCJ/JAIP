------------------------------------------------------------------------------
-- Filename     :       four_port_bank.vhd
-- Version      :       1.00
-- Author       :
-- Date         :       January 2010
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
use work.config.all;

Library unisim;
use unisim.vcomponents.all;

entity four_port_bank is
    generic(
        RAMB_S36_AWIDTH             : integer := 9
    );
    port(
        -- for chipscope debug use
        --debug_cs_4portbank : out std_logic_vector(127 downto 0);
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        enable                      : in  std_logic;
        invoke_flag                 : in  std_logic;
        return_flag                 : in  std_logic;
        R1_RegFlag                  : in  std_logic;
        R2_RegFlag                  : in  std_logic;
        W1_RegFlag                  : in  std_logic;
        W2_RegFlag                  : in  std_logic;
        -- flag means access instruction is valid
        intsrs_decode_flag_1        : in std_logic;
        intsrs_decode_flag_2        : in std_logic;
        intsrs_execution_flag_1     : in std_logic;
        intsrs_execution_flag_2     : in std_logic;
        -- LD/SW 1 2 means that is instruction one or two of instrs_pkg
        LD_addr_1                   : in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
        LD_addr_2                   : in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
        LD_data_1                   : out std_logic_vector(31 downto 0);
        LD_data_2                   : out std_logic_vector(31 downto 0);
        SD_addr_1                   : in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
        SD_addr_2                   : in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
        SD_data_1                   : in  std_logic_vector(31 downto 0);
        SD_data_2                   : in  std_logic_vector(31 downto 0);
        -- for (prepared?) stack backup / restore operations
                TH_mgt_context_switch : in  std_logic; 
		prepare_WE			: in  std_logic;
		prepare_addr            	: in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
		prepare_data            	: in  std_logic_vector(31 downto 0);
		backup_data                 : out std_logic_vector(31 downto 0);
		LVreg_valid	            	: in  std_logic_vector(1 downto 0)
		-- CS
		--debug_stack_wdaddr			: out std_logic_vector(17 downto 0);
		--debug_stack_rdaddr			: out std_logic_vector(17 downto 0)
    );
end entity four_port_bank;

architecture rtl of four_port_bank is

    component RAMB16_S36_S36 port (
        DOA, DOB                    : out std_logic_vector(31 downto 0);
        DIA, DIB                    : in  std_logic_vector(31 downto 0);
        DIPA, DIPB                  : in  std_logic_vector(3 downto 0);
        DOPA, DOPB                  : out std_logic_vector(3 downto 0);
        ADDRA, ADDRB                : in  std_logic_vector(8 downto 0);
        SSRA, SSRB                  : in  std_logic;
        CLKA, CLKB                  : in  std_logic;
        ENA, ENB                    : in  std_logic;
        WEA, WEB                    : in  std_logic);
    end component;

    signal local_variable_0         : std_logic_vector(31 downto 0);
    signal local_variable_1         : std_logic_vector(31 downto 0);
    signal local_variable_2         : std_logic_vector(31 downto 0);
    signal local_variable_3         : std_logic_vector(31 downto 0);
    signal SD_mem_en_1              : std_logic;
    signal SD_mem_en_2              : std_logic;
    signal SD_reg_en_1              : std_logic;
    signal SD_reg_en_2              : std_logic;
    signal LD_mem_en_1              : std_logic;
    signal LD_mem_en_2              : std_logic;
    signal LD_reg_en_1              : std_logic;
    signal LD_reg_en_2              : std_logic;
    signal stack_wddata1            : std_logic_vector(31 downto 0);
    signal stack_wdaddr1            : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack_we1                : std_logic;
    signal stack_rdaddr1            : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack_rddata1            : std_logic_vector(31 downto 0);
    signal stack_rddata1_temp       : std_logic_vector(31 downto 0);
    signal stack_wddata2            : std_logic_vector(31 downto 0);
    signal stack_wdaddr2            : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack_we2                : std_logic;
    signal stack_rdaddr2            : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack_rddata2            : std_logic_vector(31 downto 0);
    signal stack_rddata2_temp       : std_logic_vector(31 downto 0);
    signal LD_data_select_1         : std_logic_vector(1 downto 0);
    signal LD_data_select_2         : std_logic_vector(1 downto 0);
    signal reg1                     : std_logic_vector(31 downto 0);
    signal reg2                     : std_logic_vector(31 downto 0);
    -- for bank forward
    signal forward_flag_1           : std_logic;
    signal forward_flag_2           : std_logic;
    signal forward_data_1           : std_logic_vector(31 downto 0);
    signal forward_data_2           : std_logic_vector(31 downto 0);
    -- for reg forward
    signal compare_1                : std_logic_vector(7 downto 0);
    signal compare_2                : std_logic_vector(7 downto 0);
    signal reg_forward_11           : std_logic;
    signal reg_forward_12           : std_logic;
    signal reg_forward_21           : std_logic;
    signal reg_forward_22           : std_logic;
    -- invoke/return
    signal invoke_2cycle            : std_logic;
    signal return_2cycle            : std_logic;
    signal return_3cycle            : std_logic;
    signal SD_reg_internal_en       : std_logic;
    signal reg_forward_internal_11  : std_logic;
    signal reg_forward_internal_12  : std_logic;
    signal reg_forward_internal_21  : std_logic;
    signal reg_forward_internal_22  : std_logic;
    signal SD_addr_internal_1       : std_logic_vector(1 downto 0);
    signal SD_addr_internal_2       : std_logic_vector(1 downto 0);
    -- for solving critical path problems , added by T.H. Wu , 2013.7.3
    signal stack_rdaddr1_sel        :   std_logic;
    signal stack_rdaddr2_sel        :   std_logic;
    signal stack_wdaddr1_sel        :   std_logic;
    signal stack_wdaddr2_sel        :   std_logic;
    
    -- by fox ===================================== 2013.7.17
    signal runnable_stack          	: std_logic;
	signal stack_bkdata1_temp	   	: std_logic_vector(31 downto 0);
	signal stack_bkdata2_temp       : std_logic_vector(31 downto 0);
	signal stack0_wddata1           : std_logic_vector(31 downto 0);
    signal stack0_wdaddr1           : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack0_we1               : std_logic;
    signal stack0_rdaddr1           : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack0_rddata1           : std_logic_vector(31 downto 0);
    signal stack0_wddata2           : std_logic_vector(31 downto 0);
    signal stack0_wdaddr2           : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack0_we2               : std_logic;
    signal stack0_rdaddr2           : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack0_rddata2           : std_logic_vector(31 downto 0);
	signal stack0_enable            : std_logic;
	signal stack1_wddata1           : std_logic_vector(31 downto 0);
    signal stack1_wdaddr1           : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack1_we1               : std_logic;
    signal stack1_rdaddr1           : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack1_rddata1           : std_logic_vector(31 downto 0);
    signal stack1_wddata2           : std_logic_vector(31 downto 0);
    signal stack1_wdaddr2           : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack1_we2               : std_logic;
    signal stack1_rdaddr2           : std_logic_vector(RAMB_S36_AWIDTH-1 downto 0);
    signal stack1_rddata2           : std_logic_vector(31 downto 0);
	signal stack1_enable            : std_logic;
	signal BK_data_select	        : std_logic;
	-- ============================================
    
	
    begin

	-- by fox
	backup_data	<=	stack_bkdata1_temp when BK_data_select = '0' else stack_bkdata2_temp;
    
    -- 1 2 means that is instruction one or two of instrs_pkg
    -- determined that access instruction target
    SD_mem_en_1 <= intsrs_execution_flag_1 when W1_RegFlag = '0' else '0';
    SD_mem_en_2 <= intsrs_execution_flag_2 when W2_RegFlag = '0' else '0';
    SD_reg_en_1 <= intsrs_execution_flag_1 when W1_RegFlag = '1' else '0';
    SD_reg_en_2 <= intsrs_execution_flag_2 when W2_RegFlag = '1' else '0';

    LD_mem_en_1 <= intsrs_decode_flag_1 when R1_RegFlag = '0' else '0';
    LD_mem_en_2 <= intsrs_decode_flag_2 when R2_RegFlag = '0' else '0';
    LD_reg_en_1 <= intsrs_decode_flag_1 when R1_RegFlag = '1' else '0';
    LD_reg_en_2 <= intsrs_decode_flag_2 when R2_RegFlag = '1' else '0';

    -- stack 1 2 means memory access of bank 0 or 2
    -- modified by T.H.Wu , 2013.8.10 , try to simplify the logic for critical path
    stack_wddata1 <= SD_data_1 when ( SD_mem_en_1 = '1' and SD_addr_1(0) = '0' ) else
                     SD_data_2 when ( SD_mem_en_2 = '1' and SD_addr_2(0) = '0' ) else
                    local_variable_0 when ( invoke_flag = '1' and SD_addr_1(0) = '0' ) else
                    local_variable_1 when ( invoke_flag = '1' and SD_addr_2(0) = '0' ) else
                    local_variable_2 when ( invoke_2cycle = '1' and SD_addr_1(0) = '0' ) else
                    local_variable_3 when ( invoke_2cycle = '1' and SD_addr_2(0) = '0' ) else
                    (others => '0');
    --stack_wddata1 <= SD_data_1 when ( SD_mem_en_1 = '1' and SD_addr_1(0) = '0' ) else
    --                 SD_data_2 when ( SD_mem_en_2 = '1' and SD_addr_2(0) = '0' ) else
    --                 local_variable_0 when ( invoke_flag = '1' and SD_addr_1(0) = '0' ) else
    --                 local_variable_1 when ( invoke_flag = '1' and SD_addr_2(0) = '0' ) else
    --                 local_variable_2 when ( invoke_2cycle = '1' and SD_addr_1(0) = '0' ) else
    --                 local_variable_3 ;
                     
    --stack_wdaddr1 <= SD_addr_1(9 downto 1) when ( SD_mem_en_1 = '1' and SD_addr_1(0) = '0' ) else
    --                 SD_addr_2(9 downto 1) when ( SD_mem_en_2 = '1' and SD_addr_2(0) = '0' ) else
    --                 SD_addr_1(9 downto 1) when ( invoke_flag = '1' and SD_addr_1(0) = '0' ) else
    --                 SD_addr_2(9 downto 1) when ( invoke_flag = '1' and SD_addr_2(0) = '0' ) else
    --                 SD_addr_1(9 downto 1) when ( invoke_2cycle = '1' and SD_addr_1(0) = '0' ) else
    --                 SD_addr_2(9 downto 1) when ( invoke_2cycle = '1' and SD_addr_2(0) = '0' ) else
    --                 (others => '0');
	stack_wdaddr1 <= SD_addr_1(9 downto 1) when stack_wdaddr1_sel = '1' else SD_addr_2(9 downto 1);
    stack_we1     <= '1' when ( SD_mem_en_1 = '1' and SD_addr_1(0) = '0' ) else
                     '1' when ( SD_mem_en_2 = '1' and SD_addr_2(0) = '0' ) else
                     '1' when ( invoke_flag = '1' or invoke_2cycle = '1' ) and LVreg_valid(0) = '1' and SD_addr_1(0) = '0' else	-- by fox
                    '1' when ( invoke_flag = '1' or invoke_2cycle = '1' ) and LVreg_valid(1) = '1' and SD_addr_2(0) = '0' else	-- by fox
                     '0';
     stack_rdaddr1_sel <= not LD_addr_1(0) and (LD_mem_en_1 or return_flag or return_2cycle);
     stack_rdaddr2_sel <=     LD_addr_1(0) and (LD_mem_en_1 or return_flag or return_2cycle);
     stack_wdaddr1_sel <= not SD_addr_1(0) and (SD_mem_en_1 or invoke_flag or invoke_2cycle);
     stack_wdaddr2_sel <=     SD_addr_1(0) and (SD_mem_en_1 or invoke_flag or invoke_2cycle);
    stack_rdaddr1 <= LD_addr_1(9 downto 1) when stack_rdaddr1_sel='1' else LD_addr_2(9 downto 1);
    --stack_rdaddr1 <= LD_addr_1(9 downto 1) when ( LD_mem_en_1 = '1' and LD_addr_1(0) = '0' ) else
     --                LD_addr_2(9 downto 1) when ( LD_mem_en_2 = '1' and LD_addr_2(0) = '0' ) else
      --               LD_addr_1(9 downto 1) when ( return_flag = '1' and LD_addr_1(0) = '0' ) else
       --              LD_addr_2(9 downto 1) when ( return_flag = '1' and LD_addr_2(0) = '0' ) else
        --             LD_addr_1(9 downto 1) when ( return_2cycle = '1' and LD_addr_1(0) = '0' ) else
         --            LD_addr_2(9 downto 1) when ( return_2cycle = '1' and LD_addr_2(0) = '0' ) else
         --            (others => '0');
    LD_data_1     <= stack_rddata1 when LD_data_select_1 = "00" else
                     stack_rddata2 when LD_data_select_1 = "01" else
                     reg1; 

    -- modified by T.H.Wu , 2013.8.10 , try to simplify the logic for critical path
    stack_wddata2 <= SD_data_1 when ( SD_mem_en_1 = '1' and SD_addr_1(0) = '1' ) else
                     SD_data_2 when ( SD_mem_en_2 = '1' and SD_addr_2(0) = '1' ) else
                     local_variable_0 when (invoke_flag = '1' and SD_addr_1(0) = '1' ) else
                     local_variable_1 when (invoke_flag = '1' and SD_addr_2(0) = '1' ) else
                     local_variable_2 when (invoke_2cycle = '1' and SD_addr_1(0) = '1' ) else
                     local_variable_3 when (invoke_2cycle = '1' and SD_addr_2(0) = '1' ) else
                     (others => '0');
    --stack_wddata2 <= SD_data_1 when ( SD_mem_en_1 = '1' and SD_addr_1(0) = '1' ) else
    --                 SD_data_2 when ( SD_mem_en_2 = '1' and SD_addr_2(0) = '1' ) else
    --                 local_variable_0 when (invoke_flag = '1' and SD_addr_1(0) = '1' ) else
    --                 local_variable_1 when (invoke_flag = '1' and SD_addr_2(0) = '1' ) else
    --                 local_variable_2 when (invoke_2cycle = '1' and SD_addr_1(0) = '1' ) else
    --                 local_variable_3 ; 
    --stack_wdaddr2 <= SD_addr_1(9 downto 1) when ( SD_mem_en_1 = '1' and SD_addr_1(0) = '1' ) else
    --                 SD_addr_2(9 downto 1) when ( SD_mem_en_2 = '1' and SD_addr_2(0) = '1' ) else
    --                 SD_addr_1(9 downto 1) when (invoke_flag = '1' and SD_addr_1(0) = '1' ) else
    --                 SD_addr_2(9 downto 1) when (invoke_flag = '1' and SD_addr_2(0) = '1' ) else
    --                 SD_addr_1(9 downto 1) when (invoke_2cycle = '1' and SD_addr_1(0) = '1' ) else
    --                 SD_addr_2(9 downto 1) when (invoke_2cycle = '1' and SD_addr_2(0) = '1' ) else
    --                 (others => '0');
	stack_wdaddr2 <= SD_addr_1(9 downto 1) when stack_wdaddr2_sel = '1' else SD_addr_2(9 downto 1);
    stack_we2     <= '1' when ( SD_mem_en_1 = '1' and SD_addr_1(0) = '1' ) else
                     '1' when ( SD_mem_en_2 = '1' and SD_addr_2(0) = '1' ) else
					 '1' when ( invoke_flag = '1' or invoke_2cycle = '1' ) and LVreg_valid(0) = '1' and SD_addr_1(0) = '1' else	-- by fox
					 '1' when ( invoke_flag = '1' or invoke_2cycle = '1' ) and LVreg_valid(1) = '1' and SD_addr_2(0) = '1' else	-- by fox
                     '0';
       stack_rdaddr2 <= LD_addr_1(9 downto 1) when  stack_rdaddr2_sel = '1' else LD_addr_2(9 downto 1);
    --stack_rdaddr2 <= LD_addr_1(9 downto 1) when ( LD_mem_en_1 = '1' and LD_addr_1(0) = '1' ) else
    --                 LD_addr_2(9 downto 1) when ( LD_mem_en_2 = '1' and LD_addr_2(0) = '1' ) else
    --                 LD_addr_1(9 downto 1) when ( return_flag = '1' and LD_addr_1(0) = '1' ) else
    --                 LD_addr_2(9 downto 1) when ( return_flag = '1' and LD_addr_2(0) = '1' ) else
    --                 LD_addr_1(9 downto 1) when ( return_2cycle = '1' and LD_addr_1(0) = '1' ) else
    --                 LD_addr_2(9 downto 1) when ( return_2cycle = '1' and LD_addr_2(0) = '1' ) else
    --                 (others => '0');
    LD_data_2     <= stack_rddata1 when LD_data_select_2 = "00" else
                     stack_rddata2 when LD_data_select_2 = "01" else
                     reg2; 

    -- output select signal
    process(clk) begin
		if(rising_edge(clk)) then
        --if(Rst = '1') then
        --    LD_data_select_1 <= "00";
        --    LD_data_select_2 <= "00";
        --    BK_data_select	 <= '0';
        --else 
            if(enable = '1') then
                if ( LD_mem_en_1 = '1' and LD_addr_1(0) = '0' ) then
                    LD_data_select_1 <= "00";
                elsif ( LD_mem_en_1 = '1' and LD_addr_1(0) = '1' ) then
                    LD_data_select_1 <= "01";
                -- modified by T.H.Wu , 2013.8.10 , try to simplify the logic for critical path
                --elsif ( LD_reg_en_1 = '1' ) then
               --     LD_data_select_1 <= "10";
                else
                    LD_data_select_1 <= "11";
                end if;
    
                if ( LD_mem_en_2 = '1' and LD_addr_2(0) = '0' ) then
                    LD_data_select_2 <= "00";
                elsif ( LD_mem_en_2 = '1' and LD_addr_2(0) = '1' ) then
                    LD_data_select_2 <= "01";
                -- modified by T.H.Wu , 2013.8.10 , try to simplify the logic for critical path
               -- elsif ( LD_reg_en_2 = '1' ) then
                 --   LD_data_select_2 <= "10";
                else
                    LD_data_select_2 <= "11";
                end if;
            end if;
            --
            BK_data_select	<= prepare_addr(0); -- by fox
            --
            if(Rst = '1') then -- by fox
				runnable_stack <= '0';
            else
                if(TH_mgt_context_switch = '1')then
                    runnable_stack	<= not runnable_stack;
                end if;
            end if;

        --end if;
        end if;
    end process;


    -- invoke/return second cycle, third cycle
    process(clk) begin
		if(rising_edge(clk)) then
        --if(Rst = '1') then
        --    invoke_2cycle <= '0';
         --   return_2cycle <= '0';
        --else
            invoke_2cycle <= invoke_flag;
            return_2cycle <= return_flag;
            return_3cycle <= return_2cycle;
        --end if;
        end if;
    end process;

    -- return
    --process(clk, Rst) begin
    process(clk) begin
        --if(Rst = '1') then
        --    SD_addr_internal_1 <= (others => '0');
        --    SD_addr_internal_2 <= (others => '0');
        --    SD_reg_internal_en <= '0';
        --els
        if(rising_edge(clk)) then
            if(return_flag = '1') then
                SD_addr_internal_1 <= '0' & LD_addr_1(0);
                SD_addr_internal_2 <= '0' & LD_addr_2(0);
                SD_reg_internal_en <= '1';
            elsif (return_2cycle = '1') then
                SD_addr_internal_1 <= '1' & LD_addr_1(0);
                SD_addr_internal_2 <= '1' & LD_addr_2(0);
                SD_reg_internal_en <= '1';
            else
                SD_addr_internal_1 <= (others => '0');
                SD_addr_internal_2 <= (others => '0');
                SD_reg_internal_en <= '0';
            end if; 
        end if;
    end process;

    -- write local variables (0~3) process
    process(clk) begin
        if(rising_edge(clk)) then 
        --if(Rst = '1') then
        --    local_variable_0 <= (others => '0');
        --    local_variable_1 <= (others => '0');
        --    local_variable_2 <= (others => '0');
        --    local_variable_3 <= (others => '0');
        --else
            --if(enable = '1') then
                if (SD_reg_en_2 = '1' and SD_addr_2(1 downto 0) = "00") then
                    local_variable_0 <= SD_data_2;
                elsif (SD_reg_en_1 = '1' and SD_addr_1(1 downto 0) = "00") then
                    local_variable_0 <= SD_data_1;
                elsif (return_2cycle = '1' and SD_addr_internal_1(0) = '0') then
                    local_variable_0 <= stack_rddata1_temp;
                elsif (return_2cycle = '1' and SD_addr_internal_2(0) = '0') then
                    local_variable_0 <= stack_rddata2_temp;
                end if;
    
                if (SD_reg_en_2 = '1' and SD_addr_2(1 downto 0) = "01") then
                    local_variable_1 <= SD_data_2;
                elsif (SD_reg_en_1 = '1' and SD_addr_1(1 downto 0) = "01") then
                    local_variable_1 <= SD_data_1;
                elsif (return_2cycle = '1' and SD_addr_internal_1(0) = '1') then
                    local_variable_1 <= stack_rddata1_temp;
                elsif (return_2cycle = '1' and SD_addr_internal_2(0) = '1') then
                    local_variable_1 <= stack_rddata2_temp;
                end if;
    
                if (SD_reg_en_2 = '1' and SD_addr_2(1 downto 0) = "10") then
                    local_variable_2 <= SD_data_2;
                elsif (SD_reg_en_1 = '1' and SD_addr_1(1 downto 0) = "10") then
                    local_variable_2 <= SD_data_1;
                elsif (return_3cycle = '1' and SD_addr_internal_1(0) = '0') then
                    local_variable_2 <= stack_rddata1_temp;
                elsif (return_3cycle = '1' and SD_addr_internal_2(0) = '0') then
                    local_variable_2 <= stack_rddata2_temp;
                end if;
    
                if (SD_reg_en_2 = '1' and SD_addr_2(1 downto 0) = "11") then
                    local_variable_3 <= SD_data_2;
                elsif (SD_reg_en_1 = '1' and SD_addr_1(1 downto 0) = "11") then
                    local_variable_3 <= SD_data_1;
                elsif (return_3cycle = '1' and SD_addr_internal_1(0) = '1') then
                    local_variable_3 <= stack_rddata1_temp;
                elsif (return_3cycle = '1' and SD_addr_internal_2(0) = '1') then
                    local_variable_3 <= stack_rddata2_temp;
                end if;
            --end if; 
        --end if;
        end if;
    end process;

    reg_forward_11 <= LD_reg_en_1 and SD_reg_en_1  when LD_addr_1(1 downto 0) = SD_addr_1(1 downto 0)  else '0';
    reg_forward_12 <= LD_reg_en_1 and SD_reg_en_2  when LD_addr_1(1 downto 0) = SD_addr_2(1 downto 0)  else '0';
    reg_forward_21 <= LD_reg_en_2 and SD_reg_en_1  when LD_addr_2(1 downto 0) = SD_addr_1(1 downto 0)  else '0';
    reg_forward_22 <= LD_reg_en_2 and SD_reg_en_2  when LD_addr_2(1 downto 0) = SD_addr_2(1 downto 0)  else '0';

    reg_forward_internal_11 <= LD_reg_en_1 and SD_reg_internal_en when LD_addr_1(1 downto 0) = SD_addr_internal_1  else '0';
    reg_forward_internal_12 <= LD_reg_en_1 and SD_reg_internal_en when LD_addr_1(1 downto 0) = SD_addr_internal_2  else '0';
    reg_forward_internal_21 <= LD_reg_en_2 and SD_reg_internal_en when LD_addr_2(1 downto 0) = SD_addr_internal_1  else '0';
    reg_forward_internal_22 <= LD_reg_en_2 and SD_reg_internal_en when LD_addr_2(1 downto 0) = SD_addr_internal_2  else '0';


    -- read local variables (0~3) process
    process(clk) begin
		if(rising_edge(clk)) then
        --if(Rst = '1') then
        --    reg1 <= (others => '0');
        --    reg2 <= (others => '0');
        --else
            --if(enable = '1') then
                if (reg_forward_12 = '1') then -- forward
                    reg1 <= SD_data_2;
                elsif (reg_forward_11 = '1') then -- forward
                    reg1 <= SD_data_1;
                elsif (reg_forward_internal_12 = '1') then -- return forward
                    reg1 <= stack_rddata2_temp;
                elsif (reg_forward_internal_11 = '1') then -- return forward
                    reg1 <= stack_rddata1_temp;
                elsif (LD_reg_en_1 = '1' and LD_addr_1(1 downto 0) = "00") then
                    reg1 <= local_variable_0;
                elsif (LD_reg_en_1 = '1' and LD_addr_1(1 downto 0) = "01") then
                    reg1 <= local_variable_1;
                elsif (LD_reg_en_1 = '1' and LD_addr_1(1 downto 0) = "10") then
                    reg1 <= local_variable_2;
                elsif (LD_reg_en_1 = '1' and LD_addr_1(1 downto 0) = "11") then
                    reg1 <= local_variable_3;
                end if;
    
                if (reg_forward_22 = '1') then -- forward
                    reg2 <= SD_data_2;
                elsif (reg_forward_21 = '1') then -- forward
                    reg2 <= SD_data_1;
                elsif (reg_forward_internal_22 = '1') then -- return forward
                    reg2 <= stack_rddata2_temp;
                elsif (reg_forward_internal_21 = '1') then -- return forward
                    reg2 <= stack_rddata1_temp;
                elsif (LD_reg_en_2 = '1' and LD_addr_2(1 downto 0) = "00") then
                    reg2 <= local_variable_0;
                elsif (LD_reg_en_2 = '1' and LD_addr_2(1 downto 0) = "01") then
                    reg2 <= local_variable_1;
                elsif (LD_reg_en_2 = '1' and LD_addr_2(1 downto 0) = "10") then
                    reg2 <= local_variable_2;
                elsif (LD_reg_en_2 = '1' and LD_addr_2(1 downto 0) = "11") then
                    reg2 <= local_variable_3;
                end if;
            --end if;
        --end if;
        end if;
    end process;


    -- access memory bank fowrard
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
            forward_flag_1 <= '0';
            forward_flag_2 <= '0';
            forward_data_1 <= (others => '0');
            forward_data_2 <= (others => '0');
        else
            if(enable = '1') then
                if(stack_we1 = '1' and stack_rdaddr1 = stack_wdaddr1) then
                    forward_flag_1 <= '1';
                else
                    forward_flag_1 <= '0';
                end if;
                if(stack_we2 = '1' and stack_rdaddr2 = stack_wdaddr2) then
                    forward_flag_2 <= '1';
                else
                    forward_flag_2 <= '0';
                end if;
                forward_data_1 <= stack_wddata1;
                forward_data_2 <= stack_wddata2;
            end if;
        end if;
        end if;
    end process;
    stack_rddata1 <= stack_rddata1_temp when forward_flag_1 = '0' else
                     forward_data_1;
    stack_rddata2 <= stack_rddata2_temp when forward_flag_2 = '0' else
                     forward_data_2;


                 
	-- switch stack while context switch flag is active
	-- by fox
	--process(clk, runnable_stack, prepare_addr) begin
	process(
		runnable_stack,
		stack0_rddata1,stack0_rddata2,stack_rdaddr1,stack_rdaddr2,
		stack1_rddata1,stack1_rddata2,
		stack_wddata1, stack_wddata2, stack_wdaddr1,stack_wdaddr2,
		stack_we1,stack_we2,enable, 
		prepare_WE, prepare_addr, prepare_data
	) begin
        if(runnable_stack = '0') then
         stack_rddata1_temp	<=	stack0_rddata1;
			stack_rddata2_temp	<=	stack0_rddata2;
			stack0_rdaddr1		<=	stack_rdaddr1;
			stack0_rdaddr2		<=	stack_rdaddr2;
			stack0_wddata1		<=	stack_wddata1;
			stack0_wddata2		<=	stack_wddata2;
			stack0_wdaddr1		<=	stack_wdaddr1;
			stack0_wdaddr2		<=	stack_wdaddr2;
			stack0_we1			<= stack_we1;
			stack0_we2			<=	stack_we2;
			stack0_enable		<=	enable;
			
			stack_bkdata1_temp	<=	stack1_rddata1;
			stack_bkdata2_temp	<=	stack1_rddata2;
			stack1_rdaddr1		<=	prepare_addr(9 downto 1);
			stack1_rdaddr2		<=	prepare_addr(9 downto 1);
			stack1_wddata1		<=	prepare_data;
			stack1_wddata2		<=	prepare_data;
			stack1_wdaddr1		<=	prepare_addr(9 downto 1);
			stack1_wdaddr2		<=	prepare_addr(9 downto 1);
			if (prepare_addr(0) = '0') then 
				stack1_we1		<= 	prepare_WE;
				stack1_we2		<=	'0';
			else
				stack1_we1		<= 	'0';
				stack1_we2		<=	prepare_WE;
			end if;
			stack1_enable	<=	'1';
      else
			stack_rddata1_temp	<=	stack1_rddata1;
			stack_rddata2_temp	<=	stack1_rddata2;
			stack1_rdaddr1		<=	stack_rdaddr1;
			stack1_rdaddr2		<=	stack_rdaddr2;
			stack1_wddata1		<=	stack_wddata1;
			stack1_wddata2		<=	stack_wddata2;
			stack1_wdaddr1		<=	stack_wdaddr1;
			stack1_wdaddr2		<=	stack_wdaddr2;
			stack1_we1			<= 	stack_we1;
			stack1_we2			<=	stack_we2;
			stack1_enable		<=	enable;
			
			stack_bkdata1_temp	<=	stack0_rddata1;
			stack_bkdata2_temp	<=	stack0_rddata2;
			stack0_rdaddr1		<=	prepare_addr(9 downto 1);
			stack0_rdaddr2		<=	prepare_addr(9 downto 1);
			stack0_wddata1		<=	prepare_data;
			stack0_wddata2		<=	prepare_data;
			stack0_wdaddr1		<=	prepare_addr(9 downto 1);
			stack0_wdaddr2		<=	prepare_addr(9 downto 1);
			if (prepare_addr(0) = '0') then 
				stack0_we1		<= 	prepare_WE;
				stack0_we2		<=	'0';
			else
				stack0_we1		<= 	'0';
				stack0_we2		<=	prepare_WE;
			end if;
			stack0_enable	<=	'1';
        end if;
    end process;
					  
					  
					  
	stack0_lsb0 : RAMB16_S36_S36
    port map (
        DIA   => (others => '0'),
        DIPA  => "0000",
        DOA   => stack0_rddata1,
        ADDRA => stack0_rdaddr1,
        DIB   => stack0_wddata1,
        DIPB  => "0000",
        ADDRB => stack0_wdaddr1,
        CLKA  => clk,
        CLKB  => clk,
        ENA   => stack0_enable,
        ENB   => stack0_enable,
        SSRA  => Rst,
        SSRB  => Rst,
        WEA   => '0',
        WEB   => stack0_we1
    );

    stack0_lsb1 : RAMB16_S36_S36
    port map (
        DIA   => (others => '0'),
        DIPA  => "0000",
        DOA   => stack0_rddata2,
        ADDRA => stack0_rdaddr2,
        DIB   => stack0_wddata2,
        DIPB  => "0000",
        ADDRB => stack0_wdaddr2,
        CLKA  => clk,
        CLKB  => clk,
        ENA   => stack0_enable,
        ENB   => stack0_enable,
        SSRA  => Rst,
        SSRB  => Rst,
        WEA   => '0',
        WEB   => stack0_we2
    );
	
	stack1_lsb0 : RAMB16_S36_S36
    port map (
        DIA   => (others => '0'),
        DIPA  => "0000",
        DOA   => stack1_rddata1,
        ADDRA => stack1_rdaddr1,
        DIB   => stack1_wddata1,
        DIPB  => "0000",
        ADDRB => stack1_wdaddr1,
        CLKA  => clk,
        CLKB  => clk,
        ENA   => stack1_enable,
        ENB   => stack1_enable,
        SSRA  => Rst,
        SSRB  => Rst,
        WEA   => '0',
        WEB   => stack1_we1
    );

    stack1_lsb1 : RAMB16_S36_S36
    port map (
        DIA   => (others => '0'),
        DIPA  => "0000",
        DOA   => stack1_rddata2,
        ADDRA => stack1_rdaddr2,
        DIB   => stack1_wddata2,
        DIPB  => "0000",
        ADDRB => stack1_wdaddr2,
        CLKA  => clk,
        CLKB  => clk,
        ENA   => stack1_enable,
        ENB   => stack1_enable,
        SSRA  => Rst,
        SSRB  => Rst,
        WEA   => '0',
        WEB   => stack1_we2
    );
	 
	 
	 
--                     
--    stack_lsb0 : RAMB16_S36_S36
--    port map (
--        DIA   => (others => '0'),
--        DIPA  => "0000",
--        DOA   => stack_rddata1_temp,
--        ADDRA => stack_rdaddr1,
--        DIB   => stack_wddata1,
--        DIPB  => "0000",
--        ADDRB => stack_wdaddr1,
--        CLKA  => clk,
--        CLKB  => clk,
--        ENA   => enable,
--        ENB   => enable,
--        SSRA  => Rst,
--        SSRB  => Rst,
--        WEA   => '0',
--        WEB   => stack_we1
--    );
--
--    stack_lsb1 : RAMB16_S36_S36
--    port map (
--        DIA   => (others => '0'),
--        DIPA  => "0000",
--        DOA   => stack_rddata2_temp,
--        ADDRA => stack_rdaddr2,
--        DIB   => stack_wddata2,
--        DIPB  => "0000",
--        ADDRB => stack_wdaddr2,
--        CLKA  => clk,
--        CLKB  => clk,
--        ENA   => enable,
--        ENB   => enable,
--        SSRA  => Rst,
--        SSRB  => Rst,
--        WEA   => '0',
--        WEB   => stack_we2
--    );
	
	-- cs
	--debug_stack_wdaddr <= stack_wdaddr1 & stack_wdaddr2;
	--debug_stack_rdaddr <= stack_rdaddr1 & stack_rdaddr2;
    
    
         --debug_cs_4portbank (31 downto 0)  <=  local_variable_0;
         -- debug_cs_4portbank (63 downto 32) <=   local_variable_1;
         --debug_cs_4portbank (95 downto 64)  <=    local_variable_2;
         --debug_cs_4portbank (127 downto 96)  <=    local_variable_3;
            
            
            
end architecture rtl;
