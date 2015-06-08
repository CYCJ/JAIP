------------------------------------------------------------------------------
-- Filename     :       Cache_controller.vhd
-- Version      :       1.00
-- Author       :       Jeff Wang
-- Date         :       Mar. 2013
-- VHDL Standard:       VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.                              **
-- ** Multimedia Embedded System Lab, NCTU.                                 **
-- ** Department of Computer Science and Information engineering            **
-- ** National Chiao Tung University, Hsinchu 300, Taiwan                   **
-- ***************************************************************************

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.ALL;
use ieee.std_logic_arith.all;

--WRITE_STRATEGY  0:write_through 1:copy_back
entity Cache_controller is
	generic (
		CPU_DATA_WIDTH	:	integer		:=32;	
		TAG_SIZE		:	integer		:=13;	
		INDEX_SIZE		:	integer		:=8;	
		OFFSET_SIZE		:	integer		:=5;	
		ASSOCIATIVITY	:	positive	:=2;
		WRITE_STRATEGY	:	integer		:=1 
	);
	port (
	
		clk						      :	in	std_logic;
		rst						      :	in	std_logic;
		cache_mem_flush			      : in	std_logic;
		cache_read				      :	in	std_logic;			
		cache_write 			      :	in	std_logic; 
		cache_address			      :	in	std_logic_vector (TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto 0);
		cache_data_in			      :	in	std_logic_vector (CPU_DATA_WIDTH-1	downto	0);		
		cache_forMst_Type             :	out	std_logic;		
		cache_cmplt				      :	out	std_logic;		
		cache_data_out			      :	out	std_logic_vector (CPU_DATA_WIDTH-1 downto 0);	

--------------------------------------------------------------------------------------
--                     for memory port use                               -------------
--------------------------------------------------------------------------------------
		Cmem_B2IP_CmdAck		      : in  std_logic;			
		Cmem_B2IP_Wrdst_rdy_n         : in  std_logic;	
        Cmem_ready				      : in  std_logic; 	
		Cmem_complt                   : in  std_logic; 
		Cmem_IP2B_Mst_BE              : in  std_logic_vector (3 downto 0);			
        Cmem_data_in				  : in  std_logic_vector (CPU_DATA_WIDTH-1 downto 0);	
		
		Cmem_IP2B_Wrsof_n             : out std_logic;	
		Cmem_IP2B_Wreof_n		      : out std_logic;
		Cmem_IP2B_Wrsrc_rdy_n         : out std_logic;
        Cmem_write			          : out std_logic; 	
        Cmem_read			 	      : out std_logic;		
        Cmem_write_data               : out std_logic_vector (CPU_DATA_WIDTH-1 downto 0);	
        Cmem_addr				      : out std_logic_vector ( 31 downto 0);
		-- for multicore coordinator, and cache coherence , 2013.10.1
		COOR2JAIP_rd_ack              : in  std_logic;
		JAIP2COOR_cache_w_en          : out std_logic;
		JAIP2COOR_cache_r_en          : out std_logic;
		JAIP2COOR_info1_cache         : out std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
		JAIP2COOR_info2_cache         : out std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
		COOR2JAIP_wr_ack              : in  std_logic;
		COOR2JAIP_info1_cache         : in	std_logic_vector(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto 0);
		COOR2JAIP_info2_cache         : in	std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
		
		-- cs debug
        --debug_cs_cache_ctrl				:out std_logic_vector (97 downto 0);
		debug_cache_controller_data   : out std_logic_vector (35 downto 0)
	);
end Cache_controller;

architecture Behavioral of Cache_controller is


-------------------------------------------------------------------
--                     constant                                 ---
-------------------------------------------------------------------	
	constant CIdle				    : std_logic_vector (3 downto 0) :=  "0000";
	constant Analysis			    : std_logic_vector (3 downto 0) :=	"0001";
	constant RdFromMem		        : std_logic_vector (3 downto 0) :=	"0010";
	constant WB2mem				    : std_logic_vector (3 downto 0) :=	"0011";
	constant WT2mem				    : std_logic_vector (3 downto 0) :=	"0100";
    constant RdMemComplt            : std_logic_vector (3 downto 0) :=  "0101";
    constant WbMemComplt            : std_logic_vector (3 downto 0) :=  "0110";
    constant WT2MemComplt           : std_logic_vector (3 downto 0) :=  "0111";		
	constant CHitFinish		        : std_logic_vector (3 downto 0) :=	"1000";	
	constant Checkset			    : std_logic_vector (3 downto 0) :=	"1010";	
	constant Start_flush			: std_logic_vector (3 downto 0) :=	"1011";	
-------------------------------------------------------------------
--                      integer                                 ---
-------------------------------------------------------------------	
	signal offset_val 				: integer;	
	signal victum_entry_index		: integer range	0 to 1 := 1;
	signal victum_entry_index_R		: integer range	0 to 1 := 0;
	signal flush_index		        : integer range	0 to 1 := 1;
	signal flush_index_R	        : integer range	0 to 1 := 0;	
	signal target_index_num 	    : integer range	0 to 1 := 1; --for cache_hit and it will record it index
	signal target_index_num_R 	    : integer range	0 to 1 := 0;
	signal TR_counter			    : integer range	0 to 9 := 0;
	signal WB_counter			    : integer range	0 to 9 := 0; --for WB2mem and flush 							
	signal WB_counter_w			    : integer range	0 to 9 := 0; --for WB2mem and flush 							



	signal cache_hit		        : std_logic;
	signal cache_hit_reg         :std_logic;
	signal cache_write_temp         : std_logic;
	signal cacheWrite               : std_logic;
	signal Cmem_writeB              : std_logic;
	signal cache_enable             : std_logic;
	signal flush_cmplt              : std_logic;
	signal flush_reg                : std_logic;--record the  flush signal because flush signal has just 1 cycle
	signal cache_hit_entry			: std_logic_vector (1 downto 0);
	signal TR_counter_SLV			: std_logic_vector (2 downto 0);	
	signal counter 				    : std_logic_vector (3 downto 0);  
	signal Cmem_IP2B_Mst_BE_R       : std_logic_vector (3 downto 0);	
	signal main_ctrl_state		    : std_logic_vector (3 downto 0);
	signal state_nxt              	: std_logic_vector (3 downto 0);		
	signal mem_flush_set            : std_logic_vector (INDEX_SIZE-1 downto 0);
	signal cache_data_in_temp       : std_logic_vector ( 31 downto 0);
	signal cache_data               : std_logic_vector ( 31 downto 0);	
	signal cache_data_out_reg	    : std_logic_vector ( 31 downto 0);
  --signal cache_address_R	        : std_logic_vector (13 downto 0);	
    signal cache_addReg			    :std_logic_vector (TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto 0);		
			
-------------------------------------------------------------------
--       for cache storage (block RAM logic) use                ---
-------------------------------------------------------------------
	type type_cacheMB_we				is array (ASSOCIATIVITY-1 downto 0) of std_logic_vector(5 downto 0);
	type type_cacheMB_set_index			is array (ASSOCIATIVITY-1 downto 0) of std_logic_vector (INDEX_SIZE-1 downto 0);
	type type_cacheMB_dirty 			is array (ASSOCIATIVITY-1 downto 0) of std_logic;
	type type_cacheMB_reference  		is array (ASSOCIATIVITY-1 downto 0) of std_logic;
	type type_cacheMB_valid      		is array (ASSOCIATIVITY-1 downto 0) of std_logic;			
	type type_cacheMB_tag    			is array (ASSOCIATIVITY-1 downto 0) of std_logic_vector (TAG_SIZE-1 downto 0);
	type type_cacheMB_data_in  			is array (ASSOCIATIVITY-1 downto 0) of std_logic_vector (CPU_DATA_WIDTH-1 downto 0);
	--type type_cacheMB_data_out  		is array (ASSOCIATIVITY-1 downto 0) of std_logic_vector (2**(OFFSET_SIZE+3)-1 downto 0);
	type type_cacheMB_data_out  		is array (ASSOCIATIVITY-1 downto 0) of std_logic_vector (CPU_DATA_WIDTH-1 downto 0);

		
	signal cacheMB_we				:type_cacheMB_we;
	signal cacheMB_set_index		:type_cacheMB_set_index;
	signal cacheMB_valid_in			:type_cacheMB_valid;
	signal cacheMB_dirty_in			:type_cacheMB_dirty;
	signal cacheMB_reference_in	    :type_cacheMB_reference;
	signal cacheMB_tag_in			:type_cacheMB_tag;
	signal cacheMB_data_in			:type_cacheMB_data_in;
	signal cacheMB_valid_out		:type_cacheMB_valid;
	signal cacheMB_dirty_out		:type_cacheMB_dirty;
	signal cacheMB_reference_out	:type_cacheMB_reference;
	signal cacheMB_tag_out			:type_cacheMB_tag;
	signal cacheMB_data_out			:type_cacheMB_data_out;	 	
	signal cache_offset	   			:	std_logic_vector (2 downto 0); 	

	-- for multi-core coordinator, cache coherence use , 2013.10.1
	signal	COOR2JAIP_wr_ack_dly      : std_logic;
	signal	COOR2JAIP_wr_cmplt        : type_cacheMB_valid;
	signal	COOR2JAIP_info1_cache_dly : std_logic_vector(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto 0);
	signal	COOR2JAIP_info2_cache_dly : std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
	
	component cache_storage
		generic (
			CPU_DATA_WIDTH	:	integer;
			TAG_SIZE		:   integer;
			INDEX_SIZE		:	integer;
			OFFSET_SIZE		:	integer;
			ASSOCIATIVITY	:	integer;
			WRITE_STRATEGY	:	integer
		);
		port(
			        
			clk				   : in std_logic;
			rst                : in std_logic;
			-- for port A
			we				   : in std_logic_vector(5 downto 0);
			set_index 		   : in std_logic_vector(INDEX_SIZE-1 downto 0);
			Cmem_IP2B_Mst_BE   : in std_logic_vector(3 downto 0); 
			counter			   : in std_logic_vector(3 downto 0); 				
			valid_in		   : in std_logic;
			reference_in	   : in std_logic;
			dirty_in		   : in std_logic;
			tag_in			   : in std_logic_vector (TAG_SIZE-1 downto 0) ;			
			data_in			   : in std_logic_vector (CPU_DATA_WIDTH-1 downto 0) ;
			cache_offset	   : in std_logic_vector(2 downto 0); 
			-- for port B , cache coherence use , 2013.10.1
			COOR2JAIP_wr_ack_dly      : in  std_logic;
			COOR2JAIP_wr_cmplt        : out std_logic;
			COOR2JAIP_info1_cache_dly : in	std_logic_vector(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto 0);
			COOR2JAIP_info2_cache_dly : in	std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
			
			valid_out		   : out std_logic;
			reference_out	   : out std_logic;
			dirty_out		   : out std_logic;
			tag_out			   : out std_logic_vector (TAG_SIZE-1 downto 0) ;			
			--data_out		   : out std_logic_vector (2**(OFFSET_SIZE+3)-1 downto 0)
			data_out		: out std_logic_vector (CPU_DATA_WIDTH-1 downto 0) 
		);
	end component cache_storage;	

begin


    G1 : for idx in 0 to 1 generate
        bramobj : cache_storage
		generic map (
			CPU_DATA_WIDTH		=> CPU_DATA_WIDTH,
			TAG_SIZE			=> TAG_SIZE,
			INDEX_SIZE 			=> INDEX_SIZE,
			OFFSET_SIZE			=> OFFSET_SIZE,
			ASSOCIATIVITY 		=> ASSOCIATIVITY,
			WRITE_STRATEGY		=> WRITE_STRATEGY
		)
		port map(
			clk 				=> clk ,
			rst                 => rst,
			-- for port A
			we 					=> cacheMB_we(idx), -- for enable data into cache
			set_index 			=> cacheMB_set_index(idx),
			counter				=> counter,			
			valid_in			=> cacheMB_valid_in(idx),
			reference_in 		=> cacheMB_reference_in(idx),
			dirty_in			=> cacheMB_dirty_in(idx),
			tag_in 				=> cacheMB_tag_in(idx),
			data_in 			=> cacheMB_data_in(idx),
			cache_offset		=> cache_offset,  -- modified by T.H.Wu , 2013.9.26, for simplifying logic
			
			-- for port B , cache coherence use , 2013.10.1
			COOR2JAIP_wr_ack_dly      =>	COOR2JAIP_wr_ack_dly,
			COOR2JAIP_wr_cmplt        =>	COOR2JAIP_wr_cmplt(idx),
			COOR2JAIP_info1_cache_dly =>	COOR2JAIP_info1_cache_dly,
			COOR2JAIP_info2_cache_dly =>	COOR2JAIP_info2_cache_dly,
			-- output
			valid_out 			=> cacheMB_valid_out(idx),
			reference_out 		=> cacheMB_reference_out(idx),
			dirty_out 			=> cacheMB_dirty_out(idx),
			tag_out 			=> cacheMB_tag_out(idx),
			Cmem_IP2B_Mst_BE    => Cmem_IP2B_Mst_BE_R,  			
			data_out			=> cacheMB_data_out(idx)
		);
    end generate G1;		

    cache_forMst_Type <= '0' when  main_ctrl_state = WT2mem  else '1';  --WT2mem is used single write          
	
	
	
	Cmem_IP2B_Wrsof_n  <= '0' when (main_ctrl_state = WB2mem and WB_counter =0)  or
                                   main_ctrl_state = WT2mem or
								   (main_ctrl_state = Start_flush and WB_counter =0) 
                     else '1' ;         
	Cmem_IP2B_Wreof_n  <= '0' when WB_counter = 7 or
                                   main_ctrl_state = WT2mem 
                     else '1' ;       
	Cmem_IP2B_Wrsrc_rdy_n <= '0' when (main_ctrl_state = WB2mem and WB_counter <8)  or
                                   main_ctrl_state = WT2mem or
								  ( main_ctrl_state = Start_flush and WB_counter <8)
                        else '1';
    
	cache_data   <= cache_data_in_temp;    	
	cacheWrite   <= cache_write_temp;    	
        -- will be modified in future , not now , by T.H.Wu ,  2013.7.25
        -- while read / write request is active , we should keep cacheMB_set_index unchanged
	cacheMB_set_index(0) <=mem_flush_set when flush_reg = '1' else
						   cache_address(INDEX_SIZE+OFFSET_SIZE-1 downto OFFSET_SIZE);
	cacheMB_set_index(1) <=mem_flush_set when flush_reg = '1' else
	                       cache_address(INDEX_SIZE+OFFSET_SIZE-1 downto OFFSET_SIZE);
						   
	-- modified by T.H.Wu , 2013.9.26, for simplifying logic, and a bug found here, for timing issue
    cache_offset	<=			conv_std_logic_vector(WB_counter_w,3) when	main_ctrl_state = WB2mem or main_ctrl_state = Start_flush
						--else	cache_addReg (OFFSET_SIZE-1 downto 2); -- (4 downto 2)
						else	cache_address (OFFSET_SIZE-1 downto 2); -- (4 downto 2)
	
	
	counter		<=			"0" & std_logic_vector(to_unsigned(WB_counter_w,3))	when (main_ctrl_state = WB2mem) or (main_ctrl_state = Start_flush)
					else	std_logic_vector(to_unsigned(TR_counter,4)) ; 

	cache_hit	<=	'1' when
						(cache_hit_entry(1)='1' or cache_hit_entry(0)='1') and
						(main_ctrl_state=Analysis) else
					--'1'	when
						-- Cmem_complt ='1'and state_nxt = CIdle else --main_ctrl_state=CHitFinish 
					'0';
					
	cache_cmplt	<=	'1' when main_ctrl_state=CHitFinish  or 
							(Cmem_complt ='1' and state_nxt = CIdle and cache_enable ='1') or
							flush_cmplt = '1'else							
					'0';								
		
	target_index_num <= 1 when  (cache_hit_entry(1)='1') else
						0;
						
	cache_hit_entry(0) <= '1' when (cache_addReg(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto INDEX_SIZE+OFFSET_SIZE) = cacheMB_tag_out(0) and cacheMB_valid_out(0) = '1' ) else
						  '0';
	
	cache_hit_entry(1) <= '1' when (cache_addReg(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto INDEX_SIZE+OFFSET_SIZE) = cacheMB_tag_out(1) and cacheMB_valid_out(1) = '1' ) else
						  '0';
						  
   -- flush_cmplt <= '1' when (mem_flush_set = "111111" and cacheMB_dirty_out(0)/= '1' and cacheMB_dirty_out(1)/='1')and main_ctrl_state=Checkset else '0';
	
							 -- modified by C.C. Hsu	
	offset_val <= to_integer(IEEE.numeric_std.unsigned(cache_address(OFFSET_SIZE-1	downto 2)));
	-- offset_val <= to_integer(unsigned(cache_address(OFFSET_SIZE-1	downto 2))) when  cache_address(1 downto 0) ="00" else
				  -- to_integer(unsigned(cache_address(OFFSET_SIZE-1	downto 2)))+1;

	victum_entry_index_R <= 1 when (victum_entry_index = 0) else 0;
	target_index_num_R   <= 1 when (target_index_num = 0) else 0;
	flush_index_R        <= 1 when (flush_index = 0) else 0;
	
	
		-- added for multicore coordinator , 2013.9.26
		JAIP2COOR_cache_w_en	<=	'1'	when	main_ctrl_state = WT2MemComplt and Cmem_complt = '1'	else '0';
		JAIP2COOR_cache_r_en	<=	'1'	when	cache_read = '1' or (main_ctrl_state = Analysis and cacheWrite = '0') else '0';
		JAIP2COOR_info1_cache	<=	"010111" & cache_address	when cache_read = '1' else
									(others => '0') when main_ctrl_state = CIdle else 
									"010111" & cache_addReg; 
									-- there may be a problem, check it first if cache controller catch the wrong address, 2013.9.25
		JAIP2COOR_info2_cache    <=	 cache_data_in_temp;
		--JAIP2COOR_cache_w_en	<=	'0';
		--JAIP2COOR_cache_r_en	<=	'0';
		--JAIP2COOR_info1_cache	<=	(others => '0') ;
		--JAIP2COOR_info2_cache   <=	(others => '0') ;
		
		
		
	
--cache_addReg
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
            cache_addReg   <= (others=>'0');
        else
		    cache_addReg   <= cache_address;
		end if;
		end if;
    end process;
	
	DR_reg :
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
            main_ctrl_state   <= CIdle;
        else
			main_ctrl_state   <= state_nxt;
		end if;
		end if;
    end process;
-------------------------------------------------------------------
--				main_ctrl_state     			                ---
-------------------------------------------------------------------				
	main_ctrl_state_change : 
	process (cache_write , cache_address, cache_read,cache_write,state_nxt,cache_hit,WB_counter,cacheWrite,
			 main_ctrl_state,TR_counter,flush_reg,cacheMB_dirty_out,mem_flush_set, Cmem_complt,Cmem_B2IP_CmdAck)	-- clk
	begin
		
			case main_ctrl_state is
					when CIdle =>
					    if (flush_reg = '1' and WRITE_STRATEGY = 1) then
							state_nxt <=Checkset;
						else	
							if ((cache_write or cache_read)='1' ) then
								state_nxt <= Analysis; 
							else
								state_nxt <= CIdle;
							end if;
						end if;	
					when Analysis => 
						if (cacheWrite='0') then -- this is read request
							if(COOR2JAIP_rd_ack = '0') then 	-- by fox, added for multicore coordinator , 2013.9.25
								state_nxt <= Analysis;
							elsif (cache_hit='1') then --read hit
								state_nxt <= CHitFinish;	
							elsif(cacheMB_dirty_out(victum_entry_index)='1') then
								state_nxt <= WB2mem;								
							else 					-- read miss
								state_nxt <= RdFromMem;
							end if;
						else
							if (cache_hit='1') then --write hit
								if (WRITE_STRATEGY=1) then --wirte_back
								    state_nxt <= CHitFinish; 
								else
									state_nxt <= WT2mem;
								end if;	
							else					--write miss
								if  (WRITE_STRATEGY=1) then
									if (cacheMB_dirty_out(victum_entry_index)='1') then
										state_nxt <= WB2mem;
									else 
										state_nxt <= RdFromMem;
									end if;	
								else
									state_nxt <= RdFromMem;
								end if;	
							end if;									
						end if;
					when WT2mem =>
						if(Cmem_B2IP_CmdAck = '1') then
						    state_nxt <= WT2MemComplt;
						else
							state_nxt <= WT2mem;
						end if;	

					when WT2MemComplt => 
						if (Cmem_complt = '1') then
							state_nxt <= CIdle;							
						else
							state_nxt <= WT2MemComplt;
						end if;							
					
					
					when WB2mem => 
						if (WB_counter = 8) then
							state_nxt <= WbMemComplt;							
						else
							state_nxt <= WB2mem;
						end if;		

					when WbMemComplt => 
					    if (flush_reg='0') then
						    if (Cmem_complt = '1') then
							    state_nxt <= RdFromMem;							
						    else
							    state_nxt <= WbMemComplt;
						    end if;	
						else
						    if (Cmem_complt = '1') then
							    state_nxt <= Checkset;							
						    else
							    state_nxt <= WbMemComplt;
						    end if;	
						end if;			
						
					when RdFromMem => 
						if (TR_counter = 8) then
						  --  if (WRITE_STRATEGY =1 or cacheWrite='0') then
						   state_nxt <= RdMemComplt;
							--else--state_nxt <= WT2mem;								
						else
							state_nxt <= RdFromMem;
						end if;
						
					when RdMemComplt => 
						if (Cmem_complt = '1') then
							if (WRITE_STRATEGY =1) then
							    state_nxt <= CIdle;		
							else--WRITE_STRATEGY =0
								if (cacheWrite ='1') then
									state_nxt <= WT2mem;
								else--read request
									state_nxt <= CIdle;
								end if;	
							end if;	
						else
							state_nxt <= RdMemComplt;
						end if;						
					
					
					when CHitFinish => 
							state_nxt <= CIdle;	
					--for flush			
					when Checkset =>						
						if (flush_cmplt = '1') then --current is 110
							state_nxt <=CIdle;
						else
							if (cacheMB_dirty_out(0) = '1' or cacheMB_dirty_out(1) = '1') then
								state_nxt <= Start_flush;
							else
								state_nxt <=Checkset;
							end if;
						end if;	
						
					when Start_flush =>
						if (WB_counter = 8)  then 
							state_nxt<=WbMemComplt;
						else
							state_nxt<=Start_flush;
						end if;
					when others => 
							state_nxt <= CIdle;
						
				end case;
	end process main_ctrl_state_change;

	--at rising_edge it will be trigger in the next time.....
	do_thing_in_main_ctrl_state:
	process (clk, Rst,state_nxt) 

	begin
	
		if(Rst = '1') then
		    mem_flush_set <=(others => '0');
			--Cmem_read <='0';
		elsif(rising_edge(clk)) then 
		
				-- because it will be unsigned so it must write like below
                if (cacheMB_dirty_out(0)/= '1' and cacheMB_dirty_out(1)/='1'and mem_flush_set/="11111111"and main_ctrl_state=Checkset) then
					mem_flush_set <= mem_flush_set + '1';
				elsif (main_ctrl_state=CIdle)then
					mem_flush_set <=(others => '0');
				else
					mem_flush_set <=mem_flush_set;
				end if;				    	
					
                  --it must be descided in analysis ,otherwise it will change durning unspect area.
			if (state_nxt=Analysis) then  --when determin state_nxt is Analysis  ,because it will quickly prepare data for the cache
				if ((cacheMB_valid_out(0)/='1' and cacheMB_valid_out(1)='1')  or 
				   (cacheMB_reference_out(0)/='1' and cacheMB_reference_out(1)='1') or
				   (cacheMB_dirty_out(0)/='1'and cacheMB_dirty_out(1)='1')) then
					victum_entry_index <= 0;
				else
					victum_entry_index <= 1;
				end if;		
			end if;			
		end if;
	end process;

							
-------------------------------------------------------------------
--				below is write2cache 							---
-------------------------------------------------------------------	
-- we(0) valid_in we(1) dirty_in  we(2) reference_in  we(3) tag_in  we(4) data_in 	
  write2cache :  
  process(Cmem_ready,cache_hit_reg, main_ctrl_state,Cmem_data_in,cache_address,victum_entry_index,WB_counter, cacheWrite, flush_reg
          ,victum_entry_index_R,cache_data,target_index_num,target_index_num_R)
  begin

	    if (flush_reg ='1') then--flush is the first considering
			--when counter =7 it means it flushing now and can set the dirty bit. do not set to 8 ,because it too late
			if (main_ctrl_state =Start_flush and WB_counter =7) then
				cacheMB_dirty_in(flush_index) <= '0';
				cacheMB_we(flush_index)   <= "000010";
				cacheMB_we(flush_index_R) <= "000000";
			else
				cacheMB_we(0) <= "000000";	
				cacheMB_we(1) <= "000000";				
			end if;
		else	
			if (cacheWrite = '0') then
				if(main_ctrl_state = RdFromMem and Cmem_ready = '0') then ---read miss
					cacheMB_valid_in(victum_entry_index)		<= '1';
					cacheMB_dirty_in(victum_entry_index)		<= '0';
					cacheMB_reference_in(victum_entry_index)	<= '1';					
					cacheMB_tag_in(victum_entry_index)			<= cache_address(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto INDEX_SIZE+OFFSET_SIZE);
					cacheMB_data_in(victum_entry_index)			<= Cmem_data_in;
					cacheMB_we(victum_entry_index)   <= "011111";
					cacheMB_we(victum_entry_index_R) <= "000000";
				else
					cacheMB_we(0) <= "000000";	
					cacheMB_we(1) <= "000000";	
				end if;	
			else--write request
				if (main_ctrl_state = WT2mem ) then	--write_hit (ie, target_index_num)
					cacheMB_data_in(target_index_num) 		<= cache_data;
					cacheMB_dirty_in(target_index_num)		<= '0';	 
					cacheMB_we(target_index_num)   <= "110010";--w(5to4) it means it will write specify block (cache_offset decide)
					cacheMB_we(target_index_num_R) <= "000000";				
				elsif (cache_hit_reg = '1' or main_ctrl_state =RdMemComplt ) then	
				--RdMemComplt is for cache write miss use and cache_hit is for cache write hit use
					cacheMB_data_in(target_index_num) 		<= cache_data;
					cacheMB_dirty_in(target_index_num)		<= '1';--6.9 modify
					cacheMB_we(target_index_num)   <= "110010";	 --w(5to4) it means it will write specify block (cache_offset decide)	
					cacheMB_we(target_index_num_R) <= "000000";					
				--write miss (when go into RdFromMem it means cache write miss or cache read miss) 
				elsif(main_ctrl_state = RdFromMem and Cmem_ready = '0') then
					cacheMB_valid_in(victum_entry_index)		<= '1';						
					cacheMB_reference_in(victum_entry_index)	<= '1';					
					cacheMB_tag_in(victum_entry_index)			<= cache_address(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto INDEX_SIZE+OFFSET_SIZE);	
					cacheMB_data_in(victum_entry_index)			<= Cmem_data_in;		

					if(WRITE_STRATEGY = 1) then
						cacheMB_dirty_in(victum_entry_index)		<= '1';
					else
						cacheMB_dirty_in(victum_entry_index)		<= '0';
					end if;	
					cacheMB_we(victum_entry_index)   <= "011111";	
					cacheMB_we(victum_entry_index_R) <= "000000";	
				--write hit(v,tag have have been written when miss)	,at this moment the state is cache_finish	

				else
					cacheMB_we(0) <= "000000";	
					cacheMB_we(1) <= "000000";	
				end if;		
			end if;
		end if;	
			

			
  end process;			
	
-------------------------------------------------------------------
--				below is cache_WB2memory	or Cmem_write data  ---
-------------------------------------------------------------------			
  c_WB2mem :  
  process(main_ctrl_state,Cmem_data_in,cache_address,victum_entry_index,WB_counter,cache_data)
  begin


--when Start_flush it will write to mem just like WB2mem
		-- modified by T.H.Wu , 2013.9.26, for simplifying logic
		if(main_ctrl_state = WB2mem and WB_counter <8) then ---read miss				
            --Cmem_write_data <= cacheMB_data_out(victum_entry_index)(32*(WB_counter )+CPU_DATA_WIDTH-1 downto 32*(WB_counter ));
            Cmem_write_data <= cacheMB_data_out(victum_entry_index) ;
		elsif (main_ctrl_state = Start_flush and WB_counter<8) then
			--Cmem_write_data <= cacheMB_data_out(flush_index)(32*(WB_counter)+CPU_DATA_WIDTH-1 downto 32*(WB_counter ));
			Cmem_write_data <= cacheMB_data_out(flush_index) ;
		else		
	        Cmem_write_data <= cache_data;	
		end if;			
		
  end process;		

	
-------------------------------------------------------------------
--				below is control memory							---
-------------------------------------------------------------------		
-- read and write have counter <6 because the eof will be correct.(when it count to 7 it will be trigger.)
	Cmem_write <= '1' when  (Cmem_writeB ='1') or 
	                       (main_ctrl_state = WT2mem) else
						  -- (main_ctrl_state = Start_flush and WB_counter <6 )	else
				  '0';
	-- Cmem_read <='1' when  (cache_hit= '0' and main_ctrl_state=Analysis and cacheWrite ='0' )  or 
						  -- ( main_ctrl_state=RdFromMem and TR_counter<6) 
						   -- else
				-- '0';	

  process (clk,Rst,state_nxt,main_ctrl_state) is
  begin
	     if(Rst = '1') then
			    Cmem_read           <= '0'; 
				Cmem_writeB         <= '0';
				cache_enable        <= '0';
		   elsif (rising_edge (clk)) then
			     if( (main_ctrl_state=Analysis and state_nxt =RdFromMem) 
				   or(main_ctrl_state=WbMemComplt and state_nxt =RdFromMem) )then --modified 4/23
				      Cmem_read       <= '1';
			     elsif( Cmem_B2IP_CmdAck = '1')then
				      Cmem_read       <= '0';
				 end if;
                --modified 4/23
			     if((main_ctrl_state= Analysis and state_nxt =WB2mem) or ( main_ctrl_state= Checkset and state_nxt = Start_flush ))then
				      Cmem_writeB       <= '1';
			     elsif( Cmem_B2IP_CmdAck = '1')then
				      Cmem_writeB       <= '0';
				 end if;			

                --add 6/28
                if(cache_read ='1' or cache_write ='1') then
					cache_enable <='1';
				elsif (state_nxt = CIdle) then
					cache_enable <='0';
				end if;	
		   end if; 
  end process;
-------------------------------------------------------------------
--				below is cache_output 							---
-------------------------------------------------------------------							 
  cache_data_out <= cache_data_out_reg;				
  process (clk) is begin
	if (rising_edge (clk)) then	
	    if(Rst = '1') then
				 cache_data_out_reg <= (others => '0');
		else 
				-- modified by T.H.Wu , 2013.9.26, for simplifying logic
				-- modified by C.C. Hsu
				if(state_nxt = CHitFinish) then
					--cache_data_out_reg <= cacheMB_data_out(target_index_num)((32*offset_val)+(CPU_DATA_WIDTH-1) downto 32*offset_val); 
					--						--when Cmem_complt = '1'  else		
					cache_data_out_reg <= cacheMB_data_out(target_index_num); 		
				elsif(Cmem_ready = '0' and TR_counter_SLV = cache_address(4 downto 2)) then
					cache_data_out_reg <= Cmem_data_in;
				end if; 
		end if; 
	end if; 
  end process;  
  -- Add by C.C. Hsu
  TR_counter_SLV <= conv_std_logic_vector(TR_counter, 3);
	
   process(clk) begin
		if (rising_edge(clk)) then	
        if(Rst = '1') then
			cache_write_temp    <='0';
			cache_data_in_temp  <=(others=>'0');
			Cmem_IP2B_Mst_BE_R  <="0000";
			flush_reg           <='0';
			flush_index        <=1;
			flush_cmplt        <='0';
			cache_hit_reg     <='0';
        else
		    if (main_ctrl_state= CIdle) then--(state_nxt = Analysis) or (state_nxt = CIdle)
				cache_write_temp   <= cache_write;
			    cache_data_in_temp <= cache_data_in ;
				Cmem_IP2B_Mst_BE_R   <=Cmem_IP2B_Mst_BE;		
				--cache_address_R <= cache_address; 
			end if;				
			
			if(cache_mem_flush ='1') then
				flush_reg <='1';
			elsif(flush_cmplt ='1')	then
				flush_reg <='0';
			end if;

			if( cacheMB_dirty_out(0) ='1') then
				flush_index <=0;
			else
				flush_index <=1;
			end if;
			
			if ((mem_flush_set = "11111111" and cacheMB_dirty_out(0)/= '1' and cacheMB_dirty_out(1)/='1')and main_ctrl_state=Checkset) then
				flush_cmplt<='1';
			else
				flush_cmplt<='0';
			end if;
			
			if(cache_hit='1' ) then
				cache_hit_reg<='1';
			else
				cache_hit_reg<='0';
			end if;	
		end if;
		end if;
    end process;
	
-------------------------------------------------------------------
--				counter                 						---
-- because to simulate mem_data_rady so use clk 
-- so....data will assign at next cycle
-------------------------------------------------------------------	
   process(clk) begin
		if (rising_edge(clk)) then
        if(Rst = '1') then
            TR_counter  <= 0;
			WB_counter <= 0;
        else	
			case state_nxt is
				when RdFromMem=> 
					if (TR_counter <= 8 and Cmem_ready = '0') then--Cmem_ready = '0'
						TR_counter <= TR_counter + 1;
					else
						TR_counter <= 0;	
					end if;	 
				when others =>  
						TR_counter <= 0;
			end case;		
			WB_counter <= WB_counter_w;			
		end if;
		end if;
    end process;	
	
	
	 -- modified 2014.1.13, for write-back flushing and ML605
	process( WB_counter, state_nxt, Cmem_B2IP_Wrdst_rdy_n ) begin
		WB_counter_w	<=	WB_counter;
		case state_nxt is
			when WB2mem =>
					if (WB_counter <= 8) then--Cmem_ready = '0'
						if(Cmem_B2IP_Wrdst_rdy_n ='0') then
							WB_counter_w <= WB_counter + 1;
						else
							WB_counter_w <= WB_counter ;
						end if;	
					else
						WB_counter_w <= 0;	
					end if;	
					
			when Start_flush =>
					if (WB_counter <= 8) then--Cmem_ready = '0'
						if(Cmem_B2IP_Wrdst_rdy_n ='0') then
							WB_counter_w <= WB_counter + 1;
						else
							WB_counter_w <= WB_counter ;
						end if;	
					else
						WB_counter_w <= 0;	
					end if;	
			when others =>
					WB_counter_w <= 0;
		end case;
    end process;
		
-------------------------------------------------------------------
--				for calculate address      						---
-------------------------------------------------------------------	

   process(state_nxt,main_ctrl_state,mem_flush_set,cache_address) --WB_counter.TR_counter
   begin
        if(main_ctrl_state = WB2mem ) then
			Cmem_addr <= "010111"&cacheMB_tag_out(victum_entry_index)&cache_address(INDEX_SIZE+OFFSET_SIZE-1 downto 5)&"00000";			
		elsif ( main_ctrl_state = RdFromMem) then		
			Cmem_addr <= "010111"&cache_address(TAG_SIZE+INDEX_SIZE+OFFSET_SIZE-1 downto OFFSET_SIZE)&"00000";--13 downto 5 total:9bit
		elsif (main_ctrl_state = WT2mem) then --when write_through no mater what the cache hit or miss ,it must write back to mem for specify offset
			Cmem_addr <= "010111"&cache_address;
		elsif (main_ctrl_state =Start_flush) then
			Cmem_addr <= "010111"&cacheMB_tag_out(flush_index) & mem_flush_set (INDEX_SIZE-1 downto 0)&"00000";
		else
			Cmem_addr	<= (others=>'0');--just complete the full case
		end if;	

    end process;
	
-------------------------------------------------------------------
--				for flush                						---
-------------------------------------------------------------------	
    -- flush_index <= 0 when cacheMB_dirty_out(0) ='1' else				
				   -- 1;		   

	-- cs debug
	--debug_main_ctrl_state <= main_ctrl_state;
	
	
	
	
	
-------------------------------------------------------------------
-- for multi-core coordinator, cache coherence use , 2013.10.1
-------------------------------------------------------------------	
   process(clk) begin
		if (rising_edge(clk)) then
			----
			if(Rst = '1') then
				COOR2JAIP_wr_ack_dly      <=	'0';  
			else
				if(COOR2JAIP_wr_ack='1') then
					COOR2JAIP_wr_ack_dly      <=	'1';
				elsif(COOR2JAIP_wr_cmplt/="00") then
					COOR2JAIP_wr_ack_dly      <=	'0';
				end if;
			end if;  
			----
			if(COOR2JAIP_wr_ack='1') then
				COOR2JAIP_info1_cache_dly <=	COOR2JAIP_info1_cache; 
				COOR2JAIP_info2_cache_dly <=	COOR2JAIP_info2_cache;
			end if;
		end if;  
    end process;	
    
-------------------------------------------------------------------
-- for chipscope debug 
-------------------------------------------------------------------
   --debug_cs_cache_ctrl (3 downto 0) <= 	x"1" when main_ctrl_state = CIdle	
	--								else x"2" when main_ctrl_state =  Analysis 
	--								else x"3" when main_ctrl_state =  RdFromMem  
	--								else x"4" when main_ctrl_state =  WB2mem 
	--								else x"5" when main_ctrl_state =  WT2mem 
	--								else x"6" when main_ctrl_state =  RdMemComplt 
	--								else x"7" when main_ctrl_state =  WbMemComplt 
	--								else x"8" when main_ctrl_state =  WT2MemComplt 
	--								else x"9" when main_ctrl_state =  CHitFinish 
	--								else x"A" when main_ctrl_state =  Checkset 
	--								else x"B" when main_ctrl_state =  Start_flush 
	--								else x"F" ;
     
    --debug_cs_cache_ctrl (9 downto 4)   <= cacheMB_set_index(0) ;
	--debug_cs_cache_ctrl (15 downto 10) <= cacheMB_set_index(1) ;
	
	--debug_cs_cache_ctrl (47 downto 16) <=  cacheMB_data_out(0);
	--debug_cs_cache_ctrl (79 downto 48) <=  cacheMB_data_out(1);
	
	--debug_cs_cache_ctrl (82 downto 80) <=  cache_offset ;
	--debug_cs_cache_ctrl (85 downto 83) <=  cache_address(OFFSET_SIZE-1	downto 2) ;
	--debug_cs_cache_ctrl (89 downto 86) <=  conv_std_logic_vector(WB_counter , 4) ;
	
	--debug_cs_cache_ctrl (91 downto 90) <= cacheMB_we(0)(5 downto 4) ;
	--debug_cs_cache_ctrl (93 downto 92) <= cacheMB_we(1)(5 downto 4) ;
	
	
	--debug_cs_cache_ctrl (97 downto 94) <=  conv_std_logic_vector(TR_counter , 4) ;
	
    
	
end Behavioral;