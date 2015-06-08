------------------------------------------------------------------------------
-- Filename     :       execute.vhd
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
-- Filename     :       execute.vhd
-- Version      :       2.02
-- Author       :       Kuan-Nian Su
-- Date         :       Apr 2009
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Filename     :       execute.vhd
-- Version      :       3.00
-- Author       :       Han-Wen Kuo
-- Date         :       Jan 2011
-- VHDL Standard:       VHDL'93
-- Describe     :       New Architecture
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Filename     :       execute.vhd
-- Version      :       4.00
-- Author       :       Zi-Jing Guo
-- Date         :       2012/6/1
-- Describe     :       ADD Excption Handler
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity execution is
    generic(
		ENABLE_XCPTN				: integer := 1;
        RAMB_S36_AWIDTH             : integer := 9
    );
    port(
        -- ctrl signal
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        act_dly                     : in  std_logic;
        stall_execution_stage       : in  std_logic;
         
        bytecodes                   : in  std_logic_vector(15 downto 0);
		cst_entry                   : in  std_logic_vector(15 downto 0);
        CTRL_state                  : in  DynamicResolution_SM_TYPE;
             -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
       -- Native_ArgCnt               : in  std_logic_vector( 7 downto 0);
        Native_ArgCnt               : in  std_logic_vector( 4 downto 0);
        
        -- decode stage
        load_immediate1             : in  std_logic_vector(31 downto 0);
        load_immediate2             : in  std_logic_vector(31 downto 0);
        store1_addr                 : in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
        store2_addr                 : in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
        W1_RegFlag                  : in  std_logic;
        W2_RegFlag                  : in  std_logic;
        MemRead_ctrl                : in  Decode2Execute_MemRead_Type;
        ctrl                        : in  Decode2Execute_ControlSignal_Type;
        mem2LVreg_1_decode          : in  std_logic;
        mem2LVreg_2_decode          : in  std_logic;
        stsp_s_flag                 : in  std_logic;
        
        -- flag & req in
        write_ABC                   : in  write_ABC_type;
        invoke_flag                 : in  std_logic;
		static_flag					: in std_logic;
        return_flag                 : in  std_logic;
		clinitEN					: in  std_logic;
        push1_flag                  : out  std_logic;
        push2_flag                  : out  std_logic;
		
        -- out
        TOS_A                       : out std_logic_vector(31 downto 0);
        TOS_B                       : out std_logic_vector(31 downto 0);
        TOS_C                       : out std_logic_vector(31 downto 0);
        vp                          : out std_logic_vector(RAMB_S36_AWIDTH downto 0);
        sp                          : out std_logic_vector(RAMB_S36_AWIDTH downto 0);
        reg_valid                   : out std_logic_vector( 3 downto 0);
        branch_flag                 : out std_logic;
        alu_stall                   : out std_logic;
        StackRAM_RD1                : out std_logic_vector(31 downto 0);
        StackRAM_RD2                : out std_logic_vector(31 downto 0);
        
        -- invoke
       -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
        --ArgSize                     : in  std_logic_vector( 7 downto 0);
        ArgSize                     : in  std_logic_vector(4 downto 0);
        --invoke_objref               : out std_logic_vector(31 downto 0);
		external_access_cmplt       : in  std_logic; 
		
		--xcptn hdlr 
		xcptn_en                    : in  std_logic;
		--act                         : in  std_logic;
        xcptn_thrown_bytecode       : in  std_logic;	
		xcptn_stall                 : out std_logic;
		xcptn_flush_pipeline        : out std_logic;
		-- external memory access
		--external_access_cmplt       : in  std_logic;
		external_load_data          : in  std_logic_vector(31 downto 0);
		external_load_EID_req       : out std_logic;
		external_load_LVcnt_req     : out std_logic;
		-- parser to ER_LUT 
		prsr2ER_LUT_di   	        : in  std_logic_vector(15 downto 0);
		prsr2ER_LUT_addr            : in  std_logic_vector(9 downto 0);
		prsr2ER_LUT_wen             : in  std_logic;	
		--to mthd ctrlr	
		now_mthd_id                 : in  std_logic_vector(15 downto 0);
		ER_info                     : in  std_logic_vector(15 downto 0);
		ER_info_wen_MA_ctrlr        : in  std_logic;
		check_CST_MA_done		    : in  std_logic;
		update_return_regs     		: out std_logic;
		ret_frm_regs_wen		    : out std_logic;                      
		--ret_frm_mthd_id				: out std_logic_vector(15 downto 0);  
		ER_info_addr_rdy            : out std_logic;    
		MA_base_mem_addr_wen        : out std_logic;    	
		--to jpc ctrlr
		stall_jpc                   : in  std_logic;	
		JPC                         : in  std_logic_vector(14 downto 0);
		xcptn_jpc_wen				: out std_logic;
		xcptn_jpc                   : out std_logic_vector(15 downto 0);
		adjust_jpc2xcptn_instr      : out std_logic;
		--to cst_controller
		now_cls_id                  : in  std_logic_vector(15 downto 0);
		parent_EID                  : in  std_logic_vector(15 downto 0);
		--ret_frm_cls_id				: out std_logic_vector(15 downto 0); 
		xcptn_cst_mthd_check_en  	: out std_logic;
		xcptn_cst_mthd_check_IDs_en	: out std_logic;
		get_parent_EID              : out std_logic;
		compared_EID                : out  std_logic_vector(15 downto 0);
		--to instr buffer          
		xcptn_clean_buffer          : out std_logic;
		mask_insr1                  : out std_logic;
		--to decode
		xcptn_done                  : out std_logic;
		-- interrupt req
		interrupt_cmplt             : in  std_logic; 
		interrupt_req_xcptn			: out std_logic;
		interrupt_func_xcptn        : out std_logic_vector(23 downto 0);
		-- native HW
		xcptn_thrown_Native_HW		: in  std_logic;
		Native_HW_thrown_ID			: in  std_logic_vector(15 downto 0);			
		-- end xcptn hdlr
            -- thread management , by fox
		TH_mgt_clean_execute		: in  std_logic;
                -- modified by T.H.Wu , 2013.8.8 , for solving critical path
		--TH_mgt_clean_pipeline_cmplt	: out std_logic;
		stack_mgt_transfer_counter   : in std_logic_vector(RAMB_S36_AWIDTH downto 0); 
		TH_mgt_context_switch		: in  std_logic;  
		TH_mgt_new_thread_execute	: in  std_logic; 
		TH_mgt_LVreg2mem_CS			: in  std_logic; 
                        -- modified by T.H.Wu , 2013.7.18
                TH_data_out_dly : in std_logic_vector(31 downto 0); 
                TH_data_out_transfer_cnt_dly : in std_logic_vector(3 downto 0); 
		--thread_stack_vp			 
		--thread_stack_sp		 
		--thread_stack_A         
                --thread_stack_B        
                --thread_stack_C            
		--TH_mgt_thread_reg_valid  : in  std_logic_vector (3 downto 0);
		--thread_obj	  
		-- stack access mgt		-- by fox
		stackMgt2exe_base_addr		: in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
		stackMgt2exe_rw_stk_en		: in  std_logic;
                external_store_data                 : out  std_logic_vector(31 downto 0);	
        -- for chipscope debug use
        --debug_cs_4portbank : out std_logic_vector(127 downto 0);
		
                --debug_cs_exe   : out  std_logic_vector(93 downto 0) ;
                --debug_cs_xcptn   : out  std_logic_vector(55 downto 0) ;
        -- debug
        debug_flag                  : in  std_logic_vector(11 downto 0);
        debug_addr                  : in  std_logic_vector(11 downto 0);
        debug_data                  : out std_logic_vector(31 downto 0)
		-- cs debug  
		--debug_stack_wdaddr			: out std_logic_vector(17 downto 0);
		--debug_stack_rdaddr			: out std_logic_vector(17 downto 0)
    );
end entity execution;

architecture rtl of execution is

    component ALU 
    generic(
        width		: integer := 32
    );
    port (
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        ALU_op                      : in  std_logic_vector(3 downto 0);
        branch_op                   : in  std_logic_vector(3 downto 0);
        ALUopd1, ALUopd2            : in  std_logic_vector(31 downto 0);
        A, B                        : in  std_logic_vector(31 downto 0);
        ALU_result                  : out std_logic_vector(31 downto 0);
        branch                      : out std_logic ;
        alu_stall                   : out std_logic
    );        
    end component ALU;
    
    component four_port_bank
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
                -- by fox , solving local variable bug
		LVreg_valid	            	: in  std_logic_vector(1 downto 0)
		--cs
		--debug_stack_wdaddr			: out std_logic_vector(17 downto 0);
		--debug_stack_rdaddr			: out std_logic_vector(17 downto 0)
    );
    end component four_port_bank;
	
	component xcptn_hdlr
    port(
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
		xcptn_en                    : in  std_logic;
		--act                         : in  std_logic;
		
		xcptn_thrown_ALU   	    	: in  std_logic;                     --divided by zero
		xcptn_thrown_bytecode       : in  std_logic;					 --bytecode"athrow"
		xcptn_stall                 : out std_logic;
		xcptn_flush_pipeline        : out std_logic;
		-- external memory access
		external_access_cmplt       : in  std_logic;
		external_load_data          : in  std_logic_vector(31 downto 0);
		external_load_EID_req       : out std_logic;
		external_load_LVcnt_req     : out std_logic;
		-- parser to ER_LUT 
		prsr2ER_LUT_di   	        : in  std_logic_vector(15 downto 0);
		prsr2ER_LUT_addr            : in  std_logic_vector(9 downto 0);
		prsr2ER_LUT_wen             : in  std_logic;	
		--to execute 
		get_return_frame       		: out std_logic;
		update_return_regs     		: out std_logic;
		update_TOS_BC               : out std_logic;
		LV_cnt_wen                  : out std_logic;
		get_top2_stack              : out std_logic;
		mem2LVreg_1_xcptn           : out std_logic;
		mem2LVreg_2_xcptn           : out std_logic;
		pop1_addr_en                : out std_logic;
		pop1_BC_reg_wen             : out std_logic;
		--to mthd ctrlr
		now_mthd_id                 : in  std_logic_vector(15 downto 0);
		ER_info                     : in  std_logic_vector(15 downto 0);
		ER_info_wen_MA_ctrlr        : in  std_logic;
        check_CST_MA_done		    : in  std_logic;		
		ret_frm_regs_wen            : out std_logic;
		ER_info_addr_rdy            : out std_logic;
		MA_base_mem_addr_wen		: out std_logic;
       
		--to jpc ctrlr
		stall_jpc                   : in  std_logic;	
		JPC                         : in  std_logic_vector(14 downto 0);
		ER_JPC                      : out std_logic_vector(15 downto 0);
		ER_JPC2JPC_wen				: out std_logic;
		adjust_jpc2xcptn_instr      : out std_logic;
		--xcptn_jpc                   : out std_logic_vector(15 downto 0);
		--to cst_controller
		now_cls_id                  : in  std_logic_vector(15 downto 0);
		parent_EID                  : in  std_logic_vector(15 downto 0);
		xcptn_cst_mthd_check_en  	: out std_logic;
		xcptn_cst_mthd_check_IDs_en	: out std_logic;
		get_parent_EID              : out std_logic;
		compared_EID                : out  std_logic_vector(15 downto 0);
		--to instr buffer          
		xcptn_clean_buffer          : out std_logic;
		mask_insr1                  : out std_logic;
		--to decode
		xcptn_done                  : out std_logic;
		push1_flag                  : out  std_logic;
        push2_flag                  : out  std_logic;
		-- interrupt req
		interrupt_cmplt             : in  std_logic; 
		interrupt_req_xcptn			: out std_logic;
		interrupt_func_xcptn        : out std_logic_vector(23 downto 0);
		-- native HW
		xcptn_thrown_Native_HW		: in  std_logic;
		Native_HW_thrown_ID			: in  std_logic_vector(15 downto 0);	
                --debug_cs_xcptn   : out  std_logic_vector(55 downto 0) ;	
		-- debug flag
        debug_flag                  : in  std_logic_vector(11 downto 0);
        debug_addr                  : in  std_logic_vector(11 downto 0);
        debug_data                  : out std_logic_vector(31 downto 0)
    );
    end component xcptn_hdlr;
    
    signal act_dly_2clk               : std_logic;
    signal act_dly_3clk               : std_logic;
    signal context_switch             : std_logic;
    signal A, B, C                    : std_logic_vector(31 downto 0);
    signal sp_reg_invoke              : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal vp_reg_invoke              : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal sp_reg                     : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal vp_reg                     : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal LVreg_valid                : std_logic_vector( 3 downto 0);
    signal LVreg_valid_tmp            : std_logic_vector( 2 downto 0);
	signal valid_LV                	  : std_logic_vector( 1 downto 0);	-- by fox
    signal LVreg2mem_1, LVreg2mem_2   : std_logic;
	signal LVreg2mem_1_delay   		  : std_logic;
    signal LVreg2mem, mem2LVreg       : std_logic;
    signal LVreg2mem_addr1            : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal LVreg2mem_addr2            : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal mem2LVreg_addr1            : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal mem2LVreg_addr2            : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    
    signal next_A, next_B, next_C     : std_logic_vector(31 downto 0);
    signal next_sp                    : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    
    signal enable                     : std_logic;
    signal R1, R2, W1, W2             : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal SD1, SD2, RD1, RD2         : std_logic_vector(31 downto 0);
    signal LD1, LD2                   : std_logic_vector(31 downto 0);
    signal R1_RegFlag, R2_RegFlag     : std_logic;
    signal R1_en, R2_en, W1_en, W2_en : std_logic;
    signal specialload1_addr          : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal specialload2_addr          : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    --signal invoke_objref_addr         : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal Native_ArgAddr             : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal specialload1_en            : std_logic;
    signal specialload2_en            : std_logic;
    
    
    signal ALUopd1, ALUopd2           : std_logic_vector(31 downto 0);
    signal ALU_result                 : std_logic_vector(31 downto 0);
    signal branch                     : std_logic;
    signal alu_stall_tmp				  : std_logic;
	--for_stack_depth_info 
	 
	-- xcptn hdlr 
	
	--flip flop
	signal LV_cnt                     : std_logic_vector(15 downto 0);
	-- wirres
	
	--signal xcptn_thrown_bytecode_w    : std_logic;
	signal mem2LVreg_1_flag           : std_logic;
	signal mem2LVreg_2_flag           : std_logic;
	signal xcptn_thrown_ALU           : std_logic;
	signal get_return_frame           : std_logic;
	signal update_return_regs_w       : std_logic;
	signal update_TOS_BC              : std_logic;
	signal LV_cnt_wen                 : std_logic;
	signal get_top2_stack             : std_logic;
	signal mem2LVreg_1_xcptn          : std_logic;
	signal mem2LVreg_2_xcptn          : std_logic;
	--signal xcptn_done_w                 : std_logic;
	signal debug_ER_LUT_data   	      : std_logic_vector(31 downto 0);
	
	signal ER_JPC   	              : std_logic_vector(15 downto 0);
	signal ER_JPC2JPC_wen             : std_logic;
	signal ret_frm_regs_wen_w         : std_logic;
	
	signal pop1_addr_en               :  std_logic;
	signal pop1_BC_reg_wen            :  std_logic;
	--signal check_CST_MA_done          : std_logic;
	--end xcptn hdlr 
        -- add by T.H.Wu , 2013.7.9 , for invoking main method
        --signal is_invoke_main_mthd  :  std_logic;
        -- for stack management backup / restore ...
	signal prepare_stack_addr      	  : std_logic_vector(RAMB_S36_AWIDTH downto 0);	-- by fox
        signal backup_stack_data          : std_logic_vector(31 downto 0);	-- by fox
	signal new_thread_reg		  : std_logic;				-- by fox
	signal p_stack_rw			  : std_logic;				-- by fox
	signal prepare_data_in         	  : std_logic_vector(31 downto 0);	-- by fox
        -- added by T.H.Wu , for revising data transferring of Thread control block  , 2013.7.17
        signal  TH_mgt_ready_thread_sp  : std_logic_vector(RAMB_S36_AWIDTH downto 0);
        signal  TH_mgt_ready_thread_vp  : std_logic_vector(RAMB_S36_AWIDTH downto 0);
        signal  TH_mgt_ready_thread_LV_valid  : std_logic_vector(3 downto 0);
        signal  TH_mgt_ready_thread_A : std_logic_vector(31 downto 0);
        signal  TH_mgt_ready_thread_B : std_logic_vector(31 downto 0);
        signal  TH_mgt_ready_thread_C : std_logic_vector(31 downto 0);
        signal  TH_mgt_ready_thread_obj_ref  : std_logic_vector(31 downto 0);
        -- just for vp_reg internal use , check whether this thread is executed at first round 
        signal  TH_mgt_new_thread_execute_reg  : std_logic;
	
    begin
  
              
              
    ALU_Unit : ALU
    generic map(
        width => 32
    )
    port map(	
        Rst        => Rst,
        clk        => clk,
        ALU_op     => ctrl.ALU,
        branch_op  => ctrl.branch,
        ALUopd1    => ALUopd1,
        ALUopd2    => ALUopd2,
        A          => A, 
        B          => B,
        ALU_result => ALU_result,
        branch     => branch,
        alu_stall  => alu_stall_tmp
    );
    alu_stall <= alu_stall_tmp; 
              
    enable <= '1' when CTRL_state = Offset_access or get_return_frame = '1' or get_top2_stack = '1' or
                       pop1_addr_en = '1' or debug_flag = x"020" or debug_flag = x"021" else -- debug 
                    '1' when  CTRL_state = Get_ArgSize else	 	      
			'1' when LVreg2mem = '1' else -- by fox , 2013.7.18 , it might be a problem
			  not stall_execution_stage;
    
    four_port_bank_Unit : four_port_bank
    generic map(
        RAMB_S36_AWIDTH             => RAMB_S36_AWIDTH
    )
    port map(
        -- for chipscope debug use
       -- debug_cs_4portbank =>  debug_cs_4portbank ,
        Rst                         => Rst,
        clk                         => clk,
        enable                      => enable, 
        -- local_variable_reg store and reset ctrl flag (raise 1 cycle)
        invoke_flag                 => LVreg2mem_1,
        return_flag                 => mem2LVreg_1_flag,
        
        R1_RegFlag                  => R1_RegFlag,
        R2_RegFlag                  => R2_RegFlag,
        W1_RegFlag                  => W1_RegFlag,
        W2_RegFlag                  => W2_RegFlag,
        -- flag means access instruction is valid
        intsrs_decode_flag_1        => R1_en,
        intsrs_decode_flag_2        => R2_en,
        intsrs_execution_flag_1     => W1_en,
        intsrs_execution_flag_2     => W2_en,
        -- LD/SW 1 2 means that is instruction one or two of instrs_pkg
        LD_addr_1                   => R1,
        LD_addr_2                   => R2,
        LD_data_1                   => RD1,
        LD_data_2                   => RD2,
        SD_addr_1                   => W1,
        SD_addr_2                   => W2,
        SD_data_1                   => SD1,
        SD_data_2                   => SD2,
        -- for stack management , by box 
		TH_mgt_context_switch =>  context_switch,
		prepare_WE			=> p_stack_rw,
		prepare_addr            	=> prepare_stack_addr,
		prepare_data            	=> prepare_data_in,
		backup_data			=> backup_stack_data,
		LVreg_valid 			=> valid_LV
		--cs 
		--debug_stack_wdaddr			=> debug_stack_wdaddr,
		--debug_stack_rdaddr			=> debug_stack_rdaddr
    );
    
    --invoke_objref <= RD1;
                     
    StackRAM_RD1  <= RD1;
    StackRAM_RD2  <= RD2;
    
    debug_data <= RD2 when debug_flag = x"020"else
				 debug_ER_LUT_data ;
				 
				 
	context_switch <= TH_mgt_context_switch or (not act_dly_3clk and act_dly_2clk);
                 
        -- by fox , modified by T.H.Wu , 2013.7.17
	LVreg2mem_1_delay <= 
                                                -- '1' when (CTRL_state = Get_LV1_XRT_ref and invoke_flag = '1') else
                                                '1' when (CTRL_state = Get_LV1_XRT_ref and invoke_flag = '1') or TH_mgt_LVreg2mem_CS='1' else
						 '1' when ((CTRL_state = IllegalOffset or CTRL_state = Offset_access) and clinitEN = '1') else
						 '0';
	
    LVreg2mem <= LVreg2mem_1 or LVreg2mem_2;
    mem2LVreg <= mem2LVreg_1_flag or mem2LVreg_2_flag;
    
    sp              <= sp_reg;
    vp              <= vp_reg;
    branch_flag     <= branch;

    TOS_A           <= A;
    TOS_B           <= B;
    TOS_C           <= C;
    
    specialload1_en <= '1' when CTRL_state = Native_ArgExporting_Reg or
                                CTRL_state = Native_ArgExporting_DDR or
								(CTRL_state = Get_ArgSize and external_access_cmplt='1') else 
                       '0'; 
    specialload2_en <= '1' when CTRL_state = Native_ArgExporting_Reg or
                                CTRL_state = Native_ArgExporting_DDR or
                                debug_flag = x"020" or   -- debug
                                debug_flag = x"021" else -- debug
                       '0';
    
    R1_en <= MemRead_ctrl.R1_en or specialload1_en or get_return_frame or get_top2_stack or pop1_addr_en;
    R2_en <= MemRead_ctrl.R2_en or specialload2_en or get_return_frame or get_top2_stack;
    R1_RegFlag <= MemRead_ctrl.R1_RegFlag; 
    R2_RegFlag <= '1' when debug_flag = x"021" else -- debug
                  MemRead_ctrl.R2_RegFlag;
    
             -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
    --Native_ArgAddr    <= conv_std_logic_vector (unsigned(sp_reg) - unsigned("00" & Native_ArgCnt), RAMB_S36_AWIDTH+1);
    Native_ArgAddr    <= conv_std_logic_vector (unsigned(sp_reg) - unsigned("00"&"000" & Native_ArgCnt), RAMB_S36_AWIDTH+1);
       -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
    --specialload1_addr <= next_sp -  ArgSize(7 downto 0)  when (CTRL_state = Get_ArgSize and external_access_cmplt='1') else --   for invoke_objref
                       --  Native_ArgAddr; 
    specialload1_addr <= next_sp -  ArgSize(4 downto 0)  when (CTRL_state = Get_ArgSize and external_access_cmplt='1') else --   for invoke_objref
                         Native_ArgAddr; 
    specialload2_addr <=  -- debug_addr(9 downto 0) when debug_flag = x"020" or debug_flag = x"021" else -- debug
                         Native_ArgAddr + '1';
    
    mem2LVreg_addr1 <= vp_reg         when mem2LVreg_1_flag = '1' else
                       vp_reg  + "10";
    mem2LVreg_addr2 <= vp_reg  + "01" when mem2LVreg_1_flag = '1' else
                       vp_reg  + "11";
    
    R1 <= vp_reg + "010" + LV_cnt(9 downto 0) when get_return_frame = '1'			  else
	      sp_reg - "01"						 when get_top2_stack   = '1' or pop1_addr_en = '1' else
		  specialload1_addr                  when specialload1_en  = '1'              else
          MemRead_ctrl.load1_addr            when MemRead_ctrl.R1_sel = R1_load1_addr else
          mem2LVreg_addr1                    when mem2LVreg ='1'                      else
          next_sp - '1';
    R2 <= vp_reg + "01" + LV_cnt(9 downto 0) when get_return_frame = '1'			  else
		  sp_reg - "010"					 when get_top2_stack   = '1'              else
		  specialload2_addr       			 when specialload2_en  = '1'              else
          MemRead_ctrl.load2_addr 			 when MemRead_ctrl.R2_sel = R2_load2_addr else
          mem2LVreg_addr2        			 when mem2LVreg ='1'                      else
          next_sp - "10";

    W1_en <= ctrl.W1_en;
    W2_en <= ctrl.W2_en;
    
    LVreg2mem_addr1 <= vp_reg        when(LVreg2mem_1 and LVreg_valid(0)) = '1' else
                       vp_reg + "10" when(LVreg2mem_2 and LVreg_valid(2)) = '1' else
                       (others => '1');
    LVreg2mem_addr2 <= vp_reg + "01" when(LVreg2mem_1 and LVreg_valid(1)) = '1' else
                       vp_reg + "11" when(LVreg2mem_2 and LVreg_valid(3)) = '1' else
                       (others => '1');
     
		-- by fox
	valid_LV	<=	LVreg_valid(1 downto 0)	when LVreg2mem_1 = '1' else
					LVreg_valid(3 downto 2)	when LVreg2mem_2 = '1' else
					(others => '0');	  
	W1 <= LVreg2mem_addr1 when LVreg2mem = '1'              else	-- by fox
		  store1_addr     when ctrl.W1_sel = W1_store1_addr else
          sp_reg;
    W2 <= LVreg2mem_addr2 when LVreg2mem = '1'              else	-- by fox
		  store2_addr     when ctrl.W2_sel = W2_store2_addr else
          sp_reg + '1';	  
          
    SD1 <= A when ctrl.SD1_sel = SD1_A  else
           C;
    SD2 <= B when ctrl.SD2_sel = SD2_B else
           ALU_result;
    
    LD1 <= RD1 when ctrl.LD1_sel = LD1_RD else
           load_immediate1;
    LD2 <= RD2 when ctrl.LD2_sel = LD2_RD else
           load_immediate2;       

    ALUopd1 <= A  when ctrl.ALUopd1_sel = ALU1_A else
               B  when ctrl.ALUopd1_sel = ALU1_B else
               LD1;
    ALUopd2 <= A  when ctrl.ALUopd2_sel = ALU2_A else
               B  when ctrl.ALUopd2_sel = ALU2_B else
               C;
  
    next_A <= LD2    when ctrl.A = A_LD2 else
              C      when ctrl.A = A_C   else
              LD1    when ctrl.A = A_LD1 else
              ALU_result;
    next_B <= LD1    when ctrl.B = B_LD1 else
              A      when ctrl.B = B_A   else
              C      when ctrl.B = B_C   else
              ALU_result;
    next_C <= LD1    when ctrl.C = C_LD1 else
              LD2    when ctrl.C = C_LD2 else
              A      when ctrl.C = C_A   else
              B;
    
    next_sp <= conv_std_logic_vector
                 (unsigned(sp_reg) + signed(ctrl.sp_offset), RAMB_S36_AWIDTH+1);
    
    sp_CtrlLogic :
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
            sp_reg           <= (others => '0');
            --sp_reg_invoke    <= (others => '0');
        else
			 
            if update_return_regs_w = '1' then
                sp_reg     <= vp_reg;   
            elsif pop1_BC_reg_wen = '1' then
                sp_reg     <= sp_reg - "01";				
            elsif get_top2_stack = '1' then
                sp_reg     <= sp_reg - "010"; 	     -- -3 for pop 2 +1 for xcptn objref
            elsif TH_mgt_context_switch = '1' then		-- by fox , modified by T.H.Wu , 2013.7.17
				sp_reg	   <= TH_mgt_ready_thread_sp (RAMB_S36_AWIDTH downto 0);
            elsif(stall_execution_stage = '0') then
                if(ctrl.stsp1 = enable) then
                    sp_reg <= SD1(9 downto 0);
                elsif(ctrl.stsp2 = enable) then
                    sp_reg <= SD2(9 downto 0);
                elsif(stsp_s_flag = '1') then        -- return
                    sp_reg <= vp_reg;
                elsif(CTRL_state = Method_exit) then -- invoke
                    -- sp = sp - arg_size + max_local
                    sp_reg <= sp_reg_invoke;
                elsif(CTRL_state = Native_SpAdjusting ) then -- native
                    -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
                   -- sp_reg <= conv_std_logic_vector(unsigned(sp_reg) - unsigned("00" & Native_ArgCnt), RAMB_S36_AWIDTH+1);
                    sp_reg <= conv_std_logic_vector(unsigned(sp_reg) - unsigned("00" &"000"& Native_ArgCnt), RAMB_S36_AWIDTH+1);
                else
                    sp_reg <= next_sp;
                end if;
            end if;
        end if; 
			----------
            if(CTRL_state = max_local) then  -- for timing issue
                sp_reg_invoke <= vp_reg + bytecodes(9 downto 0);
            end if;
			------
        end if; 
    end process;
    
    reg_valid <= LVreg_valid;
    
    LVreg_valid_CtrlLogic :
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
            LVreg_valid      <= (others => '0');
            LVreg_valid_tmp  <= (others => '0');
        else
            if(CTRL_state = max_local ) then
                LVreg_valid_tmp(1 downto 0) <= bytecodes(1 downto 0);
                LVreg_valid_tmp(2) <= bytecodes(7) or bytecodes(6) or bytecodes(5) or bytecodes(4) or bytecodes(3) or bytecodes(2); 
            end if;
             
            if(update_return_regs_w = '1') then
                LVreg_valid      <= RD1(15 downto 12);
            elsif(CTRL_state = Method_exit ) then
                case LVreg_valid_tmp(2 downto 0) is
                    when "000"  => LVreg_valid <= x"0";
                    when "001"  => LVreg_valid <= x"1";
                    when "010"  => LVreg_valid <= x"3";
                    when "011"  => LVreg_valid <= x"7";
                    when others => LVreg_valid <= x"F";
                end case;
            elsif(stsp_s_flag  = '1') then
                LVreg_valid <= A(15 downto 12);
            elsif(TH_mgt_context_switch = '1') then	-- by fox
				LVreg_valid <= TH_mgt_ready_thread_LV_valid;
            end if;
        end if; 
        end if; 
    end process;
    
    reg_CtrlUnit :
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
            A                <= X"12345678";
            B                <= X"22000000";
            C                <= X"33000000";
            vp_reg           <= (others => '0');
            --vp_reg_invoke    <= (others => '0');
            --invoke_objref_addr <= (others => '0');
            --is_invoke_main_mthd <= '0';
        else
            --if(CTRL_state=Method_exit) then
            --    is_invoke_main_mthd <= '1';
            --end if;
           -- if(CTRL_state = Get_ArgSize) then
            --    invoke_objref_addr <= next_sp -  cst_entry(7 downto 0);
           -- end if;
            --if(CTRL_state = arg_size  and is_invoke_main_mthd='1') then
			
			if(update_return_regs_w = '1') then
                    vp_reg <= RD1(9 downto 0);
            elsif(TH_mgt_context_switch = '1') then	-- by fox
                    vp_reg <= TH_mgt_ready_thread_vp (RAMB_S36_AWIDTH downto 0);
            elsif(stall_execution_stage = '0') then                
                if(ctrl.stvp1 = enable) then
                    vp_reg <= SD1(9 downto 0);
                elsif(ctrl.stvp2 = enable) then
                    vp_reg <= SD2(9 downto 0);
                elsif(CTRL_state = max_stack) then
                    -- invoke
                    -- vp = sp - arg_size
                    vp_reg <= vp_reg_invoke;
                end if;
            end if;
            
            if(ctrl.Aen = enable and stall_execution_stage = '0') then
                A <= next_A;
            elsif(TH_mgt_context_switch = '1') then	-- by fox
                A <=  TH_mgt_ready_thread_A;
            elsif(write_ABC.Aen = '1') then
                A <= write_ABC.data;
            end if;
            
			if pop1_BC_reg_wen = '1' then
				B <= C;
            elsif( update_TOS_BC = '1' )then
				B <= RD1;
            elsif(ctrl.Ben = enable and stall_execution_stage = '0') then
                B <= next_B;
            elsif(TH_mgt_context_switch = '1') then	-- by fox
                B <=  TH_mgt_ready_thread_B;
            elsif(write_ABC.Ben = '1') then
                B <= write_ABC.data;
            end if;
            
			
            if pop1_BC_reg_wen = '1' then
				C <= RD1;
            elsif( update_TOS_BC = '1' )then
				C <= RD2;
            elsif(ctrl.Cen = enable and stall_execution_stage = '0') then
                C <= next_C;
            elsif(TH_mgt_context_switch = '1') then	-- by fox
                C <=  TH_mgt_ready_thread_C;
            elsif(write_ABC.Cen = '1') then
                C <= write_ABC.data;
            end if;
            ----------
        end if;       
		
			LVreg2mem_1 <= LVreg2mem_1_delay;
            LVreg2mem_2 <= LVreg2mem_1;
			
            if(CTRL_state = arg_size) then
                -- modified by T.H.Wu , 2013.8.1
                -- if (is_invoke_main_mthd='1'   and TH_mgt_new_thread_execute_reg='0') then
                if (TH_mgt_new_thread_execute_reg='0') then
                    vp_reg_invoke <= sp_reg -  bytecodes(7 downto 0);
                else
                    vp_reg_invoke <= (others=>'0');
                end if;
            end if;
			
        end if;       
    end process;  
	
        -- by fox , for thread management
	process(clk) begin
            if(rising_edge(clk)) then 
				--  if(stall_execution_stage = '0') then 
                    -- modified by T.H.Wu , 2013.8.8 , for solving critical path
				--TH_mgt_clean_pipeline_cmplt <= TH_mgt_clean_execute;
                --end if; 
				act_dly_2clk <= act_dly;
				act_dly_3clk <= act_dly_2clk;
                -- modified by T.H.Wu , 2013.7.18 , for TCB info transferring
				if(Rst = '1') then
					TH_mgt_new_thread_execute_reg	<= '0';
					--TH_mgt_ready_thread_sp  <= (others=>'0');
					--TH_mgt_ready_thread_vp  <= (others=>'0');
					--TH_mgt_ready_thread_LV_valid   <= (others=>'0');
					--TH_mgt_ready_thread_A  <= (others=>'0');
					--TH_mgt_ready_thread_B  <= (others=>'0');
					--TH_mgt_ready_thread_C  <= (others=>'0');
					--TH_mgt_ready_thread_obj_ref   <= (others=>'0');
                else
					if(CTRL_state = Method_exit) then
						TH_mgt_new_thread_execute_reg	<= '0';
					elsif(TH_mgt_new_thread_execute = '1') then
						TH_mgt_new_thread_execute_reg	<= '1';
					end if;
                end if;
                        -----
                        if(TH_data_out_transfer_cnt_dly = x"2") then
                            TH_mgt_ready_thread_sp <= TH_data_out_dly (RAMB_S36_AWIDTH downto 0);
                            TH_mgt_ready_thread_vp <= TH_data_out_dly (RAMB_S36_AWIDTH+16 downto 16);
                        end if;
                        -----
                        if(TH_data_out_transfer_cnt_dly = x"3") then
                            TH_mgt_ready_thread_LV_valid <= TH_data_out_dly (19 downto 16) ;
                        end if;
                        -----
                        if(TH_data_out_transfer_cnt_dly = x"4") then
                            TH_mgt_ready_thread_A <= TH_data_out_dly;
                        end if;
                        -----
                        if(TH_data_out_transfer_cnt_dly = x"5") then
                            TH_mgt_ready_thread_B <= TH_data_out_dly;
                        end if;
                        -----
                        if(TH_data_out_transfer_cnt_dly = x"6") then
                            TH_mgt_ready_thread_C <= TH_data_out_dly;
                        end if;
                        -----
                        if(TH_data_out_transfer_cnt_dly = x"7") then
                             TH_mgt_ready_thread_obj_ref <= TH_data_out_dly;
                        end if;
                --
            end if;
	end process;
    
        -- for stack management , by fox
	--p_stack_rw		<= '1' when TH_mgt_new_thread_execute = '1' else stackMgt2exe_rw_stk_en;		
	p_stack_rw		<= TH_mgt_new_thread_execute or stackMgt2exe_rw_stk_en;
	prepare_stack_addr	<= (others => '0') when TH_mgt_new_thread_execute = '1' else (stackMgt2exe_base_addr + stack_mgt_transfer_counter) ; 
        -- origin by fox , modified by T.H.Wu , 2013.7.17
        prepare_data_in <= TH_mgt_ready_thread_obj_ref when TH_mgt_new_thread_execute = '1' else external_load_data; 
	external_store_data	<= backup_stack_data; 
    
    
    ----------------------------------------------------------------
    --xcptn hdlr
    ----------------------------------------------------------------
	mem2LVreg_1_flag <= mem2LVreg_1_decode or mem2LVreg_1_xcptn;
	mem2LVreg_2_flag <= mem2LVreg_2_decode or mem2LVreg_2_xcptn;
	
	--xcptn_thrown_bytecode <= xcptn_thrown_bytecode_w;
	update_return_regs    <= update_return_regs_w;
	ret_frm_regs_wen      <= ret_frm_regs_wen_w;
	
	
    labal_enable_xcptn_0 : if ENABLE_XCPTN = 1 generate
	
	ExceptionHandler : xcptn_hdlr
    port map(
        Rst                         => Rst,
        clk                         => clk,
		xcptn_en                    => xcptn_en,
		--act                         => act,
		
		xcptn_thrown_ALU   	    	=> xcptn_thrown_ALU,                     --divided by zero
		xcptn_thrown_bytecode       => xcptn_thrown_bytecode,					 --bytecode"athrow"
		xcptn_stall                 => xcptn_stall,
		xcptn_flush_pipeline        => xcptn_flush_pipeline,
		-- external memory access
		external_access_cmplt       => external_access_cmplt,
		external_load_data          => external_load_data,
		external_load_EID_req       => external_load_EID_req,
		external_load_LVcnt_req     => external_load_LVcnt_req,
		-- parser to ER_LUT 
		prsr2ER_LUT_di   	        => prsr2ER_LUT_di,
		prsr2ER_LUT_addr            => prsr2ER_LUT_addr,
		prsr2ER_LUT_wen             => prsr2ER_LUT_wen,	
		--to execute 
		get_return_frame       		=> get_return_frame,
		update_return_regs     		=> update_return_regs_w,
		update_TOS_BC               => update_TOS_BC,
		LV_cnt_wen                  => LV_cnt_wen,
		get_top2_stack              => get_top2_stack,
		mem2LVreg_1_xcptn           => mem2LVreg_1_xcptn,
		mem2LVreg_2_xcptn           => mem2LVreg_2_xcptn,
		pop1_addr_en                => pop1_addr_en,
		pop1_BC_reg_wen             => pop1_BC_reg_wen,
		--to mthd ctrlr
		now_mthd_id                 => now_mthd_id,
		ER_info                     => ER_info,
		ER_info_wen_MA_ctrlr        => ER_info_wen_MA_ctrlr,
		check_CST_MA_done           => check_CST_MA_done, 
		ret_frm_regs_wen            => ret_frm_regs_wen_w,
		ER_info_addr_rdy            => ER_info_addr_rdy,
		MA_base_mem_addr_wen		=> MA_base_mem_addr_wen,
       
		--to jpc ctrlr
		stall_jpc                   => stall_jpc,
		JPC                         => JPC,
		ER_JPC                      => ER_JPC,
		ER_JPC2JPC_wen				=> ER_JPC2JPC_wen,
		adjust_jpc2xcptn_instr      => adjust_jpc2xcptn_instr,
		--xcptn_jpc                   : out std_logic_vector(15 downto 0);
		--to cst_controller
		now_cls_id                  => now_cls_id,
		parent_EID                  => parent_EID,
		xcptn_cst_mthd_check_en  	=> xcptn_cst_mthd_check_en,
		xcptn_cst_mthd_check_IDs_en	=> xcptn_cst_mthd_check_IDs_en,
		get_parent_EID              => get_parent_EID,
		compared_EID                => compared_EID,
		--to instr buffer          
		xcptn_clean_buffer          => xcptn_clean_buffer,
		mask_insr1                  => mask_insr1,
		--to decode
		xcptn_done                  => xcptn_done,
		push1_flag                  => push1_flag,
        push2_flag                  => push2_flag,
		-- interrupt req
		interrupt_cmplt             => interrupt_cmplt,
		interrupt_req_xcptn			=> interrupt_req_xcptn,
		interrupt_func_xcptn        => interrupt_func_xcptn, 
		-- native HW
		xcptn_thrown_Native_HW		=> xcptn_thrown_Native_HW,
		Native_HW_thrown_ID			=> Native_HW_thrown_ID,
                --debug_cs_xcptn                            =>  debug_cs_xcptn  , 
		-- debug flag
        debug_flag                  => debug_flag (11 downto 0),
        debug_addr                  => debug_addr (11 downto 0),
        debug_data                  => debug_ER_LUT_data
    );
	end generate;
	
    -- 2014.1.3 , disable disable xcptn_thrown_ALU , and enable it eventually when my works are done.
	xcptn_thrown_ALU <= '1' when ctrl.ALU = ALU_div and ALUopd1 = X"0000" else   '0';
	--xcptn_thrown_ALU <=  '0';
						   
    --ret_frm_mthd_id <= RD2(31 downto 16);
	--ret_frm_cls_id  <= RD1(31 downto 16);
	
	
	xcptn_jpc_wen   <= ER_JPC2JPC_wen or ret_frm_regs_wen_w;
	xcptn_jpc       <= ER_JPC when ER_JPC2JPC_wen = '1' else
					   RD2(15 downto 0);
	                   --RD2(14 downto 0)& "0";
	
	Local_cont_reg :
    process(clk) begin
		if(rising_edge(clk)) then
        if Rst = '1'  then
            LV_cnt           <= X"0000";
        else
			if LV_cnt_wen = '1' then
				LV_cnt       <= external_load_data(15 downto 0);
			end if;
		end if;
		end if;
    end process;
	
    
	-- cs debug 
    
    --debug_cs_exe (9 downto 0) <= LV_cnt (9 downto 0) ; 
    --debug_cs_exe (19 downto 10) <= R1 (9 downto 0);
    --debug_cs_exe (29 downto 20) <= R2 (9 downto 0);
    --debug_cs_exe (61 downto 30) <= LD1;
    --debug_cs_exe (93 downto 62) <= LD2;
    
		
end architecture rtl;
