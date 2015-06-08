------------------------------------------------------------------------------
-- Filename	:	stack_access_management.vhd
-- Version	:	1.00
-- Author	:	Hung-Cheng Su
-- Date		:	Nov 2012
-- VHDL Standard:	VHDL'93
------------------------------------------------------------------------------
--
-- ***************************************************************************
-- ** Copyright (c) 2007. All rights reserved.							**		
-- ** Multimedia Embedded System Lab, NCTU.								**  
-- ** Department of Computer Science and Information engineering			**
-- ** National Chiao Tung University, Hsinchu 300, Taiwan				**
-- ***************************************************************************


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity stack_access_management is
	generic(
		RAMB_S36_AWIDTH			: integer := 9;
		STACK_AREA_DDR_ADDRESS		: std_logic_vector(13 downto 0) := (X"5BF"&"11");
		BURST_LENGTH				: std_logic_vector(7 downto 0) 	:= X"40";  --byte
		Max_Thread_Number			: integer := 16
	);
	port(
		-- ctrl signal
		Rst						: in  std_logic;
		clk						: in  std_logic;
		bus_busy					: in  std_logic;
		
		stack_rw_cmplt				: out std_logic;
		thread_base					: in  std_logic_vector(Max_Thread_Number/4-1 downto 0);
		stack_length				: in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
		stack_rw_enable				: in  std_logic;
		sdram_rw_flag				: in  std_logic; -- 0=restore stack from sdram 1=backup stack to sdram
		
		-- (master) external memory access
		external_access_ack			: in  std_logic;
				external_access_cmplt			: in  std_logic;
				--external_load_data				: in  std_logic_vector(31 downto 0);
				prepare_stack_load_req		: out std_logic;
				stack_in_sdram_addr			: out std_logic_vector(15 downto 0);
		backup_stack_store_req		: out std_logic;
		stack_base					: out std_logic_vector (RAMB_S36_AWIDTH downto 0);
		parpare_stack				: out std_logic;
		stack_rw					: out std_logic
	);
end entity stack_access_management;

architecture rtl of stack_access_management is

	type STACK_SM_TYPE is(Idle, Check_Access_Request, Wait_Ack, SDRAM_Access, Done); 
	signal stk_mgt_state			: STACK_SM_TYPE;
	signal max_length		: std_logic_vector(RAMB_S36_AWIDTH downto 0);
	signal access_length	: std_logic_vector(RAMB_S36_AWIDTH downto 0);
	signal stack_base_tmp	: std_logic_vector(RAMB_S36_AWIDTH downto 0);
	signal access_type		: std_logic;
	signal ex_load_tmp		: std_logic;
	signal ex_load_reg		: std_logic;
	signal ex_store_tmp		: std_logic;
	signal ex_store_reg		: std_logic;
		-- modified by T.H.Wu , 2013.8.21 , for fixing one bug about main thread termination and its stack info backup/prepare
		signal stack_rw_enable_dly	: std_logic;
		signal stack_rw_enable_dly2   : std_logic;
		signal stack_rw_enable_dly3   : std_logic;
		signal stack_rw_enable_dly4   : std_logic;
	
	begin
	
	stack_rw_cmplt <= '1' when stk_mgt_state=Done else '0';
	
	stack_base		<= "00" & stack_base_tmp(RAMB_S36_AWIDTH downto 2);
	parpare_stack	<= '1' when stk_mgt_state=SDRAM_Access else '0';
	stack_rw		<= not access_type;
	
		-- modified by T.H.Wu , for test
	--stack_in_sdram_addr	<= STACK_AREA_DDR_ADDRESS + (thread_base & x"000") + stack_base_tmp ;
	stack_in_sdram_addr	<= thread_base  &  "00" & stack_base_tmp ;
	
	prepare_stack_load_req	<= not access_type	when stk_mgt_state = Wait_Ack or stk_mgt_state = SDRAM_Access else '0'; --ex_load_tmp or ex_load_reg;
	backup_stack_store_req	<= access_type		when stk_mgt_state = Wait_Ack or stk_mgt_state = SDRAM_Access else '0'; --ex_store_reg or ex_store_tmp;
	--external_load_req	<= access_type when stk_mgt_state=Check_Access_Request and bus_busy = '0' else '0';
	
	--external_store_req	<= access_type when stk_mgt_state=Check_Access_Request and bus_busy = '0' else '0';
	
	
	Main_FSM :
	process(clk, Rst) begin
		if(Rst = '1') then
			stk_mgt_state	<= Idle;
		elsif(rising_edge(clk)) then
			case stk_mgt_state is
				when Idle =>
					if (stack_rw_enable_dly4 = '1' ) then
						stk_mgt_state	<= Check_Access_Request; 
					else 
						stk_mgt_state	<= Idle;  
					end if ;	
					
				-- check bus is free? and access is complete?
				when Check_Access_Request =>
					if(stack_base_tmp(RAMB_S36_AWIDTH downto 2) < max_length) then
						if(bus_busy = '0') then
							stk_mgt_state	<= Wait_Ack;
						else
							stk_mgt_state	<= Check_Access_Request;
						end if;
					else
						stk_mgt_state	<= Done;
					end if;
				
				when Wait_Ack =>
					if (external_access_ack = '1') then
						stk_mgt_state <= SDRAM_Access;					
					else
						stk_mgt_state <= Wait_Ack;   
					end if ;
				
				when SDRAM_Access =>
					if(external_access_cmplt = '1') then
						stk_mgt_state	<= Check_Access_Request;
					else
						stk_mgt_state	<= SDRAM_Access;
					end if;
				
				when Done =>
						stk_mgt_state	<= Idle;

				when others => null ;
			end case;
		end if;
	end process;
	
	reg_Unit :
	process(clk) begin
		if(rising_edge(clk)) then
		if(Rst = '1') then
			stack_base_tmp	<= (others => '0');
			max_length		<= (others => '0');
			access_type		<= '1';
			stack_rw_enable_dly <= '0';
		else
		
				stack_rw_enable_dly <= stack_rw_enable;
				stack_rw_enable_dly2 <= stack_rw_enable_dly;
				stack_rw_enable_dly3 <= stack_rw_enable_dly2;
				stack_rw_enable_dly4 <= stack_rw_enable_dly3;
				
			case stk_mgt_state is
				when Idle =>
					if (stack_rw_enable_dly4 = '1' ) then
						max_length		<= stack_length;
						stack_base_tmp	<= (others => '0');
						access_type		<= sdram_rw_flag;
					else
						access_type		<= '1';
					end if ;	
					
				when SDRAM_Access =>
					if(external_access_cmplt = '1') then
						--stack_base_tmp	<= stack_base_tmp + BURST_LENGTH(7 downto 2);
						stack_base_tmp	<= stack_base_tmp + BURST_LENGTH;
					end if;
				when others => null ;
			end case;		
		end if;
		end if;
	end process;
	
	
	-- process(stk_mgt_state) begin
		-- if(stk_mgt_state=Wait_Ack or stk_mgt_state = SDRAM_Access) then
			-- ex_load_tmp		<= not access_type;
			-- ex_store_tmp	<= access_type;
		-- else
			-- ex_load_tmp		<= '0';
			-- ex_store_tmp	<= '0';
		-- end if;
	-- end process;
	
	-- ex_request_reg :
	-- process(clk, Rst) begin
		-- if(Rst = '1') then
			-- ex_load_reg		<= '0';
			-- ex_store_reg	<= '0';
		-- elsif(rising_edge(clk)) then
			-- if(stk_mgt_state=Check_Access_Request) then
				-- ex_load_reg		<= ex_load_tmp;
				-- ex_store_reg	<= ex_store_tmp;
			-- elsif(external_access_ack = '1') then
				-- ex_load_reg		<= '0';
				-- ex_store_reg	<= '0';			
			-- end if;
		-- end if;
	-- end process;
	
	
					
end architecture rtl;
