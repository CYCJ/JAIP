------------------------------------------------------------------------------
-- Filename     :       indexOf.vhd
-- Version      :       1.00
-- Author       :       Chia-Che Hsu
-- Date         :       Apr. 2013
-- VHDL Standard:       VHDL'93
-- Describe     :       finding a string pattern in a text
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2012. All rights reserved.                              **        
-- ** Multimedia Embedded System Lab, NCTU.                                 **  
-- ** Department of Computer Science and Information engineering            **
-- ** National Chiao Tung University, Hsinchu 300, Taiwan                   **
-- ***************************************************************************
--
----------------------------------Modified------------------------------------
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
--use work.config.all;

entity indexOf is
	generic(
			C_MST_AWIDTH                   : integer              := 32;
			init_num                              : integer              := 25;
			init_n                                   : integer              := 24;	
			init                                      : integer               := 23;	
			C_MST_DWIDTH                   : integer              := 32
	);
	port (
			Clk                 				      : in  std_logic;
			Rst					                  	  : in  std_logic;
			
			-- PLB MST BURST ports --
			IO_IP2Bus_MstRd_Req               : out std_logic;
			IO_IP2Bus_Mst_Addr                : out std_logic_vector(C_MST_AWIDTH-1 downto 0);
			IO_Bus2IP_MstRd_d                 : in  std_logic_vector(C_MST_DWIDTH-1 downto 0);
			IO_Bus2IP_Mst_Cmplt               : in  std_logic;
			
			-- args & ctrl ports --
			IOEn					   		      : in std_logic;
			IOCEn					   		      : in std_logic;
			LIOEn								  : in std_logic;
			VIOEn								  : in std_logic;
			IOCmplt				   		  		  : out std_logic;
			
			textRef				   		  		  : in std_logic_vector(31 downto 0);
			--strRef						   		  : in std_logic_vector(31 downto 0);
			fromIndex					   		  : in std_logic_vector(31 downto 0);
			--ch									  : in std_logic_vector(31 downto 0);
			
			res									  : out std_logic_vector(31 downto 0);
			indexof_mthd_arg1			   	          : in std_logic_vector(31 downto 0);
			
			--cs debug
			debug_IOSM							  : out std_logic_vector(3 downto 0)
	);
end entity;
architecture rtl of indexOf is 
	type IOSMType is (idle, ld_txtCount, ld_strCount, ld_txtOffset, ld_strOffset, ld_txtCharAry, ld_strCharAry, ld_first, ld_txtOutter, ld_str, ld_txtInner);
	signal IOSM 								  : IOSMType;
	signal IOSM_next							  : IOSMType;
	signal IO_rd_init_req						  : std_logic;
	signal IO_rd_char_req						  : std_logic;
	signal IO_rd_init_Addr						  : std_logic_vector(init_num downto 0);
	signal IO_obj_res_Addr_reg					  : std_logic_vector(init_num downto 0);
	signal IO_rd_char_Addr						  : std_logic_vector(init_num downto 0);
	signal IO_rd_char_Addr_reg					  : std_logic_vector(init_num downto 0);
	signal finish								  : std_logic;
	signal finish_delay							  : std_logic;
	signal IOCFlag								  : std_logic;
	signal isIOC								  : std_logic;
	signal LIOFlag								  : std_logic;
	signal isLIO								  : std_logic;
	signal VIOFlag								  : std_logic;
        -- modified by T.H.Wu , 2013.8.12 , for solving critical path
	--signal isVIO								  : std_logic;
	
	signal textRef_reg							  : std_logic_vector(init_num downto 0);
	signal strRef_reg							  : std_logic_vector(init_num downto 0);
	signal fromIndex_reg						  : std_logic_vector(init_n downto 0);
	signal txtCount								  : std_logic_vector(init_n downto 0);
	signal strCount								  : std_logic_vector(init_n downto 0);
	signal txtOffset							  : std_logic_vector(init_n downto 0);
	signal strOffset							  : std_logic_vector(init_n downto 0);
	signal txtCharAry						   	  : std_logic_vector(init_num downto 0);
	signal txtCharAry_reg					   	  : std_logic_vector(init_num downto 0);
	signal strCharAry							  : std_logic_vector(init_num downto 0);
	signal max									  : std_logic_vector(init_n downto 0);
	signal i									  : std_logic_vector(init_n downto 0) := (others => '0');
	signal i_next								  : std_logic_vector(init_n downto 0);
	signal j									  : std_logic_vector(init_n downto 0) := (others => '0');
	signal j_next								  : std_logic_vector(init_n downto 0);
	signal k									  : std_logic_vector(init_n downto 0);
	signal k_next								  : std_logic_vector(init_n downto 0);
	signal j_end								  : std_logic_vector(init_n downto 0);
	signal j_rem								  : std_logic_vector(init_n downto 0);
	signal outter_max							  : std_logic_vector(init_n downto 0);
	signal res_i								  : std_logic_vector(init_n downto 0);
	signal i_next_reg							  : std_logic_vector(init_n downto 0);
	signal j_end_reach							  : std_logic;
	signal j_end_logic							  : std_logic_vector(init_n downto 0);
	
	signal first								  : std_logic_vector(31 downto 0);
	signal first_mask							  : std_logic_vector(1 downto 0); 
	signal outter_mask							  : std_logic_vector(1 downto 0);
	signal outter_mask_next						  : std_logic_vector(1 downto 0);
	signal cmp_mask								  : std_logic_vector(3 downto 0);
	signal outter_cmp							  : std_logic_vector(3 downto 0);
	signal outter_cmp_tmp						  : std_logic_vector(3 downto 0);
	signal outter_cmp_size						  : std_logic_vector(1 downto 0) := "00";
	signal outter_cmp_size_reg					  : std_logic_vector(1 downto 0) := "00";
	signal inner_cmp							  : std_logic;
	signal str_ld_size							  : std_logic_vector(1 downto 0);
	signal str_char_buf							  : std_logic_vector(47 downto 0);
	signal str_char_buf_valid					  : std_logic_vector(2 downto 0);
	signal txt_ld_size							  : std_logic_vector(1 downto 0);
	signal txt_char_buf							  : std_logic_vector(15 downto 0);
	signal txt_char_buf_valid					  : std_logic;
	signal txt_char_tmp_48					      : std_logic_vector(47 downto 0);
	signal txt_char_buf_valid_next				  : std_logic;
	signal outter_1st_match						  : std_logic;
	signal outter_2nd_match						  : std_logic;
	signal outter_finish						  : std_logic;
	signal outer_first_na_1st					  : std_logic;
	signal outer_first_na_2nd					  : std_logic;
	signal not_find								  : std_logic;
	signal txt_head_na							  : std_logic;
	signal strRef						   		  : std_logic_vector(31 downto 0);
	signal ch									  : std_logic_vector(31 downto 0);
	
	
	type MLSMType is (waitReq, waitCmplt);
	signal MLSM									  : MLSMType;
	signal MLSM_next							  : MLSMType;
	
begin
	
	strRef		<= indexof_mthd_arg1;
	ch			<= indexof_mthd_arg1;
    
    
    
    	res <= x"FFFFFFFF" when(not_find = '1') else
		   x"FFFFFFFF" when(isLIO = '1' and (fromIndex_reg < res_i)) else
		   ("0000000" & (fromIndex_reg - res_i)) when(isLIO = '1') else
		   (others => '0') when(fromIndex_reg = 0 and txtCount = 0 and strCount = 0) else
		   x"FFFFFFFF" when(fromIndex_reg >= txtCount or res_i > max) else
                   -- modified by T.H.Wu , 2013.8.12 , for solving critical path
		  -- "000000000" & res_i(init_n downto 1) when(isVIO = '1') else 
		   ("0000000" & fromIndex_reg) when(strCount = 0) else
		   ("0000000" & (res_i - txtOffset));
		   
	IO_IP2Bus_MstRd_Req	<= '1' when(MLSM = waitReq and (IO_rd_init_req = '1' or IO_rd_char_req = '1')) else '0';
	IO_IP2Bus_Mst_Addr <= "010111" & IO_rd_init_Addr(init_num downto 2) & "00" when(IO_rd_init_req = '1') else
						  "010111" & IO_rd_char_Addr(init_num downto 2) & "00" when(IO_rd_char_req = '1') else
						  (others => '0');
	
	IO_rd_init_req <= '1' when(IOSM = ld_txtCount or IOSM = ld_strCount or IOSM = ld_txtOffset or IOSM = ld_strOffset or IOSM = ld_txtCharAry or IOSM = ld_strCharAry or IOSM = ld_first) else '0';
	IO_rd_char_req <= '1' when(IOSM = ld_txtOutter or IOSM = ld_str or (IOSM = ld_txtInner and j_end_reach = '0')) else '0';
	IO_rd_init_Addr <= IO_obj_res_Addr_reg;
	IO_rd_char_Addr <= IO_rd_char_Addr_reg;
	
	process(Rst, Clk) begin
		if(Rst = '1') then
			IOSM <= idle;
			MLSM <= waitReq;
		elsif(rising_edge(Clk)) then
			IOSM <= IOSM_next;
			MLSM <= MLSM_next;
		end if;
	end process;
	
	process(IOSM, IOEn, IO_Bus2IP_Mst_Cmplt, finish, i, max, j, j_rem, inner_cmp, outter_max, IO_Bus2IP_MstRd_d, fromIndex_reg, outter_2nd_match, outter_1st_match, 
             txt_ld_size, isIOC, isLIO, 
              -- modified by T.H.Wu , 2013.8.12 , for solving critical path
              --isVIO,  
            outter_finish, outer_first_na_1st, outer_first_na_2nd, j_end_reach, strCount, k) begin
		case IOSM is
			when idle =>
                                -- modified by T.H.Wu , 2013.8.12 , for solving critical path
				--if (IOEn = '1' or IOCEn = '1' or LIOEn = '1' or VIOEn = '1') then
				if (IOEn = '1' or IOCEn = '1' or LIOEn = '1') then
					IOSM_next <= ld_txtCount;
				else
					IOSM_next <= idle;
				end if;
			when ld_txtCount =>
				if(IO_Bus2IP_Mst_Cmplt = '1') then
                                        -- modified by T.H.Wu , 2013.8.12 , for solving critical path
					--if(fromIndex_reg >= IO_Bus2IP_MstRd_d(init_n downto 0) and isLIO = '0' and isVIO = '0') then
					if(fromIndex_reg >= IO_Bus2IP_MstRd_d(init_n downto 0) and isLIO = '0') then
						IOSM_next <= idle;
					else
						if(isIOC = '1' or isLIO = '1') then
							IOSM_next <= ld_txtOffset;
                                                -- modified by T.H.Wu , 2013.8.12 , for solving critical path
						--elsif(isVIO = '1') then
						--	IOSM_next <= ld_txtCharAry;
						else
							IOSM_next <= ld_strCount;			
						end if;
					end if;
				else
					IOSM_next <= ld_txtCount;
				end if;
			when ld_strCount =>
				if(IO_Bus2IP_Mst_Cmplt = '1') then
					if(IO_Bus2IP_MstRd_d = x"00000000") then
						IOSM_next <= idle;
					else
						IOSM_next <= ld_txtOffset;
					end if;
				else
					IOSM_next <= ld_strCount;
				end if;
			when ld_txtOffset =>
				if(IO_Bus2IP_Mst_Cmplt = '1') then
					if(isIOC = '1' or isLIO = '1') then
						IOSM_next <= ld_txtCharAry;
					else
						IOSM_next <= ld_strOffset;
					end if;
				else
					IOSM_next <= ld_txtOffset;
				end if;
			when ld_strOffset =>
				if(IO_Bus2IP_Mst_Cmplt = '1') then
					IOSM_next <= ld_txtCharAry;
				else
					IOSM_next <= ld_strOffset;
				end if;
			when ld_txtCharAry =>
				if(IO_Bus2IP_Mst_Cmplt = '1') then
                                        -- modified by T.H.Wu , 2013.8.12 , for solving critical path
					--if(isIOC = '1' or isLIO = '1' or isVIO = '1') then
					if(isIOC = '1' or isLIO = '1') then
						IOSM_next <= ld_txtOutter;
					else
						IOSM_next <= ld_strCharAry;
					end if;
				else
					IOSM_next <= ld_txtCharAry;
				end if;
			when ld_strCharAry =>
				if(IO_Bus2IP_Mst_Cmplt = '1') then
					IOSM_next <= ld_first;
				else
					IOSM_next <= ld_strCharAry;
				end if;
			when ld_first =>
				if(IO_Bus2IP_Mst_Cmplt = '1') then
					IOSM_next <= ld_txtOutter;
				else
					IOSM_next <= ld_first;
				end if;
			when ld_txtOutter =>					-- outter loop
				if(IO_Bus2IP_Mst_Cmplt = '1') then
					if(outter_finish = '1') then
						IOSM_next <= idle;	
					elsif(outter_2nd_match = '1' or outter_1st_match = '1' or outer_first_na_1st = '1' or outer_first_na_2nd = '1') then
						IOSM_next <= ld_str;
					elsif(i_next_reg <= outter_max) then
						IOSM_next <= ld_txtOutter;	
					else
						IOSM_next <= idle;
					end if;
				else
					IOSM_next <= ld_txtOutter;
				end if;
			when ld_str =>							-- inner loop
				if(IO_Bus2IP_Mst_Cmplt = '1') then

						IOSM_next <= ld_txtInner;

				else
					IOSM_next <= ld_str;
				end if;
			when ld_txtInner =>						-- inner loop
				if(IO_Bus2IP_Mst_Cmplt = '1' or j_end_reach = '1') then
					if(inner_cmp = '1') then
						if((j_rem >= txt_ld_size and j_rem(init_n) = '0' and j_end_reach = '0') or (k < strCount) or (k = 0 and k(0) = '1')) then
							IOSM_next <= ld_str;
						else
							IOSM_next <= idle;
						end if;
					else
						if(i <= max) then
							IOSM_next <= ld_txtOutter;
						else
							IOSM_next <= idle;
						end if;
					end if;
				else
					IOSM_next <= ld_txtInner;
				end if;
				
			when others =>
				IOSM_next <= idle;
		end case;
	end process;
	
	process(MLSM, IO_rd_init_req, IO_Bus2IP_Mst_Cmplt) begin
		case MLSM is
			when waitReq =>
				if(IO_rd_init_req = '1' or IO_rd_char_req = '1') then
					MLSM_next <= waitCmplt;
				else
					MLSM_next <= waitReq;
				end if;
			when waitCmplt =>
				if(IO_Bus2IP_Mst_Cmplt = '1') then
					MLSM_next <= waitReq;
				else
					MLSM_next <= waitCmplt;
				end if;
			when others =>
				MLSM_next <= waitReq;
		end case;
	end process;
	
	-- flip-flops
	process(Clk, Rst) begin
		if(Rst = '1') then
			textRef_reg <= (others => '0');
			strRef_reg <= (others => '0');
			fromIndex_reg <= (others => '0');
			txtCount <= (others => '0');
			strCount <= (others => '0');
			txtOffset <= (others => '0');
			strOffset <= (others => '0');
			txtCharAry_reg <= (others => '0');
			strCharAry <= (others => '0');
			max <= (others => '0');
			i <= (others => '0');
			j <= (others => '0');
			j_end <= (others => '0');
			k <= (others => '0');
			first <= (others => '0');
			str_char_buf <= (others => '0');
			txt_char_buf <= (others => '0');
			str_char_buf_valid <= (others => '0');
			txt_char_buf_valid <= '0';
			outter_cmp_size_reg <= (others => '0');
			res_i <= (others => '0');
			cmp_mask <= (others => '0');
			j_rem <= (others => '0');
			IO_obj_res_Addr_reg <= (others => '0');
			IO_rd_char_Addr_reg <= (others => '0');
			IOCFlag <= '0';
			outter_mask <= (others => '0');
			i_next_reg <= (others => '0');
			VIOFlag <= '0';
			LIOFlag <= '0';
			j_end_reach <= '0';
		elsif(rising_edge(clk)) then
			if(IOEn = '1') then
				textRef_reg <= textRef(init_num downto 0);
				strRef_reg <= strRef(init_num downto 0);
				fromIndex_reg <= fromIndex(init_n downto 0);
                         -- modified by T.H.Wu , 2013.8.12 , for solving critical path
			--elsif(IOCEn = '1' or LIOEn = '1' or VIOEn = '1') then
			elsif(IOCEn = '1' or LIOEn = '1') then
				textRef_reg <= textRef(init_num downto 0);
                                -- modified by T.H.Wu , 2013.8.12 , for solving critical path
				--if(VIOEn = '1') then
				--	fromIndex_reg <= fromIndex(init downto 0) & '0';
				--else	
					fromIndex_reg <= fromIndex(init_n downto 0);
				--end if;
			elsif(isLIO = '1' and IO_Bus2IP_Mst_Cmplt = '1' and IOSM = ld_txtCount and fromIndex_reg >= IO_Bus2IP_MstRd_d(init_n downto 0)) then	-- bad arg from Java program
				fromIndex_reg <= IO_Bus2IP_MstRd_d(init_n downto 0) - 1;
			end if;
			
			if(IOCEn = '1') then
				IOCFlag <= '1';
			elsif(finish_delay = '1') then
				IOCFlag <= '0';
			end if;
			
			if(LIOEn = '1') then
				LIOFlag <= '1';
			elsif(finish_delay = '1') then
				LIOFlag <= '0';
			end if;
			
                        -- modified by T.H.Wu , 2013.8.12 , for solving critical path
			--if(VIOEn = '1') then 
			--	VIOFlag <= '1';
			--elsif(finish_delay = '1') then
			--	VIOFlag <= '0';
			--end if;
			
			if(IO_Bus2IP_Mst_Cmplt = '1') then
				if(IOSM = ld_txtCount) then
                                        -- modified by T.H.Wu , 2013.8.12 , for solving critical path
					--if(isVIO = '1') then
					--	txtCount <= IO_Bus2IP_MstRd_d(init downto 0)&'0';
					--	max <= (IO_Bus2IP_MstRd_d(init downto 0)&'0') - 2;
					--else
						txtCount <= IO_Bus2IP_MstRd_d(init_n downto 0);
					--end if;
				elsif(IOSM = ld_strCount) then
					strCount <= IO_Bus2IP_MstRd_d(init_n downto 0);
				elsif(IOSM = ld_txtOffset) then
					txtOffset <= IO_Bus2IP_MstRd_d(init_n downto 0);
					if(isLIO = '1') then
						max <= fromIndex_reg - IO_Bus2IP_MstRd_d(init_n downto 0) + 1;
						i <= (others => '0');
					else
						max <= IO_Bus2IP_MstRd_d(init_n downto 0) + txtCount - strCount;
						i <= IO_Bus2IP_MstRd_d(init_n downto 0) + fromIndex_reg;
					end if;
				elsif(IOSM = ld_strOffset) then
					strOffset <= IO_Bus2IP_MstRd_d(init_n downto 0);
				elsif(IOSM = ld_txtCharAry) then
					txtCharAry_reg <= IO_Bus2IP_MstRd_d(init_num downto 0);
				elsif(IOSM = ld_strCharAry) then
					strCharAry <= IO_Bus2IP_MstRd_d(init_num downto 0);
				elsif(IOSM = ld_first) then
					first <= IO_Bus2IP_MstRd_d;
				end if;
			elsif(IOCEn = '1' or LIOEn = '1') then
				strCount <= "0" & x"000001";
				strOffset <= (others => '0');
				first <= ch(15 downto 0) & x"0000";
                        -- modified by T.H.Wu , 2013.8.12 , for solving critical path
			--elsif(VIOEn = '1') then
			--	txtOffset <= (others => '0');
			--	strCount <= x"000002";
			--	strOffset <= (others => '0');
			--	first <= ch;
			--	i <= fromIndex(init downto 0) & '0';
			end if;
			
			if((IOSM_next = ld_txtOutter or IOSM_next = idle) and IO_Bus2IP_Mst_Cmplt = '1') then
				i <= i_next_reg;
			end if;
			if(IOSM = ld_txtOutter and IO_Bus2IP_Mst_Cmplt = '1') then
				if(i = max) then
					outter_cmp_size_reg <= "01";
				else	
					outter_cmp_size_reg <= outter_cmp_size;
				end if;
				if(outter_1st_match = '1' or outer_first_na_1st = '1' or 
				  (outter_cmp(3) = '1' and first_mask = "10") or
				  outter_mask = "01") then
					res_i <= i;
				else
					res_i <= i + 1;
				end if;
			end if;
			
			if((IOSM = ld_txtOutter and outter_finish = '1') or (IOSM = ld_txtInner and inner_cmp = '1')) then
				not_find <= '0';
			else
				not_find <= '1';
			end if;
			
			if(IOSM_next = ld_str and IO_Bus2IP_Mst_Cmplt = '1') then -- k init
				k <= k_next;
			elsif(IOSM = ld_str and IO_Bus2IP_Mst_Cmplt = '1') then   -- k addition
				k <= k_next;
			end if;
		
			if(IOSM = ld_txtOutter and IO_Bus2IP_Mst_Cmplt = '1') then
				j_end <= j_end_logic;
			end if;
			
			if(IO_Bus2IP_Mst_Cmplt = '1') then
				j <= j_next;
			end if;
			
			if(IOSM = ld_txtOutter and IO_Bus2IP_Mst_Cmplt = '1') then
				if(outter_2nd_match = '1') then
					str_char_buf(15 downto 0) <= first(15 downto 0);
					str_char_buf_valid <= "001";
				else
					str_char_buf_valid <= "000";
				end if;
			elsif(IOSM = ld_str and IO_Bus2IP_Mst_Cmplt = '1') then
				if(str_char_buf_valid(0) = '1') then
					str_char_buf(47 downto 32) <= str_char_buf(15 downto 0);
					str_char_buf(31 downto 0) <= IO_Bus2IP_MstRd_d;
					if((strCount - k) = 1) then
						str_char_buf_valid <= "110";
					else
						str_char_buf_valid <= "111";
					end if;
				elsif(str_char_buf_valid(0) = '0') then
					str_char_buf(47 downto 16) <= IO_Bus2IP_MstRd_d;
					if((strCount - k) = 1) then
						str_char_buf_valid <= "100";
					else
						str_char_buf_valid <= "110";
					end if;
				end if;
			end if;
			
			if((IOSM = ld_txtOutter or IOSM = ld_txtInner) and IO_Bus2IP_Mst_Cmplt = '1') then
				txt_char_buf <= txt_char_tmp_48(15 downto 0);
				txt_char_buf_valid <= txt_char_buf_valid_next;
			end if;
			
			finish_delay <= finish;
			cmp_mask <= (first_mask(1) and outter_mask(1))&(first_mask(1) and outter_mask(0)) & (first_mask(0) and outter_mask(1)) & (first_mask(0) and outter_mask(1));
			j_rem <= j_end - j_next;
			
                         -- modified by T.H.Wu , 2013.8.12 , for solving critical path
			--if(IO_Bus2IP_Mst_Cmplt = '1' or IOEn = '1' or IOCEn = '1' or LIOEn = '1' or VIOEn = '1') then
			if(IO_Bus2IP_Mst_Cmplt = '1' or IOEn = '1' or IOCEn = '1' or LIOEn = '1') then
				if(IOSM_next = ld_txtCount) then 
                                        -- modified by T.H.Wu , 2013.8.12 , for solving critical path
					--if(isVIO = '1') then
					--	IO_obj_res_Addr_reg <= textRef(init_num downto 0) + ('0'&x"000008");
					--else
						IO_obj_res_Addr_reg <= textRef(init_num downto 0) + ('0'&x"00000C");
					--end if;
				elsif(IOSM_next = ld_txtOffset) then
					IO_obj_res_Addr_reg <= textRef_reg + ('0'&x"000008");
				elsif(IOSM_next = ld_txtCharAry) then	
					IO_obj_res_Addr_reg <= textRef_reg + ('0'&x"000004");
				elsif(IOSM_next = ld_strCount) then			
					IO_obj_res_Addr_reg <= strRef_reg + ('0'&x"00000C");
				elsif(IOSM_next = ld_strOffset) then			
					IO_obj_res_Addr_reg <= strRef_reg + ('0'&x"000008");
				elsif(IOSM_next = ld_strCharAry) then			
					IO_obj_res_Addr_reg <= strRef_reg + ('0'&x"000004");
				elsif(IOSM_next = ld_first) then			
					IO_obj_res_Addr_reg <= IO_Bus2IP_MstRd_d(init_num downto 0) + (strOffset(init_n downto 0)&'0');
				end if;
			end if;
			
			if(IOSM_next = ld_txtOutter and IO_Bus2IP_Mst_Cmplt = '1') then
				if(isIOC = '1') then
					IO_rd_char_Addr_reg <= txtCharAry + (i_next_reg(init_n downto 0)&'0');
				elsif(isLIO = '1') then
					IO_rd_char_Addr_reg <= txtCharAry + (txtOffset(init_n downto 0)&'0') + (fromIndex_reg(init_n downto 0)&'0') - (i_next_reg(init_n downto 0)&'0');
				else
					IO_rd_char_Addr_reg <= txtCharAry + (i_next_reg(init_n downto 0)&'0');
				end if;
			elsif(IOSM_next = ld_str and IO_Bus2IP_Mst_Cmplt = '1') then
				IO_rd_char_Addr_reg <= strCharAry + ((k_next(init_n downto 0) + 1)&'0') + (strOffset&'0');
			elsif(IOSM_next = ld_txtInner and IO_Bus2IP_Mst_Cmplt = '1') then
				IO_rd_char_Addr_reg <= txtCharAry + ((j_next(init_n downto 0))&'0');
			end if;
			i_next_reg <= i_next;
			outter_mask <= outter_mask_next;
			
			if(IO_Bus2IP_Mst_Cmplt = '1' and (IOSM = ld_txtOutter or IOSM = ld_txtInner)) then
				if(j_end_logic < j_next) then
					j_end_reach <= '1';
				else
					j_end_reach <= '0';
				end if;
			end if;
		end if;
	end process;
	txt_head_na <= '1' when(isLIO = '1' and (txtOffset(0) xor fromIndex_reg(0)) = '0') else
				   '0';
	txtCharAry <= IO_Bus2IP_MstRd_d(init_num downto 0) when (IOSM = ld_txtCharAry and IO_Bus2IP_Mst_Cmplt = '1') else
				  txtCharAry_reg;	
	isIOC <= IOCFlag or IOCEn;
	isLIO <= LIOFlag or LIOEn;
        -- modified by T.H.Wu , 2013.8.12 , for solving critical path
	--isVIO <= VIOFlag or VIOEn;
	
	i_next <= i + outter_cmp_size_reg when(IOSM = ld_txtInner and IOSM_next /= idle) else
			  i + outter_cmp_size;
	k_next <= "0" & x"000002" when(outter_1st_match = '1') else
			  "0" & x"000001" when(outter_2nd_match = '1' or outer_first_na_1st = '1' or outer_first_na_2nd = '1') else
			  k + str_ld_size;
	j_next <= --i + 1 when(IOSM = ld_txtOutter and outter_mask(1) = '1' and outter_mask(0) = '1' and first_mask = "01") else
			  i + 2 when(IOSM = ld_txtOutter) else
			  j + txt_ld_size;
	j_end_logic <= i + strCount - 1;
	process(IOSM, IO_Bus2IP_Mst_Cmplt, outter_mask, txt_char_buf_valid, j_rem, IO_Bus2IP_MstRd_d, txt_char_buf, first_mask, outter_finish, j_next, j_end, j_end_reach, k, strCount) begin
		if(IOSM = ld_txtOutter and IO_Bus2IP_Mst_Cmplt = '1' and outter_mask(1) = '1' and outter_mask(0) = '1' and first_mask = "01") then
			txt_char_tmp_48 <= x"00000000"&IO_Bus2IP_MstRd_d(15 downto 0);
			txt_char_buf_valid_next <= '1';
		elsif(IOSM = ld_txtInner and (IO_Bus2IP_Mst_Cmplt = '1' or j_end_reach = '1')) then
			if(txt_char_buf_valid = '1') then
				txt_char_tmp_48 <= txt_char_buf&IO_Bus2IP_MstRd_d;
				if(j_next >= j_end and k >= strCount) then
					txt_char_buf_valid_next <= '0';
				else
					txt_char_buf_valid_next <= '1';
				end if;
			else	--(txt_char_buf_valid = '0') then
				txt_char_buf_valid_next <= '0';
				txt_char_tmp_48 <= IO_Bus2IP_MstRd_d&x"0000";
			end if;
		else
			txt_char_buf_valid_next <= '0';
			txt_char_tmp_48 <= (others => '0');
		end if;
	end process;
	
	outter_max <= max + 1 when(max(0) = '0') else
				  max;
	outter_cmp_size <= "10" when(IOSM = ld_txtOutter and outter_mask = "11") else
					   "01" when(IOSM = ld_txtOutter and (outter_2nd_match = '1' or outter_mask = "01" or outter_mask = "10")) else
					   "00";
	
	process(IO_Bus2IP_Mst_Cmplt, IOSM, first_mask, strCount, k, outter_mask, j, outter_cmp_size, j_rem) begin
		if(IO_Bus2IP_Mst_Cmplt = '1') then
			if(IOSM = ld_first) then
				if(first_mask(1 downto 0) = "11") then
					str_ld_size <= "10";
				elsif(first_mask(1 downto 0) = "10" or first_mask(1 downto 0) = "01") then
					str_ld_size <= "01";
				else
					str_ld_size <= "00";
				end if;
			elsif(IOSM = ld_str) then
				-- if((strCount - k) < 1) then
					-- str_ld_size <= "01"; 
				-- else
					str_ld_size <= "10"; 
				-- end if;
			else
				str_ld_size <= "00";
			end if;
		else
			str_ld_size <= "00";
		end if;
		
		if(IO_Bus2IP_Mst_Cmplt = '1') then
			if(IOSM = ld_txtInner or IOSM = ld_txtOutter) then
				if(j_rem = 0 or j_rem(init_n) = '1') then
					txt_ld_size <= "01";
				else
					txt_ld_size <= "10";
				end if;
			else
				txt_ld_size <= "00";
			end if;
		else
			txt_ld_size <= "00";
		end if;
	end process;
	
	outter_2nd_match <= outter_cmp(2) when(first_mask = "11" and outter_1st_match = '0') else
						'0';
	outter_1st_match <= '1' when(outter_cmp(3) = '1' and outter_cmp(0) = '1' and first_mask = "11") else
						'0';
	outer_first_na_1st <= outter_cmp(1) when(first_mask = "01") else
						  '0';
	outer_first_na_2nd <= outter_cmp(0) when(first_mask = "01") else
						  '0';
	
	outter_finish <= '1' when((outter_cmp(1) = '1' or outter_cmp(0) = '1') and strCount = 1 and first_mask = "01") else
					 '1' when((outter_cmp(3) = '1' or outter_cmp(2) = '1') and strCount = 1 and first_mask = "10") else
					 '1' when(outter_1st_match = '1' and strCount = 2) else
					 '0';
	
	inner_cmp <= '1' when(str_char_buf(47 downto 32) = txt_char_tmp_48(47 downto 32) and (--txt_char_buf_valid(1) = '0' or 
																						  str_char_buf_valid(1) = '0')) else
				 '1' when(str_char_buf(47 downto 16) = txt_char_tmp_48(47 downto 16)) else	 
				 '0';
	
	outter_cmp_tmp(3) <= '1' when(IO_Bus2IP_MstRd_d(31 downto 16) = first(31 downto 16)) else
						 '0';
	outter_cmp_tmp(2) <= '1' when(IO_Bus2IP_MstRd_d(15 downto 0) = first(31 downto 16)) else
					     '0';
	outter_cmp_tmp(1) <= '1' when(IO_Bus2IP_MstRd_d(31 downto 16) = first(15 downto 0)) else
					     '0';
	outter_cmp_tmp(0) <= '1' when(IO_Bus2IP_MstRd_d(15 downto 0) = first(15 downto 0)) else
						 '0';				 
	outter_cmp <= (outter_cmp_tmp(2)&outter_cmp_tmp(3)&outter_cmp_tmp(0)&outter_cmp_tmp(1)) and cmp_mask when(isLIO = '1') else	-- lastIndexOf
				  outter_cmp_tmp and cmp_mask;
	
	first_mask <= "11" when (strOffset(0) = '0' and strCount > 1) else
				  "10" when (strOffset(0) = '0' and strCount = 1) else
				  "01" when (strOffset(0) = '1') else
				  "00";
	outter_mask_next <= "01" when(isLIO = '1' and i(0) = '0' and (txtOffset(0) xor fromIndex_reg(0)) = '0') else	-- tail not aligned
				   "11" when(isLIO = '1' and (max - i) > 1) else
				   "10" when(isLIO = '1' and (max - i) = 1 and txtOffset(0) = '1') else
				   "01" when (i(0) = '1') else
				   "11" when (i(0) = '0' and ((txtCount - i) > 1)) else
				   "10" when (i(0) = '0' and (txtCount - i) = 1) else
				   "00";
	finish <= '1' when(IOSM /= idle and IOSM_next = idle) else '0';
	IOCmplt <= finish_delay;
	-- cs debug 
	with IOSM select
		debug_IOSM <= "0000" when idle,
				"0001" when ld_txtCount, 
				"0010" when ld_strCount, 
				"0011" when ld_txtOffset, 
				"0100" when ld_strOffset, 
				"0101" when ld_txtCharAry, 
				"0110" when ld_strCharAry, 
				"0111" when ld_first, 
				"1000" when ld_txtOutter, 
				"1001" when ld_str, 
				"1010" when ld_txtInner,
				"1111" when others;
	
end architecture rtl;