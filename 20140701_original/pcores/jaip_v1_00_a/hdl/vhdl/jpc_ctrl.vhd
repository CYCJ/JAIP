------------------------------------------------------------------------------
-- Filename     :       jpc_ctrl.vhd
-- Version      :       1.00
-- Author       :       Han-Wen Kuo
-- Date         :       Nov 2010
-- VHDL Standard:       VHDL'93
-- Describe     :       New Architecture
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
-- Filename     :       jpc_ctrl.vhd
-- Version      :       
-- Author       :       
-- Date         :       
-- VHDL Standard:       VHDL'93
-- Describe     :       
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity jpc_ctrl is
    generic(
        RAMB_S18_AWIDTH             : integer := 10
    );
    port(
        clk                         : in  std_logic; 
        act                         : in  std_logic; 
        stall_jpc                   : in  std_logic;
        CTRL_state                  : in  DynamicResolution_SM_TYPE; 
        stjpc_flag                  : in  std_logic;
        native_flag                 : in  std_logic;
        switch_instr_branch : in std_logic; -- just for tableswitch / lookupswitch branch use
        branch                      : in  std_logic;
        branch_destination          : in  std_logic_vector(15 downto 0);
        TOS_A                       : in  std_logic_vector(15 downto 0);
        TOS_B                       : in  std_logic_vector(15 downto 0);
        jpc_reg_out                 : out std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
        jpc                         : out std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
        -- thread mgt   -- by fox
	context_switch		: in  std_logic;
        TH_mgt_thread_jpc       : in  std_logic_vector(15 downto 0);
	jpc_backup			: in  std_logic; 
	clean_pipeline_cmplt: in  std_logic;
		-- xcptn hdlrr
		xcptn_jpc_wen               : in  std_logic;
		xcptn_jpc                   : in  std_logic_vector(15 downto 0);
		adjust_jpc2xcptn_instr      : in std_logic;
		xcptn_stall                 : in std_logic
    );
end entity jpc_ctrl;

architecture rtl of jpc_ctrl is
    signal jpc_tmp                  : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
    signal jpc_reg                  : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
	 -- by fox
	signal backup_jpc               : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
	signal clean_pipeline_cmplt_reg	: std_logic;

begin
    jpc         <= jpc_tmp when(adjust_jpc2xcptn_instr = '0') else	-- modified by C.C.H. --timing issue
				   (others => '0');
    jpc_reg_out <= jpc_reg; 
    
    jpc_ctrl :
    process(branch_destination, branch, jpc_reg, stall_jpc, CTRL_state, TOS_A, TOS_B,context_switch, TH_mgt_thread_jpc,
                clean_pipeline_cmplt, clean_pipeline_cmplt_reg, backup_jpc,
             stjpc_flag, xcptn_jpc_wen,xcptn_jpc,adjust_jpc2xcptn_instr,switch_instr_branch,xcptn_stall
        )
            variable A_tmp : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
    begin
		if xcptn_jpc_wen = '1' then
			jpc_tmp <= xcptn_jpc(15 downto 1);
		elsif  adjust_jpc2xcptn_instr = '1' then
		    jpc_tmp <= jpc_reg - "0100";
		-- modified by T.H.Wu , 2013.9.18 , try to reduce some unecessary logics
		--elsif xcptn_stall = '1'	then
		--	jpc_tmp <= jpc_reg;
		elsif(context_switch = '1') then							-- by fox
			jpc_tmp <= TH_mgt_thread_jpc(RAMB_S18_AWIDTH+5 downto 1);
        elsif(CTRL_state = Normal) then
            if(branch = '1') then
                if(switch_instr_branch = '1') then
                    A_tmp := TOS_A(RAMB_S18_AWIDTH+3 downto 0) & "0";
                    A_tmp := A_tmp + "010";
                    jpc_tmp <= jpc_reg + A_tmp;
				else
                    jpc_tmp <= branch_destination(RAMB_S18_AWIDTH+5 downto 1);
				end if;
                --jpc_tmp <= branch_destination(RAMB_S18_AWIDTH+5 downto 1);
            elsif(clean_pipeline_cmplt = '1' and clean_pipeline_cmplt_reg = '0') then	-- by fox
				jpc_tmp <=	backup_jpc;
            elsif(stjpc_flag = '1') then
                jpc_tmp <= TOS_A(RAMB_S18_AWIDTH+5 downto 1);
            elsif(stall_jpc = '1') then
                jpc_tmp <= jpc_reg;
            else
                jpc_tmp <= jpc_reg + '1';
            end if;
        elsif(CTRL_state = Method_entry) then
            jpc_tmp <= (others => '0');
        elsif(CTRL_state = Method_flag or CTRL_state = arg_size  or
              CTRL_state = max_stack  or CTRL_state = max_local or 
              --CTRL_state = Method_exit or
              CTRL_state = Native_exit -- 2013.7.19 , why Native_exit ?? , not Method_exit ?
              ) then
            jpc_tmp <= jpc_reg + '1';
        elsif(native_flag = '1') then
            jpc_tmp <= TOS_B(RAMB_S18_AWIDTH+5 downto 1);
        else
            jpc_tmp <= jpc_reg;
        end if;
    end process;

    jpc_reg_ctrl :
    process(clk) begin
       if(rising_edge(clk))then
            if(act = '1') then
                jpc_reg <= jpc_tmp;
            else
                jpc_reg <= (others=>'0');
            end if;
            ---
                if(act = '0') then
                    backup_jpc 	<=  (others => '0');
                    clean_pipeline_cmplt_reg	<= '0';
		else
			if(branch = '1') then
				backup_jpc <= jpc_tmp ;--- "01";
			elsif(jpc_backup = '1') then -- 2013.7.16 , jpc backup for what ?
				backup_jpc <= jpc_reg;
			end if;
			clean_pipeline_cmplt_reg	<= clean_pipeline_cmplt;
		end if;
        end if;
    end process;
        
end architecture rtl;