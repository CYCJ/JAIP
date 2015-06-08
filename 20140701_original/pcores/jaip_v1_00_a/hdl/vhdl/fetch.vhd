------------------------------------------------------------------------------
-- Filename     :       fetch.vhd
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
-- Filename     :       fetch.vhd
-- Version      :       2.03
-- Author       :       Kuan-Nian Su
-- Date         :       May 2009
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Filename     :       fetch.vhd
-- Version      :       3.00
-- Author       :       Han-Wen Kuo
-- Date         :       Nov 2010
-- VHDL Standard:       VHDL'93
-- Describe     :       New Architecture
------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity Fetch is
    generic(
        HIDE_MODULE                     : integer := 1;
        ENABLE_JAIP_PROFILER   : integer := 0;
        C_MAX_AR_DWIDTH             : integer := 32;
        RAMB_S9_AWIDTH              : integer := 11;
        RAMB_S18_AWIDTH             : integer := 10

    );
    port(
        -- ctrl signal
        Rst                         : in  std_logic;
        clk                         : in  std_logic;        
        stall_fetch_stage           : in  std_logic;        
        CTRL_state                  : in  DynamicResolution_SM_TYPE;
        set_ucodePC                 : in  std_logic;
        native_flag                 : in  std_logic;
        
        ISFrom_ROM                  : out std_logic;
        
        -- method area
        jpc_reg                     : in  std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
        stall_jpc                   : out std_logic;
                
        -- translate stage
        semitranslated_code         : in  std_logic_vector(15 downto 0);
        complex                     : in  std_logic_vector( 1 downto 0);
        opd_num                     : in  std_logic_vector( 7 downto 0); 
        instr_buf_ctrl              : out std_logic_vector( 1 downto 0);
        
        -- decode stage
        stjpc_flag                  : in  std_logic;
        invoke_flag                 : in  std_logic;
        return_flag                 : in  std_logic;
        switch_instr_branch : out std_logic; -- just for tableswitch / lookupswitch branch use
        branch_trigger              : out std_logic_vector(15 downto 0); 
        instrs_pkg                  : out std_logic_vector(15 downto 0);
        opd_source                  : out std_logic_vector( 1 downto 0);
        nop_1                       : out std_logic;
        nop_2                       : out std_logic;
	clinitEN					: in  std_logic;
	is_switch_instr_start	: out  std_logic;
        switch_instr_revert_code_seq : in std_logic ;

        -- execute stage
        A_0                         : in  std_logic ;
        B_0                         : in  std_logic ;
        branch_destination          : in  std_logic_vector(15 downto 0);
        branch                      : in  std_logic; 
		-- thread management 	-- by fox
		TH_mgt_context_switch		: in std_logic; 
		TH_mgt_clean_pipeline		: in std_logic;
		TH_mgt_clean_decode			: out std_logic;
		TH_mgt_new_thread_execute	: in  std_logic;
		TH_mgt_thread_jpc              	: in  std_logic_vector(15 downto 0);
		TH_mgt_thread_trigger		: out std_logic_vector(15 downto 0);
		TH_mgt_simple_mode			: out std_logic;
		TH_mgt_reset_mode			: in  std_logic;
		-- modified by T.H.Wu , 2014.1.22, for invoking/returning sync method.
		invoke_sync_mthd_flag_dly	: in  std_logic;
		rtn_frm_sync_mthd_flag		: in  std_logic;
		COOR_cmd_cmplt_reg			: in  std_logic;
		-- xcptn
		xcptn_flush_pipeline        : in std_logic;
        --debug_cs_fetch              : out std_logic_vector(12 downto 0);
        -- debug
        debug_flag                  : in  std_logic_vector(7 downto 0);
        debug_addr                  : in  std_logic_vector(7 downto 0);
        debug_data                  : out std_logic_vector(31 downto 0);
		
		-- prof
		prof_simple_issued_A		: out std_logic;
		prof_simple_issued_B		: out std_logic;
		prof_complex_issued			: out std_logic;
		prof_issued_bytecodes_T		: in std_logic_vector(15 downto 0);
		prof_issued_bytecodes_F		: out std_logic_vector(15 downto 0)
    );
end entity Fetch;

architecture rtl of Fetch is

    --alias  complex_1_tmp            : std_logic is complex(1); -- modified by T.H.Wu , 2013.7.16
    --alias  complex_2_tmp            : std_logic is complex(0);
    signal  complex_1_tmp         : std_logic ;
    signal  complex_2_tmp         : std_logic ;
    signal complex_1, complex_2     : std_logic;
    signal special_2                  : std_logic;
    --alias  semi_code1           : std_logic_vector( 7 downto 0) is semitranslated_code(15 downto 8); -- modified by T.H.Wu , 2013.7.16
    --alias  semi_code2           : std_logic_vector( 7 downto 0) is semitranslated_code( 7 downto 0);
    signal  semi_code1               : std_logic_vector( 7 downto 0) ;
    signal  semi_code2               : std_logic_vector( 7 downto 0) ;
    signal semi_code1_nop           : std_logic;
    signal semi_code2_nop           : std_logic;
    signal opd_reg                  : std_logic_vector( 3 downto 0);
    --alias  opd_1                    : std_logic_vector( 3 downto 0) is opd_num(7 downto 4); -- modified by T.H.Wu , 2013.7.16
    --alias  opd_2                    : std_logic_vector( 3 downto 0) is opd_num(3 downto 0);
    signal  opd_1                    : std_logic_vector( 3 downto 0) ;
    signal  opd_2                    : std_logic_vector( 3 downto 0) ;
    signal opd_source_reg           : std_logic_vector( 1 downto 0);
    
    signal instr_buf_ctrl_tmp       : std_logic_vector( 1 downto 0);
    signal instr_buf_ctrl_reg       : std_logic_vector( 1 downto 0);
    signal not_stall_jpc_signal     : std_logic;
    
    signal hazard_structure         : std_logic;
    signal hazard_potential         : std_logic;
    signal instr_type               : std_logic_vector(3 downto 0);
  
	-- added by T.H.Wu , 2014.1.22 for returning sync method, restoring the j-code pc to go on the rest of j-code
    signal jcode_addr_restore_for_rtn_sync_mthd : std_logic_vector( 7 downto 0);
	--
    signal ucode_addr               : std_logic_vector( 7 downto 0);
    signal ucodeaddr_semicode       : std_logic_vector( 7 downto 0);
    signal ucodeaddr_tmp                    : std_logic_vector( 7 downto 0);
    signal pc                       : std_logic_vector( 7 downto 0);
    signal nxt                      : std_logic;
    signal nxt_reg                  : std_logic;
    signal ROM_instr                : std_logic_vector(15 downto 0);
    type   mode_type                is  (from_ROM, from_translate);
    signal mode                     : mode_type;
    signal mode_reg                 : mode_type;
    
    signal semitranslated_code_reg  : std_logic_vector(15 downto 0);

    signal branch_reg               : std_logic;
    signal stjpc_flag_reg           : std_logic;
    signal branch_trigger_reg       : std_logic_vector(15 downto 0);
    -- add tableswitch / lookupswitch , fox
    signal is_switch_instr_start_reg : std_logic;
    signal is_switch_instr_start_w : std_logic;
    signal switch_instr_branch_reg : std_logic;
    signal stall_jpc_for_switch_instr : std_logic;
    signal stall_jpc_w : std_logic;
    signal instrs_pkg_w   : std_logic_vector(15 downto 0);
	 -- add for thread management , fox
	 signal TH_mgt_clean_fetch		: std_logic ;
	-- for timing constraint issue, modified by T.H.Wu , 2013.7.25
	signal Disable_semicode_during_context_switch :  std_logic; 
	-- modified by T.H.Wu, 2014.1.23, for retuning from sync method.
	signal rtn_frm_sync_mthd_flag_dly		:	std_logic;
	signal rtn_frm_sync_mthd_active_hold	:	std_logic;
    
    
    signal debug                    : std_logic_vector(9 downto 0);
    signal debug2                   : std_logic_vector(9 downto 0);
    signal debug3                   : std_logic_vector(9 downto 0);
    signal debug4                   : std_logic_vector(9 downto 0);
    signal debug5                   : std_logic_vector(9 downto 0);
    
    signal opd_reg_1_reg            : std_logic;
    signal complex_2_reg            : std_logic;
    signal opd_reg_2_reg            : std_logic;
    signal opd_1_reg                : std_logic;
    signal hazard_structure_reg     : std_logic;
    signal special_2_reg            : std_logic;
    signal native_flag1             : std_logic;
    signal stjpc_flag1              : std_logic;
    signal branch1                  : std_logic;
    signal branch2                  : std_logic;
    signal invoke1                  : std_logic;
    signal invoke_reg               : std_logic;
    
    signal branch_numreg            : std_logic_vector(31 downto 0);
    signal cplx_mode                : std_logic_vector(31 downto 0);
    signal FFXX_opd                 : std_logic_vector(31 downto 0);
    signal XXFF_opd                 : std_logic_vector(31 downto 0);
    signal XXFF_c                   : std_logic_vector(31 downto 0);
    signal XXFF_s                   : std_logic_vector(31 downto 0);
    signal XXFF_h                   : std_logic_vector(31 downto 0);
    signal FFFF_opdopd              : std_logic_vector(31 downto 0);
    signal FFFF_opds                : std_logic_vector(31 downto 0);
    signal stall_fetch_stage_reg    : std_logic_vector(31 downto 0);
    signal FFFF_ROM                 : std_logic_vector(31 downto 0);
    signal XXFF_ROM                 : std_logic_vector(31 downto 0);
    signal FFXX_ROM                 : std_logic_vector(31 downto 0);
    signal invoke_numreg            : std_logic_vector(31 downto 0);
    signal FFXX_branch              : std_logic_vector(31 downto 0);
    signal FFFF_branch              : std_logic_vector(31 downto 0);
    signal FFFF_brs                 : std_logic_vector(31 downto 0);
    signal single_issue             : std_logic_vector(31 downto 0);
    signal nop_flag_reg             : std_logic_vector(31 downto 0);
    signal counter                  : std_logic_vector(31 downto 0);
	signal prof_simple_issued_A_reg		: std_logic;
	signal prof_simple_issued_B_reg		: std_logic;
	signal prof_complex_issued_reg		: std_logic;
	signal nop_1_tmp					: std_logic;
	signal nop_2_tmp					: std_logic;
    signal prof_issued_bytecodes		: std_logic_vector(15 downto 0);
	
    begin
--==================================================================
    labal_hide_module_0 : if HIDE_MODULE = 0 generate
    debug_data <= branch_numreg when debug_addr = x"00" else
                  cplx_mode     when debug_addr = x"01" else
                  FFXX_opd      when debug_addr = x"02" else
                  XXFF_opd      when debug_addr = x"03" else
                  XXFF_c        when debug_addr = x"04" else
                  XXFF_s        when debug_addr = x"05" else
                  XXFF_h        when debug_addr = x"06" else
                  FFFF_opdopd   when debug_addr = x"07" else
                  FFFF_opds     when debug_addr = x"08" else
                  stall_fetch_stage_reg when debug_addr = x"09" else
                  FFFF_ROM      when debug_addr = x"0A" else
                  XXFF_ROM      when debug_addr = x"0B" else
                  FFXX_ROM      when debug_addr = x"0C" else
                  invoke_numreg when debug_addr = x"0D" else
                  FFXX_branch   when debug_addr = x"0E" else
                  FFFF_branch   when debug_addr = x"0F" else
                  FFFF_brs      when debug_addr = x"10" else
                  single_issue  when debug_addr = x"11" else
                  nop_flag_reg  when debug_addr = x"12" else
                  counter       when debug_addr = x"13" else
                  x"FF000000";
                  
    ISFrom_ROM <= '0' when mode_reg = from_translate else '1';
    
    
    process(clk, Rst) begin
        if(Rst = '1') or xcptn_flush_pipeline = '1' then
            branch_numreg <= (others => '0');
            cplx_mode <= (others => '0');
            FFXX_opd <= (others => '0');
            XXFF_opd <= (others => '0');
            XXFF_c <= (others => '0');
            XXFF_s <= (others => '0');
            XXFF_h <= (others => '0');
            FFFF_opdopd <= (others => '0');
            FFFF_opds <= (others => '0');
            stall_fetch_stage_reg <= (others => '0');
            FFFF_ROM <= (others => '0');
            XXFF_ROM <= (others => '0');
            FFXX_ROM <= (others => '0');
            invoke_numreg <= (others => '0');
            FFXX_branch <= (others => '0');
            FFFF_branch <= (others => '0');
            FFFF_brs <= (others => '0');
            single_issue <= (others => '0');
            nop_flag_reg <= (others => '0');
            branch2  <= '0';
            invoke1  <= '0';
            invoke_reg  <= '0';
            counter <= (others => '0');
        elsif(rising_edge(clk)) then
            opd_reg_1_reg <= opd_reg(0);
            complex_2_reg <= complex_2;
            opd_reg_2_reg <= opd_reg(1);
            opd_1_reg <= (not opd_reg(0) and opd_1(0));
            hazard_structure_reg <= hazard_structure;
            special_2_reg <= special_2;
            invoke1 <= invoke_flag;
            invoke_reg <= invoke1;
            
            if(branch = '1') then
                branch_numreg <= branch_numreg + 1;
                branch2 <= '1';
            end if;
            if(nxt_reg = '1' and mode_reg = from_translate) then
                cplx_mode <= cplx_mode + 1;
            end if;
            if(invoke1 = '1' and invoke_reg = '0') then
                invoke_numreg <= invoke_numreg + 1;
            end if;
            
            if(native_flag = '1') then
                native_flag1 <= B_0;
            elsif(stjpc_flag = '1') then
                stjpc_flag1 <= A_0;
            elsif(branch = '1') then
                branch1 <= branch_destination(0);
            end if;
            
            if(stall_fetch_stage = '0') then
                if(branch = '1' or (nxt_reg = '1' and mode_reg = from_translate))then
                    nop_flag_reg <= nop_flag_reg + 1;
                elsif(semitranslated_code_reg(15 downto 8) = x"FF" and semitranslated_code_reg( 7 downto 0) /= x"FF" and mode_reg = from_translate) then
                    if((native_flag1 or stjpc_flag1 or branch1)= '1' ) then
                        FFXX_branch  <= FFXX_branch +1;
                        native_flag1 <= '0';
                        stjpc_flag1  <= '0';
                        branch1      <= '0';
                    elsif(opd_reg_1_reg = '1') then
                        FFXX_opd <= FFXX_opd + 1;
                    end if;
                    single_issue <= single_issue + 1;
                elsif(semitranslated_code_reg(15 downto 8) /= x"FF" and semitranslated_code_reg( 7 downto 0) = x"FF" and mode_reg = from_translate) then
                    if(opd_1_reg = '1') then
                        XXFF_opd <= XXFF_opd + 1;
                    elsif(complex_2_reg = '1') then
                        XXFF_c <= XXFF_c + 1;
                    elsif(special_2_reg = '1') then
                        XXFF_s <= XXFF_s + 1;
                    elsif(hazard_structure_reg = '1') then
                        XXFF_h <= XXFF_h + 1;
                    end if;
                    single_issue <= single_issue + 1;
                end if;
                
                if(branch = '1' or (nxt_reg = '1' and mode_reg = from_translate))then
                    counter <= counter + 1;
                elsif(semitranslated_code_reg = x"FFFF" and mode_reg = from_translate) then  
                    if(((native_flag1 or stjpc_flag1) and special_2_reg)= '1' ) then
                        FFFF_brs     <= FFFF_brs + 1;
                        native_flag1 <= '0';
                        stjpc_flag1  <= '0';
                    elsif(branch2= '1') then
                        FFFF_branch  <= FFFF_branch + 1;
                        branch2      <= '0';
                    else
                        if(opd_reg_2_reg = '1') then
                            FFFF_opdopd <= FFFF_opdopd + 1;
                        elsif(special_2_reg = '1') then
                            FFFF_opds <= FFFF_opds + 1;
                        end if;
                    end if;
                end if;
                
                if(mode_reg = from_ROM) then
                    if(ROM_instr = x"FFFF") then
                        FFFF_ROM <= FFFF_ROM + 1;
                    elsif(ROM_instr(15 downto 8) /= x"FF" and ROM_instr( 7 downto 0) = x"FF") then
                        XXFF_ROM <= XXFF_ROM + 1;
                    elsif(ROM_instr(15 downto 8) = x"FF" and ROM_instr( 7 downto 0) /= x"FF") then
                        FFXX_ROM <= FFXX_ROM + 1;
                    end if;
                end if;
            else
                stall_fetch_stage_reg <= stall_fetch_stage_reg + 1;
            end if;
        end if;
    end process;
    end generate ;
--==================================================================
    -- modified by T.H.Wu , 2013.7.25 
      complex_1_tmp  <= complex(1)  when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else '0';
      complex_2_tmp <= complex(0) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else '0';
      semi_code1       <= semitranslated_code(15 downto 8) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else x"FF";
      semi_code2       <= semitranslated_code( 7 downto 0) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else x"FF";
      opd_1                 <= opd_num(7 downto 4) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else x"0";
      opd_2                 <= opd_num(3 downto 0) when TH_mgt_clean_fetch='0' and  TH_mgt_context_switch='0' else x"0";
      --complex_1_tmp  <= complex(1)  when TH_mgt_clean_fetch='0' and Disable_semicode_during_context_switch='0' else '0';
      --complex_2_tmp <= complex(0) when TH_mgt_clean_fetch='0' and Disable_semicode_during_context_switch='0' else '0';
      --semi_code1       <= semitranslated_code(15 downto 8) when TH_mgt_clean_fetch='0' and Disable_semicode_during_context_switch='0' else x"FF";
      --semi_code2       <= semitranslated_code( 7 downto 0) when TH_mgt_clean_fetch='0' and Disable_semicode_during_context_switch='0' else x"FF";
      --opd_1                 <= opd_num(7 downto 4) when TH_mgt_clean_fetch='0' and Disable_semicode_during_context_switch='0' else x"0";
      --opd_2                 <= opd_num(3 downto 0) when TH_mgt_clean_fetch='0' and Disable_semicode_during_context_switch='0' else x"0";
      -- by fox ,  usage ?
        TH_mgt_simple_mode <= '1' when mode = from_translate and mode_reg = from_translate else '0';
    
    
    complex_1 <= '0' when opd_reg(0) = '1' else complex_1_tmp;
    
    complex_2 <= '0' when((opd_reg(0) = '0' and opd_1(0) = '1')or(opd_reg(1) = '1'))else
                 complex_2_tmp;
    
    semi_code1_nop <= '1' when semi_code1 = x"FF" else '0';
    semi_code2_nop <= '1' when semi_code2 = x"FF" else '0';
    
    -- added tableswitch / lookupswitch , 2013.7.1 , fox
    
    is_switch_instr_start <= is_switch_instr_start_reg;
    switch_instr_branch <= switch_instr_branch_reg;
    
    process (clk) begin
        if(rising_edge(clk)) then
            -- 2013.7.9 , debug for lookupswitch/tableswitch stringAtom
            -- modified since 2013.7.24 
            if(Rst='1') then 
                is_switch_instr_start_reg <= '0';
            else
                --if (branch = '1' and switch_instr_branch_reg = '0') or TH_mgt_context_switch='1'  then
                if (branch = '1' and switch_instr_branch_reg = '0') or Disable_semicode_during_context_switch='1'  then
                    is_switch_instr_start_reg <= '0';
                elsif (is_switch_instr_start_w='1') then
                    is_switch_instr_start_reg <= '1';
                end if;
            end if;
            ---
            if(Rst='1') then
                switch_instr_branch_reg <= '0'; 
            else
                if(is_switch_instr_start_reg = '1' and instrs_pkg_w(7 downto 0) = x"E0") then --fox
                    switch_instr_branch_reg  <= '1';
               elsif(branch = '1') then
                    switch_instr_branch_reg <= '0'; 
                end if;
            end if;
            --
            if(Rst='1') then
                stall_jpc_for_switch_instr <= '0';
            else
                if(instrs_pkg_w(7 downto 0) = x"D3") then
                    stall_jpc_for_switch_instr <= '1';
                elsif(branch = '1') then
                    stall_jpc_for_switch_instr <= '0';
                end if;
            end if;
        end if;
        --
    end process;
    
    process (semi_code1,semi_code2, mode_reg, complex_1, complex_2, opd_reg(0) ) begin 
        if( mode_reg = from_translate) then
            if( semi_code1=x"60" or  semi_code1=x"80" ) then
                is_switch_instr_start_w <=  complex_1;
            elsif( semi_code2=x"60" or  semi_code2=x"80" ) then
                is_switch_instr_start_w <=  complex_2 and opd_reg(0);
            else
                is_switch_instr_start_w <= '0';
            end if;
        else 
            is_switch_instr_start_w <=  '0';
        end if;
    end process;
    
    
    -- modifed by T.H. Wu , 2013.8.22 , reducing the logic for fetching specail-type opcode (at bytecode level)
    -- special instruction must be the first one, or it can't be decoded.
    --special_2 <= '0' when((opd_reg(0) = '0' and opd_1(0) = '1')or opd_reg(1) = '1' or semi_code2(7 downto 6) /= "11" or semi_code2_nop = '1')else
    --             '1' ;
    special_2 <= '0' ;
                 
      stall_jpc <= stall_jpc_w or stall_jpc_for_switch_instr;
    stall_jpc_w <= (not not_stall_jpc_signal) and not (is_switch_instr_start_reg) when mode = from_ROM or instr_buf_ctrl_tmp(1) = '1' else
                 '0' ;
                 
    not_stall_jpc_signal_ctrl :
    process(mode_reg, mode, opd_reg, instr_buf_ctrl_reg, opd_1, opd_2) begin
        if(mode_reg = from_translate and mode = from_ROM) then
            if(opd_reg(0) = '1') then -- opd + C
                not_stall_jpc_signal <= opd_2(0);
            else                       -- C + X
                not_stall_jpc_signal <= opd_1(0) and not instr_buf_ctrl_reg(0);
            end if;
        else
            not_stall_jpc_signal <= '0';
        end if;        
    end process;
    
    -- if semi_code1 and semi_code2 both are simple instruction
    hazard_potential <= not (opd_reg(0) or complex_1 or complex_2 or opd_1(0));
    instr_type       <= semi_code1(7 downto 6) & semi_code2(7 downto 6);
    -- structure_hazard_detection
    -- modifed by T.H. Wu , 2013.8.22 , reducing the logic for fetching specail-type opcode (at bytecode level)
    hazard_structure <= hazard_potential when 
                                               --(instr_type = "0011" and semi_code2_nop = '0') or   -- load-nop or load-special
                                              --(instr_type = "0111" and semi_code2_nop = '0') or   -- store-nop or store-special
                                              (instr_type = "1010" )   -- ALU-ALU
                                              --(instr_type = "1100" and semi_code1_nop = '0') or   -- nop-load or special-load
                                              --(instr_type = "1101" and semi_code1_nop = '0') or   -- nop-store or special-store
                                              --(instr_type = "1110" and semi_code1_nop = '0') or   -- nop-ALU or special-ALU
                                              --(instr_type = "1111" and semi_code1_nop = '0')  -- nop-nop or nop-special 
                                                                                                  -- or special-nop or special-special
                                              else
                                              '0'; -- load-load  load-store   load-ALU 
                                              -- store-load store-store  store-ALU
                                              -- ALU-load   ALU-store
                                              
--     structure_hazard_detection :
--     process(semi_code1, semi_code2, hazard_potential, instr_type) begin
--         case instr_type is
--         -- load-nop or load-special
--             when "0011" =>
--                 if(semi_code2(5 downto 0) /= "111111") then
--                     hazard_structure <= hazard_potential;
--                 end if;
--         -- store-nop or store-special
--             when "0111" =>
--                 if(semi_code2(5 downto 0) /= "111111") then
--                     hazard_structure <= hazard_potential;
--                 end if;
--         -- ALU-ALU
--             when "1010" =>
--                 hazard_structure <= hazard_potential;
--         -- ALU-nop or ALU-special
--             when "1011" =>
--                 if(semi_code2(5 downto 0) /= "111111") then
--                     hazard_structure <= hazard_potential;
--                 end if;
--         -- nop-load or special-load
--             when "1100" =>
--                 if(semi_code1(5 downto 0) /= "111111") then
--                     hazard_structure <= hazard_potential;
--                 end if;
--         -- nop-store or special-store
--             when "1101" =>
--                 if(semi_code1(5 downto 0) /= "111111") then
--                     hazard_structure <= hazard_potential;
--                 end if;
--         -- nop-ALU or special-ALU
--             when "1110" =>
--                 if(semi_code1(5 downto 0) /= "111111") then
--                     hazard_structure <= hazard_potential;
--                 end if;
--         -- nop-nop or nop-special or special-nop or special-special
--             when "1111" =>
--                 if(semi_code2(5 downto 0) /= "111111") then
--                     hazard_structure <= hazard_potential;
--                 end if;
--         -- load-load  load-store   load-ALU 
--         -- store-load store-store  store-ALU
--         -- ALU-load   ALU-store
--             when others =>
--                 hazard_structure <= '0';
--         end case;
--     end process;

    instr_buf_ctrl <= instr_buf_ctrl_tmp;
    
    --   buf2 buf1 byte
    --   [XX] [XX] [XX]
    -- 0  XX   XX  {XX}
    -- 1  XX  X{X  X}X
    -- 2  XX  {XX}  XX 
    instr_buf_ctrl_logic :
    process(instr_buf_ctrl_reg, opd_reg, opd_1, opd_2, complex_1, complex_2,
                       stall_fetch_stage, hazard_structure, mode_reg, -- special_2,
                           branch_reg, stjpc_flag_reg, invoke_flag, return_flag, clinitEN)
        variable instr_buf_ctrl_type0   : std_logic_vector(1 downto 0);
        variable instr_buf_ctrl_type1   : std_logic_vector(1 downto 0);
        variable instr_buf_ctrl_type2   : std_logic_vector(1 downto 0);
        variable instr_buf_ctrl_type3   : std_logic_vector(1 downto 0);
        variable instr_buf_ctrl_CX      : std_logic_vector(1 downto 0);
        variable instr_buf_ctrl_XC      : std_logic_vector(1 downto 0);
        variable instr_buf_ctrl_SX      : std_logic_vector(1 downto 0);
        variable instr_buf_ctrl_special : std_logic_vector(1 downto 0);
        variable instr_buf_ctrl_normal  : std_logic_vector(1 downto 0);
    begin
        -- C + X
        case opd_1 is
            when x"0"   => instr_buf_ctrl_type0 := "01";
            when x"1"   => instr_buf_ctrl_type0 := "10";
            when x"3"   => instr_buf_ctrl_type0 := "01";
            when others => instr_buf_ctrl_type0 := "00";
        end case;
        case opd_1 is
            when x"0"   => instr_buf_ctrl_type1 := "10";
            when x"1"   => instr_buf_ctrl_type1 := "01";
            when others => instr_buf_ctrl_type1 := "00";
        end case;
        -- opd + C
        case opd_2 is
            when x"1"   => instr_buf_ctrl_type2 := "01";
            when others => instr_buf_ctrl_type2 := "00";
        end case;
        case opd_2 is
            when x"0"   => instr_buf_ctrl_type3 := "01";
            when x"1"   => instr_buf_ctrl_type3 := "10";
            when x"3"   => instr_buf_ctrl_type3 := "01";
            when others => instr_buf_ctrl_type3 := "00";
        end case;
        if(instr_buf_ctrl_reg(0) = '0') then
            instr_buf_ctrl_SX := "01";
            instr_buf_ctrl_CX := instr_buf_ctrl_type0;
            instr_buf_ctrl_XC := instr_buf_ctrl_type2;
        else
            instr_buf_ctrl_SX := "10";
            instr_buf_ctrl_CX := instr_buf_ctrl_type1;
            instr_buf_ctrl_XC := instr_buf_ctrl_type3;
        end if;
        if(instr_buf_ctrl_reg(1) = '1') then 
            instr_buf_ctrl_special := "00";
        else
            instr_buf_ctrl_special := instr_buf_ctrl_reg;
        end if;
        debug  <= "00000000" & instr_buf_ctrl_SX;
        debug2 <= "00000000" & instr_buf_ctrl_special;
        debug3 <= "00000000" & instr_buf_ctrl_CX;
        debug4 <= "00000000" & instr_buf_ctrl_XC;
        -- for normal
        if(opd_reg(0) = '0') then -- semicodes are valid
            if(complex_1 = '0') then -- S + X
                if((complex_2 or hazard_structure) = '1') then -- S + S/C
                    instr_buf_ctrl_normal := instr_buf_ctrl_SX;
                else                                           -- S + S normal
                    instr_buf_ctrl_normal := instr_buf_ctrl_special;
                end if;
            else                     -- C + X
                instr_buf_ctrl_normal   := instr_buf_ctrl_CX;
            end if;
        else
            if(complex_2 = '0') then -- opd + S/opd
                -- modifed by T.H. Wu , 2013.8.22 , reducing the logic for fetching specail-type opcode (at bytecode level)
                --if(special_2 = '1') then -- opd + pecial instruction
                --    instr_buf_ctrl_normal := instr_buf_ctrl_SX;
                --else
                    instr_buf_ctrl_normal := instr_buf_ctrl_special;
                --end if;
            else                     -- opd + C
                instr_buf_ctrl_normal   := instr_buf_ctrl_XC;
            end if;
        end if;
        if((branch_reg or stjpc_flag_reg or invoke_flag or return_flag or native_flag or clinitEN or TH_mgt_context_switch) = '1') then -- fox
            instr_buf_ctrl_tmp <= "00";
        elsif(stall_fetch_stage = '1' or mode_reg = from_ROM or ((opd_reg(0) and opd_reg(1)) = '1') or TH_mgt_clean_fetch='1') then
            instr_buf_ctrl_tmp <= instr_buf_ctrl_reg;
        else
            instr_buf_ctrl_tmp <= instr_buf_ctrl_normal;
        end if;
    end process;
    
    instr_buf_ctrl_reg_logic :
    process(Rst,clk) begin
        if(Rst = '1') or xcptn_flush_pipeline = '1'then
            instr_buf_ctrl_reg <= "00";
        elsif(rising_edge(clk)) then
            instr_buf_ctrl_reg <= instr_buf_ctrl_tmp;
            branch_reg         <= branch;
            stjpc_flag_reg     <= stjpc_flag;
        end if;        
    end process;

    opd_ctrl :
    process(Rst,clk)
        variable opd_reg_complex : std_logic_vector(3 downto 0);
        variable opd_reg_simple  : std_logic_vector(3 downto 0);
        variable opd_1or2        : std_logic_vector(1 downto 0);
        variable opd_2_tmp       : std_logic_vector(3 downto 0);
        variable opd_reg_type0   : std_logic_vector(3 downto 0);
        variable opd_reg_type1   : std_logic_vector(3 downto 0);
        variable opd_reg_type_CX : std_logic_vector(3 downto 0);
        variable opd_reg_type_XC : std_logic_vector(3 downto 0);
    begin
        --  for complex  start
        if(opd_reg(0) = '0') then -- C + X
            opd_1or2 := opd_1(3 downto 2);
        else                      -- opd + C
            opd_1or2 := opd_2(3 downto 2);
        end if;
          -- might be timing issue here
        case opd_1or2 is           -- C + X
            when "11"   => opd_reg_type0 := "0001"; -- opd  = 4
            when others => opd_reg_type0 := "0000";
        end case;
        case opd_1or2 is           -- opd + C
            when "01"   => opd_reg_type1 := "0001"; -- opd  = 3
            when "11"   => opd_reg_type1 := "0011"; -- opd  = 4
            when others => opd_reg_type1 := "0000";
        end case;
        if(instr_buf_ctrl_reg(0) = '0') then -- 00 10
            opd_reg_type_CX := opd_reg_type0;
            opd_reg_type_XC := opd_reg_type1;
        else                                  -- 01
            opd_reg_type_CX := opd_reg_type1;
            opd_reg_type_XC := opd_reg_type0;
        end if;
        if(opd_reg(0) = '0') then -- C + X
            opd_reg_complex := opd_reg_type_CX;
        else                      -- opd + C
            opd_reg_complex := opd_reg_type_XC;
        end if;
        --  for complex  end
        --  for simple   start
            -- modifed by T.H. Wu , 2013.8.22 , reducing the logic for fetching specail-type opcode (at bytecode level)
        --if((special_2 or complex_2 or hazard_structure) = '1') then
        if((complex_2 or hazard_structure) = '1') then
            opd_2_tmp := "0000";
        else
            opd_2_tmp := opd_2;
        end if;
        if(opd_reg(0) = '0') then     -- opd_reg = 00
            if(opd_1(0) = '0') then     -- S + S
                opd_reg_simple := opd_2_tmp;
            else                        -- S + opd
                opd_reg_simple := '0' & opd_1(3 downto 1);
            end if;
        else 
            if(opd_reg(1) = '0') then -- opd_reg = 01
                opd_reg_simple := opd_2_tmp;
            else      -- opd_reg = 11
                opd_reg_simple(1 downto 0) := opd_reg(3 downto 2);
                opd_reg_simple(3 downto 2) := "00";
            end if;
        end if;
        --  for simple   end
        if(Rst = '1') or xcptn_flush_pipeline = '1' then
            opd_reg   <= "0011";
        elsif(rising_edge(clk)) then
            if(native_flag = '1') then
                opd_reg <= "000" & B_0;
           -- elsif(invoke_flag = '1' or clinitEN = '1' )then -- modified by T.H.Wu , 2013.8.1
            elsif(invoke_flag = '1' or clinitEN = '1' or TH_mgt_new_thread_execute='1')then
                opd_reg <= "0011";
            elsif(stjpc_flag = '1') then
                opd_reg <= "000" & A_0;
            elsif(TH_mgt_context_switch = '1') then -- by fox
                opd_reg <= "0" &  TH_mgt_thread_jpc(0) & "11";
            elsif(branch = '1') then
                    -- 2013.7.9 , why switch_instr_branch_reg should be here ??
                    if(switch_instr_branch_reg = '1') then --fox
                            opd_reg <= "0011";
                        else
                            opd_reg <= '0' & branch_destination(0) & "11";
                    end if;
             elsif(TH_mgt_clean_fetch='1') then -- by fox
		if(branch_reg = '1') then
			opd_reg	<= "00" & opd_reg(3 downto 2);
		else
			opd_reg <= opd_reg;
		end if;
            elsif(stall_fetch_stage = '1') then
                opd_reg <= opd_reg;
            elsif(mode_reg = from_translate) then
                if(mode = from_translate) then -- normal 
                    opd_reg <= opd_reg_simple;
                else                           -- complex
                    opd_reg <= opd_reg_complex;
                end if;
            end if;
        end if;        
    end process;
    
    opd_source <= opd_source_reg;
    
    --   buf2 buf1 byte
    --   [XX] [XX] [XX]
    -- 0  OO   OO   XX
    -- 1  XO   OO   OO
    -- 2  XX   OO   OO
    --
    -- X => instruction
    -- O => operand
    opd_source_ctrl :
    process(clk, Rst) begin
        if(Rst = '1')or xcptn_flush_pipeline = '1' then
            opd_source_reg <= "00";
        elsif(rising_edge(clk)) then
            if(stall_fetch_stage = '0' and mode_reg = from_translate) then
                if (is_switch_instr_start_w='1') then
                    opd_source_reg <= "10";
                elsif(opd_reg(0) = '0' and opd_1(0) = '1') then
                    opd_source_reg <= (instr_buf_ctrl_reg(0) and complex_1) & not instr_buf_ctrl_reg(0);
                else
                    opd_source_reg <= not instr_buf_ctrl_reg(0) & instr_buf_ctrl_reg(0);
                end if;
            end if;
        end if;
    end process;
    
    branch_trigger <= branch_trigger_reg;
    
    -- need simplified, cause only inst1 can be branch instruction
    branch_addr_ctrl :
    process(clk, Rst)
        variable br_addr1            : std_logic_vector(15 downto 0);
        variable br_addr2            : std_logic_vector(15 downto 0);
        variable br_addr3            : std_logic_vector(15 downto 0);
        variable br_semicode1        : std_logic_vector(15 downto 0); --  
        variable br_semicode2        : std_logic_vector(15 downto 0); --  
        variable jpc_reg_tmp1        : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
        variable jpc_reg_tmp2        : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
    begin
        
        if(Rst = '1')or xcptn_flush_pipeline = '1' then
            branch_trigger_reg <= (others => '0');
        elsif(rising_edge(clk)) then
            jpc_reg_tmp1 := jpc_reg -  '1';
            jpc_reg_tmp2 := jpc_reg - "10";
            br_addr1     := jpc_reg_tmp1 & '0';
            br_addr3     := jpc_reg_tmp1 & '1';
            br_addr2     := jpc_reg_tmp2 & '1';
            if(instr_buf_ctrl_reg(0) = '0') then -- 00 10
                br_semicode1 := br_addr1;
                br_semicode2 := br_addr3;
            else                                 -- 01
                br_semicode1 := br_addr2;
                br_semicode2 := br_addr1;
            end if;
            -- for chipscope debug
            --debug_cs_fetch (19 downto 8) <=      br_semicode1 (11 downto 0); 
            --debug_cs_fetch (31 downto 20) <=   br_semicode2 (11 downto 0);
            if(stall_fetch_stage = '0' and mode_reg = from_translate) then
                -- modified by T.H.Wu , 2013.8.19 , for changing logic to determine branch destination of each related bytecode
                if(complex_1 = '1') then 
                    if(semi_code1(7 downto 4) = x"C" and opd_1 = x"F") then-- invokeinterface                       
                        branch_trigger_reg <= br_semicode1 + "101";
                    elsif (semi_code1(7 downto 4) = x"D" or semi_code1(7 downto 4) = x"B" or semi_code1(7 downto 4) = x"A") then -- invokevirtual 
                        branch_trigger_reg <= br_semicode1 + "011";          
                    else
                        branch_trigger_reg <= br_semicode1 ;                        
                    end if;
                else
                --elsif(complex_2 = '1') then 
                    if(semi_code2(7 downto 4) = x"C" and opd_2 = x"F") then -- invokeinterface
                        branch_trigger_reg <= br_semicode2 + "101";
                    elsif(semi_code2(7 downto 4) = x"D" or semi_code2(7 downto 4) = x"B" or semi_code2(7 downto 4) = x"A")then  -- invokevirtual 
                        branch_trigger_reg <= br_semicode2 + "011";    
                    else
                        branch_trigger_reg <= br_semicode2 ;                        
                    end if;
                --else -- condition branch & goto
                --    branch_trigger_reg <= br_semicode1;
                end if;
                --
		-- by fox ,
        -- usage ?? why don't we use branch_trigger_reg instead of TH_mgt_thread_trigger ?? 2013.7.16
		if(opd_reg(1 downto 0) = "11") then
			TH_mgt_thread_trigger	<= br_semicode1 + "010";
		elsif(opd_reg(0) = '0') then	
			TH_mgt_thread_trigger	<= br_semicode1;
		else
			TH_mgt_thread_trigger	<= br_semicode2;
		end if;
                --
            end if;
        end if;
    end process;

    -- might be bug in complex-complex combination
    u_code_ctrl : -- by fox
    process(mode_reg, complex_1, complex_2, nxt, branch, opd_reg, invoke_sync_mthd_flag_dly,
                TH_mgt_new_thread_execute, TH_mgt_reset_mode,switch_instr_branch_reg) begin
        if(mode_reg = from_translate) then
            if ((complex_1 or (complex_2 and opd_reg(0))) = '1' or TH_mgt_new_thread_execute='1')then -- by fox
                mode <= from_ROM;
            else
                mode <= from_translate;
            end if;
        else -- what do reset mode and simple mode mean in  thread manager ?? 2013.7.16
            if(((nxt or branch) = '1' and switch_instr_branch_reg='0' and invoke_sync_mthd_flag_dly='0') or TH_mgt_reset_mode='1') then -- by fox
                mode <= from_translate;
            else
                mode <= from_ROM;
            end if;
        end if;
    end process;
    
    ucodeaddr_semicode <= semi_code1 when (complex_1 = '1') else semi_code2 ;
	--fox
    -- for skip switch padding bytes
    ucodeaddr_tmp   <=  ucodeaddr_semicode + 1 when(is_switch_instr_start_w = '1' and (instr_buf_ctrl_reg(0) = jpc_reg(0))) else  
                                        ucodeaddr_semicode;
    
    -- special case ??
    ucode_addr <=			x"FF"	when set_ucodePC = '1' or TH_mgt_reset_mode='1' -- by fox
                            -- by fox , modified by T.H.Wu , 2013.7.16 , for
                            -- might be a problem , j-code of starting a new thread is part of invokevirtual ??
                    else    x"D9"	when TH_mgt_new_thread_execute = '1' --modify by Jeff for GC
                    else	pc      when(stall_fetch_stage = '1')
					else    x"93"	when invoke_sync_mthd_flag_dly='1'	-- for invoking sync method. 2014.2.6, this will be modified if we find out better way to change address of ROM
					else	x"98"	when rtn_frm_sync_mthd_flag='1' 	-- for returning sync method. critical path, the hardest part
                    else	ucodeaddr_tmp	when (mode_reg = from_translate and mode = from_ROM)
					else	x"B9"	when(CTRL_state = ClinitRetFrm1) -- for clinit
					else    pc - "011"   when switch_instr_revert_code_seq = '1' -- for lookupswitch
                    else    pc + '1' ;

    u_code_reg_ctrl :
    process(clk, Rst) begin
        if(Rst = '1' or xcptn_flush_pipeline = '1' ) then
            mode_reg <= from_translate;
            pc       <= (others => '0');
            nxt_reg  <= '0';
			jcode_addr_restore_for_rtn_sync_mthd <= (others=>'0');
			rtn_frm_sync_mthd_flag_dly		<=	'0';
			rtn_frm_sync_mthd_active_hold	<=	'0';
        elsif(rising_edge(clk)) then
            if(mode = from_ROM) then
                -- modified by T.H.Wu , 2014.1.23, for returning from sync method.
				if(rtn_frm_sync_mthd_active_hold='1' and COOR_cmd_cmplt_reg='1') then 
					pc	<=	jcode_addr_restore_for_rtn_sync_mthd ;
				else
					pc	<=	ucode_addr; 
				end if;       
            end if;
			--
            if((branch = '1' and switch_instr_branch_reg='0') or TH_mgt_reset_mode='1') then -- fox
                mode_reg <= from_translate;
            elsif(stall_fetch_stage = '0') then
                mode_reg <= mode;
            end if;
			--
            if(stall_fetch_stage = '0') then
                if(mode_reg = from_ROM) then
                    nxt_reg  <= nxt;
				elsif(is_switch_instr_start_reg = '1' and branch = '1') then   --fox
                    nxt_reg <= '1';	
                else
                    nxt_reg  <= '0';
                end if;
            end if;
			-- modified by T.H.Wu , 2014.1.23, for returning from sync method.
			if(rtn_frm_sync_mthd_flag='1') then
				jcode_addr_restore_for_rtn_sync_mthd <= pc;
			end if;
			--
			rtn_frm_sync_mthd_flag_dly	<=	rtn_frm_sync_mthd_flag;
			--
			if(rtn_frm_sync_mthd_flag_dly='1') then
				rtn_frm_sync_mthd_active_hold	<=	'1';
			elsif(COOR_cmd_cmplt_reg='1') then
				rtn_frm_sync_mthd_active_hold	<=	'0';
			end if;
        end if;
    end process;
    
    instrs_pkg <= instrs_pkg_w;
     instrs_pkg_w <=    x"FFFF"     when TH_mgt_context_switch = '1' else -- by fox
    --instrs_pkg_w <=    x"FFFF"     when Disable_semicode_during_context_switch = '1' else -- modified by T.H.Wu , 2013.7.25
                                    semitranslated_code_reg when mode_reg = from_translate else
                                    ROM_instr;
	 
    -- for next instr is normal or nop
    semitranslated_code_reg_ctrl :
    process(clk, Rst, xcptn_flush_pipeline, TH_mgt_context_switch) begin
        if(Rst = '1') or xcptn_flush_pipeline = '1' or TH_mgt_context_switch = '1'  then -- by fox , is it essential ?
            semitranslated_code_reg <= (others => '1');
        elsif(rising_edge(clk)) then
            if(stall_fetch_stage = '0') then
                if((complex_1 or opd_reg(0) or branch) = '1') then
                        if(is_switch_instr_start_reg = '1') then   --fox
                            semitranslated_code_reg(15 downto 8) <= x"78";
                        else
                            semitranslated_code_reg(15 downto 8) <= x"FF";
                        end if;
                else
                    semitranslated_code_reg(15 downto 8) <= semi_code1;
                end if;
                -- modifed by T.H. Wu , 2013.8.22 , reducing the logic for fetching specail-type opcode (at bytecode level)
                --if((opd_reg(1) or complex_2 or hazard_structure or special_2 or (not opd_reg(0) and opd_1(0)) or branch) = '1') then
                if((opd_reg(1) or complex_2 or hazard_structure or (not opd_reg(0) and opd_1(0)) or branch) = '1') then
                    semitranslated_code_reg( 7 downto 0) <= x"FF";
                else
                    semitranslated_code_reg( 7 downto 0) <= semi_code2;
                end if;
            end if;
        end if;
    end process;
	
     ------------------------------------------------- start of jaip profiler -----------------------------------------------------------
      label_enable_jaip_profiler_4 : if ENABLE_JAIP_PROFILER = 1 generate
      process(clk, Rst, xcptn_flush_pipeline, TH_mgt_context_switch) begin
        if(Rst = '1') or xcptn_flush_pipeline = '1' or TH_mgt_context_switch = '1'  then -- by fox , is it essential ?
		prof_simple_issued_A_reg <= '0';
		prof_simple_issued_B_reg <= '0';
        elsif(rising_edge(clk)) then
            if(stall_fetch_stage = '0') then
                if((complex_1 or opd_reg(0) or branch) = '1') then
                                    -------------------------- start of jaip profiler -------------------------
                                    --label_enable_jaip_profiler_0 : if ENABLE_JAIP_PROFILER = 1 generate
					prof_simple_issued_A_reg <= '0';
					if(mode_reg = from_translate and complex_1 = '1' and branch = '0') then
						prof_simple_issued_A_reg <= '1';
					else
						prof_simple_issued_A_reg <= '0';
					end if;
                                    --end generate;
                else
                                    -------------------------- start of jaip profiler -------------------------
                                    --label_enable_jaip_profiler_1 : if ENABLE_JAIP_PROFILER = 1 generate
					if(mode = from_translate) then
						prof_simple_issued_A_reg <= '1';
					else
						prof_simple_issued_A_reg <= '0';
					end if;
                                    --end generate;
                end if;
                -- modifed by T.H. Wu , 2013.8.22 , reducing the logic for fetching specail-type opcode (at bytecode level)
               -- if((opd_reg(1) or complex_2 or hazard_structure or special_2 or (not opd_reg(0) and opd_1(0)) or branch) = '1') then
                if((opd_reg(1) or complex_2 or hazard_structure or (not opd_reg(0) and opd_1(0)) or branch) = '1') then
                                    -------------------------- start of jaip profiler -------------------------
                                    --label_enable_jaip_profiler_2 : if ENABLE_JAIP_PROFILER = 1 generate
					prof_simple_issued_B_reg <= '0';
					if(mode_reg = from_translate and complex_2 = '1' and opd_reg(0) = '1'  and branch = '0') then
						prof_simple_issued_B_reg <= '1';
					else
						prof_simple_issued_B_reg <= '0';
					end if;
                                    --end generate;
                else
                                    -------------------------- start of jaip profiler -------------------------
                                    --label_enable_jaip_profiler_3 : if ENABLE_JAIP_PROFILER = 1 generate
					if(mode = from_translate) then
						prof_simple_issued_B_reg <= '1';
					else
						prof_simple_issued_B_reg <= '0';
					end if;
                                    --end generate;
                end if;
            end if;
        end if;
    end process;
    
	process(Clk, Rst) begin
		if(Rst = '1') then
			prof_complex_issued_reg <= '0';
		elsif(rising_edge(Clk)) then
			if(mode_reg = from_translate and mode = from_ROM and branch = '0') then
				prof_complex_issued_reg <= '1';
			else
				prof_complex_issued_reg <= '0';
			end if;
			if(stall_fetch_stage = '0') then
				prof_issued_bytecodes <= prof_issued_bytecodes_T;
			end if;
		end if;
	end process;
	
	prof_issued_bytecodes_F <= prof_issued_bytecodes;
	
    prof_simple_issued_A <= prof_simple_issued_A_reg when(nop_1_tmp = '0') else
							'0';
	prof_simple_issued_B <= prof_simple_issued_B_reg when(nop_2_tmp = '0') else
							'0';
	prof_complex_issued <= prof_complex_issued_reg;
    end generate;
    ----------------------------------------------- end of jaip profiler ---------------------------------------------------
	
    -- for immediate nop
    nop_ctrl :
    process(stall_fetch_stage, branch, nxt_reg, mode_reg, switch_instr_branch_reg) begin
        if(((stall_fetch_stage or branch) = '1' or (nxt_reg = '1' and mode_reg = from_translate)) and switch_instr_branch_reg='0' ) then
            nop_1_tmp <='1';
            nop_2_tmp <='1';
        else
            nop_1_tmp <='0';
            nop_2_tmp <='0';
        end if; 
    end process;
	nop_1 <= nop_1_tmp;
	nop_2 <= nop_2_tmp;

    -- modified J-code ROM by T.H.Wu , 2013.8.14 , for removing special J-code
    u_code_ROM : RAMB16_S18
    generic map(
        INIT_00 =>
                   --   ineg end    --
                   x"0088" &      -- x"0F" =>  idimm_0  isub_reverse 
                   --   ineg start    --
                   --   pop2    end --
                   x"7878" &      -- x"0E" => 
                   --   pop2    start --
                   x"C1F5" &      -- x"0D" =>  --if_acmpne    => if_cmpne
                   x"C0F5" &      -- x"0C" =>  --if_acmpeq    => if_cmpeq
                   x"C5F5" &      -- x"0B" =>  --if_icmple    => if_cmple
                   x"C4F5" &      -- x"0A" =>  --if_icmpgt    => if_cmpgt
                   x"C3F5" &      -- x"09" =>   --if_icmpge    => if_cmpge
                   x"C2F5" &      -- x"08" =>   --if_icmplt    => if_cmplt
                   x"C1F5" &      -- x"07" =>   --if_icmpne    => if_cmpne
                   x"C0F5" &      -- x"06" =>   --if_icmpeq    => if_cmpeq
                   x"CDF5" &      -- x"05" =>   --ifle
                   x"CCF5" &      -- x"04" =>   --ifgt
                   x"CBF5" &      -- x"03" =>   --ifge
                   x"CAF5" &      -- x"02" =>   --iflt
                   x"C9F5" &      -- x"01" =>   --ifne
                   x"C8F5",       -- x"00" =>   --ifeq     

        INIT_01 => 
                    --   newarray     end --
                   X"78F6" &      -- X"1F" =>
                   X"FFF5" &      -- X"1E" =>
                   X"20DF" &      -- X"1D" =>
                   --   newarray    start -- 
                   --   anewarray end   --
		   X"78FF" &      -- X"1C" =>
                   X"FFF6" &      -- X"1B" =>                         Normal
                   X"34DF" &      -- X"1A" =>    ldc_load        get_L1_XRT_ref
                   X"FFF5" &      -- X"19" =>                         Normal
                   X"FFE4" &      -- X"18" =>    nop          ldc
                   --   anewarray start -- 
                   --     ldc_w ldc2_w end     -- ... it is wried , why triggering 2nd  DSRU ? 2013.8.14
                   X"FFEC" &      -- X"17" => 
                   X"34F6" &      -- X"16" =>    ldc_load, nop        Normal 
                                          --                   Get_LV1_XRT_ref
                   X"F5F5" &      -- X"15" =>    Normal         
                   X"FFEC" &      -- X"14" =>    nop,  *new* 
                   --     ldc_w ldc2_w start     --
                   --     ldc end     --
                   X"FFF6" &      -- X"13" =>    nop, nop
                   X"34F6" &      -- X"12" =>    ldc_load, nop        Normal 
                   X"FFF5" &      -- X"11" =>                                 Get_LV1_XRT_ref 
                   X"FFEE" ,      -- X"10" =>    nop,  ldc               Normal 
                   --     ldc start     --

        INIT_02 =>  
                   --   arraylength     start -- ... modified by T.H.Wu  2013.8.16
                   X"D8F6" &      -- X"2F" =>   refload
                   X"0CF5" &      -- X"2E" =>   ldimm_12 
                   --   arraylength     start --
                   --   iinc          end --
                   x"8450" &      -- x"2D" =>  iadd   stval_opd
                   x"1021" &      -- x"2C" =>  ldval_opd ldopd<1>
                   --   iinc        start --
                   --   putstatic end   --
                   X"78F7" &     -- X"2B" =>     pop  Normal
                                  --                                  Offset_access
                                  --                                  Lower_addr
                                  --                                  Up_address
                   X"FFF6" &      -- X"2A" =>                           Get_entry2
                   X"FFF5" &      -- X"29" =>                         Get_entry 
                   X"FFEB" &      -- X"28" =>               putstatic
                   --   putstatic start   --
		   --   getfield end   --     
                   X"FFF7" &      -- X"27" =>             Field_load
                                  --                                  Offset_access
                                  --                                  Lower_addr
                                  --                                                       						
                   X"FFF6" &      -- X"26" =>                          
                   X"FFF5" &      -- X"25" =>                  Normal
                   X"FFE8" &      -- X"24" =>    nop        getfield
                   --   getfield start   --
		  --   getstatic end   --
                   X"FFF7" &      -- X"23" =>                         Normal
                                  --                                  Offset_access
                                  --                                  Lower_addr
                                  --                                  Up_address
                   X"FFF6" &      -- X"22" =>                         Get_entry2
                   X"FFF5" &      -- X"21" =>                         Get_entry 
                   X"00EA",       -- X"20" =>    ldopd2     getstatic
                   --   getstatic start   --
                   
        INIT_03 =>
                   X"FFFF" &      -- X"3F" =>
		   X"FFFF" &      -- X"3E" =>
                   X"FFFF" &      -- X"3D" =>
                   X"FFFF" &      -- X"3C" =>
                   X"FFFF" &      -- X"3B" =>
                   X"FFFF" &      -- X"3A" =>
                   X"FFFF" &      -- X"39" =>
                   X"FFFF" &      -- X"38" =>
                   X"FFFF" &      -- X"37" =>
		   X"FFFF" &      -- X"36" =>
                   X"FFFF" &      -- X"35" =>
                   X"FFFF" &      -- X"34" =>     
                   X"FFFF" &      -- X"33" =>     
                   X"FFFF" &      -- X"32" =>     
                   X"FFFF" &      -- X"31" =>     
                   X"FFFF" ,      -- X"30" =>     
                   
        INIT_04 => 
                   --   bastore end   --
                   X"7878" &      -- X"4F" =>    pop2
                   X"DEF5" &      -- X"4E" =>    ref_store_b
                   --  bastore  start --
                   --   sastore end   --
                   X"7878" &      -- X"4D" =>    pop2
                   X"DDF5" &      -- X"4C" =>    ref_store_s
                   --  sastore  start --
                   --   iastore end   --
                   X"7878" &      -- X"4B" =>    pop2
                   X"DCF5" &      -- X"4A" =>    ref_store_w
                   --  iastore  start --
                   --   putfield end   --
                   X"7878" &      -- X"49" =>    pop,        pop      Normal
                   X"FFF7" &      -- X"48" =>                         Field_store
                                  --                                  Offset_access
                                  --                                  Lower_addr
                                  --                                  Up_address
                   X"FFF6" &      -- X"47" =>                        Get_entry2
                   X"FFF5" &      -- X"46" =>                         Get_entry 
                   X"FFE9" &      -- X"45" =>    nop        putfield
                   --   putfield start   --
		   --   new      end  --
                   X"FFF6" &     -- X"44" =>
                   X"FFF5" &     -- X"43" =>              Normal
                                  --                                  Lower_addr
                                  --                                  Up_address
                   X"FFF6" &      -- X"42" =>            Get_entry2 
                   X"FFF5" &      -- X"41" =>    nop,      nop        Normal
                   X"28EC",       -- X"40" =>    ldopd2    new          
                   --   new     start --
                   
        INIT_05 => 
                   X"FFFF" &      -- X"5F" =>
                   X"FFFF" &      -- X"5E" =>
                   X"FFFF" &      -- X"5D" =>
                   X"FFFF" &      -- X"5C" =>
                   X"FFFF" &      -- X"5B" =>
                   X"FFFF" &      -- X"5A" =>
                   X"FFFF" &      -- X"59" =>
                   X"FFFF" &      -- X"58" =>
                   X"FFFF" &      -- X"57" =>
                   X"FFFF" &      -- X"56" =>
                   X"FFFF" &      -- X"55" =>
                   X"FFFF" &      -- X"54" =>
                   X"FFFF" &      -- X"53" =>
                   X"FFFF" &      -- X"52" =>    
                   X"FFFF" &      -- X"51" =>    
                   X"FFFF" ,      -- X"50" =>     
        INIT_06 =>
                   X"F1F5" &      -- X"6F" =>  -- goto
                   X"C9F5" &      -- X"6E" =>  -- ifnonnull
                   X"C8F5" &      -- X"6D" =>  -- ifnull
                   X"E7F5" &      -- X"6C" =>  -- athrow
                   --   tableswitch end --
                   X"F1FF" &      -- X"6B" =>   goto case 
                   X"78FF" &      -- X"6A" =>   pop nop
                   X"F1E0" &      -- X"69" =>   goto index_offset
                   X"CA10" &      -- X"68" =>   iflt
                   X"38FF" &      -- X"67" =>   dup 
                   X"CC10" &      -- X"66" =>   ifgt
                   X"2C87" &      -- X"65" =>   ldopd4 sub
                   X"F0D3" &      -- X"64" =>   swap stall_jpc                
                   X"2C87" &      -- X"63" =>   ldopd4 sub
                   X"38FF" &      -- X"62" =>   dup nop
                   X"E001" &      -- X"61" =>   switch  get_default_offset   
                   X"FFF5" ,      -- X"60" =>   nop for padding bytes
                   --   tableswitch start   --
                   
        INIT_07 =>
                   X"FFFF" &      -- X"7F" =>
                   X"FFFF" &      -- X"7E" =>
                   --   ireturn    end   --
                   X"FFF6" &      -- X"7D" =>    mem2reg_2
                   X"E6FF" &      -- X"7C" =>    mem2reg_1
                   X"DBE1" &      -- X"7B" =>    stjpc      return_off Offset_Ready
                   X"70FF" &      -- X"7A" =>    stvp                  Check_Offset
                   X"FFF5" &      -- X"79" =>                          Get_Offset
                   X"E5FF" &      -- X"78" =>    stsp_s                Wait_enable
                                          --                     C <= A
                   X"F3E3" &      -- X"77" =>    exchange    ireturn_on
                   --   ireturn  start   --
                   --   return    end   --
                   X"FFF6" &      -- X"76" =>    mem2reg_2
                   X"E6FF" &      -- X"75" =>    mem2reg_1
                   X"78E1" &      -- X"74" =>    pop                   Offset_Ready
                   X"DBFF" &      -- X"73" =>    stjpc     return_off  Check_Offset
                   X"70FF" &      -- X"72" =>    stvp                  Get_Offset
                   X"FFF5" &      -- X"71" =>                          Wait_enable
                   X"E5E2" ,      -- X"70" =>    stsp_s    return_on
                   --   return  start   --

        INIT_08 =>
                   X"FFFF" &      -- X"8F" =>    
                   X"FFFF" &      -- X"8E" =>    
                   X"FFFF" &      -- X"8D" =>    
                   X"FFFF" &      -- X"8C" =>    
                   X"FFFF" &      -- X"8B" => 
                   X"FFFF" &      -- X"8A" =>
                   --   lookupswitch end    --
                   X"F110" &      -- X"89" =>    goto default_offset
                   X"78FF" &      -- X"88" =>    pop nop 
                   X"C8FF" &      -- X"87" =>    ifqe
                   X"E003" &      -- X"86" =>    compute npair
                   X"2C87" &      -- X"85" =>    ldopd4 sub
                   X"38FF" &      -- X"84" =>    dup nop
                   X"E002" &      -- X"83" =>    get_npair
                   X"FFF6" &      -- X"82" =>    nop nop
                   X"E001" &      -- X"81" =>    switch_on  get_default_offset
                   X"FFF5",       -- X"80" =>
                   --   lookupswitch start  --
                    
        INIT_09 =>
                   X"FFFF" &      -- X"9F" =>    
                   X"FFFF" &      -- X"8E" =>    
                   X"FFFF" &      -- X"9D" =>    
                   X"FFFF" &      -- X"9C" =>
					-- monitorexit end, returning sync method end --
                   X"78F5" &      -- X"9B" =>
                   X"FFF6" &      -- X"9A" =>
                   X"F9F5" &      -- X"99" =>
                   --  monitorexit start --
                   X"18F5" &      -- X"98" => 
					-- returning sync method start --
                   X"FFF5" &      -- X"97" =>
                   X"FFF6" &      -- X"96" =>
					-- monitorenter end, invoking sync method end --  
                   X"78F5" &      -- X"95" => 
                   X"F8F5" &      -- X"94" => 
					-- monitorenter start --
                   X"18F5" &      -- X"93" =>
					-- invoking sync method start --  
		   --   multianewarray end    --
                   X"7878" &      -- X"92" =>    
                   X"EB0B" &      -- X"91" =>   
                   X"22F5",       -- X"90" =>
                   --   multianewarray start  --
                   
        INIT_0A => 
				   X"FFFF" &      -- X"AF" =>
                   X"FFFF" &      -- X"AE" =>
                   X"FFFF" &      -- X"AD" =>
                   X"FFFF" &      -- X"AC" =>
                   X"FFFF" &      -- X"AB" =>
                   X"FFFF" &      -- X"AA" =>
				   X"FFFF" & 
                   --   invokestatic     end    --
                   X"FFFF" &      -- X"A8" =>    mem2reg_2           Method_exit
                   X"E6FF" &      -- X"A7" =>    mem2reg_1           max_local
                   X"FFFF" &      -- X"A6" =>                        max_stack
                   X"FFFF" &      -- X"A5" =>                        arg_size                 Native_exit
                   X"FFFF" &      -- X"A4" =>                        Method_flag              Native_StackAdjusting1
                   X"FFFF" &      -- X"A3" =>                        Method_entry             Native_SpAdjusting
                   X"FFFC" &      -- X"A2" =>                        Get_entry2
                   X"3031" &      -- X"A1" =>    ldjpc       ldvp    Normal
                   X"00EF",       -- X"A0" =>    ldimm_0     invoke static
                   --   invokestatic!!!!!!!

        INIT_0B => 
		 -- clinit end 
                   X"FFF6" &      -- X"BF" =>   Method_exit
                   X"E6F5" &      -- X"BE" =>   max_local
				   X"FFF6" &      -- X"BD" =>    max_stack
                   X"FFF5" &      -- X"BC" =>    arg_size
                   X"FFF6" &      -- X"BB" =>    Method_flag
                   X"FFF5" &      -- X"BA" =>    Method_entry
                                                                -- pipeline stall
                   --                                     ClinitRetFrm3
                   --                                     ClinitRetFrm2 
                   X"3031"&       -- X"B9" =>	  ClinitRetFrm1   -- modified by T.H.Wu , 2013.8.20 , a bug about clinit 
                   -- clinit start 
                   --   invokespecial   end    --
                   X"F6F5" &      -- X"B8" =>    mem2reg_2           Method_exit
                   X"E6F6" &      -- X"B7" =>    mem2reg_1           max_local
                   X"FFF5" &     -- X"B6" =>                         max_stack
                   X"FFF6" &     -- X"B5" =>                         arg_size                 Native_exit
                   X"FFF5" &      -- X"B4" =>                        Method_flag              Native_StackAdjusting1
                   X"FFF6" &      -- X"B3" =>                        Method_entry             Native_SpAdjusting
                                  --                                 Enable_MA_management
                                  --                                 IllegalOffset
                                  --                                 Offset_access
                                  --                                 Lower_addr 
                   X"FFFB" &      -- X"B2" =>    nop         nop     Get_entry
                   X"3031" &      -- X"B1" =>    ldjpc       ldvp    Normal
                   X"00EF",       -- X"B0" =>    ldimm_0     invoke static
                   --   invokespecial  start   --  !!!!!!!

        INIT_0C => 
                   X"F0F5" &      -- X"CF" => -- swap --
		   X"D1F5" &      -- X"CE" => -- dup2 --
                   X"D2F5" &      -- X"CD" => -- dup_x2 --
                   X"D0F5" &      -- X"CC" => -- dup_x1 --
                   X"D9F5" &      -- X"CB" => -- caload , saload --
                   X"DAF5" &      -- X"CA" => -- baload --
                   X"D8F5" &      -- X"C9" => -- iaload , aaload , laload , faload , daload --
                   --   invokeinterface end   --
                   X"FFF5" &      -- X"C8" =>    mem2reg_2           Method_exit
                   X"E6F6" &      -- X"C7" =>    mem2reg_1           max_local
                   X"FFF5" &      -- X"C6" =>    invokeinterface     max_stack
                   X"FFF6" &      -- X"C5" =>                        arg_size
                   X"FFF5" &      -- X"C4" =>                        Method_flag
                   X"FFF6" &      -- X"C3" =>                        Method_entry
                                  --                                 Enable_MA_management
                                  --                                 Offset_access
                                  --                                 ...
                                  --                                 invoke_objref_next
                                  --                                 invoke_objref_ListClsID
                                  --                                 Get_ObjClsID
                                  --                                 Lower_addr
                                  --                                 Get_ArgSize
                   X"FFFB" &      -- X"C2" =>                        
                   X"3031" &      -- X"C1" =>    ldimm_0,    ldjpc   Normal
                   X"00ED",       -- X"C0" =>    ldimm_0     invoke
                   --   invokeinterface start   --

        INIT_0D => X"FFFF" & --for GC
				   X"E6FF" &      -- X"DE" =>
                   X"FFFF" &      -- X"DD" =>
                   X"FFFF" &      -- X"DC" =>
                   X"FFFF" &      -- X"DB" =>  
                   X"FFFF" &      -- X"DA" =>    
                   X"FFFF" &      -- X"D9" =>--for GC
                   --   invokevirtual  end   --
                   X"FFFF" &      -- X"D8" =>    mem2reg_2           Method_exit
                   X"E6FF" &      -- X"D7" =>    mem2reg_1           max_local
                   X"FFFF" &      -- X"D6" =>    invokeinterface     max_stack
                   X"FFFF" &      -- X"D5" =>                        arg_size
                   X"FFFF" &      -- X"D4" =>                        Method_flag
                   X"FFFF" &      -- X"D3" =>                        Method_entry
                   X"FFFC" &      -- X"D2" =>                        Get_entry2
                   X"3031" &      -- X"D1" =>    ldimm_0,    ldjpc   Normal
                   X"00ED",       -- X"D0" =>    ldimm_0     invoke
                   --   invokevirtual  start   -- 
				   
        INIT_0E => 
                   X"FFFF" &      -- X"EF" =>    
                   X"FFFF" &      -- X"EE" =>    
                   X"FFFF" &      -- X"ED" =>    
                   X"FFFF" &      -- X"EC" =>    
                   X"FFFF" &      -- X"EB" => 
                   X"FFFF" &      -- X"EA" =>    
                   X"FFFF" &      -- X"E9" =>
                   X"FFFF" &      -- X"E8" =>
                   X"FFFF" &      -- X"E7" =>    
                   X"FFFF" &      -- X"E6" =>                   
                   X"FFFF" &      -- X"E5" =>    
                   X"FFFF" &      -- X"E4" =>    
                   X"FFFF" &      -- X"E3" =>                
                   X"FFFF" &      -- X"E2" =>    
                   X"FFFF" &      -- X"E1" =>    
                   X"FFFF",       -- X"E0" =>
        
        INIT_0F => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_10 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
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
        INIT_3F => X"0000000000000000000000000000000000000000000000000000000000000000",
        INITP_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INITP_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INITP_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INITP_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INITP_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INITP_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INITP_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
        INITP_07 => X"0000000000000000000000000000000000000000000000000000000000000000"
    )
    port map (
        ADDR(9 downto 8) => "00",
        ADDR(7 downto 0) => ucode_addr,
        DI  => (others => '0'),
        DIP => "00",
        DO  => ROM_instr,
        CLK => clk,
        EN  => '1',
        SSR => Rst,
        WE  => '0'
    );
 
        -- modified by T.H.Wu , 2013.8.14  
    TransAddr_ctrl :
    process(pc, rtn_frm_sync_mthd_active_hold) begin
        --  TransAddr LSB = 0 --
        case pc is 

            -- (0x58)   pop2
            -- when X"0B" => nxt <= '1';  -- pop       pop  -- modified by T.H.Wu, 2013.8.15 , for j-code sequence movement
            when X"0E" => nxt <= '1';  -- pop       pop 
            
            -- (0x84)   iinc
            --when X"0E" => nxt <= '1';  -- 2013.8.16 12:53
            when X"2D" => nxt <= '1';  
            
            --when X"10" => nxt <= '1';  -- ineg  -- modified by T.H.Wu, 2013.8.15 , for j-code sequence movement
            when X"0F" => nxt <= '1';  -- ineg
            
            --when X"15" => nxt <= '1';  -- ldc  -- modified by T.H.Wu, 2013.8.15 , for j-code sequence movement
            when X"13" => nxt <= '1';  -- ldc
            
            --when X"1B" => nxt <= '1';  -- ldc_w ldc2_w  -- modified by T.H.Wu, 2013.8.15 , for j-code sequence movement
            when X"17" => nxt <= '1';  -- ldc_w ldc2_w
            
            when X"1F" => nxt <= '1';  -- newarray
            
            when X"23" => nxt <= '1';  -- getstatic
            when X"2B" => nxt <= '1';  -- putstatic
            
            --when X"33" => nxt <= '1';  -- getfield -- 2013.8.16 10:54
            when X"27" => nxt <= '1';  -- getfield
            --when X"3C" => nxt <= '1';  -- putfield -- 2013.8.16 10:54
            when X"49" => nxt <= '1';  -- putfield
            
            when X"44" => nxt <= '1';  -- new
            
            --when X"4C" => nxt <= '1';  -- anewarray   -- modified by T.H.Wu, 2013.8.15 , for j-code sequence movement
            when X"1C" => nxt <= '1';  -- anewarray
            
            --when X"51" => nxt <= '1';  -- arraylength   -- 2013.8.16 12:53 
            when X"2F" => nxt <= '1';  -- arraylength
            
            --when X"55" => nxt <= '1';  -- iastore aastore   -- 2013.8.16 12:53 
            when X"4B" => nxt <= '1';  -- iastore aastore
           -- when X"59" => nxt <= '1';  -- sastore  castore -- 2013.8.16 12:53 
            when X"4D" => nxt <= '1';  -- sastore castore
           -- when X"5D" => nxt <= '1';  -- bastore    -- 2013.8.16 12:53 
            when X"4F" => nxt <= '1';  -- bastore  
             
		when X"6B" => nxt <= '1';  -- tableswitch

            when X"76" => nxt <= '1';  -- return
            --when X"7E" => nxt <= '1';  -- ireturn  dreturn freturn lreturn -- 2013.8.16 14:47 
            when X"7D" => nxt <= '1';  -- ireturn  dreturn freturn lreturn
	   when X"89" => nxt <= '1';  -- lookupswitch 
            when X"92" => nxt <= '1'; -- multinewarray 
            when X"95" => nxt <= '1'; -- monitorenter 
            when X"9B" => nxt <= not rtn_frm_sync_mthd_active_hold; -- monitorexit  
            
            when X"B8" => nxt <= '1';  --   invokespecial 
			
			when X"D8" => nxt <= '1';--invokevirtual --2014
            when X"A8" => nxt <= '1';--invokestatic --2014
			--when X"AF" => nxt <= '1';--for areturn --2014
			when X"DF" => nxt <= '1';--for GC --2014
			 
	   --when X"D6" => nxt <= '1';    -- clinit	   -- 2013.8.16 14:47 
	   when X"BF" => nxt <= '1';    -- clinit	  
        
          -------------------------------------------------------------------------------------------------
          -- 2013.8.19 17:33 
           when   x"0D" => nxt <= '1';  --if_acmpne    => if_cmpne
           when   x"0C" => nxt <= '1';  --if_acmpeq    => if_cmpeq
           when   x"0B" => nxt <= '1';  --if_icmple    => if_cmple
           when   x"0A" => nxt <= '1';  --if_icmpgt    => if_cmpgt
           when   x"09" => nxt <= '1';   --if_icmpge    => if_cmpge
           when   x"08" => nxt <= '1';   --if_icmplt    => if_cmplt
           when   x"07" => nxt <= '1';   --if_icmpne    => if_cmpne
           when   x"06" => nxt <= '1';   --if_icmpeq    => if_cmpeq
           when   x"05" => nxt <= '1';   --ifle
           when   x"04" => nxt <= '1';   --ifgt
           when   x"03" => nxt <= '1';   --ifge
           when   x"02" => nxt <= '1';   --iflt
           when   x"01" => nxt <= '1';   --ifne
           when   x"00" => nxt <= '1';   --ifeq   
                   
           when   X"6F" => nxt <= '1';  -- goto
           when   X"6E" => nxt <= '1';  -- ifnonnull
           when   X"6D" => nxt <= '1';  -- ifnull
           when   X"6C" => nxt <= '1';  -- athrow
                   
            when    X"CF" => nxt <= '1';  -- swap --
            when    X"CE" => nxt <= '1';  -- dup2 --
              when    X"CD" => nxt <= '1';  -- dup_x2 --
              when    X"CC" => nxt <= '1';  -- dup_x1 --
              when    X"CB" => nxt <= '1';   -- caload , saload --
              when    X"CA" => nxt <= '1';  -- baload --
              when    X"C9" => nxt <= '1';  -- iaload , aaload , laload , faload , daload -- 
            -- 2013.8.19 17:33 
            -------------------------------------------------------------------------------------------------
        
             when      X"C8" => nxt <= '1';  -- invokeinterface 
             
             -- this is essential , can not be deleted , 2013.8.14
            when X"FF" => nxt <= '1';  -- end 
       
            when others    => nxt <= '0';
        end case;
    end process;
    
    
	 -- fox , for thread management , 2013.7.11 
	process(clk) begin
            if(rising_edge(clk)) then
            if(Rst = '1' ) then
                 TH_mgt_clean_fetch <= '0';
                 TH_mgt_clean_decode <= '0'; 
                 Disable_semicode_during_context_switch <= '0';
            else
		TH_mgt_clean_fetch	<= TH_mgt_clean_pipeline;
                if(stall_fetch_stage = '0') then 
			TH_mgt_clean_decode <= TH_mgt_clean_fetch; 
		end if;
                -- modified by T.H.Wu , 2013.7.25
                if(TH_mgt_clean_fetch='1') then
                    Disable_semicode_during_context_switch <= '1';
                elsif (TH_mgt_context_switch='1') then
                    Disable_semicode_during_context_switch <= '0';
                end if;
            end if;
            end if;
	end process;
    
    
	
    --debug_cs_fetch (0) <= '1' when mode = from_ROM else '0' ;
    --debug_cs_fetch (1) <= '1' when mode_reg = from_ROM else '0' ;
    --debug_cs_fetch (2) <= nxt ;
    --debug_cs_fetch (10 downto 3) <=   ucode_addr (7 downto 0);
    --debug_cs_fetch (11) <= nxt_reg ;
    --debug_cs_fetch (12) <= rtn_frm_sync_mthd_active_hold ;
	
    --debug_cs_fetch (8) <= complex_2;
    --debug_cs_fetch (9) <= not_stall_jpc_signal;
    --debug_cs_fetch (10) <= invoke_flag;
    --debug_cs_fetch (11) <= nxt;
    --debug_cs_fetch (15 downto 12) <= opd_1 ;
    --debug_cs_fetch (19 downto 16) <= opd_2 ;
    --debug_cs_fetch (20) <= is_switch_instr_start_w;
    --debug_cs_fetch (21) <= is_switch_instr_start_reg;
    -- debug_cs_fetch (37 downto 22) <= branch_trigger_reg;
    -- debug_cs_fetch (45 downto 38) <= ucodeaddr_semicode;
    -- debug_cs_fetch (53 downto 46) <= ucodeaddr_tmp ;
    -- debug_cs_fetch (61 downto 54) <= ucode_addr;
    -- debug_cs_fetch (62) <= nxt_reg;
    -- debug_cs_fetch (63) <= branch;
    -- debug_cs_fetch (65 downto 64) <= opd_source_reg;
    -- debug_cs_fetch (66) <= switch_instr_branch_reg;
    -- debug_cs_fetch (67) <= stall_jpc_for_switch_instr;

end architecture rtl;