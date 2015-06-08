------------------------------------------------------------------------------
-- Filename	:	MethodArea_management.vhd
-- Version	:	3.00
-- Author	:	Han-Wen Kuo
-- Date		:	Feb 2011
-- VHDL Standard:	VHDL'93
-- Describe	:	New Architecture
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2011. All rights reserved.							**		
-- ** Multimedia Embedded System Lab, NCTU.								**  
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
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

entity method_image_controller is
	generic(
		RAMB_S18_AWIDTH			: integer := 10;
		METHOD_AREA_DDR_ADDRESS	: std_logic_vector(31 downto 0) := X"5A000000"
	);		
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		MA_mgt_en					: in  std_logic;
		DR2MA_mgt_mthd_id			: in  std_logic_vector(15 downto 0); 
		C_25_16					: in  std_logic_vector(9 downto 0);
		B_25_16					: in  std_logic_vector(9 downto 0); 
		return_flag				: in  std_logic;
		ireturn_flag				: in  std_logic;
		CST_check_done			: in  std_logic;
		Mthd_check_done			: out  std_logic; 
		--external_loaded_buffer	: in  std_logic_vector(31 downto 0);
		-- (slave) write from external part(power PC) to method_area_management
		MthdLookupTable_wen		: in  std_logic;
		MthdLookupTable_idx		: in  std_logic_vector(15 downto 0);
		MthdLookupTable_info		: in  std_logic_vector(15 downto 0);  
		-- (master) external memory access
		external_MstRd_CmdAck : in  std_logic; -- added by T.H. Wu , 2013.6.20 
		external_MstRd_burst_data_rdy : in std_logic; -- added by T.H. Wu , 2013.6.20 
		external_access_cmplt		: in  std_logic;
		--external_load_data		: in  std_logic_vector(31 downto 0);
		MthdLoading_req			: out std_logic;
		MthdLoading_ex_addr		: out std_logic_vector(31 downto 0);
		--trigger CST FSM keeping going
		-- Mthd_Loading_done			: out std_logic;
		MthdLoading_stall			: out std_logic; 
		-- method area
		Mgt2MA_wen				: out std_logic;
		Mgt2MA_addr				: out std_logic_vector(11 downto 0);  
		--Mgt2MA_data				: out std_logic_vector(15 downto 0);
		Mgt2MA_block_base_sel		: out std_logic_vector( 4 downto 0); --can delete? (no , jpc[11:10]+base_idx )
		-- 
		now_mthd_id				: out std_logic_vector(15 downto 0);	
		-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
		rtn_frm_sync_mthd_flag		: in	std_logic;
		sync_mthd_invoke_rtn_cmplt	: in	std_logic;
		-- xcptn hdlr
		CST_FSM_Check_offset		: in  std_logic;	
		ret_frm_regs_wen			: in  std_logic;					
		ret_frm_mthd_id				: in  std_logic_vector(15 downto 0);  
		ER_info_addr_rdy			: in  std_logic;	
		MA_base_mem_addr_wen		: in  std_logic;		
		ER_info					: out std_logic_vector(15 downto 0);
		ER_info_wen_MA_ctrlr		: out std_logic;
		MA_base_mem_addr			: out std_logic_vector(31 downto 0)
	);
end entity method_image_controller;

architecture rtl of method_image_controller is 
	signal MA_CTRL_state			: MA_management_SM_TYPE;  
	signal next_MA_CTRL_state	: MA_management_SM_TYPE; 	
	--
	signal selected_DOA			: std_logic_vector(15 downto 0);  
	signal selected_DOB			: std_logic_vector(15 downto 0);  
	--bram bank 0 1 2 3
	signal ADDRA_0				: std_logic_vector( 9 downto 0);
	signal DOA_0					: std_logic_vector(15 downto 0);  
	signal DIA_0					: std_logic_vector(15 downto 0); 
	signal WEA_0					: std_logic;	
	signal ADDRB_0				: std_logic_vector( 9 downto 0);
	signal DOB_0					: std_logic_vector(15 downto 0);
	signal DIB_0					: std_logic_vector(15 downto 0); 
	signal WEB_0					: std_logic;
	signal ADDRA_1				: std_logic_vector( 9 downto 0);
	signal DOA_1					: std_logic_vector(15 downto 0);  
	signal DIA_1					: std_logic_vector(15 downto 0); 
	signal WEA_1					: std_logic;	
	signal ADDRB_1				: std_logic_vector( 9 downto 0);
	signal DOB_1					: std_logic_vector(15 downto 0);
	signal DIB_1					: std_logic_vector(15 downto 0); 
	signal WEB_1					: std_logic;
	signal ADDRA_2				: std_logic_vector( 9 downto 0);
	signal DOA_2					: std_logic_vector(15 downto 0);  
	signal DIA_2					: std_logic_vector(15 downto 0); 
	signal WEA_2					: std_logic;	
	signal ADDRB_2				: std_logic_vector( 9 downto 0);
	signal DOB_2					: std_logic_vector(15 downto 0);
	signal DIB_2					: std_logic_vector(15 downto 0); 
	signal WEB_2					: std_logic;
	signal ADDRA_3				: std_logic_vector( 9 downto 0);
	signal DOA_3					: std_logic_vector(15 downto 0);  
	signal DIA_3					: std_logic_vector(15 downto 0); 
	signal WEA_3					: std_logic;	
	signal ADDRB_3				: std_logic_vector( 9 downto 0);
	signal DOB_3					: std_logic_vector(15 downto 0);
	signal DIB_3					: std_logic_vector(15 downto 0); 
	signal WEB_3					: std_logic;
	
	signal malloc				: std_logic_vector( 4 downto 0);
	signal malloc_tmp			: std_logic_vector( 4 downto 0);
	signal loaded_blk_base_idx	: std_logic_vector( 4 downto 0);		
	signal loading_addr_base		: std_logic_vector(15 downto 0);	
	signal loading_size			: std_logic_vector(15 downto 0);
	signal cnt					: std_logic_vector(15 downto 0);		
	signal MthdLookupTable_update   : std_logic;  
	signal data_reg1				: std_logic_vector(15 downto 0);  
	signal data_reg2				: std_logic_vector(15 downto 0); 
	
	signal now_mthd_id_reg		: std_logic_vector( 9 downto 0);
	signal check_mthd_id			: std_logic_vector( 9 downto 0);
	signal return_mthd_id		: std_logic_vector( 9 downto 0);
	signal data_select			: std_logic_vector( 1 downto 0);
	signal overwrite_mthd_id		: std_logic_vector( 9 downto 0);
	signal AllocationTable_Wen	: std_logic;
	
	signal ClsLoading_req_tmp	: std_logic;
	signal ClsLoading_ex_addr_tmp   : std_logic_vector(31 downto 0);
	
	signal mthd_not_cached		: std_logic;
	
	type AllocationTable_file is array (integer range 31 downto 0) of std_logic_vector(9 downto 0);
	signal AllocationTable : AllocationTable_file;
	signal CMreg_first_round		: std_logic;
	
	-- added by T.H. Wu , 2013.6.4
	signal mst_burst_rd_addr_offset	:  std_logic_vector(15 downto 0);
	signal mst_burst_rd_addr_offset_w :  std_logic_vector(15 downto 0);
	-- added by T.H. Wu , for solving return method bug , 2013.7.9
	signal return_mthd_id_reg_w		: std_logic_vector(9 downto 0);
	signal return_mthd_id_reg			: std_logic_vector(9 downto 0);
	signal return_flag_dly		: std_logic; 
		-- modified by T.H.Wu , 2013.9.4 , for multi-core and synchronization issue
	signal   RISC2MA_LUT_we_sync		: std_logic;
	signal   RISC2MA_LUT_we_hold		: std_logic;
	signal   RISC2MA_LUT_we_hold_w	: std_logic;
	signal  RISC2MA_LUT_addr_hold	: std_logic_vector(15 downto 0);
	signal  RISC2MA_LUT_addr_hold_w : std_logic_vector(15 downto 0);
	signal  RISC2MA_LUT_di_hold		: std_logic_vector(15 downto 0);
	signal  RISC2MA_LUT_di_hold_w	: std_logic_vector(15 downto 0);
	-- added by T.H. Wu , for returning sync method , 2014.1.22
	signal	rtn_frm_sync_mthd_flag_dly			: 	std_logic;
	
	signal Mthd_loading_done  		: std_logic;
	signal first_cycle_check_offset : std_logic;
	
	begin	
	
	-- (master) external memory access
	-- modified by T.H.Wu , for fixing the bug about loading method image from DDR ram to MA buffer , 2013.7.24 
	MthdLoading_req	<= '1' when MA_CTRL_state = Wait_Ack 
													-- or 
													-- MA_CTRL_state = WAIT_RD_VALID or
													-- MA_CTRL_state = WR_2_MACB
								else '0';
	MthdLoading_ex_addr<= METHOD_AREA_DDR_ADDRESS + loading_addr_base + mst_burst_rd_addr_offset;
	
	MA_base_mem_addr   <= METHOD_AREA_DDR_ADDRESS + loading_addr_base;
	
	-- xcptn hdlr
	ER_info			<= selected_DOB;
	ER_info_wen_MA_ctrlr <= --'1' when MA_CTRL_state = Check_Offset else
							'1' when CST_FSM_Check_offset = '1' else
							'0';	
	
	-- method area
	Mgt2MA_wen		<= '1' when MA_CTRL_state = WR_2_MACB else	'0';				
	Mgt2MA_addr		<= mst_burst_rd_addr_offset(12 downto 1) when MA_CTRL_state =  WR_2_MACB else	x"000";					
	--Mgt2MA_data		<= external_loaded_buffer(31 downto 16) when MA_CTRL_state = Data_seg1 else
	--					external_loaded_buffer(15 downto  0) when MA_CTRL_state = Data_seg2 else
	--					X"0000" ;
	

	now_mthd_id <= "000000" & now_mthd_id_reg;
	
	MthdLoading_stall <= not return_flag when (MA_CTRL_state = Wait_enable and MA_mgt_en = '1') or
											MA_CTRL_state = Get_Offset or MA_CTRL_state = Check_Offset  else
						'1'			when 
												MA_CTRL_state = Mthd_Loading or
												MA_CTRL_state = Wait_Ack or
											MA_CTRL_state = WR_2_MACB or 
											MA_CTRL_state = WAIT_RD_VALID or
											MA_CTRL_state = WAIT_MST_RD_CMPLT or 
											MA_CTRL_state = Update or 
											MA_CTRL_state = Offset_Ready 
					else	'0' ;	

	--CST_check_done
	Mthd_check_done <= '1' when MA_CTRL_state = Check_Offset and mthd_not_cached = '0' else
					Mthd_loading_done ;	
	--Mthd_Loading_done <= '1'  when MA_CTRL_state = Offset_Ready else  --Update reduce 1 cycle(?)				
	--					'0' ;					
	
	next_MA_CTRL_state_CtrlLogic :
	process(clk) begin
		if(rising_edge(clk)) then
		if(Rst = '1') then
			MA_CTRL_state	<= Wait_enable;
		else
			case MA_CTRL_state is
				
				when Wait_enable =>
					if (MA_mgt_en = '1' ) then
						MA_CTRL_state <= Get_Offset ; 
					else 
						MA_CTRL_state <= Wait_enable ;  
					end if ;	
				
				when Get_Offset =>
					-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
					if(rtn_frm_sync_mthd_flag_dly='1') then
						MA_CTRL_state	<= Wait_monExit_cmplt ;
					else
						MA_CTRL_state	<= Check_Offset ;
					end if;
				
				when Check_Offset =>
					if mthd_not_cached = '0' then
						MA_CTRL_state <= Offset_Ready;
					elsif CST_check_done = '1' then
						MA_CTRL_state <= Mthd_Loading;
					else
						MA_CTRL_state <= Check_Offset;
					end if;
				
				when Offset_Ready =>												
					MA_CTRL_state	<= Wait_enable;
				
				
				when Mthd_Loading => 
						if(mst_burst_rd_addr_offset>=loading_size) then
								MA_CTRL_state <= Update;
						else 
							MA_CTRL_state <= Wait_Ack;
						end if; 
				
				when Wait_Ack =>  
					--if (external_access_cmplt = '1') then						
					if (external_MstRd_CmdAck  = '1') then					
						MA_CTRL_state <= WAIT_RD_VALID;					
					else
						MA_CTRL_state <= Wait_Ack;   
					end if ;
				
				when WAIT_RD_VALID =>
						if(external_MstRd_burst_data_rdy='0') then
							MA_CTRL_state	<= WR_2_MACB;
						end if; 
				
				when WR_2_MACB =>
						if(mst_burst_rd_addr_offset>=loading_size or external_MstRd_burst_data_rdy='1') then
							MA_CTRL_state	<=  WAIT_MST_RD_CMPLT;
						end if;
						
				when WAIT_MST_RD_CMPLT =>
						if ( external_access_cmplt = '1' ) then
								MA_CTRL_state <= Mthd_Loading; 
						end if;
				
				when Update =>
					MA_CTRL_state	<= Offset_Ready;
				-- modified by T.H.Wu , 2014.1.22, for returning from sync method.
				-- it might cause a problem, if loading caller method is needed, meanwhile the stall flag for monitor
				-- still has not deactivated
				when Wait_monExit_cmplt  =>
					if( sync_mthd_invoke_rtn_cmplt = '1') then
						MA_CTRL_state	<=  Check_Offset;
					end if;
				
				when others => null ;
			end case;
		end if;
		end if;
	end process;
	
	--RAM_select_base
	Mgt2MA_block_base_sel <= malloc	when MA_CTRL_state = WR_2_MACB else	loaded_blk_base_idx;   
	
	malloc_tmp	<= malloc + mst_burst_rd_addr_offset(12 downto 8);
	
	reg_CtrlUnit :
	process(clk)  begin
		if(rising_edge(clk)) then 
		if(Rst = '1') then
			loaded_blk_base_idx<= (others => '0');
			malloc			<= "00001";   
			loading_addr_base  <= (others => '0');
			loading_size	<= (others => '0');
			overwrite_mthd_id  <= (others => '0');
			AllocationTable_Wen <= '0';
			now_mthd_id_reg	<= (others => '0');
			mthd_not_cached	<= '0';
			CMreg_first_round  <= '1';
			first_cycle_check_offset <= '0';
			Mthd_loading_done  <= '0';
			mst_burst_rd_addr_offset <= (others=>'0') ;
			RISC2MA_LUT_we_hold <= '0';
			RISC2MA_LUT_addr_hold  <=   (others => '0');
			RISC2MA_LUT_di_hold	<=   (others => '0');
			rtn_frm_sync_mthd_flag_dly	<=	'0';
		else
			case MA_CTRL_state is
				when Wait_enable =>
					if (MA_mgt_en = '1' ) then
						Mthd_loading_done <= '0' ; 
					end if ;	
					
					if ret_frm_regs_wen = '1' then
						now_mthd_id_reg <= ret_frm_mthd_id(9 downto 0);
					end if;
					
					if MA_base_mem_addr_wen = '1' then
						loading_addr_base   <= selected_DOA ;
					end if;
					
					
				when Get_Offset =>		
					loaded_blk_base_idx <= selected_DOA(4 downto 0) ;
					mthd_not_cached	<= selected_DOA(5);
					loading_addr_base   <= selected_DOB ;
					now_mthd_id_reg	<= check_mthd_id;

				when Check_Offset =>
					if first_cycle_check_offset = '1' then 
						loading_size	<= selected_DOA ; 
					end if;
					
				--when Offset_Ready =>
				--	cnt				<= X"0000" ;
					
				when Mthd_Loading => 
					loaded_blk_base_idx <= malloc;

				--when Data_seg1 | Data_seg2 =>
				--	cnt				<= cnt + "10" ;

				when Update =>   	
					malloc			<= malloc_tmp + '1';-- malloc + cnt(15 downto 11)+'1';
					Mthd_loading_done   <= '1';
				when others => null ;
											
			end case;	

			if MA_CTRL_state = Get_Offset then	first_cycle_check_offset <= '1';
			else 								first_cycle_check_offset <= '0'; end if;
							
			
			if (MA_CTRL_state = Check_Offset or MA_CTRL_state = WR_2_MACB) then   
				overwrite_mthd_id <= AllocationTable(to_integer(unsigned(malloc_tmp)));
			end if; 
			if (MA_CTRL_state = Mthd_Loading and overwrite_mthd_id /= now_mthd_id_reg) then  
			--if ((MA_CTRL_state=WR_2_MACB or MA_CTRL_state=Mthd_Loading ) and overwrite_mthd_id /= now_mthd_id_reg) then  
				AllocationTable_Wen <= '1' ;
			else
				AllocationTable_Wen <= '0';
			end if;
			
			-- 2013.7.5 , there's the same problem with class symbol table controller. 
			--if(malloc = "00000") then
			if(malloc_tmp = "00000") then  -- modified by T.H.Wu , 2013.7.2 , but useless now 
			--if(malloc = "11111") then -- by fox , C.C.Hsu , 2013.8.13 , for XML parser execution
				CMreg_first_round <= '0' ;
			end if;
			
			mst_burst_rd_addr_offset <= mst_burst_rd_addr_offset_w ;
			
			-- added by T.H.Wu , 2013.9.4
			-- write to CST controller lokkup table , and considering synchronization issue
			RISC2MA_LUT_we_hold	<= RISC2MA_LUT_we_hold_w;
			RISC2MA_LUT_addr_hold  <=  RISC2MA_LUT_addr_hold_w ;
			RISC2MA_LUT_di_hold	<=  RISC2MA_LUT_di_hold_w  ;
			
			-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
			rtn_frm_sync_mthd_flag_dly	<=	rtn_frm_sync_mthd_flag;
		end if;
		end if;
	end process;
	
	
	AllocationTable_CtrlLogic :
	process(clk) begin
		if(rising_edge(clk)) then
		if(Rst = '1') then
			for idx in 31 downto 0 loop
				AllocationTable(idx) <= (others => '0');
			end loop;
		else
			if(AllocationTable_Wen = '1') then
				AllocationTable(to_integer(unsigned(malloc_tmp))) <= now_mthd_id_reg(9 downto 0);
			end if;
		end if;
		end if;
	end process;
	
	
	
	
	mst_burst_rd_addr_Proc :
	process(mst_burst_rd_addr_offset, MA_CTRL_state, loading_size ) begin
				mst_burst_rd_addr_offset_w <= mst_burst_rd_addr_offset ;
				--
				if(MA_CTRL_state =  WR_2_MACB and mst_burst_rd_addr_offset<loading_size) then
					mst_burst_rd_addr_offset_w <= mst_burst_rd_addr_offset + "0100";
				elsif ( MA_CTRL_state = Offset_Ready or MA_CTRL_state = Get_Offset  ) then
					mst_burst_rd_addr_offset_w <= (others=>'0');
				end if;
	end process;
	
	
	
	
	-- added by T.H.Wu , 2013.9.4
	RISC2MA_LUT_sync_Proc :
	process( RISC2MA_LUT_we_hold, RISC2MA_LUT_addr_hold, RISC2MA_LUT_di_hold,
					MthdLookupTable_wen, MthdLookupTable_idx, MthdLookupTable_info )
	begin
			RISC2MA_LUT_we_hold_w <= RISC2MA_LUT_we_hold ;
			RISC2MA_LUT_addr_hold_w <= RISC2MA_LUT_addr_hold ;
			RISC2MA_LUT_di_hold_w <= RISC2MA_LUT_di_hold  ;
			--
			if(MthdLookupTable_wen='1') then 
				RISC2MA_LUT_we_hold_w <= '1';
				RISC2MA_LUT_addr_hold_w <=  MthdLookupTable_idx ;
				RISC2MA_LUT_di_hold_w <= MthdLookupTable_info;
			elsif (RISC2MA_LUT_we_sync='1') then
				RISC2MA_LUT_we_hold_w <= '0';
			end if;
	end process;
	
	RISC2MA_LUT_we_sync <= '0' when MA_mgt_en = '1'  or MA_CTRL_state = Get_Offset or 
																MA_CTRL_state = Check_Offset or MA_CTRL_state = Mthd_Loading
													else RISC2MA_LUT_we_hold;
													
													
													
	
		-- all control registers will be gathered HERE ! 2013.7.9
	process(clk) begin
		if(rising_edge(clk)) then
		if(rst = '1') then
			return_flag_dly <= '0';
			return_mthd_id_reg <= (others => '0');
		else
			if(return_flag_dly = '0' and return_flag = '1') then -- the first cycle of return flag
				return_mthd_id_reg <= return_mthd_id_reg_w;
			end if;
			return_flag_dly <= return_flag;
		end if;
		end if;
	end process;
	
	return_mthd_id_reg_w <= C_25_16 when ireturn_flag = '1' else -- C and B will be change, since jcode seq. of return would be continue while MA waiting for CST loading.
							B_25_16;							-- now_mthd_id_reg is an option, but there may some risks.
	return_mthd_id <= return_mthd_id_reg_w when(return_flag_dly = '0' and return_flag = '1') else
										-- the first cycle of return flag
					return_mthd_id_reg;
					
	check_mthd_id <= now_mthd_id_reg(9 downto 0)	when ER_info_addr_rdy = '1' else
									return_mthd_id				when return_flag = '1'	else
									DR2MA_mgt_mthd_id(9 downto 0); 
	
	data_select <= "01"								when ER_info_addr_rdy = '1'	else
				"10"							when MA_CTRL_state = Get_Offset else
				"00" ;
				
	selected_DOA <= DOA_0 when  check_mthd_id(9 downto 8) = "00" else
					DOA_1 when  check_mthd_id(9 downto 8) = "01" else 
					DOA_2 when  check_mthd_id(9 downto 8) = "10" else
					DOA_3 ;  --when  DR2MA_mgt_mthd_id(9 downto 8) = "11"
					
	
	ADDRA_0 <= --MthdLookupTable_idx(9 downto 0) when MthdLookupTable_wen = '1' else -- modified by T.H.Wu , 2013.9.4
			RISC2MA_LUT_addr_hold(9 downto 0) when RISC2MA_LUT_we_sync = '1' else
			check_mthd_id(7 downto 0) & data_select ;
	ADDRA_1 <= --MthdLookupTable_idx(9 downto 0) when MthdLookupTable_wen = '1' else -- modified by T.H.Wu , 2013.9.4
			RISC2MA_LUT_addr_hold(9 downto 0) when RISC2MA_LUT_we_sync = '1' else
			check_mthd_id(7 downto 0) & data_select ;
	ADDRA_2 <= --MthdLookupTable_idx(9 downto 0) when MthdLookupTable_wen = '1' else -- modified by T.H.Wu , 2013.9.4
			RISC2MA_LUT_addr_hold(9 downto 0) when RISC2MA_LUT_we_sync = '1' else
			check_mthd_id(7 downto 0) & data_select ;
	ADDRA_3 <= --MthdLookupTable_idx(9 downto 0) when MthdLookupTable_wen = '1' else -- modified by T.H.Wu , 2013.9.4
			RISC2MA_LUT_addr_hold(9 downto 0) when RISC2MA_LUT_we_sync = '1' else
			check_mthd_id(7 downto 0) & data_select ;		
	
		--DIA_0 <= MthdLookupTable_info			when MthdLookupTable_wen = '1' else  -- modified by T.H.Wu , 2013.9.4
		DIA_0 <= RISC2MA_LUT_di_hold			when RISC2MA_LUT_we_sync = '1' else
			"00000000000" & malloc ;
	--DIA_1 <= MthdLookupTable_info			when MthdLookupTable_wen = '1' else  -- modified by T.H.Wu , 2013.9.4
	DIA_1 <= RISC2MA_LUT_di_hold			when RISC2MA_LUT_we_sync = '1' else
			"00000000000" & malloc ;
	--DIA_2 <= MthdLookupTable_info			when MthdLookupTable_wen = '1' else -- modified by T.H.Wu , 2013.9.4
	DIA_2 <= RISC2MA_LUT_di_hold			when RISC2MA_LUT_we_sync = '1' else
			"00000000000" & malloc ;		
		--DIA_3 <= MthdLookupTable_info			when MthdLookupTable_wen = '1' else -- modified by T.H.Wu , 2013.9.4
		DIA_3 <= RISC2MA_LUT_di_hold			when RISC2MA_LUT_we_sync = '1' else
			"00000000000" & malloc ;
						
	MthdLookupTable_update <= mthd_not_cached when MA_CTRL_state = Check_Offset else
							'0';
	
	WEA_0   <= MthdLookupTable_update when MA_CTRL_state = Check_Offset and check_mthd_id(9 downto 8) = "00" else
							--MthdLookupTable_wen	when MthdLookupTable_idx(11 downto 10) = "00" else -- modified by T.H.Wu , 2013.9.4
							RISC2MA_LUT_we_sync	when RISC2MA_LUT_addr_hold(11 downto 10) = "00" else
			'0' ;
	WEA_1   <= MthdLookupTable_update when MA_CTRL_state = Check_Offset and check_mthd_id(9 downto 8) = "01" else
						-- MthdLookupTable_wen	when MthdLookupTable_idx(11 downto 10) = "01" else -- modified by T.H.Wu , 2013.9.4
							RISC2MA_LUT_we_sync	when RISC2MA_LUT_addr_hold(11 downto 10) = "01" else
			'0' ;		
	WEA_2   <= MthdLookupTable_update when MA_CTRL_state = Check_Offset and check_mthd_id(9 downto 8) = "10" else
							--MthdLookupTable_wen	when MthdLookupTable_idx(11 downto 10) = "10" else -- modified by T.H.Wu , 2013.9.4
							RISC2MA_LUT_we_sync	when RISC2MA_LUT_addr_hold(11 downto 10) = "10" else
			'0' ;		
		WEA_3   <= MthdLookupTable_update when MA_CTRL_state = Check_Offset and check_mthd_id(9 downto 8) = "11" else
							--MthdLookupTable_wen	when MthdLookupTable_idx(11 downto 10) = "11" else -- modified by T.H.Wu , 2013.9.4
							RISC2MA_LUT_we_sync	when RISC2MA_LUT_addr_hold(11 downto 10) = "11" else 
			'0' ;
	
	-- one situation B port read  : Get_Offset load method externel memory offset
	-- one situation B port write : (Wait_Acl) (AllocationTable_Wen==1)
	selected_DOB <= DOB_0 when  check_mthd_id(9 downto 8) = "00" else
					DOB_1 when  check_mthd_id(9 downto 8) = "01" else 
					DOB_2 when  check_mthd_id(9 downto 8) = "10" else
					DOB_3  ;  --when  DR2MA_mgt_mthd_id(9 downto 8) = "11"
	
	ADDRB_0 <= overwrite_mthd_id(7 downto 0) & "00" when AllocationTable_Wen = '1' else	
			check_mthd_id(7 downto 0) & "11"	when MA_CTRL_state = Get_Offset or ER_info_addr_rdy = '1' else	
			check_mthd_id(7 downto 0) & "01" ;
	ADDRB_1 <= overwrite_mthd_id(7 downto 0) & "00" when AllocationTable_Wen = '1' else
			check_mthd_id(7 downto 0) & "11"	when MA_CTRL_state = Get_Offset or ER_info_addr_rdy = '1' else
			check_mthd_id(7 downto 0) & "01" ;
	ADDRB_2 <= overwrite_mthd_id(7 downto 0) & "00" when AllocationTable_Wen = '1' else
			check_mthd_id(7 downto 0) & "11"	when MA_CTRL_state = Get_Offset or ER_info_addr_rdy = '1' else
			check_mthd_id(7 downto 0) & "01" ;
	ADDRB_3 <= overwrite_mthd_id(7 downto 0) & "00" when AllocationTable_Wen = '1' else
			check_mthd_id(7 downto 0) & "11"	when MA_CTRL_state = Get_Offset or ER_info_addr_rdy = '1' else
			check_mthd_id(7 downto 0) & "01" ;
	
	DIB_0 <= x"FFFF";
	DIB_1 <= x"FFFF";
	DIB_2 <= x"FFFF";
	DIB_3 <= x"FFFF";

	WEB_0 <= AllocationTable_Wen and not CMreg_first_round when overwrite_mthd_id(9 downto 8) = "00"  else
			'0' ;
	WEB_1 <= AllocationTable_Wen and not CMreg_first_round when overwrite_mthd_id(9 downto 8) = "01"  else
			'0' ;
	WEB_2 <= AllocationTable_Wen and not CMreg_first_round when overwrite_mthd_id(9 downto 8) = "10"  else
			'0' ;		
	WEB_3 <= AllocationTable_Wen and not CMreg_first_round when overwrite_mthd_id(9 downto 8) = "11"  else
			'0' ;
			
	MthdLookupTable_0 : RAMB16_S18_S18
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
		DOA   => DOA_0,
		ADDRA => ADDRA_0,
		CLKA  => clk,
		DIA   => DIA_0,
		DIPA  => "00",
		ENA   => '1',
		SSRA  => Rst,
		WEA   => WEA_0,
		
		DOB   => DOB_0,
		ADDRB => ADDRB_0,
		CLKB  => clk,
		DIB   => DIB_0,
		DIPB  => "00",
		ENB   => '1',
		SSRB  => Rst,
		WEB   => WEB_0
		);
		
	MthdLookupTable_1 : RAMB16_S18_S18
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
		DOA   => DOA_1,
		ADDRA => ADDRA_1,
		CLKA  => clk,
		DIA   => DIA_1,
		DIPA  => "00",
		ENA   => '1',
		SSRA  => Rst,
		WEA   => WEA_1,
		
		DOB   => DOB_1,
		ADDRB => ADDRB_1,
		CLKB  => clk,
		DIB   => DIB_1,
		DIPB  => "00",
		ENB   => '1',
		SSRB  => Rst,
		WEB   => WEB_1
		);	
		
	MthdLookupTable_2 : RAMB16_S18_S18
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
		DOA   => DOA_2,
		ADDRA => ADDRA_2,
		CLKA  => clk,
		DIA   => DIA_2,
		DIPA  => "00",
		ENA   => '1',
		SSRA  => Rst,
		WEA   => WEA_2,
		
		DOB   => DOB_2,
		ADDRB => ADDRB_2,
		CLKB  => clk,
		DIB   => DIB_2,
		DIPB  => "00",
		ENB   => '1',
		SSRB  => Rst,
		WEB   => WEB_2
		);

	MthdLookupTable_3 : RAMB16_S18_S18
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
		DOA   => DOA_3,
		ADDRA => ADDRA_3,
		CLKA  => clk,
		DIA   => DIA_3,
		DIPA  => "00",
		ENA   => '1',
		SSRA  => Rst,
		WEA   => WEA_3,
		
		DOB   => DOB_3,
		ADDRB => ADDRB_3,
		CLKB  => clk,
		DIB   => DIB_3,
		DIPB  => "00",
		ENB   => '1',
		SSRB  => Rst,
		WEB   => WEB_3
		);	

end architecture rtl;
