------------------------------------------------------------------------------
-- Filename     :       thread_management.vhd
-- Version      :       1.00
-- Author       :       Hung-Cheng Su
-- Date         :       Nov 2012
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
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use ieee.std_logic_arith.conv_std_logic_vector;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity thread_management is 
    generic(
        RAMB_S18_AWIDTH             	: integer := 10;
		RAMB_S36_AWIDTH          : integer := 9;
		Max_Thread_Number	: integer := 16
    );
    port(
		-- ctrl signal
		Rst                         : in  std_logic;
		clk                         : in  std_logic;
		act_dly                         : in  std_logic; 
		SetTimeSlices_Wen           : in  std_logic; 
		stack_rw_cmplt				: in  std_logic;
		thread_base					: out std_logic_vector(Max_Thread_Number/4-1 downto 0);
		stack_length				: out std_logic_vector(RAMB_S36_AWIDTH downto 0);
		stack_rw_enable				: out std_logic;
		sdram_rw_flag				: out std_logic;
		
		context_switch	        	: out std_logic; 
		thread_number				: out std_logic_vector(4 downto 0);
		jpc_backup					: out std_logic;
                -- unified 32-bit input / output data port HERE !
		TH_data_in_valid			: in std_logic;
		TH_data_in                  : in std_logic_vector (31 downto 0) ;
		TH_data_out_valid			: out std_logic;
		TH_data_out                 : out std_logic_vector (31 downto 0) ;
		-- from soj , golbal counter for data transfer in ThreadControlBlock
		TH_data_in_transfer_cnt_dly : in   std_logic_vector( 3 downto 0);
		-- added by T.H.Wu 2013.7.18 , for transferring TCB info to other modules in JAIP sequentially
		thread_ctrl_state_out       :out    Thread_management_SM_TYPE;
		TH_data_out_transfer_cnt    :out   std_logic_vector( 3 downto 0);
		
        -- method area 
		ClsLoading_stall            : in  std_logic;
		TH_trigger_MA_ctrl_en	 : out std_logic; 
		
		--from dynamic resolution (new thread)
		new_thread_flag				: in  std_logic;
		-- added by T.H. Wu , 2013.7.9
		Thread_start_cmplt_flag     : out  std_logic ;   
		new_thread_execute			: out std_logic; 
		
		-- from fetch stage
		simple_mode					: in  std_logic;
		reset_mode					: out std_logic;
		
		-- from decode stage
		CS_reset_lv					: out std_logic;
		
		-- from execute stage
		LVreg2mem_CS				: out std_logic;
		-- for debug  can delete
		--=============================================
		--thread_counter				: out std_logic_vector(31 downto 0);	-- for debug can delete
		--slice						: out std_logic_vector(31 downto 0);	-- for debug can delete
		--ready_thread_info			: out std_logic_vector(31 downto 0);	-- for debug can delete
		--timeout_tmp					: out std_logic;						-- for debug can delete
		--timeover					: out std_logic;						-- for debug can delete
		--thread_mgt_state			: out std_logic_vector(3 downto 0);
		--=============================================
		
		-- for multi-core coordinator , 2013.10.5
		current_run_thread_slot_idx	: out std_logic_vector(Max_Thread_Number/4-1 downto 0); 
	 	now_thread_monitorenter_succeed	: in std_logic ; 
	 	now_thread_monitorenter_fail	: in std_logic ; 
	 	monitorexit_sender_is_the_core	: in std_logic ; 
	 	monitorexit_lockfree			: in std_logic ; 
	 	monitorexit_nextowner_here		: in std_logic ; 
		monitorexit_nextowner_thread_slot_idx	: in std_logic_vector(Max_Thread_Number/4-1 downto 0);
	 	monitorenter_cmplt				: out std_logic ; 
	 	monitorexit_cmplt				: out std_logic ; 
		-- from soj
		before_16clk_now_TH_timeout_out	: out std_logic;
		now_TH_start_exec_over_28clk	: out std_logic;
		thread_dead_flag				: in  std_logic;
		interrupt_req					: in  std_logic;
		clean_pipeline_cmplt			: in  std_logic;	-- by fox
		clean_pipeline					: out std_logic;
		stall_all_flag					: in  std_logic;		-- sure execute stage complete(alu_stall) 
        -- for chipscope debug use .
		debug_cs_thread_mgt                  : out std_logic_vector(47 downto 0)
    );
end entity thread_management;

architecture rtl of thread_management is

    component RAMB16_S36_S36 port (
		-- port A
        DOA                    : out std_logic_vector(31 downto 0);
        DIA                    : in  std_logic_vector(31 downto 0);
        DIPA                   : in  std_logic_vector(3 downto 0);
        DOPA                   : out std_logic_vector(3 downto 0);
        ADDRA                  : in  std_logic_vector(8 downto 0);
        SSRA                   : in  std_logic;
        CLKA                   : in  std_logic;
        ENA                    : in  std_logic;
        WEA                    : in  std_logic;
		-- port B
        DOB                    : out std_logic_vector(31 downto 0);
        DIB                    : in  std_logic_vector(31 downto 0);
        DIPB                   : in  std_logic_vector(3 downto 0);
        DOPB                   : out std_logic_vector(3 downto 0);
        ADDRB                  : in  std_logic_vector(8 downto 0);
        SSRB                   : in  std_logic;
        CLKB                   : in  std_logic;
        ENB                    : in  std_logic;
        WEB                    : in  std_logic
	);
    end component;
	
	
        -- generate main thread here !! modified by fox , 2013.8.1
        signal act_dly_2clk                                : std_logic;  
        signal first_thread_setup_cmplt                    : std_logic; 
        signal new_thread_flag_inactive_1clk               : std_logic; 
        signal new_thread_flag_inactive_1clk_dly1          : std_logic; 
        signal thread_ctrl_state			: Thread_management_SM_TYPE;
	--signal state_reg					: Thread_management_SM_TYPE;
	signal thread_dead					: std_logic;
	signal new_thread_flag_dly			: std_logic;
	signal get_state_2cycle				: std_logic;
	signal get_state_3cycle				: std_logic; -- modified by T.H.Wu , 2013.9.10
	signal MT_mgt_en_reg				: std_logic;
	signal context_switch_tmp			: std_logic;
	signal backup_length				: std_logic_vector(RAMB_S36_AWIDTH downto 0); 
	signal mem2LVreg_reg          		: std_logic;
	signal new_thread_ex				: std_logic;
	signal clean_pipeline_reg			: std_logic;
	signal do_switch					: std_logic;

	--signal new_thread_start				: std_logic;
	
	signal time_counter					: std_logic_vector(23 downto 0);
	signal timeout						: std_logic;
	signal time_slice					: std_logic_vector(23 downto 0);
	signal now_TH_exec_cnt_increase_flag:	std_logic;
	signal now_TH_exec_cnt_without_any_stall : std_logic_vector(4 downto 0);
	
	-- know thread id & info
	signal previous_thread				: std_logic_vector(5 downto 0);
	signal runnable_thread				: std_logic_vector(5 downto 0);	
	signal ready_thread					: std_logic_vector(5 downto 0);
	signal new_thread_id				: std_logic_vector(5 downto 0);
	signal thread_num_reg				: std_logic_vector(4 downto 0); 
	signal thread_num_reg_dly			: std_logic_vector(4 downto 0); 
	signal rdy_thread_num_reg			: std_logic_vector(4 downto 0); 
	signal rdy_thread_num_reg_w			: std_logic_vector(4 downto 0); 
	--signal rdy_thread_num_reg_dly		: std_logic_vector(Max_Thread_Number/4-1 downto 0); 
	signal nxt_rdy_TH_new_coming		: std_logic;
	signal get_thread_state				: std_logic;
	
	--signal which_use_previous_stack		: std_logic_vector(14 downto 0);
			
	-- mgt ready & waiting queue
	signal next_ready					: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal readyQ_tail					: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	--signal next_waiting					: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	--signal waitingQ_tail				: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	type queue_file is array (integer range Max_Thread_Number-1 downto 0) of std_logic_vector(5 downto 0);
    signal ReadyQueue : queue_file;
	--signal WaitingQueue : queue_file;
	-- record the slot index which the thread is in waiting state. 
	signal WaitBit_list : std_logic_vector(Max_Thread_Number-1 downto 0);
    
	-- know thread is exist?
	signal empty_slot					: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal previous_thread_in_slot		: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal now_thread_in_slot			: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal ready_thread_in_slot			: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal find_empty_slot				: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal find_ready_slot				: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal TCB_slot						: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	--type allocation_file is array (integer range Max_Thread_Number-1 downto 0) of std_logic_vector(15 downto 0);
	--signal AllocationList : allocation_file;
	
	-- mgt thread info
	type ready_thread_state_file is array (integer range 7 downto 0) of std_logic_vector(31 downto 0);
	signal ready_thread_TCBlist 		: ready_thread_state_file;
	--signal new_thread_init_state	: ready_thread_state_file;
	type thread_state_file is array (integer range Max_Thread_Number-1 downto 0) of std_logic_vector(31 downto 0);
	signal ThreadControlBlock : thread_state_file;
    
	 
	signal over				: std_logic;  
        -- added by T.H.Wu 2013.7.18 , for TCB info transferring to other modules. 
        signal TH_data_out_transfer_cnt_reg : std_logic_vector( 3 downto 0);
        signal TH_data_out_transfer_cnt_reg_w : std_logic_vector( 3 downto 0); 
        -- added by T.H.Wu 2013.9.25 , for loading next ready thread's TCB info sequentially. 
        signal TCB2rdyTHstate_cnt_reg	: std_logic_vector(3 downto 0);
        signal TCB2rdyTHstate_cnt_reg_w	: std_logic_vector(3 downto 0); 
		signal TCB2rdyTHstate_cnt_increment_flag	:	std_logic;
		signal TCB2rdyTHstate_cnt_increment_flag_w	:	std_logic;
		-- 
        -- added by T.H.Wu , 2013.8.21 , for fixing one bug
        signal stack_rw_enable_w : std_logic;
        signal stack_rw_enable_reg : std_logic;
		-- added by T.H.Wu , 2013.10.4 , this signal is activated before 16 clocks of currently running thread timeout
        signal before_16clk_now_TH_timeout : std_logic;
	
        -- 2013.7.5  for temporary use , will be deleted after optimizing .
	signal  ex2java_data                :  std_logic_vector(31 downto 0); 
	signal MA2TM_thread_info			:  std_logic_vector(31 downto 0); -- cls id & mt id
	signal  TH2MA_thread_info : std_logic_vector(31 downto 0);
	signal	DR2TM_thread_info	: std_logic_vector(31 downto 0); -- cls id & mt id
	signal	runnable_obj		: std_logic_vector(31 downto 0);
	signal	thread_stack_info     :  std_logic_vector(31 downto 0);
	signal	thread_stack_A           :  std_logic_vector(31 downto 0);
	signal     thread_stack_B          :  std_logic_vector(31 downto 0);
	signal    thread_stack_C          :  std_logic_vector(31 downto 0); 
	signal	thread_jpc              	:   std_logic_vector(15 downto 0);
	signal thread_reg_valid           :   std_logic_vector( 3 downto 0);
	signal switch_jpc              	:  std_logic_vector(15 downto 0);
	signal thread_obj	    	:  std_logic_vector(31 downto 0);
	signal TOS_A			        : std_logic_vector(31 downto 0);
	signal TOS_B				: std_logic_vector(31 downto 0);
	signal TOS_C				: std_logic_vector(31 downto 0);
	signal reg_valid                   :  std_logic_vector( 3 downto 0);
	signal vp				:  std_logic_vector(RAMB_S36_AWIDTH downto 0);
	signal sp				:  std_logic_vector(RAMB_S36_AWIDTH downto 0);
	
	-- added by T.H.Wu , 2013.10.7, for multi-core coordinator
	signal	previous_thread_state 	:	std_logic_vector(1 downto 0);
	signal	runnable_thread_state 	:	std_logic_vector(1 downto 0);
	signal	ready_thread_state	 	:	std_logic_vector(1 downto 0); 
	-- -- --
	signal	now_thread_monitorenter_fail_hold		:	std_logic;
	signal	now_thread_monitorenter_fail_dly_1clk	:	std_logic;
	signal	monitorexit_nextowner_here_dly			:	std_logic; 
	signal	TCB0_we		:	std_logic;
	signal	readyQ_we	:	std_logic;
	signal	monitorexit_nextowner_TCB0_sync		:	std_logic;
	signal	monitorexit_nextowner_readyQ_sync	:	std_logic;
	
	signal	monitorexit_nextowner_TCB0_hold_w	:	std_logic;
	signal	monitorexit_nextowner_TCB0_hold		:	std_logic;
	signal	monitorexit_nextowner_readyQ_hold_w	:	std_logic;
	signal	monitorexit_nextowner_readyQ_hold	:	std_logic;
	signal	monitorexit_nextowner_thread_slot_idx_hold_w:	std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal	monitorexit_nextowner_thread_slot_idx_hold	:	std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal	monitorexit_nextowner_readyQ_TH_id			:	std_logic_vector(5 downto 0);
	signal	monitorexit_nextowner_readyQ_TH_id_w		:	std_logic_vector(5 downto 0);
	
	-- modified by T.H.Wu for experiment, when one thread succeeds to get the lock , its time slice should be stop accumulating
	-- until the thread release the lock, ignore the case of multiple lock hold on a thread
	signal	run_thread_time_slice_keep_unchanged		:	std_logic;
		
				 
	 
	-- port A
	signal	TCBlist_WEA				:	std_logic;
	signal	TCBlist_thread_w_offset :	std_logic_vector(3 downto 0);
	signal	TCBlist_ADDRA			:	std_logic_vector(8 downto 0);
	signal	TCBlist_DIA		 		:	std_logic_vector(31 downto 0);
	signal	TCBlist_DOA		 		:	std_logic_vector(31 downto 0); 
	-- port B
	signal	TCBlist_WEB				:	std_logic;
	signal	TCBlist_thread_r_offset :	std_logic_vector(3 downto 0);
	signal	TCBlist_ADDRB			:	std_logic_vector(8 downto 0);
	signal	TCBlist_DIB				:	std_logic_vector(31 downto 0);
	signal	TCBlist_DOB				:	std_logic_vector(31 downto 0);
		
		
		
    
        ------------------------------------- start of the design ---------------------------------------
	begin
	
		-- for new thread from other core to this core
		before_16clk_now_TH_timeout_out <= before_16clk_now_TH_timeout;
	
		-- note by T.H.Wu , 2013.9.9 		
		new_thread_flag_inactive_1clk <= new_thread_flag_dly and not new_thread_flag;
		
		-- modified by T.H.Wu , 2013.9.10 
        Thread_start_cmplt_flag <= (act_dly_2clk and new_thread_flag_inactive_1clk_dly1)
									or
									(not act_dly_2clk and first_thread_setup_cmplt);
    
        -- modified by T.H.Wu , 2013.8.1
	new_thread_execute <= '1' when 
								(thread_ctrl_state=Check_Timeout and timeout = '1' and ready_thread_TCBlist(0)(30) = '0')
								or  
								((not act_dly_2clk) and act_dly) = '1'
					else '0' ; 
	
	TH_trigger_MA_ctrl_en	<= MT_mgt_en_reg when ready_thread_TCBlist(0)(30) = '1' else '0';
	
	LVreg2mem_CS	<= '1' when thread_ctrl_state=ContextSwitch and MT_mgt_en_reg = '1' else
					   '0';
	
	context_switch	<= context_switch_tmp;
	
	context_switch_tmp	<=		'1' when	(thread_ctrl_state=ContextSwitch and ClsLoading_stall = '0')
						else	'0'; 
	
	 
	
	thread_number	<= thread_num_reg_dly;
	
	CS_reset_lv	<= mem2LVreg_reg;
	
	clean_pipeline	<= over or clean_pipeline_reg;
	
	jpc_backup	<= over and not clean_pipeline_reg;
    
        TH_data_out_transfer_cnt <= TH_data_out_transfer_cnt_reg; -- added by T.H.Wu , 2013.7.18
        
        thread_ctrl_state_out <= thread_ctrl_state; -- added by T.H.Wu , 2013.7.18
        
        stack_rw_enable <= stack_rw_enable_w and not stack_rw_enable_reg;   -- added by T.H.Wu , 2013.8.21
		
	current_run_thread_slot_idx <= now_thread_in_slot;	-- added by T.H.Wu , 2013.10.5
	
	
	--
	reset_mode	<= '1' when thread_ctrl_state=ContextSwitch and MT_mgt_en_reg = '1' and ready_thread_TCBlist(0)(30) = '1' else '0';
	
	-- stack backup or restore arg. reset
	process(
            thread_ctrl_state, previous_thread, ready_thread,ready_thread_in_slot,
             previous_thread_in_slot, ready_thread_TCBlist(2), backup_length
         ) 
		--variable slot_shift		: std_logic_vector(Max_Thread_Number/4+2 downto 0);
	begin
		if(thread_ctrl_state = Prepare_Next_thread) then
			if(previous_thread /= ready_thread ) then -- 2013.10.7
				stack_rw_enable_w <= not stack_rw_cmplt;
			else
				stack_rw_enable_w <= '0';
			end if;	
			thread_base			<= ready_thread_in_slot;
			stack_length		<= ready_thread_TCBlist(2)(RAMB_S36_AWIDTH downto 0); 
			sdram_rw_flag		<= '0';
		elsif(thread_ctrl_state = Backup_Previous_Stack) then 
			stack_rw_enable_w	<= not stack_rw_cmplt; 
			thread_base			<= previous_thread_in_slot;
			stack_length		<= backup_length;							
			sdram_rw_flag		<= '1';
		else
			stack_rw_enable_w	<= '0';
			thread_base			<= (others => '0');
			stack_length		<= (others => '0');							
			sdram_rw_flag		<= '1';
		end if;
    end process;
	
	
	state_CtrlUnit :
	process(clk) begin
		if(rising_edge(clk)) then
            if(Rst = '1') then
				thread_ctrl_state	<= Idle;
            else
				case thread_ctrl_state is
                when Idle =>
					-- modified by T.H.Wu , 2013.9.8 , for multi-core coordinator
                    --if (thread_num_reg=x"1" ) then
                    if (
						thread_num_reg_dly="00010" or -- thread_num_reg should delay 1 clock HERE
						( act_dly_2clk='0' and get_state_3cycle='1') -- thread_num_reg=x"1" and
					) then 
                        thread_ctrl_state	<= Prepare_next_thread_TCB_info; 
                    end if ;	
					
				when Check_Timeout =>
					if(timeout = '1' ) then
						thread_ctrl_state	<= ContextSwitch; 
					end if;
					
				when ContextSwitch =>
					if(ClsLoading_stall = '0') then	 
						-- bitstream may go wrong if we modify thread_num_reg below,  2013.9.6
						if(thread_num_reg = "00001" ) then
							thread_ctrl_state	<= Idle;
						elsif(thread_dead = '0') then
							-- modified by T.H.Wu , 2013.7.18
                            thread_ctrl_state	<= Backup_previous_thread_TCBinfo;
						else
							-- check if  number of ready thread (include run thread) in ready queue is larger or equal to 0.
							thread_ctrl_state	<= AllThreadsWait; 
						end if; 
					end if;	
					
				when Backup_previous_thread_TCBinfo => -- added by T.H.Wu , 2013.7.18
					if(TH_data_in_transfer_cnt_dly=x"8") then
						thread_ctrl_state <= Backup_Previous_Stack;
					end if;
					
				when Backup_Previous_Stack =>
					if(stack_rw_cmplt = '1') then 
						thread_ctrl_state	<= AllThreadsWait;
					end if;
					
				when AllThreadsWait => 
					-- the currently unique ready thread of this core.
					--if(rdy_thread_num_reg > x"1" or (rdy_thread_num_reg=x"1" and now_thread_monitorenter_fail_hold='1')) then
					-- modified by T.H.Wu , 2013.10.29  
					if(rdy_thread_num_reg > "00001" or (rdy_thread_num_reg="00001" and timeout='1')) then
						thread_ctrl_state	<= Prepare_Next_thread; 
					end if;	
					
				when Prepare_Next_thread =>
					if(previous_thread = ready_thread or stack_rw_cmplt = '1') then 
						thread_ctrl_state	<= Prepare_next_thread_TCB_info; 
					end if;
					
				when  Prepare_next_thread_TCB_info => -- added by T.H.Wu , 2013.7.18
					if(TH_data_out_transfer_cnt_reg=x"8") then
						-- modified here by T.H.Wu , 2013.9.10
						-- for multi-core execution , new thread initialization before the core is activated.
						if(thread_num_reg="00001" and act_dly_2clk='0') then
							thread_ctrl_state <= Idle ;
						else
							thread_ctrl_state <= Check_Timeout;
						end if;
					end if;
					
				when others => null ;
			end case;
		end if;
		end if;
    end process;
	 
    -- 2013.7.23 , when only 2 thread context-switch , this may be bug for backup/restoring next  ready thread's TCB
	-- modified by T.H.Wu , 2013.9.8 , for multi-core coordinator
	get_thread_state	<= '1' when
								(thread_ctrl_state=Idle and thread_num_reg = "00010") or 
								(thread_ctrl_state=ContextSwitch and ClsLoading_stall = '0') or  -- origin by fox
								-- modified for 2 thread execution
								(thread_ctrl_state=AllThreadsWait  
									--and rdy_thread_num_reg = x"2"
									-- hidden by T.H.Wu , 2013.10.29 , when # threads > 3 , prepare thread may go wrong
									and (rdy_thread_num_reg > "00001"  or (rdy_thread_num_reg="00001" and timeout='1'))
									and (previous_thread = ready_thread or nxt_rdy_TH_new_coming='1' 
										)
								) or 
								-- modified for 2 thread execution
								(act_dly_2clk='0' and new_thread_flag_inactive_1clk_dly1='1')
									-- modified for the first thread  (maybe not main thread) set-up, 2013.9.10
								
                 else      '0';
	
	
	reg_CtrlUnit :
	process(clk) 
		variable state_info			: integer;
		variable thread_state   	: std_logic_vector(Max_Thread_Number/4+2 downto 0);
	begin
        if(rising_edge(clk)) then	
            if(Rst = '1') then 
				act_dly_2clk				    <= '0'; 
				thread_dead				<= '0';
				previous_thread 		<= "111111"; --x"FF";
				runnable_thread 		<= "000000"; --x"00";
				ready_thread 			<= "000001"; --x"01";  
				new_thread_id 			<= "000001"; --x"00"; -- modified by T.H.Wu, 2013.10.5  
				thread_num_reg 			<=	(others => '0');
				rdy_thread_num_reg		<=	(others => '0'); 
				nxt_rdy_TH_new_coming	<=	'0';
				empty_slot				<=	x"1";
				previous_thread_in_slot	<=	(others => '0');
				now_thread_in_slot		<=	(others => '0');
				ready_thread_in_slot	<=	(others => '0'); 
				------ added by T.H.Wu for updating TCB  , 2013.10.5
				previous_thread_state	<= TH_STATE_IDLE;
				runnable_thread_state	<= TH_STATE_IDLE;
				ready_thread_state		<= TH_STATE_IDLE;
				now_thread_monitorenter_fail_hold <= '0';
				now_thread_monitorenter_fail_dly_1clk <= '0';
				monitorexit_nextowner_TCB0_hold		<=	'0' ;
				monitorexit_nextowner_readyQ_hold	<=	'0' ;
				monitorexit_nextowner_thread_slot_idx_hold	<=	(others => '0');
				monitorexit_nextowner_readyQ_TH_id			<=	(others => '0');
				monitorenter_cmplt	<= '0';
				monitorexit_cmplt	<= '0';
				--
				run_thread_time_slice_keep_unchanged	<=	'0';
				--
				MT_mgt_en_reg						<= '0'; 
				TH_data_out_transfer_cnt_reg		<= (others=>'0');
				TCB2rdyTHstate_cnt_reg				<= (others=>'0');
				TCB2rdyTHstate_cnt_increment_flag	<= '0';
				stack_rw_enable_reg        			<= '0';
            else 
				case thread_ctrl_state is
					when Idle =>
						mem2LVreg_reg	<= '0';
						first_thread_setup_cmplt<= '0';
						--if(new_thread_flag = '1' ) then -- modified by T.H.Wu , 2013.7.9
						-- modified by T.H.Wu , 2013.9.8 , for multi-core coordinator use
						if(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"0") then
							if(thread_num_reg="00000") then -- if executing complex benchmark , it will be useful.
								runnable_thread <= new_thread_id;
								runnable_thread_state	<=	TH_STATE_READY;
							end if;
							if(thread_num_reg="00001") then
								ready_thread <= new_thread_id; 
								ready_thread_state	<=	TH_STATE_READY;
								-- there may be a problem, if a new thread acquire monitor immediately when it start to execute ....
							end if;
						end if;
					when Prepare_Next_thread =>			
						mem2LVreg_reg	<= '0'; 
					
					when Check_Timeout =>
						if(timeout = '1') then
							MT_mgt_en_reg	<= '1'; 
							-- if(ready_thread_TCBlist(0)(30) = '0') then
								-- new_thread_start	<= '1';
							-- end if;
						end if;
						if(now_thread_monitorenter_fail_hold='1') then
							runnable_thread_state <= TH_STATE_WAIT; 
						end if;
					
					when ContextSwitch =>					
						if(MT_mgt_en_reg = '1') then
							MT_mgt_en_reg	<= '0';
							previous_thread	<= runnable_thread;
							runnable_thread	<= ready_thread;
							ready_thread	<= ReadyQueue(to_integer(unsigned(next_ready))); 
							--backup_length	<= sp; -- modified by T.H.Wu , 2013.7.18
						end if;
					
						if(ClsLoading_stall = '0') then
							previous_thread_in_slot	<= now_thread_in_slot;
							now_thread_in_slot 		<= ready_thread_in_slot;
							--new_thread_start		<= '0'; 
							if(ready_thread_TCBlist(0)(30) = '1') then
								mem2LVreg_reg	<= '1';
							end if;
							-- added by T.H.Wu for updating TCB  , 2013.10.5
							previous_thread_state <= runnable_thread_state;
							runnable_thread_state <= ready_thread_state;
						end if;
					when Backup_previous_thread_TCBinfo => -- modified by T.H.Wu , 2013.11.19, mismatch ?
						--if(TH_data_in_transfer_cnt_dly =x"2") then
						if(TH_data_in_transfer_cnt_dly =x"3") then
							backup_length	<= TH_data_in (RAMB_S36_AWIDTH downto 0);
						end if;
						mem2LVreg_reg	<= '0'; -- modified by T.H.Wu , 2013.7.19
					--when Backup_Previous_Stack =>
						--mem2LVreg_reg	<= '0';  -- modified by T.H.Wu , 2013.7.19 , for modifying state controller
					-- added by T.H.Wu , 2013.9.10
					when Prepare_next_thread_TCB_info =>
						if(TH_data_out_transfer_cnt_reg=x"8" and thread_num_reg="00001" and act_dly_2clk='0') then
							first_thread_setup_cmplt <= '1';
						end if;
						-- --
						if(now_thread_monitorenter_fail_hold='1' and TH_data_out_transfer_cnt_reg=x"8") then
							runnable_thread_state <= TH_STATE_WAIT; 
						end if;
						-- --
					
					when others => null ;
				end case; 
				
				empty_slot			<=	find_empty_slot;
				ready_thread_in_slot<=	find_ready_slot; 
				stack_rw_enable_reg	<=	stack_rw_enable_w ; 
				rdy_thread_num_reg	<=	rdy_thread_num_reg_w;
				
				-- if(new_thread_flag_dly = '1') then -- modified by T.H. Wu , 2013.7.9
				if(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"8") then
					new_thread_id		<= new_thread_id + "01";
					thread_num_reg	<= thread_num_reg + "00001";
				elsif(thread_dead_flag = '1') then
					thread_num_reg	<= thread_num_reg - "00001";
				end if; 
				----
				if(get_state_3cycle='1') then
					ready_thread_state <= ready_thread_TCBlist(0)(29 downto 28);
				end if;
				---- 
				-- note by T.H.Wu , 2013.11.4 ,	fixed bug, when ready thread  from 1 to 2 (from 0 to 1) ,we should
				--									check one more thing: ready_thread=runnable_thread
				 --modified by T.H.Wu , 2013.12.2 , fix the problem for TMT 16 threads
				--if( monitorexit_nextowner_readyQ_sync='1' and rdy_thread_num_reg < x"2") then
				if( monitorexit_nextowner_readyQ_sync='1' and rdy_thread_num_reg < "00010" and 
					(ready_thread_state/=TH_STATE_READY	or ready_thread=runnable_thread or ready_thread="000000")
				) then
					ready_thread <= monitorexit_nextowner_readyQ_TH_id;
					ready_thread_state <= TH_STATE_READY;
				end if;
				
				if( monitorexit_nextowner_readyQ_sync='1' and rdy_thread_num_reg < "00010" and 
					(ready_thread_state/=TH_STATE_READY	or ready_thread=runnable_thread or ready_thread="000000")
				) then
					nxt_rdy_TH_new_coming <= '1';
				elsif(thread_ctrl_state=Prepare_next_thread_TCB_info) then
					nxt_rdy_TH_new_coming <= '0';
				end if;
					 
				
				
				----
				if(now_thread_monitorenter_fail='1') then
					now_thread_monitorenter_fail_hold <= '1';
				elsif(
							thread_ctrl_state=Check_Timeout or now_thread_monitorenter_succeed='1'
						or (thread_num_reg="00001" and monitorexit_nextowner_readyQ_sync='1')
				) then
					-- when only one threadi in the core and monitorexit from other cores comes to this core
					-- we still need to change the thread from wait state to ready state
					--, more exactly, stop to stall the single thread
					now_thread_monitorenter_fail_hold <= '0';
				end if;
				----
				if(thread_dead_flag = '1') then
					thread_dead <= '1';
				elsif(thread_ctrl_state=ContextSwitch and ClsLoading_stall = '0') then
					thread_dead <= '0';
				end if;
				---- 
				now_thread_monitorenter_fail_dly_1clk	<=	now_thread_monitorenter_fail;
				monitorexit_nextowner_TCB0_hold		<=	monitorexit_nextowner_TCB0_hold_w ;
				monitorexit_nextowner_readyQ_hold	<=	monitorexit_nextowner_readyQ_hold_w ;
				monitorexit_nextowner_thread_slot_idx_hold	<=	monitorexit_nextowner_thread_slot_idx_hold_w ;
				monitorexit_nextowner_readyQ_TH_id		<=	monitorexit_nextowner_readyQ_TH_id_w ;
				-- modified by T.H.Wu ,   timing issue , 2013.10.26 
				if(now_thread_monitorenter_succeed='1' or (thread_ctrl_state=Check_Timeout and now_thread_monitorenter_fail_hold='1')) then
					monitorenter_cmplt	<= '1';
				else
					monitorenter_cmplt	<= '0';
				end if;
				-- --
				monitorexit_cmplt	<= monitorexit_nextowner_readyQ_sync or monitorexit_lockfree;
				-- --
				if(now_thread_monitorenter_succeed='1') then
					run_thread_time_slice_keep_unchanged	<=	'1';
				elsif( monitorexit_sender_is_the_core='1' ) then
					run_thread_time_slice_keep_unchanged	<=	'0';
				end if;
				-- --
				act_dly_2clk	 <= act_dly;
				-- added by T.H.Wu , 2013.7.18
				TH_data_out_transfer_cnt_reg	<= TH_data_out_transfer_cnt_reg_w;
				TCB2rdyTHstate_cnt_reg			<= TCB2rdyTHstate_cnt_reg_w;
				TCB2rdyTHstate_cnt_increment_flag	<=	TCB2rdyTHstate_cnt_increment_flag_w;
			---
            end if;
			
			-- modified by T.H.Wu , 2013.10.2 , for fixing the bug when TCB list stored in BRAM.  
			thread_num_reg_dly	<=	thread_num_reg;
			monitorexit_nextowner_here_dly <= monitorexit_nextowner_here and not now_thread_monitorenter_succeed;
			
			-- 2013.7.23 , when only 2 thread context-switch , this may be bug for backup/restoring next  ready thread's TCB
			-- modified by T.H.Wu , so we need to delay to fetch the ready thread's TCB until we make sure next  ready thread 
			thread_state	:= ("000" & ready_thread_in_slot) ;
			state_info		:= to_integer(unsigned(thread_state));
			
			if(get_state_2cycle = '1') then -- origin by fox , 2013.7.23 
				ready_thread_TCBlist(0)	<=  ThreadControlBlock(state_info); 
			end if;
			---
			if(TCB2rdyTHstate_cnt_reg=x"2") then
				ready_thread_TCBlist(1)	<=  TCBlist_DOB;
			end if;
			if(TCB2rdyTHstate_cnt_reg=x"3") then
				ready_thread_TCBlist(2)	<=  TCBlist_DOB; -- vp & sp 
			end if;
			if(TCB2rdyTHstate_cnt_reg=x"4") then
				ready_thread_TCBlist(3)	<=  TCBlist_DOB;
			end if;
			if(TCB2rdyTHstate_cnt_reg=x"5") then
				ready_thread_TCBlist(4)	<=  TCBlist_DOB;
			end if;
			if(TCB2rdyTHstate_cnt_reg=x"6") then
				ready_thread_TCBlist(5)	<=  TCBlist_DOB;
			end if;
			if(TCB2rdyTHstate_cnt_reg=x"7") then
				ready_thread_TCBlist(6)	<=  TCBlist_DOB;
			end if;
			if(TCB2rdyTHstate_cnt_reg=x"8") then
				ready_thread_TCBlist(7)	<=  TCBlist_DOB;
			end if; 
        end if;
    end process;
	
	
	-- find first empty slot start from TCB 0 to end
	process(new_thread_flag,TH_data_in_transfer_cnt_dly,empty_slot, ThreadControlBlock)  
	begin
		find_empty_slot <= empty_slot;
		-- modified by T.H. Wu , 2013.7.9
		if(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"0") then
			for index in 0 to Max_Thread_Number-1 loop
				if(ThreadControlBlock(index)(31) = '0') then 
					find_empty_slot <= conv_std_logic_vector(index, Max_Thread_Number/4);
					exit; 
				end if;
			end loop;   
		end if;
    end process;
	
	-- find ready thread in which slot -- 2013.7.18  
	process(get_thread_state, ready_thread, ready_thread_in_slot, ThreadControlBlock)  
	begin
		find_ready_slot <= ready_thread_in_slot; 
		--
		if(get_thread_state = '1') then
			for index in 0 to Max_Thread_Number-1 loop
				if(ThreadControlBlock(index)(5 downto 0) = ready_thread) then 
					find_ready_slot <= conv_std_logic_vector(index, Max_Thread_Number/4); 
					exit; 
				end if;
			end loop;
			----- 
		end if; 
    end process;
	
	
	
	Queue_CtrlLogic :
    process(clk) begin
		if(rising_edge(clk)) then 
        if(Rst = '1') then
			-- fix the bug for multi-thread performance , 2013.9.16
			-- modified by T.H. Wu , 2014.2.26, fix the problem , which JAIP is on second round of thread ready queue
			next_ready		<= x"0";
			readyQ_tail		<= x"0"; --x"1"; 
			--
            for idx in 0 to Max_Thread_Number-1 loop
                ReadyQueue(idx) <= (others => '0');
            end loop;
			-- 
        else
			--if(new_thread_flag_dly = '1') then 
			-- modified by T.H. Wu , 2013.7.9
			-- modified by T.H. Wu , 2014.2.26, fix the problem , which JAIP is on second round of thread ready queue
			--if(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"1") then
			if(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"1" and act_dly_2clk='1') then
				ReadyQueue(to_integer(unsigned(readyQ_tail))) <= new_thread_id;
				readyQ_tail <= readyQ_tail + "01"; 
			elsif( timeout = '1' and thread_ctrl_state=Check_Timeout ) then
				if (thread_dead = '0' and runnable_thread_state=TH_STATE_READY) then
					ReadyQueue(to_integer(unsigned(readyQ_tail))) <= runnable_thread;
					readyQ_tail <= readyQ_tail + "01";  
				end if;
				ReadyQueue(to_integer(unsigned(next_ready))) <= (others=>'0'); -- added for debug , 2013.10.25
			elsif (monitorexit_nextowner_readyQ_sync='1' and thread_num_reg>"00001") then
				-- recall when number of ready threads in this core is 1, and current thread has failed to acquire monitor,
				-- the thread would not be removed from readyQ , later when the other thread of other core release monitor,
				-- and next owner of the monitor is in this core, the current thread of this core should add the thread ID
				-- into readyQ .
				ReadyQueue(to_integer(unsigned(readyQ_tail))) <= monitorexit_nextowner_readyQ_TH_id;
				readyQ_tail <= readyQ_tail + "01"; 
			end if; 
			--
			if(timeout = '1' and thread_ctrl_state=Check_Timeout) then
				next_ready <= next_ready + "01";
			end if;
			-- 
			--
		end if;
		end if;
    end process;
	
	-- added by T.H.Wu , 2013.10.7, calculating ready thread number if there's no ready thread to facilitate CPU
	-- or if some other core call monitorexit to weakup one thread in this core
	-- there's another way ,evaluate next_ready and readyQ_tail directly....
	process (
		rdy_thread_num_reg, new_thread_flag, TH_data_in_transfer_cnt_dly, monitorexit_nextowner_readyQ_sync,
		thread_dead_flag, now_thread_monitorenter_fail, monitorexit_nextowner_here
	) begin
		rdy_thread_num_reg_w <= rdy_thread_num_reg ;
		 -- new thread / thread from wait to ready 
			if(	
				(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"8") or
				(now_thread_monitorenter_succeed='1' and monitorexit_nextowner_here='1') or
					--  now_thread_in_slot=monitorexit_nextowner_thread_slot_idx
				(monitorexit_nextowner_readyQ_sync='1')
			) then
				rdy_thread_num_reg_w <= rdy_thread_num_reg + "00001";
				-- thread from ready to wait / thread terminates
			elsif ((thread_dead_flag = '1') or (now_thread_monitorenter_fail='1')) then
				rdy_thread_num_reg_w <= rdy_thread_num_reg - "00001";
			end if; 
	end process;
	
	
	
	----
	process (
		monitorexit_nextowner_TCB0_hold, monitorexit_nextowner_readyQ_hold, monitorexit_nextowner_thread_slot_idx_hold,
		monitorexit_nextowner_readyQ_TH_id, monitorexit_nextowner_here, monitorexit_nextowner_thread_slot_idx,
		monitorexit_nextowner_TCB0_sync, monitorexit_nextowner_here_dly, ThreadControlBlock, monitorexit_nextowner_readyQ_sync,
		now_thread_monitorenter_succeed
	)
	begin
		monitorexit_nextowner_TCB0_hold_w <= monitorexit_nextowner_TCB0_hold;
		monitorexit_nextowner_readyQ_hold_w <= monitorexit_nextowner_readyQ_hold;
		monitorexit_nextowner_thread_slot_idx_hold_w <= monitorexit_nextowner_thread_slot_idx_hold;
		monitorexit_nextowner_readyQ_TH_id_w		 <= monitorexit_nextowner_readyQ_TH_id;
		-- the clock for updating thread state of TCB list 
		--if(monitorexit_nextowner_here='1') then
		if(monitorexit_nextowner_here='1' and now_thread_monitorenter_succeed='0') then
			monitorexit_nextowner_TCB0_hold_w <= '1';
			monitorexit_nextowner_thread_slot_idx_hold_w <= monitorexit_nextowner_thread_slot_idx;
		elsif(monitorexit_nextowner_TCB0_sync='1') then
			monitorexit_nextowner_TCB0_hold_w <= '0';
		end if;
		-- delay 1 clock for updating ready queue
		if(monitorexit_nextowner_here_dly='1') then
			monitorexit_nextowner_readyQ_hold_w <= '1'; 
			monitorexit_nextowner_readyQ_TH_id_w <= ThreadControlBlock 
						(to_integer(unsigned(monitorexit_nextowner_thread_slot_idx_hold)))
						(5 downto 0);
		elsif (monitorexit_nextowner_readyQ_sync='1') then
			monitorexit_nextowner_readyQ_hold_w <= '0';
		end if;
	end process;
	----
	----
	monitorexit_nextowner_readyQ_sync <= '0' when readyQ_we = '1' else monitorexit_nextowner_readyQ_hold;
	monitorexit_nextowner_TCB0_sync <=	'0' when TCB0_we = '1' else monitorexit_nextowner_TCB0_hold;
	----
	readyQ_we <=	'1' when	(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"1")
						or		(
									timeout = '1' and thread_ctrl_state=Check_Timeout and 
									thread_dead = '0' and runnable_thread_state=TH_STATE_READY
								)
			else	'0';
	TCB0_we <=	'1'	when
					(thread_ctrl_state=Backup_previous_thread_TCBinfo	and TH_data_in_transfer_cnt_dly=x"1")
				-- [note] 2013.10.4, in practical case :
				-- TCB slot of new thread, and TCB slot of next owner of lock could not be the same.
				-- TCB slot of thread dead, and TCB slot of next owner of lock could not be the same.
				or	(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"1") 
				or	((thread_ctrl_state=Check_Timeout or thread_ctrl_state=Prepare_next_thread_TCB_info)  and thread_dead='1')
		else	'0';
	
	
	TCB_slot <= 
				-- 2013.7.18 , might be bug , if Thread.start () is invoked in the mean time making a backup  for TCB info . 
				-- (new_thread_flag='1') , then the backup may go wrong.
				previous_thread_in_slot when  thread_ctrl_state=Backup_previous_thread_TCBinfo 
		else -- modified by T.H.Wu , 2013.7.18
				empty_slot  when new_thread_flag = '1' and TH_data_in_transfer_cnt_dly/=x"0" 
		else	now_thread_in_slot; 
	
	
	--TCB entry(each element has 32 bit):
	--	0. 		exist(1 bit) new(1 bit) thread id
	--	1. 		cls id & mt id
	--	2. 		vp & sp 
	--	3. 		reg_valid & jpc
	--	456.	3 top of stack(A,B,C)
	--	7.		empty
	ThreadControlBlock_CtrlLogic :
    process(clk) 
		variable info0			: integer;
		variable info1			: integer;
		variable thread_info0   : std_logic_vector(Max_Thread_Number/4+2 downto 0);
	begin
		if(rising_edge(clk)) then
        if(Rst = '1') then 
			-- modified by T.H.Wu , 2013.9.8 for multi-core coordinator use  
			for idx in 0 to Max_Thread_Number-1 loop
				ThreadControlBlock(idx) <= (others => '0');
			end loop;
        else	 
			thread_info0 := ("000"  & TCB_slot) ; --& "000";
			info0 := to_integer(unsigned(thread_info0)); 
			-- init new thread info
			-- modified this if statement by T.H.Wu , 2013.7.18 
			
			if(thread_ctrl_state=Backup_previous_thread_TCBinfo and TH_data_in_transfer_cnt_dly =x"1") then 
				ThreadControlBlock(info0)	<= ThreadControlBlock(info0)(31) & "1" & previous_thread_state
												& ThreadControlBlock(info0)(27 downto 0);
			elsif(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly=x"1") then
			-- note:thread_state :
			-- "000" idle 
			-- "001" wait
			-- "010" ready
			-- "011" running 
				ThreadControlBlock( info0 ) <= 
						"10" & TH_STATE_READY &	ThreadControlBlock(info0)(27 downto 6)
						& new_thread_id;
			-- note by T.H.Wu , 2013.10.4 , update each thread state...
			elsif( monitorexit_nextowner_TCB0_sync = '1' ) then
					info1 := to_integer(unsigned( monitorexit_nextowner_thread_slot_idx_hold));
					ThreadControlBlock(info1) <= ThreadControlBlock(info1)(31 downto 30) & 
												TH_STATE_READY & ThreadControlBlock(info1)(27 downto 0)	;
			-- modified by T.H.Wu , 2013.7.18 --  there's a problem
			elsif( (thread_ctrl_state=Check_Timeout or thread_ctrl_state=Prepare_next_thread_TCB_info)  and thread_dead='1' ) then 
				ThreadControlBlock(info0) 	<= "00" & TH_STATE_IDLE & X"0000000";
			end if;
		end if;
		end if;
    end process;
	
	
		-- port A
		TCBlist_WEA		<= '1' when	(thread_ctrl_state=Backup_previous_thread_TCBinfo 
										and TH_data_in_transfer_cnt_dly>=x"2" and TH_data_in_transfer_cnt_dly <=x"7") or
									(new_thread_flag = '1' and TH_data_in_transfer_cnt_dly>=x"2" and TH_data_in_transfer_cnt_dly<=x"8")
						else	'0';
		TCBlist_thread_w_offset <= TH_data_in_transfer_cnt_dly - x"1";
		TCBlist_ADDRA	<=	("00" & TCB_slot & TCBlist_thread_w_offset(2 downto 0)); 
		TCBlist_DIA		<=	TH_data_in ; 
		
		-- port B
		TCBlist_WEB		<= '0';
		TCBlist_thread_r_offset <= TCB2rdyTHstate_cnt_reg ;
		TCBlist_ADDRB	<=	("00" & ready_thread_in_slot & TCBlist_thread_r_offset(2 downto 0));
		TCBlist_DIB		<=	x"00000000"; 
	
		--G1 : for idx in 0 to 7 generate
			RAM_array : RAMB16_S36_S36
			port map(
				-- port A
				ADDRA	=> TCBlist_ADDRA,
				DIPA	=> (others=>'0') ,
				DIA		=> TCBlist_DIA , 
				DOA		=> TCBlist_DOA ,
				CLKA	=> clk,
				SSRA	=> rst,
				ENA 	=> '1',
				WEA		=> TCBlist_WEA,
				-- port B
				ADDRB	=> TCBlist_ADDRB, 
				DIPB	=> (others=>'0') ,
				DIB		=> TCBlist_DIB , 
				DOB		=> TCBlist_DOB ,
				CLKB 	=> clk,
				SSRB 	=> rst,
				ENB		=> '1',
				WEB		=> TCBlist_WEB
			);
		--end generate G1;
		
		 
		
		
    
    
    ----------------------------------------------------------------------------------------------------------------------
    -- added by T.H.Wu , 2013.9.25
	--  , for loading next ready thread's TCB info sequentially. 
    ----------------------------------------------------------------------------------------------------------------------
    process (TCB2rdyTHstate_cnt_reg, get_thread_state, TCB2rdyTHstate_cnt_increment_flag) begin
		TCB2rdyTHstate_cnt_reg_w <= TCB2rdyTHstate_cnt_reg;
		TCB2rdyTHstate_cnt_increment_flag_w <= TCB2rdyTHstate_cnt_increment_flag;
		if(get_thread_state='1')then
			TCB2rdyTHstate_cnt_increment_flag_w <= '1';
		elsif (TCB2rdyTHstate_cnt_reg>=x"8") then
			TCB2rdyTHstate_cnt_increment_flag_w <= '0';
		end if;
		--
		if (TCB2rdyTHstate_cnt_increment_flag_w='1') then
			TCB2rdyTHstate_cnt_reg_w <= TCB2rdyTHstate_cnt_reg + x"1";
		else
			TCB2rdyTHstate_cnt_reg_w <= (others=>'0');
		end if;
    end process;
	
        ----------------------------------------------------------------------------------------------------------------------
        -- added by T.H.Wu , 2013.7.18
        -- for prepare TCB info of next ready thread , send them to other modules sequentially.
        ----------------------------------------------------------------------------------------------------------------------
    process (TH_data_out_transfer_cnt_reg, thread_ctrl_state ) begin
        TH_data_out_transfer_cnt_reg_w <= TH_data_out_transfer_cnt_reg ;
        if(thread_ctrl_state=Prepare_next_thread_TCB_info) then
            TH_data_out_transfer_cnt_reg_w <= TH_data_out_transfer_cnt_reg + x"1"; 
        else
            TH_data_out_transfer_cnt_reg_w <= (others=>'0') ;
        end if;
    end process;
    
    process (
            TH_data_out_transfer_cnt_reg,  TH2MA_thread_info,	thread_stack_info, --ThreadControlBlock
			thread_reg_valid,  thread_jpc, thread_stack_A, thread_stack_B, thread_stack_C, thread_obj
    )  
	begin 
        ---
		case TH_data_out_transfer_cnt_reg is
            when x"1" =>        TH_data_out <= TH2MA_thread_info;
            when x"2" =>        TH_data_out <= thread_stack_info;
            when x"3" =>        TH_data_out <= x"000" & thread_reg_valid & thread_jpc;
            when x"4" =>        TH_data_out <= thread_stack_A;
            when x"5" =>        TH_data_out <= thread_stack_B;
            when x"6" =>        TH_data_out <= thread_stack_C;
            --when x"7" =>      TH_data_out <= thread_obj; 
            when others =>		TH_data_out <= thread_obj;
        end case;
    end process;
	
    -- recall that ....
	TH2MA_thread_info	<= ready_thread_TCBlist(1);
	thread_stack_info	<= ready_thread_TCBlist(2);
	thread_jpc			<= ready_thread_TCBlist(3)(15 downto 0);
	thread_reg_valid	<= ready_thread_TCBlist(3)(19 downto 16);
	thread_stack_A		<= ready_thread_TCBlist(4);
	thread_stack_B		<= ready_thread_TCBlist(5);
	thread_stack_C		<= ready_thread_TCBlist(6);
	thread_obj			<= ready_thread_TCBlist(7); 
        ----------------------------------------------------------------------------------------------------------------------
    
	
	-- sub-fsm
	process(clk) begin
		if(rising_edge(clk)) then 
			new_thread_flag_dly <= new_thread_flag;
			get_state_2cycle	<= get_thread_state;
			get_state_3cycle	<= get_state_2cycle;
			new_thread_flag_inactive_1clk_dly1 <= new_thread_flag_inactive_1clk; 
		end if;
    end process;
	
	counter_for_CS :
    process(clk) begin
		if(rising_edge(clk)) then 
        if(Rst = '1') then
			time_slice		<= x"007A12";--x"000003E8";--x"00007A12";--x"000002BC";  --x"00002710";
			time_counter	<= (others => '0');
			timeout			<= '0';
			before_16clk_now_TH_timeout <= '0';
			now_TH_exec_cnt_increase_flag	<=	'0';
			now_TH_exec_cnt_without_any_stall(4 downto 0) <= "00000";
			now_TH_start_exec_over_28clk	<=	'0';
        else
			if(SetTimeSlices_Wen = '1') then
				time_slice <= TH_data_in(23 downto 0); -- ex2java_data;
			end if;
			
			if(thread_ctrl_state=ContextSwitch or now_thread_monitorenter_succeed='1') then --and MT_mgt_en_reg = '1') then
				timeout	<= '0';   
			elsif(do_switch = '1' or thread_dead = '1' or now_thread_monitorenter_fail_hold='1') then
				timeout <= '1'; 
			elsif(over = '1') then
				timeout	<= '0';
			end if;
			
			
			if(thread_ctrl_state=ContextSwitch ) then 
				time_counter <= (others => '0'); 
			elsif(do_switch = '1' or thread_dead = '1' or now_thread_monitorenter_fail_hold='1' 
					--or	run_thread_time_slice_keep_unchanged = '1'
				) then 
				time_counter <= time_counter;
			elsif(over = '1') then 
				time_counter <= (others => '0'); 
			elsif(thread_ctrl_state = Prepare_Next_thread or 
				  thread_ctrl_state = Check_Timeout or 
				  thread_ctrl_state = Backup_Previous_Stack or
				  --thread_ctrl_state = AllThreadsWait or	-- timer counter should be stopped if current thread
															-- is in AllThreadsWait state.
				  thread_ctrl_state = Prepare_next_thread_TCB_info or 
				  thread_ctrl_state  = Backup_previous_thread_TCBinfo
				  )	and interrupt_req = '0'
				  then	 
					time_counter <= time_counter + "01"; 
			end if;
			
			
			--
			-- note by T.H.Wu , 2013.10.24 , there may be some unknown problems .
			if(
				(thread_ctrl_state=Check_Timeout and (time_counter+x"16") >= time_slice) or
				(
					--(thread_ctrl_state=Check_Timeout or (thread_ctrl_state=Prepare_next_thread_TCB_info and TH_data_out_transfer_cnt_reg>=x"8")) 
					(thread_ctrl_state=Check_Timeout or thread_ctrl_state=Prepare_next_thread_TCB_info) 
					and 
					(thread_dead = '1' or now_thread_monitorenter_fail_hold='1')
				)
			) then
				before_16clk_now_TH_timeout <= '1';
			elsif (thread_ctrl_state=ContextSwitch and ClsLoading_stall = '0') then
				before_16clk_now_TH_timeout <= '0';
			end if;
			
			-- added by T.H.Wu, 2014.3.6
			if(thread_ctrl_state=ContextSwitch and ClsLoading_stall = '0') then
				now_TH_exec_cnt_increase_flag	<=	'1';
			elsif(now_TH_exec_cnt_without_any_stall(4 downto 0) = "11100") then
				now_TH_exec_cnt_increase_flag	<=	'0';
			end if;
			--
			if(now_TH_exec_cnt_increase_flag = '1') then
				now_TH_exec_cnt_without_any_stall(4 downto 0)	<=	now_TH_exec_cnt_without_any_stall(4 downto 0) + "01";
			else
				now_TH_exec_cnt_without_any_stall(4 downto 0)	<=	"00000";
			end if;
			--
			if(now_TH_exec_cnt_without_any_stall(4 downto 0) = "11100") then
				now_TH_start_exec_over_28clk <= '1';
			else
				now_TH_start_exec_over_28clk <= '0';
			end if;
			
		end if;
		end if;
    end process;
	
	process(clk) begin
		if(rising_edge(clk)) then
		if(Rst = '1' ) then
            clean_pipeline_reg	<= '0';
			do_switch			<= '0';
        else
			if(thread_ctrl_state = Check_Timeout) then
				if(over = '1') then
					clean_pipeline_reg	<= '1';
					do_switch			<= '0';
				elsif(clean_pipeline_cmplt = '1' and stall_all_flag = '0') then
					clean_pipeline_reg	<= '0';
					do_switch			<= '1';
				end if;
			else
				do_switch			<= '0';
				clean_pipeline_reg	<= '0';
            end if;
        end if;
        end if;
	end process;
	
	over			<= '1' when	(time_counter >= time_slice and stall_all_flag = '0' and simple_mode = '1')
								--and run_thread_time_slice_keep_unchanged = '0'	-- modified by T.H.Wu , 2013.11.7
								and thread_ctrl_state = Check_Timeout  
								-- modified by T.H.Wu , 2013.10.8
					else '0'; 
	
	----------------------------------------------------------------------
	----------------------------------------------------------------------
	----------------------------------------------------------------------
	debug_cs_thread_mgt(3 downto 0)	<= 
                           x"1" when thread_ctrl_state = Idle else
						   x"2" when thread_ctrl_state = Check_Timeout else
						   x"3" when thread_ctrl_state = ContextSwitch else
						   x"4" when thread_ctrl_state = Backup_Previous_Stack else
						   x"5" when thread_ctrl_state = Prepare_Next_thread else
						   x"6" when thread_ctrl_state = Backup_previous_thread_TCBinfo else
						   x"7" when thread_ctrl_state = Prepare_next_thread_TCB_info else
						   x"8" when thread_ctrl_state = AllThreadsWait else
						   x"F";
     
            debug_cs_thread_mgt(8 downto 4) <= runnable_thread (4 downto 0);
            debug_cs_thread_mgt(13 downto 9) <= ready_thread (4 downto 0);
            debug_cs_thread_mgt(18 downto 14) <= previous_thread (4 downto 0);
            debug_cs_thread_mgt(19) <= over;
            debug_cs_thread_mgt(20) <= nxt_rdy_TH_new_coming;
            debug_cs_thread_mgt(25 downto 21) <= rdy_thread_num_reg(4 downto 0) ; 
												--	TCB_slot (3 downto 0);
            debug_cs_thread_mgt(26) <= before_16clk_now_TH_timeout ; --; --new_thread_flag ;
            debug_cs_thread_mgt(27) <= thread_dead_flag ;
        
            debug_cs_thread_mgt(28) <= get_thread_state ; --run_thread_time_slice_keep_unchanged; --clean_pipeline_reg;
            debug_cs_thread_mgt(29) <= timeout ;
            debug_cs_thread_mgt(30) <= monitorexit_nextowner_readyQ_sync;
            debug_cs_thread_mgt(31) <= monitorexit_nextowner_TCB0_sync ;
            debug_cs_thread_mgt(35 downto 32) <= next_ready(3 downto 0); 
            debug_cs_thread_mgt(36) <= '0' ;
			debug_cs_thread_mgt(41 downto 37)	<= thread_num_reg (4 downto 0); -- monitorexit_nextowner_thread_slot_idx_hold;
		 	--debug_cs_thread_mgt(47 downto 42)	<= monitorexit_nextowner_readyQ_TH_id;
            debug_cs_thread_mgt(45 downto 42) <= readyQ_tail (3 downto 0); 
            debug_cs_thread_mgt(47 downto 46) <= runnable_thread_state (1 downto 0); 
            --debug_cs_thread_mgt(19 downto 16) <= empty_slot (3 downto 0);
		
            --debug_cs_thread_mgt(30) <= simple_mode ;
            
		--debug_cs_thread_mgt(35 downto 31) <=  new_thread_id(4 downto 0) ; 
                --debug_cs_thread_mgt(39 downto 36) <= previous_thread_in_slot (3 downto 0);
                --debug_cs_thread_mgt(49 downto 40) <= backup_length (9 downto 0);
        
		--debug_cs_thread_mgt(31 downto 28) <= TH_data_in_transfer_cnt_dly(3 downto 0) ;
		--debug_cs_thread_mgt(40 downto 32) <= TCBlist_ADDRA (8 downto 0);
		--debug_cs_thread_mgt(49 downto 41) <= TCBlist_ADDRB (8 downto 0);
		--debug_cs_thread_mgt(50) <= TCBlist_WEA;
		--debug_cs_thread_mgt(82 downto 51) <= TCBlist_DOB;  
                
                     
end architecture rtl;
