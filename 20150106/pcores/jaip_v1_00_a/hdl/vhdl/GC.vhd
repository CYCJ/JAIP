------------------------------------------------------------------------------
-- Filename	:	GC.vhd
-- Version	:	1.00
-- Author	:	Jun-Fu Wang
-- Date		:	2014
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
use ieee.std_logic_arith.all;

entity GC is
	generic(
		Table_bit				: integer := 9;
		TableS_bit				: integer := 11; 
		REF_bit					: integer := 22;
		SIZE_bit					: integer := 20;
		NEXT_bit					: integer := 11;
		COUNT_bit				: integer := 5;
		Meth_col_en				: integer := 1
	);
	port(
		Rst						: in  std_logic;
		clk						: in  std_logic;
		GC_Alloc_en				: in  std_logic;
		GC_Alloc_arr_en			: in  std_logic;
		GC_Null_en				: in  std_logic;
		GC_areturn_flag			: in  std_logic;
		GC_StackCheck_f				: in  std_logic;	
		GC_anewarray_flag		: in  std_logic;
		GC_Clinit_Stop			: in  std_logic; 
		GC_Mthd_Exit				: in  std_logic;
		GC_Mthd_Enter_f			: in  std_logic;
		GC_Mthd_Enter			: in  std_logic;
		GC_ext_wr_heap_ptr		: in  std_logic;
		GC_AllocSize				: in  std_logic_vector(15 downto 0);
		GC_reference				: in  std_logic_vector(REF_bit-1 downto 0);
		GC_current_heap_ptr_ext	: in  std_logic_vector(31 downto 0);
		GC_A						: in  std_logic_vector(31 downto 0);

		GC_cmplt					: out std_logic;
		GC_Current_Heap_Addr		: out std_logic_vector(31 downto 0);
		GC_Heap_Addr				: out std_logic_vector(31 downto 0) 
	);
end entity GC;

architecture rtl of GC is  

	component GC_table
		generic (
		REF_bit					: integer;
		SIZE_bit				: integer;
		NEXT_bit				: integer;
		COUNT_bit				: integer
		);
		port(
		Rst					: in  std_logic;
		clk						: in  std_logic;
		
		Addr_A					: in  std_logic_vector(TableS_bit-1 downto 0);
		WE_A					: in  std_logic; -- read/write control
		Data_In_A				: in  std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0);
		Data_Out_A				: out std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0);

		Addr_B					: in  std_logic_vector(TableS_bit-1 downto 0);	
		WE_B					: in  std_logic; 
		Data_In_B				: in  std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0);
		Data_Out_B				: out std_logic_vector(REF_bit+NEXT_bit+SIZE_bit+COUNT_bit-1 downto 0)			
		);
	end component GC_table;
		
-------------------------------------------------------------------
--					constant								---
-------------------------------------------------------------------	
	constant Idle					: std_logic_vector (4 downto 0) :=  "00000";
	constant SFreeSpace  			: std_logic_vector (4 downto 0) :=	"00011";
	constant BRAMAccess			: std_logic_vector (4 downto 0) :=  "00100";
	constant SReference  			: std_logic_vector (4 downto 0) :=	"00101";
	constant InsertRow				: std_logic_vector (4 downto 0) :=	"00110";
	constant UpdateGC				: std_logic_vector (4 downto 0) :=	"00111";
	constant Split				: std_logic_vector (4 downto 0) :=	"01000";
	constant WriteSplit				: std_logic_vector (4 downto 0) :=  "01001";
	constant BRAMAccessR			: std_logic_vector (4 downto 0) :=	"01010";
	constant CheckMerge			: std_logic_vector (4 downto 0) :=  "01101";
	constant Merge					: std_logic_vector (4 downto 0) :=  "01110";	
	constant EraseData			: std_logic_vector (4 downto 0) :=  "01111";
	constant WriteErase			: std_logic_vector (4 downto 0) :=  "10000";	
	constant ArrayAlloc			: std_logic_vector (4 downto 0) :=  "10001";
	constant SizeTooLess			: std_logic_vector (4 downto 0) :=  "10010";
	constant SizeTooLess_sec		: std_logic_vector (4 downto 0) :=  "10011";
	
	constant Finish				: std_logic_vector (4 downto 0) :=  "11111";
-------Method collection
	constant Idle_M				: std_logic_vector (3 downto 0) :=  "0000";
	constant PushMflag			: std_logic_vector (3 downto 0) :=  "0001";
	constant WaitRef				: std_logic_vector (3 downto 0) :=  "0010";
	
	constant PushRef				: std_logic_vector (3 downto 0) :=  "0011";
	constant PopRef				: std_logic_vector (3 downto 0) :=  "0100";
	constant SReference_M			: std_logic_vector (3 downto 0) :=  "0101";
	constant BRAMAccessR_M		: std_logic_vector (3 downto 0) :=  "0110";
	constant CheckRefEnd			: std_logic_vector (3 downto 0) :=  "0111";
	constant EraseCounter		: std_logic_vector (3 downto 0) :=  "1000";
	constant SearchStack			: std_logic_vector (3 downto 0) :=  "1001";
	constant SearchNext			: std_logic_vector (3 downto 0) :=  "1010";
	constant SearchFound			: std_logic_vector (3 downto 0) :=  "1011";
	constant EraseRefData		: std_logic_vector (3 downto 0) :=  "1100";
	constant WaitBram			: std_logic_vector (3 downto 0) :=  "1101";
	constant Normal_addr_pop_assign : std_logic_vector (3 downto 0) :=  "1110";
	
	constant Finish_M			: std_logic_vector (3 downto 0) :=  "1111";
	
	constant HOW_MANY_COLUMN		: integer := 2**(Table_bit);
	
	
-------------------------------------------------------------------
--					signal								---
-------------------------------------------------------------------
	signal c_state					: std_logic_vector (4 downto 0);
	signal n_state				: std_logic_vector (4 downto 0);
		
	
	signal Alloc_en_r			: std_logic;
	signal Alloc_arr_en_r		: std_logic;
	signal GC_anewarray_flag_r	: std_logic;
	signal Null_en_r				: std_logic;
	signal AllocSize_r			: std_logic_vector(SIZE_bit-1 downto 0);
	signal reference_r			: std_logic_vector(REF_bit-1 downto 0);
	
	signal SFinish				: std_logic;
	signal RFinish				: std_logic;
	signal RNotFound				: std_logic;
	signal SFound				: std_logic;
	signal UpdateGC_count		: std_logic_vector(4 downto 0);

	
	
	signal cur_GC_useaddr		: std_logic_vector(TableS_bit-1 downto 0);
	signal Search_addr			: std_logic_vector(TableS_bit-1 downto 0);
	signal merge_addr			: std_logic_vector(TableS_bit-1 downto 0);
	signal cur_GC_useaddr_full	: std_logic;
	
	signal GC_addr				: std_logic_vector(TableS_bit-1 downto 0);
	signal GC_write_en			: std_logic;
	signal GC_data_in			: std_logic_vector(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto 0);	
	signal GC_data_out			: std_logic_vector(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto 0);
	signal GC_data_out_r			: std_logic_vector(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto 0);

	signal Mthd_Addr				: std_logic_vector(TableS_bit-1 downto 0);
	signal Mthd_GC_data_out		: std_logic_vector(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto 0);
	signal Mthd_GC_data_in		: std_logic_vector(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto 0);	
	signal Mthd_WriteBRAM_en		: std_logic;
	signal Mthd_exitBuf_r		: std_logic;
	signal Mthd_enterBuf_r		: std_logic;
	signal GC_fake_enter_c		: std_logic_vector(4 downto 0);	
	
	signal cur_ref				: std_logic_vector(REF_bit-1 downto 0);
	signal cur_count				: std_logic_vector(COUNT_bit-1 downto 0);
	signal cur_size				: std_logic_vector(SIZE_bit-1 downto 0);
	signal cur_pre_pointer		: std_logic_vector(NEXT_bit-1 downto 0);
	signal pre_pointer			: std_logic_vector(NEXT_bit-1 downto 0);

	--this series of signals mean it is the previous data
	--we can use these signals to check the combination
	signal back_pre_pointer		: std_logic_vector(NEXT_bit-1 downto 0);
	signal back_count			: std_logic_vector(COUNT_bit-1 downto 0);
	signal back_size				: std_logic_vector(SIZE_bit-1 downto 0);
	signal back_reference		: std_logic_vector(REF_bit-1 downto 0);	
	signal merge_size			: std_logic_vector(SIZE_bit-1 downto 0);
	signal Rfini_addr			: std_logic_vector(TableS_bit-1 downto 0); 
	
	signal split_ref				: std_logic_vector(REF_bit-1 downto 0);
	signal split_size			: std_logic_vector(SIZE_bit-1 downto 0);
	signal split_pre_pinter		: std_logic_vector(NEXT_bit-1 downto 0);
	signal split_pre_size		: std_logic_vector(SIZE_bit-1 downto 0);
	
	signal current_heap_ptr		: std_logic_vector(REF_bit-1 downto 0);
	signal checklastaddr_count	: std_logic_vector(2 downto 0);
	signal WriteErase_table_en	: std_logic;
-------Method collection
	type RAM is array (HOW_MANY_COLUMN-1 downto 0) of std_logic_vector(REF_bit downto 0);	
	signal MEM: RAM := (others => (others => ('0')));	
	signal Addr						: std_logic_vector(Table_bit-1 downto 0);	
	signal PopAddr   				: std_logic_vector(Table_bit-1 downto 0);
	signal AretnAddr   				: std_logic_vector(Table_bit-1 downto 0);
	
	signal DataIN					: std_logic_vector(REF_bit downto 0);
	signal DataOut					: std_logic_vector(REF_bit downto 0);	
	signal Write_en					: std_logic; -- read/write control
	signal Mthd_Addr_reg			: std_logic_vector(TableS_bit-1 downto 0);

	signal c_state_M				: std_logic_vector (3 downto 0);
	signal n_state_M				: std_logic_vector (3 downto 0);
	
	signal current_pop_ref			: std_logic_vector(REF_bit downto 0);	
	signal areturn_pop_ref		: std_logic_vector(REF_bit downto 0); 
	signal temp_return_flag		: std_logic;
	signal GC_mth_writeRef		: std_logic;					
	signal Mthd_size				: std_logic_vector(SIZE_bit-1 downto 0);
	signal Mthd_pre_pointer		: std_logic_vector(NEXT_bit-1 downto 0);
	signal Mthd_ref				: std_logic_vector(REF_bit-1 downto 0);	
	signal GC_StackCheck_data	: std_logic_vector(31 downto 0);
	signal NoNeedStackCheck		: std_logic_vector(REF_bit-1 downto 0);
	signal Mthd_fini_count		: std_logic_vector(3 downto 0);
	signal Curr_mth_top_judge	: std_logic;  
	signal EraseRefData_delay	: std_logic;
	signal normal_last_sear_flag   : std_logic;
	signal R_counter			: integer range	0 to 127 := 0;
	signal Record_addr			: integer range	0 to 127 := 0;
	
	signal cur_useaddr_fst		: std_logic; 
	signal cur_useaddr_secd		: std_logic; 
	signal cur_useaddr_thd		: std_logic; 
	signal cur_useaddr_forth	: std_logic;
	
begin	
	
		garbageCollection_table :GC_table
		generic map(
		REF_bit					=>REF_bit,
		SIZE_bit				=>SIZE_bit,
		NEXT_bit				=>NEXT_bit,
		COUNT_bit				=>COUNT_bit
		)
		port map(
		Rst					=> Rst,
		clk						=> clk,
		Addr_A					=> GC_addr,
		WE_A					=> GC_write_en,
		Data_In_A				=> GC_data_in,
		Data_Out_A				=> GC_data_out,
		
		Addr_B				=> Mthd_Addr,
		WE_B					=> Mthd_WriteBRAM_en,
		Data_In_B				=> Mthd_GC_data_out,
		Data_Out_B				=> Mthd_GC_data_in
		);
		
	
-------------------------------------------------------------------
--					Finite-state-machine					---
-------------------------------------------------------------------
	process(clk) 
	begin
		if(rising_edge(clk)) then
		if(Rst = '1') then
			c_state   <= Idle;
		else
			c_state   <= n_state;
		end if;
		
		end if;
	end process;
	
	process(Alloc_en_r,reference_r,cur_count,back_reference,back_count,Null_en_r,RFinish,SFound,SFinish,c_state,checklastaddr_count,
			back_size,AllocSize_r,cur_size,cur_ref,GC_data_out,Alloc_arr_en_r,RNotFound,split_pre_size,GC_anewarray_flag_r)
	begin
		case c_state is
		when Idle =>
			if ((Alloc_arr_en_r='1' and GC_anewarray_flag_r='1') or cur_GC_useaddr_full='1') then--it will be the anewarray's newarray
				n_state <= ArrayAlloc;
			elsif(Alloc_en_r = '1' or Alloc_arr_en_r='1') then
				if(AllocSize_r<5) then
					n_state <= SizeTooLess;
				elsif(cur_useaddr_forth='1'and AllocSize_r<500) then
					n_state <= SizeTooLess_sec;
				elsif(cur_useaddr_thd='1'and AllocSize_r<400 and cur_useaddr_forth='0')	then
					n_state <= SizeTooLess_sec;
				elsif(cur_useaddr_secd='1' and AllocSize_r<250 and cur_useaddr_thd='0'and cur_useaddr_forth='0')then
					n_state <= SizeTooLess_sec;			
				elsif(cur_useaddr_fst='1' and AllocSize_r<150 and cur_useaddr_secd='0' and cur_useaddr_thd='0' and cur_useaddr_forth='0')then
					n_state <= SizeTooLess_sec;
				else				
					n_state <= SFreeSpace;
				end if;

			elsif(Null_en_r = '1') then
				n_state <= SReference;			
			else	
				n_state <= c_state;
			end if;
			
		when SizeTooLess_sec=>
			n_state <= Finish;			
		when SizeTooLess=>
			n_state <= Finish;
			
			
		when ArrayAlloc =>
			n_state <= InsertRow;
		
		when SReference =>
			n_state <= BRAMAccessR;

			
		when BRAMAccessR =>
			if(RNotFound = '1') then
				n_state <= Finish;
			else
				n_state <= SReference;
			end if;	
		


		when CheckMerge =>
			if(back_count=0 and back_reference+back_size = cur_ref) then 
				n_state<= Merge;
			else
				n_state<= Finish;
			end if;
		
		when Merge =>
			n_state<= EraseData;
			
		when EraseData =>
			n_state<= WriteErase;
		
		when WriteErase =>
			n_state<= Finish;
		
		when SFreeSpace =>
			if(SFinish = '1') then
				if(SFound = '1' ) then
					n_state <= UpdateGC;
				else
					n_state <= InsertRow;
				end if;	
			else
				n_state <= BRAMAccess;
			end if;	
			
		when BRAMAccess =>
			n_state <=SFreeSpace;
		
		--modify 2014/03/14 
		--because cur_size has been modify to another size ,
		--we need use another signal (split_pre_size) to judge
		when UpdateGC =>
			if(split_pre_size > AllocSize_r) then--cur_size > AllocSize_r
				n_state <= Split;
			else
				n_state <= Finish;
			end if;	
			
		when InsertRow =>				
			n_state <= Finish;			
			
		when Split =>
			n_state <= WriteSplit;
				
		when WriteSplit=>
			n_state <= Finish;

		when Finish =>
			n_state <= Idle;
			
		when others => 
			n_state <= Idle;			
		end case;	
	end process;
-------------------------------------------------------------------
--					register for output					---
-------------------------------------------------------------------
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			GC_cmplt			<= '0';
			GC_Current_Heap_Addr <=(others=>'0');
			GC_Heap_Addr		<=(others=>'0');
		elsif(rising_edge(clk)) then	
			
			GC_Current_Heap_Addr <=	x"5c"&current_heap_ptr&"00";	
			
			GC_Heap_Addr<=x"5c"&reference_r&"00";

				
			if(c_state = Finish) then
				GC_cmplt		<='1';
			else
				GC_cmplt		<='0';
			end if;	
		
		end if;
	end process;



		
-------------------------------------------------------------------
--					register for input					---
-------------------------------------------------------------------	
	process(clk, Rst) 
	begin		
		if(Rst = '1') then
			Alloc_en_r		<= '0';
			Alloc_arr_en_r	<= '0';
			Null_en_r		<= '0';
			AllocSize_r	<=(others=>'0');
			reference_r	<=(others=>'0');
		elsif(rising_edge(clk)) then
			Alloc_en_r	<= GC_Alloc_en;
			
			if(GC_Alloc_arr_en='1') then
				Alloc_arr_en_r<='1';
			elsif(c_state = Finish)	then
				Alloc_arr_en_r<='0';
			end if;	
			
			if(GC_anewarray_flag='1') then
				GC_anewarray_flag_r<='1';
			elsif(GC_Alloc_en='1') then	
				GC_anewarray_flag_r<='0'; --until the next new enable is coming, then it will set to zero
			end if;	
				
				AllocSize_r <= "0000"&GC_AllocSize;
			
			if(GC_Alloc_en = '1' or GC_Alloc_arr_en='1') then
				reference_r <= current_heap_ptr;
			elsif(Null_en_r ='1') then
				reference_r <= GC_reference;
			elsif(SFound ='1') then--c_state =SFreeSpace and 
				reference_r <= GC_data_out(REF_bit+SIZE_bit+NEXT_bit+COUNT_bit-1 downto SIZE_bit+NEXT_bit+COUNT_bit);
			else
				reference_r <= reference_r;
			end if;	
			
			if(GC_Null_en='1') then 
				Null_en_r<='1';
			else	
				Null_en_r   <= Null_en_r;
			end if;	
			
			
		end if;
	end process;	
-------------------------------------------------------------------
--					register for GC-table					---
-------------------------------------------------------------------	
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			GC_write_en   <= '0';
			GC_addr	<=(others=>'0');
			cur_GC_useaddr<=x"00"&"001";--if change the generic here need to modify
			merge_addr	<=(others=>'0');
			GC_data_out_r <=(others=>'0');
			GC_data_in	<=(others=>'0');	
			pre_pointer	<=(others=>'0');	
			cur_GC_useaddr_full	<= '0';
			cur_useaddr_fst		<= '0';	
			cur_useaddr_secd	<= '0';	
			cur_useaddr_thd	<= '0';	
			cur_useaddr_forth   <= '0';	
		elsif(rising_edge(clk)) then
		
		if(cur_GC_useaddr >40) then
			cur_useaddr_fst<='1';
		else
			cur_useaddr_fst<='0';
		end if;	
		
		if(cur_GC_useaddr >80) then
			cur_useaddr_secd<='1';
		else
			cur_useaddr_secd<='0';
		end if;	
		
		if(cur_GC_useaddr >150) then
			cur_useaddr_thd<='1';
		else
			cur_useaddr_thd<='0';
		end if;	

		if(cur_GC_useaddr >200) then
			cur_useaddr_forth<='1';
		else
			cur_useaddr_forth<='0';
		end if;			
		
		if(cur_GC_useaddr = 2040) then
			cur_GC_useaddr_full<='1';
		else
			cur_GC_useaddr_full<='0';
		end if;	
		--modify 2014.03.14 
		--need to doubt check
		if(WriteErase_table_en='1' and c_state = InsertRow) then
			pre_pointer  <=GC_addr-1;
		elsif(c_state = InsertRow) then
			pre_pointer  <=cur_GC_useaddr;
		else	
			pre_pointer  <=pre_pointer;
		end if;	
		
		GC_data_out_r <= GC_data_out;
		
		if(c_state = InsertRow or c_state = Merge or c_state=UpdateGC or c_state =WriteSplit or c_state =WriteErase) then
			GC_write_en   <= '1';
		else
			GC_write_en   <= '0';
		end if;
		
		--if change the generic here need to modify
		if(c_state = Idle )	then
			GC_addr<=x"00"&"001";
		elsif(c_state = BRAMAccess or (c_state = BRAMAccessR and GC_data_out(REF_bit+SIZE_bit+NEXT_bit+COUNT_bit-1 downto SIZE_bit+NEXT_bit+COUNT_bit) /=reference_r)) then
			GC_addr<=GC_addr+1;
		elsif(c_state = UpdateGC or WriteErase_table_en='1') then
			GC_addr<=GC_addr-1;
		elsif(c_state = Merge) then
			GC_addr<=cur_pre_pointer;
		elsif(c_state =EraseData) then
			GC_addr<=merge_addr;
		elsif(c_state = InsertRow or c_state =WriteSplit) then
			GC_addr<=cur_GC_useaddr;
		elsif(RFinish='1') then
			-- In order to retrieve the data from previous data		
			-- If we use cur_pre_pointer, it will be too late to take
			GC_addr<= GC_data_out_r(SIZE_bit+COUNT_bit+NEXT_bit-1 downto SIZE_bit+COUNT_bit);
		else
			GC_addr<=GC_addr;
		end if;

		if(c_state = CheckMerge) then
			merge_addr  <=GC_addr;
		else	
			merge_addr  <=merge_addr;
		end if;	
		
		
		--if change the generic here need to modify
		if(c_state = InsertRow) then
			GC_data_in<=reference_r &pre_pointer&AllocSize_r&"0000"&"1";
		elsif (c_state = UpdateGC) then
			GC_data_in<=reference_r &cur_pre_pointer &cur_size&"0000"&"1";			
		elsif (c_state =Merge) then	
			GC_data_in<=back_reference &back_pre_pointer &merge_size&"00000";	
		elsif (c_state = WriteSplit) then
			GC_data_in<=split_ref&split_pre_pinter&split_size&"00000";
		elsif (c_state = WriteErase) then
			GC_data_in<=x"00000000000000"&"01";			
		else
			GC_data_in<=(others=>'0');
		end if;	
		
		if(  (c_state = InsertRow or c_state = WriteSplit) and WriteErase_table_en = '0'  ) then
			cur_GC_useaddr<=cur_GC_useaddr+1;
		else
			cur_GC_useaddr<=cur_GC_useaddr;
		end if;		
		
		--if change the generic here need to modify
		if (c_state = BRAMAccess or (c_state = BRAMAccessR and GC_data_out(REF_bit+SIZE_bit+NEXT_bit+COUNT_bit-1 downto SIZE_bit+NEXT_bit+COUNT_bit) /=reference_r)) then
			Search_addr<=Search_addr+1;
		elsif(c_state = Idle)	then
			Search_addr<=x"00"&"001";	
		else
			Search_addr<=Search_addr;
		end if;	
		
			
		end if;
	end process;
	
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			RFinish	<= '0';
			SFinish	<= '0';
			SFound	<= '0';
			RNotFound  <= '0';
		elsif(rising_edge(clk)) then
			
		if(c_state = BRAMAccess) then
			if(GC_data_out(REF_bit+SIZE_bit+NEXT_bit+COUNT_bit-1 downto SIZE_bit+NEXT_bit+COUNT_bit)=0)then--GC_reference equal to zero
				SFound <= '0';
				SFinish<='1';
			elsif (GC_data_out(COUNT_bit-1 downto 0)="000000" and GC_data_out(SIZE_bit+COUNT_bit-1 downto COUNT_bit)>=AllocSize_r)then --Using FIFO to reuse space(which has been collected)	
				SFound <='1';
				SFinish<='1';
			else
				SFound<='0';
				SFinish<='0';
			end if;
		elsif(c_state = Idle) then --if the state back to the idle, reset the signals
				SFound <='0';
				SFinish<='0';			
		else
			SFound<='0';
			SFinish<='0';
		end if;	
		

		if((c_state = BRAMAccessR) and GC_data_out(REF_bit+SIZE_bit+NEXT_bit+COUNT_bit-1 downto SIZE_bit+NEXT_bit+COUNT_bit) =reference_r) then
			RFinish<='1';
		--elsif (c_state = Idle) then
			--RFinish<='0';
		else
			RFinish<='0';
		end if;	
		
		if(GC_data_out_r(0) = '0' and GC_data_out_r(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto NEXT_bit+SIZE_bit+COUNT_bit)=x"00000"&"00") then
			RNotFound<='1';	
		else
			RNotFound<='0';
		end if;	
		
		
			
		
			
		end if;
	end process;
	
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			cur_count	<= (others=>'0');
			cur_size	<= (others=>'0');
			cur_pre_pointer	<= (others=>'0');
			cur_ref	<= (others=>'0');
			
			back_count	<= (others=>'0');
			back_size	<= (others=>'0');
			back_reference<= (others=>'0');
			back_pre_pointer  <= (others=>'0');
			
			merge_size   <= (others=>'0');
		elsif(rising_edge(clk)) then
					
		

		if(RFinish='1' or SFinish='1') then
			cur_count<=GC_data_out_r(COUNT_bit-1 downto 0);			
		else
			cur_count<=cur_count;
		end if;	
		
		
		if(RFinish='1' or SFound='1') then
			cur_pre_pointer <=GC_data_out_r(SIZE_bit+COUNT_bit+NEXT_bit-1 downto SIZE_bit+COUNT_bit);
			cur_ref  <=GC_data_out_r(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto NEXT_bit+SIZE_bit+COUNT_bit);
		else
			cur_pre_pointer <=cur_pre_pointer;
			cur_ref  <=cur_ref;
		end if;	
		
		--When updateGC the size will be change , we cant take it from table (it will be wrong)
		if(RFinish='1') then
			cur_size <=GC_data_out_r(SIZE_bit+COUNT_bit-1 downto COUNT_bit);
		elsif( SFound='1') then	
			cur_size <=AllocSize_r;
		else
			cur_size <=cur_size;
		end if;		

			back_count	<= back_count;
			back_size	<= back_size;
			back_pre_pointer<=back_pre_pointer;
			back_reference  <= back_reference;
		
		merge_size <=back_size+cur_size;
			
		end if;
	end process;

	
	
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			current_heap_ptr	<= "00"&x"00000";
		elsif(rising_edge(clk)) then
					
			if(c_state = InsertRow or c_state =SizeTooLess or c_state =SizeTooLess_sec) then
				current_heap_ptr <=current_heap_ptr+AllocSize_r;
			elsif(GC_ext_wr_heap_ptr='1') then
				current_heap_ptr <=GC_current_heap_ptr_ext(REF_bit+1 downto 2);
			else
				current_heap_ptr <=current_heap_ptr;
			end if;	
		
			
		end if;
	end process;	
	
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			split_size	<= (others=>'0');
			split_pre_size <= (others=>'0');
			split_pre_pinter	<= (others=>'0');
			split_ref	<= (others=>'0');
			split_pre_size <= (others=>'0');
			Rfini_addr	<= (others=>'0');
		elsif(rising_edge(clk)) then
			
			
			if(c_state = Split) then
				split_pre_pinter	<= GC_addr;
				split_size	<= split_pre_size - AllocSize_r;
				split_ref	<= cur_ref  + AllocSize_r;
			else
				split_pre_pinter	<= split_pre_pinter;
				split_size	<= split_size;
				split_ref	<= split_ref;
			end if;	
			
			if(SFound = '1') then
				split_pre_size <= GC_data_out_r(SIZE_bit+COUNT_bit-1 downto COUNT_bit);
			else
				split_pre_size <=split_pre_size;
			end if;	
			
			if(RFinish='1') then
				Rfini_addr <=GC_addr;
			else
				Rfini_addr <=Rfini_addr;
			end if;
				
			
		end if;
	end process;	


	process(clk, Rst) 
	begin
		if(Rst = '1') then
			WriteErase_table_en <='0';
			
		elsif(rising_edge(clk)) then
			
			--modify 2014.03.16
			--add the c_state,if not the address of GC will be accident modify 
			if(GC_data_out_r(0)='1' and c_state = SFreeSpace and
			GC_data_out_r(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto NEXT_bit+SIZE_bit+COUNT_bit) =0) then
				WriteErase_table_en	<= '1';
			else
				WriteErase_table_en	<= '0';
			end if;	
			
		end if;
	end process;	


-------------------------------------------------------------------
--					Method Collection						---
-------------------------------------------------------------------	


-------------------------------------------------------------------
--					Finite-state-machine					---
-------------------------------------------------------------------

	process(clk, Rst) 
	begin
		if(Rst = '1') then
			c_state_M   <= Idle_M;
		elsif(rising_edge(clk)) then
			c_state_M   <= n_state_M;
			
		end if;	
	end process;

	process(GC_Mthd_Enter,c_state_M,GC_Mthd_Exit,current_pop_ref,Mthd_GC_data_in,c_state,R_counter,Record_addr,Curr_mth_top_judge,GC_areturn_flag,EraseRefData_delay,temp_return_flag,GC_StackCheck_f)
	begin
		case c_state_M is
		when Idle_M =>
			if(GC_Mthd_Enter='1' and Meth_col_en = 1) then
				n_state_M <= PushMflag;
			else
				n_state_M <= c_state_M;
			end if;
			
		when PushMflag =>
			n_state_M<=WaitRef;
			
		when WaitRef =>
			if (c_state = InsertRow or c_state = UpdateGC ) then
				n_state_M <=PushRef;
			elsif(GC_areturn_flag='1' or GC_StackCheck_f='1') then-- this priority is higher than temp_return_flag
				n_state_M <=SearchStack;
			elsif(temp_return_flag='1') then
				if(normal_last_sear_flag='1')then
					n_state_M <=Normal_addr_pop_assign;
				else
					n_state_M <=PopRef;
				end if;	
			else
				n_state_M <=c_state_M;
			end if;	
			
		when SearchStack =>
			if(areturn_pop_ref(REF_bit downto 1)  =GC_StackCheck_data(REF_bit+1 downto 2)) then
				n_state_M <=SearchFound;
			-- elsif (areturn_pop_ref(0) = '1')then--it means search finish
				-- if(temp_return_flag ='1') then--it means that during the search so trigger is up,we need to do something
					-- n_state_M <=CheckRefEnd;
				-- else
					-- n_state_M <=WaitRef;
				-- end if;	
			elsif (AretnAddr<2 or NoNeedStackCheck = GC_StackCheck_data(REF_bit+1 downto 2)) then
				if(temp_return_flag ='1' and normal_last_sear_flag='1') then
					n_state_M <= Normal_addr_pop_assign;
				elsif(temp_return_flag='1')then
					n_state_M <= PopRef;				
				else
					n_state_M <=WaitRef;
				end if;		
			else
				n_state_M <=WaitBram;
			end if;	
			
		when WaitBram =>	
			n_state_M<=SearchNext;
			
		when SearchNext=>
			n_state_M <=SearchStack;
			
		when SearchFound =>
			n_state_M <=EraseRefData;
			
		when EraseRefData =>
			if(EraseRefData_delay='1')then
				if(temp_return_flag ='1' and normal_last_sear_flag='1') then
					n_state_M <= Normal_addr_pop_assign;
				elsif(temp_return_flag='1')then
					n_state_M <= PopRef;				
				else
					n_state_M <=WaitRef;
				end if;	
			else
				n_state_M<=c_state_M;
			end if;	
			
		when Normal_addr_pop_assign=>
			n_state_M <=PopRef;
			
		
		when PushRef=>
			n_state_M <=WaitRef;
			
		when PopRef =>
			n_state_M <=CheckRefEnd;
			
		when CheckRefEnd=>	
			if(current_pop_ref(0) ='1' or PopAddr="000000000") then
				n_state_M <= Finish_M;
			else
				n_state_M <=SReference_M;
			end if;
	
		
		when SReference_M=>
			if(Mthd_GC_data_in(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto NEXT_bit+SIZE_bit+COUNT_bit) = current_pop_ref(REF_bit downto 1)) then
				n_state_M <=EraseCounter;
			elsif(current_pop_ref=0)	then
				n_state_M <=PopRef;				
			elsif((Mthd_Addr_reg="00000000000" or Mthd_GC_data_in(0) = '0') and Mthd_GC_data_in(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto NEXT_bit+SIZE_bit+COUNT_bit)=x"00000"&"00")	then--if not found reference
				n_state_M<=PopRef;
			else
				n_state_M <=BRAMAccessR_M;
			end if;
		when BRAMAccessR_M =>
			if(c_state = SFreeSpace or c_state = BRAMAccess) then--c_state is the first priority
				n_state_M <= c_state_M;
			else	
				n_state_M <= SReference_M;
			end if;	
						
		
		when EraseCounter =>
			n_state_M <= PopRef;
		
		when Finish_M =>
			n_state_M <= Idle_M;
			
		when others => 
			n_state_M <= Idle_M;			
		end case;	
	end process;
		
	
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			current_pop_ref	<= (others=>'0');
		elsif(rising_edge(clk)) then
					
			if(c_state_M = PopRef or c_state_M=CheckRefEnd) then --modify 0612
				current_pop_ref <=DataOut;
			else
				current_pop_ref <=current_pop_ref;
			end if;			
			
		end if;
	end process;

	process(clk, Rst) 
	begin
		if(Rst = '1') then
			areturn_pop_ref	<= (others=>'0');
			temp_return_flag   <='0';
		elsif(rising_edge(clk)) then
					
			if(c_state_M =SearchStack) then
				areturn_pop_ref <=DataOut;
			else
				areturn_pop_ref <=areturn_pop_ref;
			end if;			

			if(GC_Mthd_Exit='1' and Record_addr = R_counter-1 and c_state_M = WaitRef) then
				temp_return_flag<='1';
			elsif(c_state_M =CheckRefEnd) then
				temp_return_flag<='0';
			else
				temp_return_flag<=temp_return_flag;
			end if;	
			
		end if;
	end process;

  process (clk, Rst)is begin
	if(rising_edge (clk))then
		if(Rst = '1')then
		GC_StackCheck_data		<=(others => '0');
		NoNeedStackCheck		<=(others => '0');
		else
			if((GC_Mthd_Exit = '1' or GC_StackCheck_f='1')and c_state_M = WaitRef ) then
				GC_StackCheck_data <=GC_A;
			else
				GC_StackCheck_data<=GC_StackCheck_data;
			end if;
			
			if(n_state_M = WaitRef and c_state_M =SearchStack) then
				NoNeedStackCheck <=GC_StackCheck_data(REF_bit+1 downto 2);
			else
				NoNeedStackCheck<=NoNeedStackCheck;
			end if;
			
		end if;
	end if;
  end process;		
-------------------------------------------------------------------
--					register for GC-table					---
-------------------------------------------------------------------		
	
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			Mthd_Addr_reg	<= (others=>'0');
			Mthd_WriteBRAM_en <='0';
			Mthd_GC_data_out  <= (others=>'0');
		elsif(rising_edge(clk)) then
		
			--if change the generic here need to modify		
			if(c_state_M = SReference_M and Mthd_GC_data_in(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto NEXT_bit+SIZE_bit+COUNT_bit) /= current_pop_ref(REF_bit downto 1)) then
				if(normal_last_sear_flag='0')then
					Mthd_Addr_reg <= Mthd_Addr_reg+1;
				elsif(Mthd_Addr_reg>0) then
					Mthd_Addr_reg <= Mthd_Addr_reg-1;
				end if;	
			elsif(c_state_M = Finish_M or c_state_M = PopRef)	then
				if(normal_last_sear_flag='0')then
					Mthd_Addr_reg <= x"00"&"001";
				else
					Mthd_Addr_reg <= Mthd_Addr_reg;
				end if;	
			elsif(c_state_M = Normal_addr_pop_assign) then
				Mthd_Addr_reg <= cur_GC_useaddr-1;-- if minus one the cost is so high (clock rate) become low
			else
				Mthd_Addr_reg <=Mthd_Addr_reg;
			end if;	
			
		
			if(c_state_M = EraseCounter) then
				Mthd_WriteBRAM_en   <='1';
			else
				Mthd_WriteBRAM_en   <='0';
			end if;

		if(c_state_M = EraseCounter) then
			Mthd_GC_data_out<=Mthd_ref&Mthd_pre_pointer&Mthd_size&"00000";
		else
			Mthd_GC_data_out<=Mthd_GC_data_out;
		end if;				
										
		end if;
	end process;

	Mthd_Addr<=Mthd_Addr_reg;
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			Mthd_size		<= (others=>'0');
			Mthd_pre_pointer  <= (others=>'0');
			Mthd_ref		<= (others=>'0');
		elsif(rising_edge(clk)) then
							
		if(c_state_M = SReference_M) then
			Mthd_size		<=Mthd_GC_data_in(SIZE_bit+COUNT_bit-1 downto COUNT_bit);
			Mthd_pre_pointer  <=Mthd_GC_data_in(SIZE_bit+COUNT_bit+NEXT_bit-1 downto SIZE_bit+COUNT_bit);
			Mthd_ref		<=Mthd_GC_data_in(REF_bit+SIZE_bit+COUNT_bit+NEXT_bit-1 downto NEXT_bit+SIZE_bit+COUNT_bit);
		else
			Mthd_size		<=Mthd_size;		
			Mthd_pre_pointer  <=Mthd_pre_pointer;
			Mthd_ref		<=Mthd_ref;
		end if;			
		
		end if;
	end process;	
	
	
-------------------------------------------------------------------
--					register for method_table				---
-------------------------------------------------------------------	
	process(clk, Rst) 
	begin
		if(Rst = '1') then
			Write_en	<= '0';
			PopAddr	<=(others=>'0');
			AretnAddr	<=(others=>'0');
			GC_mth_writeRef <='0';
			DataIN	<=(others=>'0');
			Curr_mth_top_judge<='0';
		elsif(rising_edge(clk)) then

		
		if((c_state = InsertRow or c_state = UpdateGC ) and c_state_M = WaitRef and GC_Clinit_Stop='0') then
			GC_mth_writeRef   <= '1';
		else
			GC_mth_writeRef   <= '0';
		end if;		
		
		if(n_state_M = PushMflag or GC_mth_writeRef='1' or c_state_M = SearchFound) then
			Write_en   <= '1';
		else
			Write_en   <= '0';
		end if;
	
		if((c_state_M = PopRef )and PopAddr>0)	then
			PopAddr<=PopAddr-1;
		elsif(GC_mth_writeRef='1' or n_state_M = PushMflag) then
			PopAddr<=PopAddr+1;			
		else
			PopAddr<=PopAddr;
		end if;

		if(c_state_M = WaitRef) then
			AretnAddr <= PopAddr;
		elsif (c_state_M = WaitBram and areturn_pop_ref(REF_bit downto 1)  /=GC_StackCheck_data(REF_bit+1 downto 2) and AretnAddr>1)	then
			AretnAddr<=AretnAddr-1;
		end if;	
		
		if(n_state_M = PushMflag) then
			DataIN<=x"00000"&"001";--if the last bit is 1 meaning it is the end of GC_reference
		elsif (c_state_M = SearchFound) then
			DataIN<=x"00000"&"000";		--erase the stack data
		elsif (GC_mth_writeRef='1') then
			DataIN<=reference_r&'0';		
		else
			DataIN<=(others=>'0');
		end if;		
		
		if(DataOut(0)='1')then
			Curr_mth_top_judge<='1';
		else
			Curr_mth_top_judge<='0';
		end if;

			
		end if;
	end process;
	
	Addr <=AretnAddr when c_state_M = SearchNext or c_state_M = SearchStack or c_state_M = SearchFound or c_state_M =WaitBram or c_state_M =EraseRefData else PopAddr;

	process(clk, Rst) 
	begin
		if(Rst = '1') then
			R_counter<=0;
			Record_addr <=0;
			Mthd_fini_count<=(others=>'0');
			normal_last_sear_flag<='0';
			EraseRefData_delay <='0';
		elsif(rising_edge(clk)) then
			if(GC_Mthd_Enter_f = '1' or GC_Mthd_Enter='1') then
				R_counter<= R_counter+1;
			elsif (GC_Mthd_Exit='1' and R_counter > 0) then
				R_counter<= R_counter-1;
			else
				R_counter<= R_counter;
			end if;
			
				
			if(c_state_M = Idle_M and GC_Mthd_Enter='1') then
				Record_addr<=R_counter;
			else
				Record_addr<=Record_addr;
			end if;	
			
			if(c_state_M=Finish_M and Mthd_fini_count<8) then
				Mthd_fini_count<= Mthd_fini_count+1;
			else
				Mthd_fini_count<=Mthd_fini_count;
			end if;

			if(Mthd_fini_count<6) then
				normal_last_sear_flag<='1';
			else
				normal_last_sear_flag<='0';
			end if;	
				
			if(c_state_M = EraseRefData) then
				EraseRefData_delay<='1';
			else
				EraseRefData_delay<='0';
			end if;	
					
		end if;
	end process;
	
	
-------------------------------------------------------------------
--					Implement STACK by BRAM				---
-------------------------------------------------------------------	
	process(clk, Rst)
	begin
		if clk'event and clk = '1' then
			if Write_en = '1' then
				-- Synchronous Write
				MEM(CONV_INTEGER(unsigned(Addr))) <= DataIN;
			end if;
			
			DataOut <= MEM(CONV_INTEGER(unsigned(Addr)));
		end if;
	end process;
	
	
end architecture rtl;
