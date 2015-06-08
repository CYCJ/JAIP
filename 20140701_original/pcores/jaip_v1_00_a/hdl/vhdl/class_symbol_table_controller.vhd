------------------------------------------------------------------------------
-- Filename     :       MethodArea_management.vhd
-- Version      :       3.00
-- Author       :       Han-Wen Kuo
-- Date         :       Feb 2011
-- VHDL Standard:       VHDL'93
-- Describe     :       New Architecture
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2011. All rights reserved.                              **        
-- ** Multimedia Embedded System Lab, NCTU.                                 **  
-- ** Department of Computer Science and Information engineering            **
-- ** National Chiao Tung University, Hsinchu 300, Taiwan                   **
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity class_symbol_table_controller is
    generic(
        RAMB_S18_AWIDTH             : integer := 10;
        METHOD_AREA_DDR_ADDRESS     : std_logic_vector(31 downto 0) := X"5A000000"
    );		
    port(
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        CST_checking_en             : in  std_logic;
        DR2CST_ctrlr_cls_id         : in  std_logic_vector(15 downto 0);
        A_23_16	                    : in  std_logic_vector(7 downto 0);
        B_23_16                     : in  std_logic_vector(7 downto 0);
        return_flag                 : in  std_logic;
        ireturn_flag                : in  std_logic;
		--check_mthd_id2MA            : out std_logic_vector (9 downto 0);
		CST_check_done              : out std_logic;
		-- to global_counter_logic
		--global_counter				: in  std_logic_vector(15 downto 0);
		-- external_loaded_buffer      : in  std_logic_vector(31 downto 0);  -- marked by T.H. Wu , 2013.6.20
        -- (slave) write from external part(power PC) to method_area_management
        CSTProfileTable_Wen         : in  std_logic;
        CSTProfileTable_idx         : in  std_logic_vector(15 downto 0);
        CSTProfileTable_di          : in  std_logic_vector(15 downto 0);
        -- (master) external memory access
        external_MstRd_CmdAck : in  std_logic; -- added by T.H. Wu , 2013.6.20 
        external_MstRd_burst_data_rdy : in std_logic; -- added by T.H. Wu , 2013.6.20 
        external_access_cmplt       : in  std_logic;
        --external_load_data          : in  std_logic_vector(31 downto 0);
        CSTLoading_req              : out std_logic;
        CSTLoading_ex_addr          : out std_logic_vector(31 downto 0);
		--trigger CTRL keep going
        CSTLoading_stall            : out std_logic;
		-- method area signals
		MA_checking_done			: in  std_logic; 	
        -- CST ctrlr to buffer signals
        CST_ctrlr2buffer_wen        : out std_logic;
        CST_ctrlr2buffer_addr       : out std_logic_vector(11 downto 0);  
       -- CST_ctrlt2buffer_data       : out std_logic_vector(31 downto 0); -- marked by T.H. Wu , 2013.6.20
        CST_ctrlr2buffer_block_base : out std_logic_vector( 4 downto 0);
        -- 
        cls_id 	      	            : out std_logic_vector(15 downto 0);
		-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
		rtn_frm_sync_mthd_flag		: in	std_logic;
		sync_mthd_invoke_rtn_cmplt	: in	std_logic;
		-- xcptn hdlr
		ret_frm_regs_wen		    : in  std_logic;    
        get_parent_EID		        : in  std_logic;    
		ret_frm_cls_id				: in  std_logic_vector(15 downto 0);  
		compared_EID                : in  std_logic_vector(15 downto 0);
        CST_FSM_Check_offset        : out std_logic;
		parent_EID                  : out std_logic_vector(15 downto 0);
        -- debug
        debug_cs_CSTctrl      : out  std_logic_vector  (35 downto 0);
        debug_flag                  : in  std_logic_vector(31 downto 0);
        debug_addr                  : in  std_logic_vector(31 downto 0);
        debug_data                  : out std_logic_vector(31 downto 0)
    );
end entity class_symbol_table_controller;

architecture rtl of class_symbol_table_controller is 
    signal CST_CTRL_state            : CST_Controller_SM_TYPE;  
    signal next_CST_CTRL_state       : CST_Controller_SM_TYPE; 	

    signal ADDRA                    : std_logic_vector( 9 downto 0);
    signal DOA                      : std_logic_vector(15 downto 0);  
    signal DIA                      : std_logic_vector(15 downto 0); 
    signal WEA                      : std_logic;    
    signal ADDRB                    : std_logic_vector( 9 downto 0);
    signal DOB                      : std_logic_vector(15 downto 0);
    signal DIB                      : std_logic_vector(15 downto 0); 
    signal WEB                      : std_logic;
    
    signal malloc                   : std_logic_vector( 4 downto 0);
    signal malloc_tmp               : std_logic_vector( 4 downto 0);
    signal select_reg               : std_logic_vector( 4 downto 0);	   	   
    signal loading_offset           : std_logic_vector(15 downto 0);	
    signal loading_size             : std_logic_vector(15 downto 0);
    signal cnt                      : std_logic_vector(15 downto 0);     	
    signal CSTProfileTable_update   : std_logic;  
    signal data_reg1                : std_logic_vector(15 downto 0);  
    signal data_reg2                : std_logic_vector(15 downto 0); 
    
    signal now_cls_id               : std_logic_vector(15 downto 0);
    signal new_cls_id               : std_logic_vector( 7 downto 0);
    signal return_cls_id            : std_logic_vector( 7 downto 0);
    signal data_select              : std_logic_vector( 1 downto 0);
    signal over_write_cls_id        : std_logic_vector( 7 downto 0);
    signal ResidenceTable_Wen       : std_logic;
    
    signal CSTLoading_req_tmp       : std_logic;
    signal CSTLoading_ex_addr_tmp   : std_logic_vector(31 downto 0);
    
    signal CST_not_cached           : std_logic;
    
    type ResidenceTable_file is array (integer range 31 downto 0) of std_logic_vector(7 downto 0);
    signal ResidenceTable : ResidenceTable_file;
    signal CMreg_first_round        : std_logic;
    
    signal debug_MA_flag            : std_logic_vector(31 downto 0);
	
	signal CST_loading_done         : std_logic;
    
    -- added by T.H. Wu , 2013.6.20
    signal mst_burst_rd_addr_offset     :  std_logic_vector(15 downto 0);
    signal mst_burst_rd_addr_offset_w :  std_logic_vector(15 downto 0);
    -- added by T.H. Wu , for returning sync method , 2014.1.22
	signal	rtn_frm_sync_mthd_flag_dly	: 	std_logic;
	
        -- modified by T.H.Wu , 2013.9.4 , for multicore and synchonization issue
     signal   RISC2CST_LUT_we_sync         : std_logic;
     signal   RISC2CST_LUT_we_hold         : std_logic;
     signal   RISC2CST_LUT_we_hold_w     : std_logic;
      signal  RISC2CST_LUT_addr_hold     : std_logic_vector(15 downto 0);
      signal  RISC2CST_LUT_addr_hold_w : std_logic_vector(15 downto 0);
      signal  RISC2CST_LUT_di_hold         : std_logic_vector(15 downto 0);
      signal  RISC2CST_LUT_di_hold_w     : std_logic_vector(15 downto 0);
    -- for chipscope debug
    signal debug_CST_state : std_logic_vector( 3 downto 0);
    
    
    begin   
	
    
    -- (master) external memory access
    CSTLoading_req     <= CSTLoading_req_tmp;
    -- modified by T.H.Wu , for fixing the bug about loading method image from DDR ram to CST buffer , 2013.7.24 
    CSTLoading_req_tmp <= '1' when CST_CTRL_state = Wait_Ack 
                                                            --or 
                                                            --CST_CTRL_state = WAIT_RD_VALID or
                                                            --CST_CTRL_state = WR_2_CSTCB 
                                          else  '0';
    
    CSTLoading_ex_addr     <= CSTLoading_ex_addr_tmp;
    CSTLoading_ex_addr_tmp <= METHOD_AREA_DDR_ADDRESS + loading_offset + mst_burst_rd_addr_offset;
    -- CSTLoading_ex_addr_tmp <= METHOD_AREA_DDR_ADDRESS + loading_offset + global_counter; --  modified by T.H. Wu , 2013.6.20
    
    -- to CST buffer
    CST_ctrlr2buffer_wen  <= '1' when CST_CTRL_state = WR_2_CSTCB else 
                            '0';
    CST_ctrlr2buffer_addr <= mst_burst_rd_addr_offset(13 downto 2) when CST_CTRL_state = WR_2_CSTCB else     x"000";
     -- marked by T.H. Wu , 2013.6.20
    --CST_ctrlr2buffer_addr <= global_counter(13 downto 2) when CST_CTRL_state = WR_2_CSTCB else     x"000";
    --CST_ctrlt2buffer_data <= external_loaded_buffer when CST_CTRL_state = WR_2_CSTCB else
    --	                     X"00000000";
    
    cls_id <= now_cls_id ;
    
    --???? return??
    CSTLoading_stall <= not return_flag when (CST_CTRL_state = Wait_enable and CST_checking_en = '1') or
                                              CST_CTRL_state = Get_Offset or CST_CTRL_state = Check_Offset  else 
                        '1'             when CST_CTRL_state = CST_Loading or CST_CTRL_state = Wait_Ack or
                                              CST_CTRL_state = WR_2_CSTCB or CST_CTRL_state = WAIT_RD_VALID or
                                             CST_CTRL_state = WAIT_MST_RD_CMPLT or
                                             CST_CTRL_state = Update or CST_CTRL_state = Offset_Ready  else        
                        '0' ;
						
					  
    --CST_check_done
    CST_check_done <= '1' when CST_CTRL_state = Check_Offset and CST_not_cached = '0' else
	                  CST_loading_done ; 
					  
    --xcptn
	CST_FSM_Check_offset <= '1' when CST_CTRL_state = Check_Offset else
	                        '0' ; 
    
    next_CST_CTRL_state_CtrlLogic :
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
        	CST_CTRL_state      <= Wait_enable;
        else
            case CST_CTRL_state is
              	
                when Wait_enable =>
                    if (CST_checking_en = '1' ) then
                        CST_CTRL_state <= Get_Offset ; 
                    else 
                        CST_CTRL_state <= Wait_enable ;  
                    end if ;	
                
                when Get_Offset =>
					-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
					if(rtn_frm_sync_mthd_flag_dly='1') then
						CST_CTRL_state     <= Wait_monExit_cmplt;
					else
						CST_CTRL_state     <= Check_Offset ; 
					end if;
                
                when Check_Offset =>
                    if(CST_not_cached = '1') then
                        CST_CTRL_state <= CST_Loading;
                    else
                        CST_CTRL_state <= Offset_Ready;
                    end if;
                
                when Offset_Ready =>               	        	                 	
                    CST_CTRL_state     <= Wait_enable;
                
                -----------------------------------------------------------------------------------------
                -- modified the rest of state controller of CST for burst mode transfer , 2013.6.20
                -----------------------------------------------------------------------------------------
                when CST_Loading => 
                        if(mst_burst_rd_addr_offset >= loading_size) then
                            CST_CTRL_state <= Update;
                        else  
                             CST_CTRL_state <= Wait_Ack;
                        end if; 
                
                when Wait_Ack =>  
                    --if (external_access_cmplt = '1') then 	           	
                    if (external_MstRd_CmdAck = '1') then     	           	
                        CST_CTRL_state <= WAIT_RD_VALID;                  	
                    else
                        CST_CTRL_state <= Wait_Ack;   
                    end if ;
                
                when WAIT_RD_VALID =>
                        if(external_MstRd_burst_data_rdy='0' ) then
                            CST_CTRL_state <= WR_2_CSTCB;
                         end if;
                
                when WR_2_CSTCB => 
                        if(mst_burst_rd_addr_offset >= loading_size or external_MstRd_burst_data_rdy='1') then
                            CST_CTRL_state <= WAIT_MST_RD_CMPLT ;
                         end if;
                 when  WAIT_MST_RD_CMPLT =>
                        if ( external_access_cmplt = '1' ) then
                                CST_CTRL_state <= CST_Loading;
                        end if;
                
                when Update =>
                    CST_CTRL_state     <= Offset_Ready;
				-- modified by T.H.Wu , 2014.1.22, for returning from sync method.
				-- it might cause a problem, if loading caller method is needed, meanwhile the stall flag for monitor
				-- still has not deactivated
				when Wait_monExit_cmplt  =>
					if( sync_mthd_invoke_rtn_cmplt = '1') then
						CST_CTRL_state     <=  Check_Offset;
					end if;
					
                when others => null ;
            end case;
        end if;
        end if;
    end process;

    CST_ctrlr2buffer_block_base  <= malloc     when CST_CTRL_state = WR_2_CSTCB else              
                                    select_reg;
    
    --malloc_tmp       <= malloc + global_counter(12 downto 8); 
    malloc_tmp       <= malloc + mst_burst_rd_addr_offset(12 downto 8); 
    --!! cnt is the counts of n bytes
    
    reg_CtrlUnit :
    process(clk)  begin
		if(rising_edge(clk)) then 
        if(Rst = '1') then
            select_reg         <= (others => '0');
            malloc             <= "00001";     
            --data_reg1          <= (others => '0');
            --data_reg2          <= (others => '0');
            --cnt                <= (others => '0');
            loading_offset     <= (others => '0');
            loading_size       <= (others => '0');
            over_write_cls_id  <= (others => '0');
            ResidenceTable_Wen <= '0';
            now_cls_id         <= (others => '0');
            CST_not_cached     <= '0';
            CMreg_first_round  <= '1';
			CST_loading_done   <= '0';
            mst_burst_rd_addr_offset <= (others => '0');
            RISC2CST_LUT_we_hold <= '0';
            RISC2CST_LUT_addr_hold  <=   (others => '0');
            RISC2CST_LUT_di_hold      <=   (others => '0');
			rtn_frm_sync_mthd_flag_dly<=	'0';
        else       	  
			case CST_CTRL_state is
				when Wait_enable =>
					if (CST_checking_en = '1' ) then
						CST_loading_done <= '0';
					end if ;
					
					if ret_frm_regs_wen = '1' then
						now_cls_id <= ret_frm_cls_id;
					end if; 
					
				when Get_Offset =>		--BLOCK INDEX
					select_reg        <= DOA(4 downto 0) ;
					CST_not_cached    <= DOA(5);
					loading_offset    <= DOB ;
					now_cls_id        <= x"00" & ADDRA(9 downto 2);

				when Check_Offset =>
					loading_size      <= DOA ; 
					--cnt               <= X"0000" ;
					
				when CST_Loading => 
					select_reg        <= malloc;


				when Update =>   	
					malloc            <= malloc_tmp + '1' ;-- malloc + cnt(15 downto 11)+'1';
				
				-- modified by C.C.H.	
				when Offset_Ready =>	
					CST_loading_done  <= '1';
				when others => null ;
											
			end case;      
                             
            
            if (CST_CTRL_state = Check_Offset or CST_CTRL_state = WR_2_CSTCB) then   
                over_write_cls_id <= ResidenceTable(to_integer(unsigned(malloc_tmp)));
            end if;
            
            -- ResidenceTable_Wen 2013.6.28
            if (CST_CTRL_state = CST_Loading and over_write_cls_id /= now_cls_id) then  
            --if ((CST_CTRL_state = WR_2_CSTCB  or CST_CTRL_state = CST_Loading) and over_write_cls_id /= now_cls_id) then  
                ResidenceTable_Wen <= '1' ;
            else
                ResidenceTable_Wen <= '0';
            end if;
            
            -- 2013.7.5 , there's a serious problem, malloc can not be updated immediately in some case 
            --if(malloc = "00000") then
            if(malloc_tmp = "00000") then -- modified by T.H.Wu , 2013.7.2 , but useless now 
            --if(malloc = "11111") then -- by fox , C.C.Hsu , 2013.8.13 , for XML parser execution
                CMreg_first_round <= '0' ;
            end if;
            
            mst_burst_rd_addr_offset <= mst_burst_rd_addr_offset_w ;
            -- added by T.H.Wu , 2013.9.4
            -- write to CST controller lokkup table , and considering synchronization issue
            RISC2CST_LUT_we_hold <= RISC2CST_LUT_we_hold_w;
            RISC2CST_LUT_addr_hold  <=  RISC2CST_LUT_addr_hold_w ;
            RISC2CST_LUT_di_hold      <=   RISC2CST_LUT_di_hold_w  ; 
			-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
			rtn_frm_sync_mthd_flag_dly	<=	rtn_frm_sync_mthd_flag;
        end if;
        end if;
    end process;
    
    
    
    mst_burst_rd_addr_Proc :
    process(mst_burst_rd_addr_offset, CST_CTRL_state, loading_size ) begin
                mst_burst_rd_addr_offset_w <= mst_burst_rd_addr_offset ;
                --
                if(CST_CTRL_state =  WR_2_CSTCB and mst_burst_rd_addr_offset<loading_size) then
                    mst_burst_rd_addr_offset_w <= mst_burst_rd_addr_offset + "0100";
                elsif ( CST_CTRL_state = Offset_Ready or CST_CTRL_state = Get_Offset  ) then
                    mst_burst_rd_addr_offset_w <= (others=>'0');
                end if;
    end process;
    
    
    -- added by T.H.Wu , 2013.9.4
    RISC2CST_LUT_sync_Proc :
    process( RISC2CST_LUT_we_hold, RISC2CST_LUT_addr_hold, RISC2CST_LUT_di_hold,
                    CSTProfileTable_Wen, CSTProfileTable_idx, CSTProfileTable_di )
    begin
            RISC2CST_LUT_we_hold_w <= RISC2CST_LUT_we_hold ;
            RISC2CST_LUT_addr_hold_w <= RISC2CST_LUT_addr_hold ;
            RISC2CST_LUT_di_hold_w <= RISC2CST_LUT_di_hold  ;
            --
            if(CSTProfileTable_Wen='1') then
            --if(CSTProfileTable_Wen='1' and RISC2CST_LUT_we_hold='0') then
                RISC2CST_LUT_we_hold_w <= '1';
                RISC2CST_LUT_addr_hold_w <=  CSTProfileTable_idx ;
                RISC2CST_LUT_di_hold_w <= CSTProfileTable_di;
            elsif (RISC2CST_LUT_we_sync='1') then
                RISC2CST_LUT_we_hold_w <= '0';
            end if;
    end process;
    
    RISC2CST_LUT_we_sync <= '0' when CST_checking_en = '1'  or CST_CTRL_state = Get_Offset or 
                                                                CST_CTRL_state = Check_Offset or CST_CTRL_state = CST_Loading
                                                    else RISC2CST_LUT_we_hold;
    
    ResidenceTable_CtrlLogic :
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
            for idx in 31 downto 0 loop
                ResidenceTable(idx) <= (others => '0');
            end loop;
        else
            if(ResidenceTable_Wen = '1') then
                ResidenceTable(to_integer(unsigned(malloc_tmp))) <= now_cls_id(7 downto 0);
            end if;
        end if;
        end if;
    end process;
    
    
    return_cls_id <= B_23_16   when ireturn_flag = '1' else
                     A_23_16 ;
    
    new_cls_id <= return_cls_id        when return_flag = '1'  else
                  DR2CST_ctrlr_cls_id(7 downto 0); 
    
	
    data_select <= "10"                     when CST_CTRL_state = Get_Offset else
                   "00" ;
    
    ADDRA <= debug_addr(9 downto 0)          when debug_flag = x"00000001"  else
             -- CSTProfileTable_idx(9 downto 0) when CSTProfileTable_Wen = '1' else -- modified by T.H.Wu , 2013.9.4
             RISC2CST_LUT_addr_hold(9 downto 0) when RISC2CST_LUT_we_sync = '1' else
             new_cls_id & data_select ;
    
    DIA   <=  RISC2CST_LUT_di_hold    when RISC2CST_LUT_we_sync = '1' else
                -- CSTProfileTable_di      when CSTProfileTable_Wen = '1' else ---- modified by T.H.Wu , 2013.9.4
             "00000000000" & malloc ;

    CSTProfileTable_update <= CST_not_cached when CST_CTRL_state = Check_Offset else
                              '0';
    --WEA   <= CSTProfileTable_update or CSTProfileTable_Wen ;
    WEA   <= CSTProfileTable_update or RISC2CST_LUT_we_sync ; -- modified by T.H.Wu , 2013.9.4
    
    ADDRB <= compared_EID(7 downto 0) & "11"             when get_parent_EID = '1'  else
	         over_write_cls_id & "00"        when ResidenceTable_Wen = '1'  else
             new_cls_id & "01" ;
			 
	parent_EID <= DOB;	 
    
    DIB   <= x"FFFF";

    WEB   <= ResidenceTable_Wen and not CMreg_first_round;

    CSTProfileTable : RAMB16_S18_S18
    generic map(
        INIT_00 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_01 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_02 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_03 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_04 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_05 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_06 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_07 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_08 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_09 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_0A => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_0B => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_0C => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_0D => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_0E => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_0F => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_10 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_11 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_12 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_13 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_14 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_15 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_16 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_17 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_18 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_19 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_1A => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_1B => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_1C => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_1D => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_1E => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_1F => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_20 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_21 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_22 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_23 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_24 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_25 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_26 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_27 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_28 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_29 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_2A => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_2B => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_2C => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_2D => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_2E => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_2F => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_30 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_31 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_32 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_33 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_34 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_35 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_36 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_37 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_38 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_39 => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_3A => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_3B => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_3C => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_3D => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_3E => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
        INIT_3F => X"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"
    )        
    port map (
        DOA   => DOA,
        ADDRA => ADDRA,
        CLKA  => clk,
        DIA   => DIA,
        DIPA  => "00",
        ENA   => '1',
        SSRA  => Rst,
        WEA   => WEA,
        
        DOB   => DOB,
        ADDRB => ADDRB,
        CLKB  => clk,
        DIB   => DIB,
        DIPB  => "00",
        ENB   => '1',
        SSRB  => Rst,
        WEB   => WEB
        );
        
        
        --------------------------------------
        -- for chipscope debug use
        --------------------------------------
    process(CST_CTRL_state) begin
                case CST_CTRL_state is
                    when Wait_enable   => debug_CST_state <= X"1";
                    when Get_Offset    => debug_CST_state <= X"2";
                    when Check_Offset  => debug_CST_state <= X"3";
                    when Offset_Ready  => debug_CST_state <= X"4";
                    when CST_Loading   => debug_CST_state <= X"5";
                    when Wait_Ack      => debug_CST_state <= X"6";
                    when WAIT_RD_VALID      => debug_CST_state <= X"7";
                    when WR_2_CSTCB     => debug_CST_state <= X"8";
                    when WAIT_MST_RD_CMPLT =>  debug_CST_state <= X"9";
                    when Update        => debug_CST_state <= X"A";
                    when others => debug_CST_state <= x"F";
                end case;
    end process;
    
        debug_cs_CSTctrl(3 downto 0) <=  debug_CST_state(3 downto 0);
	debug_cs_CSTctrl (19 downto 4) <= loading_offset;  -- <= DOB ;
        debug_cs_CSTctrl (35 downto 20) <=  loading_size;
        --debug_cs_CSTctrl (13 downto 4) <=  ADDRA;
        --debug_cs_CSTctrl (21 downto 14) <=  DOA(7 downto 0);
        --debug_cs_CSTctrl (26 downto 22) <= select_reg  ; -- <= DOA(4 downto 0) ;
	--debug_cs_CSTctrl (27) <= CST_not_cached  ; -- <= DOA(5);
        
        --debug_cs_CSTctrl (75   downto 60) <=  mst_burst_rd_addr_offset;
        --debug_cs_CSTctrl (107 downto 76) <=   external_loaded_buffer ;
        --debug_cs_CSTctrl (76) <=   external_MstRd_burst_data_rdy;
        --debug_cs_CSTctrl (113 downto 109) <=  malloc_tmp ;
        --debug_cs_CSTctrl (118 downto 114) <=  malloc ;
        --debug_cs_CSTctrl (84 downto 77) <=  over_write_cls_id;
        --debug_cs_CSTctrl (92 downto 85) <=  now_cls_id (7 downto 0);
        --debug_cs_CSTctrl (93) <= ResidenceTable_Wen;
        --debug_cs_CSTctrl (94) <= CSTProfileTable_update; 
        
        
end architecture rtl;
