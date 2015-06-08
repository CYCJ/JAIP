------------------------------------------------------------------------------
-- Filename     :       top.vhd
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
-- Filename     :       top.vhd
-- Version      :       2.03 
-- Author       :       Kuan-Nian Su
-- Date         :       May 2009
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Filename     :       soj.vhd
-- Version      :       3.00
-- Author       :       Han-Wen Kuo
-- Date         :       Jan 2011
-- VHDL Standard:       VHDL'93
-- Describe     :       New Architecture
------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.config.all;
Library UNISIM;
use UNISIM.vcomponents.all;

entity soj is
    generic(
        METHOD_AREA_DDR_ADDRESS     : std_logic_vector(31 downto 0) := X"5A000000";
		STACK_AREA_DDR_ADDRESS		: std_logic_vector(13 downto 0) := (X"5BF"&"11"); -- by fox
		Max_Thread_Number			: integer := 16;								 -- by fox
		BURST_LENGTH				: std_logic_vector(7 downto 0)  := X"40";	        -- by fox
        HIDE_MODULE                 : integer := 1;
        ENABLE_JAIP_PROFILER  		: integer := 0;
        C_MAX_AR_DWIDTH             : integer := 64;
        RAMB_S9_AWIDTH              : integer := 11;
        RAMB_S18_AWIDTH             : integer := 10;
        RAMB_S36_AWIDTH             : integer := 9
    );
    port(
        -- basic signal
        Rst                         : in	std_logic;
        clk                         : in	std_logic; 
		the_core_act				: out	std_logic; 
		core_id						: in	std_logic_vector (1 downto 0);
		--GC
		GC_Cmplt_in                 : in  std_logic;
		GC_areturn_flag_out         : out  std_logic;
		anewarray_flag2GC           : out  std_logic;
		GC_Clinit_Stop              : out  std_logic;
		Mthod_exit_flag_out         : out  std_logic;
		Mthod_enter_flag_out        : out  std_logic;
		Mthod_enter_flag_f_out      : out  std_logic;
		GC_arrayAlloc_en_out        : out  std_logic;  
		GC_StackCheck_flag          : out  std_logic;
		-- enable xcptn          
		xcptn_en                    : in  std_logic;  

        -- (slave) write from external part(power PC) to soj reg
        ex2java_wen                 : in  std_logic;
        ex2java_addr                : in  std_logic_vector(13 downto 0);
        ex2java_data                : in  std_logic_vector(31 downto 0);   
		-- (slave) CST profile table
        CSTProfileTable             : in  std_logic_vector(31 downto 0);
		-- (slave) Mthd profile table
        MthdProfileTable            : in  std_logic_vector(31 downto 0);
		
		-- (slave) parser to ER_LUT
		parser2ER_LUT               : in  std_logic_vector(31 downto 0);
        -- (master) external memory access
        external_MstRd_CmdAck : in  std_logic; -- added by T.H. Wu , 2013.6.20 
        external_MstRd_burst_data_rdy : in std_logic; -- added by T.H. Wu , 2013.6.20 
        external_MstWr_burst_data_rdy : in std_logic;
        external_access_cmplt       : in std_logic;
        external_access_addr        : out std_logic_vector(31 downto 0);
        external_load_req           : out std_logic;
        external_load_data          : in  std_logic_vector(31 downto 0);
        external_store_req          : out std_logic;
        external_store_data         : out std_logic_vector(31 downto 0);
		-- added by T.H.Wu , 2013.8.7 , for changing bus transfer mode in pipeline
		jpl_mst_transfer_Type		: out std_logic;
		IP2Bus_Mst_BE               : out std_logic_vector( 3 downto 0);
		current_heap_ptr			: in std_logic_vector(31 downto 0);
		
		-- class info table
		clsiInternLoadReq					: out std_logic;
		clsiInternStoreReq				: out std_logic;
		clsiAddr					: out std_logic_vector(11 downto 0);
		clsInfo						: in std_logic_vector(31 downto 0);
		clsiCmplt					: in std_logic;
		clsiInternWrData					: out std_logic_vector(31 downto 0); 
		-- for multi-core coordinator , modified by T.H.Wu 2014.2.11
		JAIP2COOR_cmd					: out std_logic_vector(2 downto 0) ;
		JAIP2COOR_info1_pipeline		: out std_logic_vector(31 downto 0);
		JAIP2COOR_info2_pipeline		: out std_logic_vector(31 downto 0);
		JAIP2COOR_pending_resMsgSent	: out std_logic;
		COOR_res_msg_bak				: in	std_logic_vector(15 downto 0);
		COOR_info1_bak					: in	std_logic_vector(31 downto 0);
		COOR_info2_bak					: in	std_logic_vector(31 downto 0);
		COOR_cmd_cmplt					: out	std_logic;

        -- interrupt
        interrupt_req               : out std_logic;
        interrupt_func              : out std_logic_vector(23 downto 0);

        -- cache up top of stack
        TOS_A                       : out std_logic_vector(31 downto 0);
        TOS_B                       : out std_logic_vector(31 downto 0);
        TOS_C                       : out std_logic_vector(31 downto 0);

        -- parameters of host service
        Host_arg1                   : out std_logic_vector(31 downto 0);
        Host_arg2                   : out std_logic_vector(31 downto 0);
        Host_arg3                   : out std_logic_vector(31 downto 0);
        Host_arg4                   : out std_logic_vector(31 downto 0);
        Host_arg5                   : out std_logic_vector(31 downto 0);
		
		native_HW_en				: out std_logic;
                -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
		--native_HW_ID				: out std_logic_vector(7 downto 0);
		native_HW_ID				: out std_logic_vector(4 downto 0);
		native_HW_cmplt				: in std_logic;
		
		Alloc_en				: out std_logic;
		AllocSize				: out std_logic_vector(15 downto 0);
		
		-- native HW
		xcptn_thrown_Native_HW		: in  std_logic;
		Native_HW_thrown_ID			: in  std_logic_vector(15 downto 0);	
		
		CTRL_state_out                : out  DynamicResolution_SM_TYPE;
        
		debug_cs_soj        : out  std_logic_vector  (25 downto 0);
         debug_cs_MActrl      : out  std_logic_vector  (31 downto 0);
        --debug_cs_fetch              : out std_logic_vector(12 downto 0);
		--debug_cs_decode                       : out std_logic_vector(48 downto 0); 
        --debug_cs_4portbank : out std_logic_vector(127 downto 0);
		--debug_cs_exe   : out  std_logic_vector(93 downto 0) ;
		-- debug_cs_xcptn   : out  std_logic_vector(55 downto 0) ;
        debug_cs_thread_mgt               : out  std_logic_vector  (47 downto 0); 
        debug_cs_stk_mgt                        : out std_logic_vector (2 downto 0); 
	
        --debug_cs_CSTctrl      : out  std_logic_vector  (35 downto 0);
        debug_flag                  : in  std_logic_vector(31 downto 0);
        debug_addr                  : in  std_logic_vector(31 downto 0);
        debug_data                  : out std_logic_vector(31 downto 0);

		--debug for new buffer
		debug_nb_SW                 : in  std_logic_vector(31 downto 0);
		debug_nb_do                 : out std_logic_vector(31 downto 0); 
		
        
		-- cs debug	
		--debug_block_select_base		: out std_logic_vector(4 downto 0);
		--debug_alu_stall				: out std_logic; 
        
		-- debug_prof_simple_issued_A_D		: out std_logic;
		-- debug_prof_simple_issued_B_D		: out std_logic;
		-- debug_prof_complex_issued_D		    : out std_logic;
		-- debug_prof_issued_bytecodes_D	    : out std_logic_vector(15 downto 0);
		 
		-- mmes profiler
		prof_invoke_flag			: out std_logic;
		prof_return_flag			: out std_logic;
		prof_DSRU_on				: out std_logic;
		prof_mem_access_on			: out std_logic;
		prof_DR2MA_mgt_mthd_id		: out std_logic_vector(15 downto 0);
		
		prof_simple_issued_A_D 		: out std_logic;
		prof_simple_issued_B_D 		: out std_logic;
		prof_issued_bytecodes_D		: out std_logic_vector(15 downto 0)
		
    );
end entity soj;

architecture rtl of soj is

    component jpc_ctrl is
        generic(
            RAMB_S18_AWIDTH             : integer := 10
        );
        port(
            clk                         : in  std_logic; 
            act                         : in  std_logic; 
            stall_jpc                   : in  std_logic;
            CTRL_state                  : in  DynamicResolution_SM_TYPE; 
            native_flag                 : in  std_logic;
            stjpc_flag                  : in  std_logic;
            branch                      : in  std_logic;
            branch_destination          : in  std_logic_vector(15 downto 0);
            TOS_A                       : in  std_logic_vector(15 downto 0);
            TOS_B                       : in  std_logic_vector(15 downto 0);
            jpc_reg_out                 : out std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
            jpc                         : out std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
            switch_instr_branch : in std_logic; -- just for tableswitch / lookupswitch branch use
            -- thread mgt   -- by fox
            context_switch		: in  std_logic;
            TH_mgt_thread_jpc          : in  std_logic_vector(15 downto 0);
            jpc_backup			: in  std_logic; 
            clean_pipeline_cmplt: in  std_logic;
		-- xcptn hdlrr
            xcptn_jpc_wen               : in  std_logic;
	    xcptn_jpc                   : in  std_logic_vector(15 downto 0);
            adjust_jpc2xcptn_instr      : in  std_logic;
            xcptn_stall                 : in  std_logic
        );
    end component jpc_ctrl;

	component method_area_controller is
	generic(
        RAMB_S18_AWIDTH          : integer := 10;
        METHOD_AREA_DDR_ADDRESS  : std_logic_vector(31 downto 0) := X"5A000000"
    );
    port(
         Rst 				  : in  std_logic;
         clk 				  : in  std_logic;
         MA_mgt_en			  : in  std_logic;
         DR2MA_mgt_mthd_id 	  : in  std_logic_vector(15 downto 0);
         C_25_16 			  : in  std_logic_vector(9 downto 0);
         B_25_16 			  : in  std_logic_vector(9 downto 0); 
         return_flag          : in  std_logic;
         ireturn_flag         : in  std_logic;
		 CST_check_done       : in  std_logic;
		 Mthd_check_done      : out  std_logic; 
		-- external_loaded_buffer : in  std_logic_vector(31 downto 0);
         MthdProfileTable_wen : in  std_logic;
         MthdProfileTable_idx : in  std_logic_vector(15 downto 0);
         MthdProfileTable_info: in  std_logic_vector(15 downto 0); 
		 
        external_MstRd_CmdAck : in  std_logic; -- added by T.H. Wu , 2013.6.20 
        external_MstRd_burst_data_rdy : in std_logic; -- added by T.H. Wu , 2013.6.20 
         external_access_cmplt: in  std_logic;
         -- external_load_data   : in  std_logic_vector(31 downto 0);
         MthdLoading_req 	  : out  std_logic;
         MthdLoading_ex_addr  : out  std_logic_vector(31 downto 0);
        -- Mthd_Loading_done 	  : out  std_logic;
		 MthdLoading_stall    : out std_logic;
         Mgt2MA_wen 		  : out  std_logic;
         Mgt2MA_addr 		  : out  std_logic_vector(11 downto 0);
         --Mgt2MA_data		  : out  std_logic_vector(15 downto 0);
         Mgt2MA_block_base_sel: out  std_logic_vector(4 downto 0);
         now_mthd_id 		  : out  std_logic_vector(15 downto 0);
		-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
		rtn_frm_sync_mthd_flag	: in	std_logic;
		sync_mthd_invoke_rtn_cmplt: in	std_logic;
		 -- xcptn hdlr
		 CST_FSM_Check_offset : in  std_logic;    
	 	 ret_frm_regs_wen	  : in  std_logic;                      
	 	 ret_frm_mthd_id	  : in  std_logic_vector(15 downto 0);  
		 ER_info_addr_rdy     : in  std_logic;    
		 MA_base_mem_addr_wen : in  std_logic;    	
		 ER_info              : out std_logic_vector(15 downto 0);
		 ER_info_wen_MA_ctrlr : out std_logic;
		 MA_base_mem_addr     : out std_logic_vector(31 downto 0);
		 --
		 --check_mthd_id        : in std_logic_vector (9 downto 0);
		 --debug
         debug_cs_MActrl      : out  std_logic_vector  (31 downto 0);
         debug_flag 	      : in  std_logic_vector(31 downto 0);
         debug_addr 	      : in  std_logic_vector(31 downto 0);
         debug_data 		  : out  std_logic_vector(31 downto 0)
		 
		 --cs debug
		 --debug_MA_state		  : out std_logic_vector(7 downto 0);
		 --debug_loading_size			 : out std_logic_vector(15 downto 0); 
		 --debug_DR2MA_mgt_mthd_id		 : out std_logic_vector(9 downto 0);
		 --debug_check_mthd_id			 : out std_logic_vector(9 downto 0);
		 --debug_overwrite_mthd_id		 : out std_logic_vector(9 downto 0);
		 --debug_ResidenceTable_Wen	 : out std_logic;
		 --debug_malloc				 : out std_logic_vector(4 downto 0); 
        );
    end component method_area_controller;
	
	component method_area_buffer is
    port(
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        --act                         : in  std_logic;
        address                     : in  std_logic_vector(11 downto 0);
        block_select_base           : in  std_logic_vector( 4 downto 0);  
        methodarea_wr_en            : in  std_logic;
        methodarea_wr_val           : in  std_logic_vector(31 downto 0);
        stall_instruction_buffer    : in  std_logic;
        instruction_buffer_2        : out std_logic_vector(15 downto 0);
        instruction_buffer_1        : out std_logic_vector(15 downto 0);   
        bytecodes                   : out std_logic_vector(15 downto 0);
            --  thread management , 2013.7.16
            clear_buffer   : in  std_logic;
		-- xcptn
		xcptn_flush_pipeline        : in  std_logic;
		mask_insr1                  : in  std_logic;
        -- debug
        debug_flag                  : in  std_logic_vector(31 downto 0);
        debug_addr                  : in  std_logic_vector(31 downto 0);
        debug_data                  : out std_logic_vector(31 downto 0) 
        );
    end component method_area_buffer;
	
	component class_symbol_table_controller is
	generic(
        RAMB_S18_AWIDTH             : integer := 10;
        METHOD_AREA_DDR_ADDRESS     : std_logic_vector(31 downto 0) := X"5A000000"
    );
    port(
         Rst 							: in  std_logic;
         clk 							: in  std_logic;
         CST_checking_en 				: in  std_logic;
         DR2CST_ctrlr_cls_id 			: in  std_logic_vector(15 downto 0);
         A_23_16						: in  std_logic_vector(7 downto 0);
         B_23_16						: in  std_logic_vector(7 downto 0);
         return_flag					: in  std_logic;
         ireturn_flag				    : in  std_logic; 
		 CST_check_done                 : out std_logic; 
		--external_loaded_buffer          : in  std_logic_vector(31 downto 0); -- marked by T.H. Wu , 2013.6.20
         CSTProfileTable_Wen			: in  std_logic;
         CSTProfileTable_idx 		    : in  std_logic_vector(15 downto 0);
         CSTProfileTable_di 		    : in  std_logic_vector(15 downto 0); 
        external_MstRd_CmdAck : in  std_logic; -- added by T.H. Wu , 2013.6.20 
        external_MstRd_burst_data_rdy : in std_logic; -- added by T.H. Wu , 2013.6.20 
         external_access_cmplt 		    : in  std_logic;
        -- external_load_data 		    : in  std_logic_vector(31 downto 0);
         CSTLoading_req 			 	: out  std_logic;
         CSTLoading_ex_addr 			: out  std_logic_vector(31 downto 0);
         CSTLoading_stall 				: out  std_logic;
         MA_checking_done 				: in  std_logic;
         CST_ctrlr2buffer_wen 			: out  std_logic;
         CST_ctrlr2buffer_addr 			: out  std_logic_vector(11 downto 0);
         --CST_ctrlt2buffer_data 			: out  std_logic_vector(31 downto 0);
         CST_ctrlr2buffer_block_base 	: out  std_logic_vector(4 downto 0);
         cls_id 						: out  std_logic_vector(15 downto 0);
		-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
		rtn_frm_sync_mthd_flag			: in  std_logic;
		sync_mthd_invoke_rtn_cmplt		: in  std_logic;
		 -- xcptn hdlr
		 ret_frm_regs_wen		        : in  std_logic;       
		 get_parent_EID		            : in  std_logic;  
		 ret_frm_cls_id				    : in  std_logic_vector(15 downto 0);  
		 compared_EID                   : in  std_logic_vector(15 downto 0);
		 CST_FSM_Check_offset           : out std_logic;
		 parent_EID                     : out std_logic_vector(15 downto 0);
		 --
        --debug_cs_CSTctrl      : out  std_logic_vector  (35 downto 0);
         debug_flag 					: in  std_logic_vector(31 downto 0);
         debug_addr 					: in  std_logic_vector(31 downto 0);
         debug_data						: out  std_logic_vector(31 downto 0)
        );
    end component class_symbol_table_controller;
	
	component class_symbol_table_buffer is
    port(
        Rst                         : in  std_logic;
        clk                         : in  std_logic;
        address                     : in  std_logic_vector(11 downto 0);
        block_select_base           : in  std_logic_vector( 4 downto 0); 
        CST_buffer_wen              : in  std_logic;
        CST_buffer_wr_data          : in  std_logic_vector(31 downto 0);  
        CST_entry                   : out std_logic_vector(31 downto 0)
        );
    end component class_symbol_table_buffer;
	    

    component DynamicResolution_management is
        generic(
            ENABLE_JAIP_PROFILER   : integer := 0;
            RAMB_S18_AWIDTH             : integer := 10
        );
        port(
            -- ctrl signal
            Rst                         : in  std_logic;
            clk                         : in  std_logic;
            --act                         : in  std_logic;
			--GC
			GC_Cmplt_in                 : in  std_logic;
            -- (slave) write from external part(power PC) to DynamicResolution_management
            DR_reg_en                   : in  std_logic;
            ex2java_data                : in  std_logic_vector(31 downto 0);
            
            -- (master) external memory access
            external_access_cmplt       : in std_logic;
            external_load_req           : in  std_logic;
            external_store_req          : in  std_logic;
            external_load_data          : in  std_logic_vector(31 downto 0);
            DynamicResolution           : out std_logic_vector(31 downto 0);
            DR_addr                     : out std_logic_vector(31 downto 0);
            DynamicResolution_load_req  : out std_logic;
            DynamicResolution_store_req : out std_logic;
			
			-- class info table
			clsiInternLoadReq					: out std_logic;
			clsiInternStoreReq				: out std_logic;
			clsiAddr					: out std_logic_vector(11 downto 0);
			clsInfo_in					: in std_logic_vector(31 downto 0);
			clsiCmplt					: in std_logic;
			clsiInternWrData					: out std_logic_vector(31 downto 0);
		
			-- clinit
			clinitClsID					: out std_logic_vector(15 downto 0);
			clinitMthdID				: out std_logic_vector(15 downto 0);
			clinitEN					: out std_logic;

            -- method area
            CST_entry                   : in  std_logic_vector(31 downto 0);
            operand0                    : in  std_logic_vector( 7 downto 0);
            operand1                    : in  std_logic_vector( 7 downto 0);
            search_ptr_out              : out std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);

            -- interrupt 
            interrupt_cmplt             : in  std_logic;
            interrupt_req_DR            : out std_logic;
            interrupt_func_DR           : out std_logic_vector(23 downto 0);
            
            -- invoke
            invoke_objref_from_exe_stage               : in  std_logic_vector(31 downto 0); 
			-- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
            --ArgSize                     : out std_logic_vector( 7 downto 0);
            ArgSize                     : out std_logic_vector(4 downto 0);
			-- thread mgt -- by fox
			invoke_objref_reg_2_TH_mgt   : out std_logic_vector(31 downto 0);
			new_thread_execute			: in  std_logic;
			TH_mgt_ready_thread_cls_id_mthd_id	: in  std_logic_vector(31 downto 0); 
			-- added by T.H. Wu , for invoking sync method use. , 2014.1.22 
			invoke_sync_mthd_flag		: out std_logic;
			sync_mthd_invoke_rtn_cmplt	: in std_logic;
			
            -- flag in
            ClsLoading_stall            : in  std_logic;        
            invoke_flag                 : in  std_logic;
            static_flag                 : in  std_logic;
            field_wr                    : in  std_logic;
            new_obj_flag                : in  std_logic;
			ldc_flag                    : in  std_logic;
			ldc_w_flag					: in  std_logic;
			getStatic					: in std_logic;

            DynamicResolution_en        : in  std_logic;
            CTRL_state_out              : out DynamicResolution_SM_TYPE;
            
            -- Native
             -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
            --Native_ArgCnt               : out std_logic_vector( 7 downto 0);
            Native_ArgCnt               : out std_logic_vector( 4 downto 0);
            Native_CycCnt               : out std_logic_vector( 1 downto 0);
            native_flag                 : out std_logic;
            pop1_flag                   : out std_logic;
            pop2_flag                   : out std_logic;
            set_ucodePC                 : out std_logic;
			native_HW_en				: out std_logic;
                        -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
			--native_HW_ID				: out std_logic_vector(7 downto 0);
			native_HW_ID				: out std_logic_vector(4 downto 0);
			native_HW_cmplt				: in std_logic;
			
            -- debug
            debug_flag                  : in  std_logic_vector(31 downto 0);
            debug_addr                  : in  std_logic_vector(31 downto 0);
            debug_data                  : out std_logic_vector(31 downto 0);
			-- cs debug
			prof_native_mthd_id				: out std_logic_vector(15 downto 0)
        );
    end component DynamicResolution_management;

    component Translate is
        generic(
            ENABLE_JAIP_PROFILER   : integer := 0;
            RAMB_S18_AWIDTH             : integer := 10
        );
        port(
            -- ctrl signal
            Rst                         : in  std_logic;
            clk                         : in  std_logic;
            stall_translate_stage       : in  std_logic;

            -- method area
            bytecodes                   : in  std_logic_vector(15 downto 0);
            instruction_buffer_1        : in  std_logic_vector(15 downto 0);

            -- fetch stage
            instr_buf_ctrl                   : in  std_logic_vector( 1 downto 0);
            semitranslated_code         : out std_logic_vector(15 downto 0);
            complex                     : out std_logic_vector( 1 downto 0);
            opd_num                     : out std_logic_vector( 7 downto 0);
			
			-- prof
			prof_issued_bytecodes_T		: out std_logic_vector(15 downto 0)
        );
    end component Translate;

    component Fetch is
        generic(
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
            switch_instr_branch : out std_logic; -- just for tableswitch / lookupswitch branch use
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
            branch_trigger              : out std_logic_vector(15 downto 0);
            instrs_pkg                  : out std_logic_vector(15 downto 0);
            opd_source                  : out std_logic_vector( 1 downto 0);
            nop_1                       : out std_logic;
            nop_2                       : out std_logic;
			clinitEN					: in  std_logic;
			is_switch_instr_start	: out  std_logic;
			switch_instr_revert_code_seq : in std_logic ; 
            -- execute stage
            A_0                         : in  std_logic;
            B_0                         : in  std_logic;
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
			-- xcptn
		    xcptn_flush_pipeline        : in std_logic;
			-- modified by T.H.Wu , 2014.1.22, for invoking/returning sync method.
			invoke_sync_mthd_flag_dly	: in  std_logic;
			rtn_frm_sync_mthd_flag		: in  std_logic;
			COOR_cmd_cmplt_reg			: in  std_logic;
		
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
     end component Fetch;

    component decode is
        generic(
            ENABLE_JAIP_PROFILER   : integer := 0;
            RAMB_S18_AWIDTH                 : integer := 10;
            RAMB_S36_AWIDTH                 : integer := 9
        );
        port(
            -- ctrl signal
            Rst                             : in  std_logic;
            clk                             : in  std_logic;
            stall_decode_stage      : in  std_logic;
            CTRL_state                      : in  DynamicResolution_SM_TYPE;
			-- ldc
            DR_addr                         : in  std_logic_vector(31 downto 0);

            -- method area
            instruction_buffer_2            : in  std_logic_vector(15 downto 0);
            instruction_buffer_1            : in  std_logic_vector(15 downto 0);
            bytecodes                       : in  std_logic_vector(15 downto 0);
            now_cls_id                      : in  std_logic_vector(15 downto 0);
			now_mthd_id	        			: in  std_logic_vector(15 downto 0);

            -- jpc CtrlLogic
            branch_destination              : out std_logic_vector(15 downto 0);

            -- fetch stage
            branch_trigger                  : in  std_logic_vector(15 downto 0);
            instrs_pkg                      : in  std_logic_vector(15 downto 0);
            opd_source                      : in  std_logic_vector( 1 downto 0);
            nop_1                           : in  std_logic;
            nop_2                           : in  std_logic;
            is_switch_instr_start	: in  std_logic; 
            switch_instr_revert_code_seq : out std_logic ;

            -- execte stage
            vp                              : in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
            sp                              : in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
            branch                          : in  std_logic;
            reg_valid                       : in  std_logic_vector( 3 downto 0);
            load_immediate1                   : out std_logic_vector(31 downto 0);
            load_immediate2                   : out std_logic_vector(31 downto 0);
            store1_addr                     : out std_logic_vector(RAMB_S36_AWIDTH downto 0);
            store2_addr                     : out std_logic_vector(RAMB_S36_AWIDTH downto 0);
            W1_RegFlag                      : out std_logic;
            W2_RegFlag                      : out std_logic;
            MemRead_ctrl                    : out Decode2Execute_MemRead_Type;
            ctrl                            : out Decode2Execute_ControlSignal_Type;
            mem2LVreg_1_decode                : out std_logic;
            mem2LVreg_2_decode                : out std_logic;
            stsp_s_flag                     : out std_logic;

            -- opd out
            operand0_out                    : out std_logic_vector(7 downto 0);
            operand1_out                    : out std_logic_vector(7 downto 0);
            operand2_out                    : out std_logic_vector(7 downto 0);
            operand3_out                    : out std_logic_vector(7 downto 0);

            -- flag & req in
            pop1_flag                       : in  std_logic;
            pop2_flag                       : in  std_logic;
			push1_flag                      : in  std_logic;
            push2_flag                      : in  std_logic;
            interrupt_req                   : in  std_logic;
            interrupt_cmplt                 : in  std_logic;
            external_load_req               : in  std_logic;
            external_store_req              : in  std_logic;
            external_access_cmplt           : in  std_logic;

            -- flag & req out
            DynamicResolution_en            : out std_logic;            
            invoke_flag                     : out std_logic;
            new_obj_flag                    : out std_logic;
            static_flag                     : out std_logic;
            field_wr                        : out std_logic;
			ldc_flag                        : out std_logic;
			ldc_w_flag						: out std_logic;
            stjpc_flag                      : out std_logic;
            return_flag                     : out std_logic;
			ireturn_flag                    : out std_logic;
			newarray_flag					: out std_logic;
			
			getStatic						: out std_logic;
            interrupt_req_decode            : out std_logic;
            refload_req                     : out std_logic;
            refstore_req                    : out std_logic;
            refAcs_sel                     : out std_logic_vector(1 downto 0);
            interrupt_func_decode           : out std_logic_vector(23 downto 0);
            -- thread management , by fox
		TH_mgt_clean_decode			: in std_logic;
		TH_mgt_clean_execute		: out std_logic;
		TH_mgt_context_switch		: in std_logic;
		TH_mgt_CS_reset_lv			: in std_logic;
		-- to multi-core coordinator , added by T.H.Wu , 2013.9.7
		JAIP2COOR_cmd_monitor_enter_req : out std_logic;
		JAIP2COOR_cmd_monitor_exit_req : out std_logic;
			
			-- prof
			prof_simple_issued_A		: in std_logic;
			prof_simple_issued_B		: in std_logic;
			prof_complex_issued			: in std_logic;
			prof_issued_bytecodes_F		: in std_logic_vector(15 downto 0);
			prof_simple_issued_A_D		: out std_logic;
			prof_simple_issued_B_D		: out std_logic;
			prof_complex_issued_D		: out std_logic;
			prof_issued_bytecodes_D		: out std_logic_vector(15 downto 0);
			--debug_cs_decode                       : out std_logic_vector(48 downto 0);
			
			--xcptn thrown by bytecode
			xcptn_done                      : in  std_logic;
		    xcptn_thrown_bytecode           : out std_logic
        );
    end component decode;

    component execution is
        generic(
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
			--Native_ArgCnt               : in  std_logic_vector( 7 downto 0);
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
			static_flag			 : in std_logic;
			return_flag                 : in  std_logic;
			clinitEN			 : in std_logic;
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
			ArgSize                     : in  std_logic_vector( 4 downto 0);
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
			check_CST_MA_done           : in  std_logic;
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
			compared_EID                : out std_logic_vector(15 downto 0);
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
                        stack_mgt_transfer_counter	: in std_logic_vector(RAMB_S36_AWIDTH downto 0);
                        TH_mgt_context_switch		: in  std_logic;
                        TH_mgt_new_thread_execute	: in  std_logic;
                        TH_mgt_LVreg2mem_CS			: in  std_logic;
                        -- modified by T.H.Wu , 2013.7.18
                        TH_data_out_dly                             : in std_logic_vector(31 downto 0); 
                        TH_data_out_transfer_cnt_dly : in std_logic_vector(3 downto 0); 
                        --thread_stack_vp			 
                        --thread_stack_sp		 
                        --thread_stack_A         
                        --thread_stack_B        
                        --thread_stack_C            
                        --TH_mgt_thread_reg_valid  : in  std_logic_vector(3 downto 0);
                        --thread_obj	
                        -- stack access mgt		-- by fox
                        external_store_data          : out  std_logic_vector(31 downto 0);	 
                        stackMgt2exe_base_addr	: in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
                        stackMgt2exe_rw_stk_en    : in  std_logic;
                        --debug_cs_4portbank : out std_logic_vector(127 downto 0);
                        --debug_cs_exe   : out  std_logic_vector(93 downto 0) ;
                        --debug_cs_xcptn   : out  std_logic_vector(55 downto 0) ;
			-- debug
			debug_flag                  : in  std_logic_vector(11 downto 0);
			debug_addr                  : in  std_logic_vector(11 downto 0);
			debug_data                  : out std_logic_vector(31 downto 0)
			-- cs debug
			--debug_alu_stall				: out std_logic; 
		--debug_stack_wdaddr			: out std_logic_vector(17 downto 0);
		--debug_stack_rdaddr			: out std_logic_vector(17 downto 0)
        );
    end component execution;
    
    -- by fox
        
	component thread_management is
     generic(
        RAMB_S18_AWIDTH        	: integer := 10;
		RAMB_S36_AWIDTH        	: integer := 9;
		Max_Thread_Number		: integer := 16
     );
        port(
        -- for chipscope debug use .
		debug_cs_thread_mgt         : out std_logic_vector(47 downto 0);
		-- ctrl signal
		Rst                         : in  std_logic;
		clk                         : in  std_logic;
		act_dly                     : in  std_logic;
		SetTimeSlices_Wen           : in  std_logic; 
		stack_rw_cmplt				: in  std_logic;
		thread_base					: out std_logic_vector(Max_Thread_Number/4-1 downto 0);
		stack_length				: out std_logic_vector(RAMB_S36_AWIDTH downto 0);
		stack_rw_enable				: out std_logic;
		sdram_rw_flag				: out std_logic;
		
		context_switch	        	: out std_logic; 
		thread_number				: out std_logic_vector(4 downto 0);
		jpc_backup					: out std_logic;
                -- added by T.H.Wu 2013.7.18 , for transferring TCB info to other modules in JAIP sequentially
                -- unified 32-bit input / output data port HERE !
		TH_data_in_valid			: in std_logic;
		TH_data_in                  : in std_logic_vector (31 downto 0) ;
		TH_data_out_valid			: out std_logic;
		TH_data_out                 : out std_logic_vector (31 downto 0) ;
		TH_data_in_transfer_cnt_dly : in std_logic_vector( 3 downto 0);
		TH_data_out_transfer_cnt    :out std_logic_vector( 3 downto 0);
		thread_ctrl_state_out       :out Thread_management_SM_TYPE;
		
        -- method area 
		ClsLoading_stall            : in  std_logic;
		TH_trigger_MA_ctrl_en	: out std_logic; 
		
		--from dynamic resolution (new thread)
		new_thread_flag				: in  std_logic;
		Thread_start_cmplt_flag     : out  std_logic;  
		new_thread_execute			: out std_logic; 
		-- from fetch stage  
		simple_mode					: in  std_logic;
		reset_mode					: out std_logic; 
		-- from decode stage 
		CS_reset_lv					: out std_logic; 
		-- from execute stage 
		LVreg2mem_CS				: out std_logic;
		-- for multi-core coordinator , 2013.10.5
		current_run_thread_slot_idx	: out std_logic_vector(Max_Thread_Number/4-1 downto 0);
	 	now_thread_monitorenter_succeed	: in std_logic ; 
	 	now_thread_monitorenter_fail	: in std_logic ; 
	 	monitorexit_sender_is_the_core	: in std_logic ; 
	 	monitorexit_nextowner_here		: in std_logic ; 
	 	monitorexit_lockfree			: in std_logic ; 
		monitorexit_nextowner_thread_slot_idx	: in std_logic_vector(Max_Thread_Number/4-1 downto 0);
	 	monitorenter_cmplt				: out std_logic ; 
	 	monitorexit_cmplt				: out std_logic ; 
		-- from soj
		before_16clk_now_TH_timeout_out	: out std_logic;
		now_TH_start_exec_over_28clk	: out std_logic;
		thread_dead_flag			: in  std_logic;
		interrupt_req				: in  std_logic;
		clean_pipeline_cmplt		: in  std_logic;	-- by fox
		clean_pipeline				: out std_logic;
		stall_all_flag				: in  std_logic		-- sure execute stage complete(alu_stall) 
    );
    end component thread_management;
        
        
	-- by fox
	component stack_access_management is
        generic(
            RAMB_S36_AWIDTH             : integer := 9;
			STACK_AREA_DDR_ADDRESS		: std_logic_vector(13 downto 0) := (X"5BF"&"11");
			BURST_LENGTH				: std_logic_vector(7 downto 0) 	:= X"40";  --byte
			Max_Thread_Number			: integer := 16
        );
        port(
		-- for chipscope debug
                 debug_cs_stk_mgt                        : out std_logic_vector (2 downto 0); 
            -- ctrl signal
			Rst                         : in  std_logic;
			clk                         : in  std_logic;
			bus_busy					: in  std_logic;
		
			stack_rw_cmplt				: out std_logic;
			thread_base					: in  std_logic_vector(Max_Thread_Number/4-1 downto 0);
			stack_length				: in  std_logic_vector(RAMB_S36_AWIDTH downto 0);
			stack_rw_enable				: in  std_logic;
			sdram_rw_flag				: in  std_logic; -- 0=restore stack from sdram 1=backup stack to sdram
		
			-- (master) external memory access
			external_access_ack			: in  std_logic;
			external_access_cmplt       : in  std_logic;
			prepare_stack_load_req		: out std_logic;
			stack_in_sdram_addr			: out std_logic_vector(15 downto 0);
			backup_stack_store_req		: out std_logic;
		
			stack_base					: out std_logic_vector(RAMB_S36_AWIDTH downto 0); 
			stack_rw					: out std_logic
        );
    end component stack_access_management;
			
            
    
    -- for soj use
	signal act_w						: std_logic;
    signal act_dly                      : std_logic; -- modified by T.H.Wu , 2013.8.1
    signal act_dly2                     : std_logic;  
	signal set_act_reg					: std_logic;
	signal set_act_w					: std_logic;
	signal core_id_reg					: std_logic_vector (1 downto 0); 
    signal stall_all                   : std_logic;
	signal stall_all_AASM_Heap		   : std_logic;
	signal bus_occupied_by_AASM		   : std_logic; -- added by T.H.Wu , 2013.7.26
    signal write_ABC                   : write_ABC_type;
    signal field_access_addr           : std_logic_vector(31 downto 0);
    signal array_access_addr           : std_logic_vector(31 downto 0);
    signal array_w_access_addr         : std_logic_vector(31 downto 0);
    signal array_s_access_addr         : std_logic_vector(31 downto 0);
    signal array_b_access_addr         : std_logic_vector(31 downto 0);
    
    signal IP2Bus_Mst_BE_s             : std_logic_vector( 3 downto 0);
    signal IP2Bus_Mst_BE_b             : std_logic_vector( 3 downto 0);
    
    signal external_load_data_s        : std_logic_vector(15 downto 0);
    signal external_load_data_b        : std_logic_vector(7 downto 0);
    -- for invoke / return main method use 
    signal main_mthd_id                   : std_logic_vector(15 downto 0);
    
    --signal DR_state                    : std_logic;
    signal MethodArea_Wen              : std_logic;
    signal MethodArea_addr             : std_logic_vector(11 downto 0);
    signal MethodArea_data             : std_logic_vector(31 downto 0);
	-- delay flags from native hardware interface for one clock, 2013.9.13
	signal native_HW_en_tmp_dly			: std_logic;
	signal native_HW_ID_w_dly			: std_logic_vector(4 downto 0);

    signal stall_translate_stage       : std_logic;
    signal semitranslated_code         : std_logic_vector(15 downto 0);
    signal opd_num                     : std_logic_vector( 7 downto 0);
    signal complex                     : std_logic_vector( 1 downto 0);

    signal stall_jpc                   : std_logic;
    signal stall_jpc_f                 : std_logic;
    signal instr_buf_ctrl              : std_logic_vector( 1 downto 0);
    signal jpc                         : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
    signal jpc_reg                     : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
    signal opd_source                  : std_logic_vector( 1 downto 0); 
     signal switch_instr_branch : std_logic; -- just for tableswitch / lookupswitch branch use
     signal is_switch_instr_start	:  std_logic;-- just for tableswitch / lookupswitch branch use
    signal stall_fetch_stage           : std_logic;
    signal switch_instr_revert_code_seq : std_logic ;

    signal bytecodes                   : std_logic_vector(15 downto 0);
    signal instruction_buffer_1        : std_logic_vector(15 downto 0);
    signal instruction_buffer_2        : std_logic_vector(15 downto 0);
    signal branch_trigger              : std_logic_vector(15 downto 0);
    signal instrs_pkg                  : std_logic_vector(15 downto 0);
    signal nop_1, nop_2                : std_logic;

    signal stall_decode_stage          : std_logic;
    signal branch_destination          : std_logic_vector(15 downto 0);

    signal load_immediate1             : std_logic_vector(31 downto 0);
    signal load_immediate2             : std_logic_vector(31 downto 0);
    signal store1_addr                 : std_logic_vector(9 downto 0);
    signal store2_addr                 : std_logic_vector(9 downto 0);
    signal W1_RegFlag                  : std_logic;
    signal W2_RegFlag                  : std_logic;
    signal MemRead_ctrl                : Decode2Execute_MemRead_Type;
    signal ctrl                        : Decode2Execute_ControlSignal_Type;
    signal mem2LVreg_1_decode            : std_logic;
    signal mem2LVreg_2_decode            : std_logic;
    signal stsp_s_flag                 : std_logic;

    signal operand0                    : std_logic_vector(7 downto 0);
    signal operand1                    : std_logic_vector(7 downto 0);
    signal operand2                    : std_logic_vector(7 downto 0);
    signal operand3                    : std_logic_vector(7 downto 0);

    signal interrupt_cmplt             : std_logic;
    signal interrupt_req_tmp           : std_logic;
    signal external_load_req_tmp       : std_logic;
    signal external_store_req_tmp      : std_logic;
    signal external_load_req_reg       : std_logic;
    signal external_store_req_reg      : std_logic;
    signal external_access_addr_tmp    : std_logic_vector(31 downto 0);
	signal external_store_data_tmp	   : std_logic_vector(31 downto 0);
	signal clsiAddr_tmp				   : std_logic_vector(11 downto 0);	
    
    signal invoke_flag                 : std_logic;
    signal static_flag                 : std_logic;
    signal field_wr                    : std_logic;
	signal ldc_flag                    : std_logic;
	signal ldc_w_flag				   : std_logic;
    signal stjpc_flag                  : std_logic;
    signal return_flag                 : std_logic;
    signal ireturn_flag                : std_logic;
    signal new_obj_flag                : std_logic;
	signal getStatic				   : std_logic;
    signal interrupt_req_decode        : std_logic;
    signal refload_req                 : std_logic;
    signal refstore_req                : std_logic;
    signal refAcs_sel                 : std_logic_vector(1 downto 0);
    signal interrupt_func_decode       : std_logic_vector(23 downto 0);
    signal pop1_flag                   : std_logic;
    signal pop2_flag                   : std_logic;
    signal set_ucodePC                 : std_logic;
    signal native_flag                 : std_logic;
	signal arrayAlloc_en				   : std_logic;
	signal arrayAllocSize			   : std_logic_vector(15 downto 0);
	signal arrayTag					   : std_logic_vector(7 downto 0);
	signal arrayLength				   : std_logic_vector(15 downto 0);
	signal arrayLengthAligned		   : std_logic_vector(15 downto 0);
	signal newarray_flag			   : std_logic; 
	
    signal stall_execution_stage       : std_logic;

	-- note by T.H.Wu , 2013.9.12 , all arguments of native hardware may be delayed for 1 clock
    signal A, B, C                     : std_logic_vector(31 downto 0);
    signal A_dly, B_dly, C_dly	       : std_logic_vector(31 downto 0);
    signal vp, sp                      : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal vp_dly                      : std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal reg_valid                   : std_logic_vector( 3 downto 0);
    signal branch_flag                 : std_logic;
    signal alu_stall                   : std_logic;
    signal StackRAM_RD1, StackRAM_RD2  : std_logic_vector(31 downto 0);
    
    --signal invoke_objref               : std_logic_vector(31 downto 0);
       -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
    --signal ArgSize                     : std_logic_vector( 7 downto 0); 
    signal ArgSize                     : std_logic_vector( 4 downto 0); 
    
    --------------------------------------------------------------------------------------------------------------------------------
    -- for thread management
    signal TH_mgt_SetTimeSlices_Wen_w : std_logic ;
	signal	before_16clk_now_TH_timeout_out	: std_logic;
	signal	now_TH_start_exec_over_28clk	: std_logic;
     signal  TH_new_thread_flag_w : std_logic ;
    signal TH_mgt_SetTimeSlices_Wen		: std_logic ;
    signal TH_mgt_context_switch        		: std_logic ; 
    signal TH_mgt_thread_number        		: std_logic_vector(4 downto 0);
     
    signal TH_mgt_thread_base        		: std_logic_vector(Max_Thread_Number/4-1 downto 0);
    signal TH_mgt_stack_length        		: std_logic_vector(RAMB_S36_AWIDTH downto 0);
    signal TH_mgt_stack_rw_enable        		: std_logic ;
    signal TH_mgt_sdram_rw_flag        		: std_logic ;
    signal TH_mgt_jpc_backup        		: std_logic ;
    
    signal TH_trigger_MA_ctrl_en   : std_logic ;  
      -- added by T.H.Wu , 2013.7.19 .  
    signal TH_trigger_MA_ctrl_en_dly   : std_logic ;
    signal TH_new_thread_flag   : std_logic ;   -- from D.R. while invoking Thread.start()
    signal TH_mgt_new_thread_execute   : std_logic ;  
    
    signal TH_mgt_simple_mode   : std_logic ;  
    signal TH_mgt_reset_mode   : std_logic ;  
    signal TH_mgt_CS_reset_lv   : std_logic ;  
    signal TH_mgt_LVreg2mem_CS   : std_logic ;   
    
    signal TH_data_in_valid        : std_logic ;
    signal TH_data_in        		: std_logic_vector (31 downto 0) ;
    signal TH_data_out_valid      : std_logic ;
    signal TH_data_out_dly  	:  std_logic_vector (31 downto 0) ; 
    signal TH_data_out_dly_w	:  std_logic_vector (31 downto 0) ; 
    -- 2013.7.8 , global data transfer input / output counter  for maintaining thread control block in thread management 
    signal TH_data_in_transfer_cnt_dly   : std_logic_vector( 3 downto 0);
    signal TH_data_in_transfer_cnt   : std_logic_vector( 3 downto 0);
    signal TH_data_in_transfer_cnt_w  : std_logic_vector( 3 downto 0);
    signal TH_data_out_transfer_cnt_dly     : std_logic_vector( 3 downto 0);
    signal TH_data_out_transfer_cnt_dly_w : std_logic_vector( 3 downto 0); 
    signal TH_state_dly        :   Thread_management_SM_TYPE;
    signal TH_state_dly_w    :   Thread_management_SM_TYPE;
    -- for (sequential) content trasferring of  thread control block 
    -- *** for restoring next ready thread ***
    signal TH_mgt_ready_thread_cls_id_mthd_id  : std_logic_vector(31 downto 0);
    signal TH_mgt_thread_jpc   : std_logic_vector(15 downto 0);
    -- *** for backuping previous thread *** -- modified by T.H.Wu 2013.7.18
        signal TH_mgt_runnable_thread_backup_flag_w   : std_logic ;  
        signal TH_mgt_runnable_thread_backup_flag       : std_logic ;  
        signal TH_prev_thread_cls_id   : std_logic_vector(15 downto 0);
        signal TH_prev_thread_mthd_id  : std_logic_vector(15 downto 0);
	signal TH_prev_thread_vp            :  std_logic_vector(RAMB_S36_AWIDTH downto 0);
	signal TH_prev_thread_sp            :  std_logic_vector(RAMB_S36_AWIDTH downto 0); 
        signal TH_prev_thread_reg_valid  : std_logic_vector(3 downto 0);
        signal TH_prev_thread_jpc : std_logic_vector(15 downto 0);
        signal TH_prev_thread_A : std_logic_vector(31 downto 0);
        signal TH_prev_thread_B : std_logic_vector(31 downto 0);
        signal TH_prev_thread_C : std_logic_vector(31 downto 0);
     
    signal TH_mgt_thread_trigger  : std_logic_vector(15 downto 0);  -- trigger what ?  2013.7.16 
    --
     signal   invoke_objref_reg_2_TH_mgt  : std_logic_vector(31 downto 0);
     signal   Thread_start_cmplt_flag : std_logic ;  
     signal   Thread_start_cmplt_flag_dly : std_logic ;  
	-- stack access management
	signal StackMgt_rw_cmplt			: std_logic;
	signal prepare_stack_load_req	: std_logic;
	signal stackMgt2DDR_addr		: std_logic_vector(15 downto 0);  
	signal backup_stack_store_req	: std_logic;		
	signal stackMgt2exe_base_addr	: std_logic_vector(RAMB_S36_AWIDTH downto 0); 
	signal stackMgt2exe_rw_stk_en					: std_logic;
        -- in soj , thread management will need some additional circuit below
        -- origin by fox , 2013.7.13
        signal token_rw_tmp				: std_logic;
	signal token_rw					: std_logic;
	signal token_tmp				: std_logic; -- check who get the bus lock , if token=0 , runnable thread get bus lock
                                                                                           -- otherwise token=1 , stack management get the bus lock.
	signal token					: std_logic; 
        -- modified by T.H.Wu , for fixing bug from token and MA controller / CST controller , and critical path issue , 2013.7.24 
        signal CSTLoading_stall_dly : std_logic; 
        signal MthdLoading_stall_dly : std_logic; 
        -- 
	signal bus_occupied_by_run_thread	: std_logic; -- modified by T.H.Wu , original name : bus_busy_tmp
        -- 2013.7.16
        -- before context switch between any 2 threads , we must make sure the next one bytecode instruction 
        -- which is not executed yet and hold until next time current thread are waken up 
        signal TH_mgt_thread_dead   : std_logic ;  
        signal TH_mgt_thread_dead_reg   : std_logic ; 
                -- modified by T.H.Wu , 2013.8.19 , hold thread dead flag until next context switch ,
                -- it used to stall jpc for current dead thread (if happened)
        signal TH_mgt_clean_pipeline   : std_logic ;  
	--signal TH_mgt_clean_fetch	: std_logic;
	signal	TH_mgt_clean_decode	: std_logic;  
	signal	TH_mgt_clean_execute   : std_logic ;  
	signal	current_run_thread_slot_idx	: std_logic_vector(Max_Thread_Number/4-1 downto 0); 
		
	-- modified by T.H.Wu , 2013.8.8 , for solving critical path
    --signal TH_mgt_clean_pipeline_cmplt   : std_logic ;  
	-------------------------------------------------------------------
	-- for communicating between JAIP core and multi-core coordinator
	-------------------------------------------------------------------
	-- added by T.H.Wu , 2013.9.7
	signal	JAIP2COOR_cmd_reg_w		: std_logic_vector (2 downto 0) ;
	signal	JAIP2COOR_cmd_reg		: std_logic_vector (2 downto 0) ;
	signal	JAIP2COOR_cmd_newTH_req_w  : std_logic ;  
	signal	JAIP2COOR_cmd_newTH_req  : std_logic ;  
	-- to multi-core coordinator , added by T.H.Wu , 2013.9.7
	signal	JAIP2COOR_cmd_monitor_enter_req : std_logic;
	signal	JAIP2COOR_cmd_monitor_exit_req : std_logic;
	signal	JAIP2COOR_cmd_monitor_enter_req_dly : std_logic;
	signal	JAIP2COOR_cmd_monitor_exit_req_dly : std_logic;
	signal	JAIP2COOR_info1_reg_w		: std_logic_vector (31 downto 0);
	signal	JAIP2COOR_info1_reg			: std_logic_vector (31 downto 0);
	signal	JAIP2COOR_info2_reg_w		: std_logic_vector (31 downto 0);
	signal	JAIP2COOR_info2_reg			: std_logic_vector (31 downto 0); 
	-- added by T.H.Wu , 2013.9.8
	signal	COOR_cmd_cmplt_reg		: std_logic ;
	signal	COOR_cmd_cmplt_reg_w	: std_logic ;
	signal	newTH_sender_is_the_core	: std_logic ; 
	signal	newTH_sender_is_the_core_w	: std_logic ; 
	signal	newTH_receive_is_not_the_core	: std_logic ; 
	signal	newTH_receive_is_not_the_core_w	: std_logic ; 
	signal	newTH_from_TH_mgt_cmplt	: std_logic ;
	signal	newTH_from_TH_mgt_cmplt_w	: std_logic ;
	signal	native_HW_newTH_cmplt		: std_logic ;
	signal	native_HW_newTH_cmplt_w		: std_logic ; 
	-- added by T.H.Wu , 2013.10.7 
	signal	now_thread_monitorenter_succeed		: std_logic ; 
	signal	now_thread_monitorenter_succeed_w	: std_logic ; 
	signal	now_thread_monitorenter_fail		: std_logic ; 
	signal	now_thread_monitorenter_fail_w		: std_logic ; 
	signal	now_thread_monitorenter_fail_dly	: std_logic ; 
	signal	soj_now_TH_monitorenter_fail_hold	: std_logic ; 
	signal	soj_now_TH_monitorenter_fail_hold_W	: std_logic ; 
	signal	monitorexit_sender_is_the_core		: std_logic ; 
	signal	monitorexit_sender_is_the_core_w	: std_logic ; 
	signal	monitorexit_receiver_is_the_core	: std_logic ; 
	signal	monitorexit_receiver_is_the_core_w	: std_logic ; 
	signal	monitorexit_lockfree				: std_logic ; 
	signal	monitorexit_lockfree_w				: std_logic ; 
	signal	monitorexit_nextowner_here			: std_logic ; 
	signal	monitorexit_nextowner_here_w		: std_logic ;   
	signal	monitorexit_nextowner_thread_slot_idx	: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal	monitorexit_nextowner_thread_slot_idx_w	: std_logic_vector(Max_Thread_Number/4-1 downto 0);
	signal	monitorenter_cmplt					: std_logic ; 
	signal	monitorexit_cmplt					: std_logic ; 
	signal	monitorenter_cmplt_from_TH_mgt		: std_logic ;
	signal	monitorenter_cmplt_from_TH_mgt_w	: std_logic ;
	signal	monitorexit_cmplt_from_TH_mgt		: std_logic ;
	signal	monitorexit_cmplt_from_TH_mgt_w		: std_logic ;
	signal	JAIP2COOR_cmd_monitor_stall_reg		: std_logic ;
	signal	JAIP2COOR_cmd_monitor_stall_reg_w	: std_logic ;
	signal	JAIP2COOR_cmd_monitor_stall			: std_logic ;
	-- added by T.H.Wu , 2013.9.12
	signal	COOR_res_msg_hold_w 	: std_logic_vector (15 downto 0); 
	signal	COOR_res_msg_hold		: std_logic_vector (15 downto 0); 
	signal	COOR_res_msg_we_hold	: std_logic ;
	signal	COOR_res_msg_we_hold_w	: std_logic ;
	signal	COOR_res_msg_we_sync	: std_logic ;
	signal	sync_mthd_invoke_rtn_cmplt: std_logic ;
	signal	sync_mthd_invoke_rtn_cmplt_w: std_logic ;
	signal	COOR_res_msg_sync		: std_logic_vector (15 downto 0); 
	-- added by T.H.Wu, 2014.3.6
	signal	block_COOR_msg_we_before_16clk_now_TH_timeout_w	:	std_logic;
	signal	JAIP2COOR_pending_resMsgSent_reg	: std_logic;
	signal	JAIP2COOR_pending_resMsgSent_reg_w	: std_logic;
				
	
	signal Runnable_load_req		: std_logic;
	signal Runnable_store_req		: std_logic;
	signal Runnable_access_ack		: std_logic;
	signal Runnable_access_cmplt	: std_logic;
	signal Runnable_access_cmplt_dly: std_logic;
	signal Runnable_MstRd_burst_data_rdy	: std_logic;
	signal Runnable_MstWr_burst_data_rdy	: std_logic;
	signal StackSpace_load_req		: std_logic;
	signal StackSpace_store_req		: std_logic;
	signal StackSpace_access_ack	: std_logic;
	signal StackSpace_access_cmplt	: std_logic;
	signal StackSpace_MstRd_burst_data_rdy	: std_logic;
	signal StackSpace_MstWr_burst_data_rdy	: std_logic;
	signal external_access_busy		: std_logic;  
    --  2013.7.17
        signal stack_mgt_transfer_counter_reg       : std_logic_vector (RAMB_S36_AWIDTH downto 0); -- only for stack management transferring use
        signal stack_mgt_transfer_counter              : std_logic_vector (RAMB_S36_AWIDTH downto 0);
        ---- ****** for stack management *******
        signal stack_backup_data  : std_logic_vector(31 downto 0);
        -----------------------------------------------------------------------------------------------------
    
    signal RefCls_en                   : std_logic;
    signal MA_management_en            : std_logic;
    signal ClsLoading_req              : std_logic;
    signal ClsLoading_ex_addr          : std_logic_vector(31 downto 0);
    signal ClsLoading_stall            : std_logic;
    signal ClsLoading_Wen              : std_logic;
    signal ClsLoading_MA_addr          : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
    signal ClsLoading_data             : std_logic_vector(15 downto 0);
    signal RAM_select_base             : std_logic_vector( 4 downto 0);
    signal cls_num 	      	           : std_logic_vector(15 downto 0);
	signal clsiStoreReq_tmp			   : std_logic;
	signal clsiLoadReq_tmp			   : std_logic;
	signal clsiLoading 				   : std_logic;
	signal clsiStoring				   : std_logic;

	--signal ClsLoading_stall            : std_logic;
    signal DynamicResolution_en        : std_logic;
    signal DynamicResolution           : std_logic_vector(31 downto 0);
    signal DR_reg_en                   : std_logic;
    signal DR_addr                     : std_logic_vector(31 downto 0);
    signal DynamicResolution_load_req  : std_logic;
    signal DynamicResolution_store_req : std_logic;
    signal search_ptr                  : std_logic_vector(RAMB_S18_AWIDTH+4 downto 0);
    signal interrupt_req_DR            : std_logic;
    signal interrupt_func_DR           : std_logic_vector(23 downto 0);
    signal CTRL_state                  : DynamicResolution_SM_TYPE; 
             -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
    --signal Native_ArgCnt               : std_logic_vector( 7 downto 0);
    signal Native_ArgCnt               : std_logic_vector( 4 downto 0);
    signal Native_CycCnt               : std_logic_vector( 1 downto 0);
       -- modified by T.H.Wu , for executing Thread.start() , 2013.7.11
    --signal native_HW_ID_w		: std_logic_vector(7 downto 0);
    signal native_HW_ID_w		: std_logic_vector(4 downto 0);

    signal Host_arg1_reg               : std_logic_vector(31 downto 0);
    signal Host_arg2_reg               : std_logic_vector(31 downto 0);
    signal Host_arg3_reg               : std_logic_vector(31 downto 0);
    signal Host_arg4_reg               : std_logic_vector(31 downto 0);
    signal Host_arg5_reg               : std_logic_vector(31 downto 0);
	signal field_access_cnt            : std_logic_vector(31 downto 0);
	signal methd_invoke_cnt            : std_logic_vector(31 downto 0);
    
    
    signal pfieldaccess                : std_logic;
    signal gfieldaccess                : std_logic;
    signal debug_data_DR               : std_logic_vector(31 downto 0);
    signal debug_data_cls_mng          : std_logic_vector(31 downto 0);
    signal debug_data_fetch            : std_logic_vector(31 downto 0);
    signal debug_data_execute          : std_logic_vector(31 downto 0);
	signal debug_data_CST              : std_logic_vector(31 downto 0);
	signal debug_data_MA               : std_logic_vector(31 downto 0);

    signal debug_dynamic_resolution    : std_logic_vector(1 downto 0);
    -- 00 invoke
    -- 01 get fd
    -- 10 put fd
    signal debug_invoke                : std_logic_vector(31 downto 0);
    signal debug_invoke_cycle_cnt      : std_logic_vector(31 downto 0);
    signal debug_get_fd                : std_logic_vector(31 downto 0);
    signal debug_get_fd_cycle_cnt      : std_logic_vector(31 downto 0);
    signal debug_put_fd                : std_logic_vector(31 downto 0);
    signal debug_put_fd_cycle_cnt      : std_logic_vector(31 downto 0);
    
    signal debug_bram_address       : std_logic_vector(31 downto 0);
    signal debug_bram_data_in       : std_logic_vector(31 downto 0);
    signal debug_bram_we            : std_logic;
    signal debug_bram_we_tmp        : std_logic;
    signal debug_bram_we_tmp_reg    : std_logic;
    signal debug_bram_counter       : std_logic_vector(31 downto 0);
    signal debug_bram_out           : std_logic_vector(31 downto 0);
    
    signal debug_bytecode           : std_logic_vector(31 downto 0);

    signal debug2_bram_address       : std_logic_vector(31 downto 0);
    signal debug2_bram_data_in       : std_logic_vector(31 downto 0);
    signal debug2_bram_we            : std_logic;
    signal debug2_bram_we_tmp        : std_logic;
    signal debug2_bram_we_tmp_reg    : std_logic;
    signal debug2_bram_counter       : std_logic_vector(31 downto 0);
    signal debug2_bram_out           : std_logic_vector(15 downto 0);
    signal debug2_cls_num_tmp        : std_logic_vector(15 downto 0);
    signal debug2_cls0_cnt           : std_logic_vector(31 downto 0);
    signal debug2_cls0_cnt2          : std_logic_vector(31 downto 0); 
    signal double_issue             : std_logic_vector(31 downto 0);
    signal not_double_issue         : std_logic_vector(31 downto 0);
    signal nopnop                   : std_logic_vector(31 downto 0);
    signal Normal_nopnop            : std_logic_vector(31 downto 0);
    signal instrs_pkg_FF            : std_logic_vector(31 downto 0);
    signal ucode_nopnop             : std_logic_vector(31 downto 0);
    signal ISFrom_ROM               : std_logic;
    signal nopflag                  : std_logic_vector(31 downto 0);
    signal stall_all_reg            : std_logic_vector(31 downto 0);
    signal stall_fetch_stage_reg    : std_logic_vector(31 downto 0);
	
	-- xcptn 
	signal	CST_check_id       	       : std_logic_vector(15 downto 0);
	signal	MTHD_check_id      	       : std_logic_vector(15 downto 0);
	--execute
	--signal xcptn_en                    : std_logic;
	signal xcptn_thrown_bytecode       : std_logic;	
	signal xcptn_stall                 : std_logic;
	signal xcptn_flush_pipeline        : std_logic;
	signal external_load_EID_req       : std_logic;
	signal external_load_LVcnt_req     : std_logic;
    signal prsr2ER_LUT_di   	       : std_logic_vector(15 downto 0);
	signal prsr2ER_LUT_addr            : std_logic_vector(9 downto 0);
	signal prsr2ER_LUT_wen             : std_logic;	
	signal ER_info                     : std_logic_vector(15 downto 0);
	signal ER_info_wen_MA_ctrlr        : std_logic;
	signal update_return_regs     	   : std_logic;
	signal ret_frm_regs_wen		       : std_logic;                      
	signal ret_frm_mthd_id			   : std_logic_vector(15 downto 0);  
	signal ER_info_addr_rdy            : std_logic;    
	--signal check_CST_MA_done           : std_logic;  
	signal MA_base_mem_addr_wen        : std_logic;  
  	signal MA_base_mem_addr			   : std_logic_vector(31 downto 0);
	signal xcptn_jpc_wen			   : std_logic;
	signal xcptn_jpc                   : std_logic_vector(15 downto 0);
	signal xcptn_cst_mthd_check_done   : std_logic;
	signal ret_frm_cls_id			   : std_logic_vector(15 downto 0); 
	signal xcptn_cst_mthd_check_en     : std_logic;
	signal xcptn_cst_mthd_check_IDs_en : std_logic;         
	signal xcptn_clean_buffer          : std_logic;
	signal mask_insr1                  : std_logic;
	signal xcptn_done                  : std_logic;
	signal CST_FSM_Check_offset        : std_logic;
	signal get_parent_EID              : std_logic;
	signal parent_EID   			   : std_logic_vector(15 downto 0); 
	signal compared_EID   			   : std_logic_vector(15 downto 0); 
	-- interrupt req
	signal	interrupt_req_xcptn		   : std_logic;
	signal	interrupt_func_xcptn       : std_logic_vector(23 downto 0);     
    signal  adjust_jpc2xcptn_instr     : std_logic;	
	signal native_HW_cmplt_tmp		   : std_logic;
	signal native_HW_en_tmp			   : std_logic;
	signal push1_flag_tmp              : std_logic;
    signal push2_flag_tmp              : std_logic;
	signal decode_push				   : std_logic;
	signal execute_push				   : std_logic;
	-- end xcptn
	
	--for_stack_depth_info 
    signal return_mask               : std_logic;
	signal buffer_check_by_retrun    : std_logic;

	
	--CST
	signal CST_checking_en           : std_logic;
	signal DR2CST_ctrlr_cls_id 		 : std_logic_vector(15 downto 0);

	signal CSTProfileTable_wen       : std_logic;
	alias  CSTProfileTable_idx       : std_logic_vector(15 downto 0) is CSTProfileTable (31 downto 16);
    alias  CSTProfileTable_di        : std_logic_vector(15 downto 0) is CSTProfileTable (15 downto  0);
	
	signal CSTLoading_req 		     : std_logic;
    signal CSTLoading_ex_addr 		 : std_logic_vector(31 downto 0);
    signal CSTLoading_stall 		 : std_logic;
	
	signal MA_checking_done 		 : std_logic;
	
	signal CST_ctrlr2buffer_wen 	 : std_logic;
    signal CST_ctrlr2buffer_addr	 : std_logic_vector(11 downto 0);
    --signal CST_ctrlt2buffer_data 	 : std_logic_vector(31 downto 0);
    signal CST_ctrlr2buffer_block_base : std_logic_vector(4 downto 0);
	
	signal cls_id 				     : std_logic_vector(15 downto 0);
	--signal now_cls_id 				 : std_logic_vector(15 downto 0);
	
	--CST buffer
	signal CST_buffer_addr			 : std_logic_vector(11 downto 0);
	signal CST_buffer_wen 	 	     : std_logic;
	signal CST_buffer_wr_data    	 : std_logic_vector(31 downto 0);
	signal CST_entry            	 : std_logic_vector(31 downto 0);
	
	
	--MTHD
	signal DR2MA_mgt_mthd_id	 	 : std_logic_vector(15 downto 0); 
	signal CST_check_done			 : std_logic;
	signal Mthd_check_done			 : std_logic;
	
	signal MthdProfileTable_wen      : std_logic;
	alias  MthdProfileTable_idx      : std_logic_vector(15 downto 0) is MthdProfileTable (31 downto 16);
    alias  MthdProfileTable_info     : std_logic_vector(15 downto 0) is MthdProfileTable (15 downto  0);
	
	signal MthdLoading_req 			 : std_logic;
    signal MthdLoading_ex_addr 		 : std_logic_vector(31 downto 0);
    signal Mthd_Loading_done 		 : std_logic;
	signal MthdLoading_stall 		 : std_logic;
	
    signal Mgt2MA_wen 				 : std_logic;
    signal Mgt2MA_addr				 : std_logic_vector(11 downto 0);
   -- signal Mgt2MA_data 		 		 : std_logic_vector(15 downto 0);
    signal Mgt2MA_block_base_sel 	 : std_logic_vector(4 downto 0); 
    signal now_mthd_id 				 : std_logic_vector(15 downto 0);
	-- modified by T.H.Wu , 2014.1.22, for invoking from sync method.
	signal invoke_sync_mthd_flag	: std_logic;
	signal invoke_sync_mthd_flag_dly	: std_logic;
	-- modified by T.H.Wu , 2014.1.21, for returning from sync method.
	signal rtn_frm_sync_mthd_flag		: 	std_logic;
	
	-- global_external_loaded_buffer
	signal external_loaded_buffer 	 : std_logic_vector(31 downto 0); 
	signal debug_CTRL_state 			:  std_logic_vector(5 downto 0);
	
	signal AASM						 : ArrayAllocType;
	signal AASM_next				 : ArrayAllocType;
	signal newarrayStoreReq			 : std_logic;
	
	--debug 
	signal debug_nb_di       	    : std_logic_vector(31 downto 0);
	signal debug_nb_cnt             : std_logic_vector(8 downto 0);
    signal debug_nb_addr            : std_logic_vector(8 downto 0);
	signal debug_nb_SW_addr         : std_logic_vector(8 downto 0);
	signal debug_SW_rd              : std_logic;
    signal debug_nb_wen             : std_logic;	
	signal debug_nb_di2       	    : std_logic_vector(31 downto 0);
	signal debug_nb_cnt2            : std_logic_vector(8 downto 0);
    signal debug_nb_addr2           : std_logic_vector(8 downto 0);
	signal debug_nb_SW_addr2        : std_logic_vector(8 downto 0);
	signal debug_SW_rd2             : std_logic;
    signal debug_nb_wen2            : std_logic;
	signal ll 					    : std_logic_vector(31 downto 0);
	signal lA 					    : std_logic_vector(31 downto 0);
	signal lS 					    : std_logic_vector(31 downto 0);
	signal Sl 					    : std_logic_vector(31 downto 0);
	signal SA 					    : std_logic_vector(31 downto 0);
	signal SS 					    : std_logic_vector(31 downto 0);
	signal Al 					    : std_logic_vector(31 downto 0);
	signal AS 					    : std_logic_vector(31 downto 0);
	signal AA 					    : std_logic_vector(31 downto 0);
	--signal check_mthd_id			: std_logic_vector(9 downto 0);
	signal prof_simple_issued_A		: std_logic;
	signal prof_simple_issued_B		: std_logic;
	signal prof_complex_issued		: std_logic;
	signal prof_issued_bytecodes_T	: std_logic_vector(15 downto 0);
	signal prof_issued_bytecodes_F	: std_logic_vector(15 downto 0);
	signal prof_simple_issued_A_D_tmp	: std_logic;
	signal prof_simple_issued_B_D_tmp	: std_logic;
	signal prof_complex_issued_D_tmp	: std_logic;
	signal prof_issued_bytecodes_D_tmp	: std_logic_vector(15 downto 0);
	
	-- mmes profiler
	signal mem_access_flag			: std_logic;
	signal prof_native_mthd_id		: std_logic_vector(15 downto 0);
	
	signal clinitClsID				: std_logic_vector(15 downto 0);
	signal clinitMthdID				: std_logic_vector(15 downto 0);
	signal clinitEN					: std_logic;
	signal objSize					: std_logic_vector(5 downto 0);
	
	
	-- added by T.H.Wu , 2013.11.5, for monitorenter / monitorexit profiling
	signal	prof_monitor_cnt 		: std_logic_vector(31 downto 0);
	signal	prof_monitor_cnt_w		: std_logic_vector(31 downto 0);
	signal	prof_monitor_bus_clk 	: std_logic_vector(31 downto 0);
	signal	prof_monitor_bus_clk_w	: std_logic_vector(31 downto 0);
	signal	prof_monitor_all_clk 	: std_logic_vector(31 downto 0);
	signal	prof_monitor_all_clk_w	: std_logic_vector(31 downto 0);
	
	--GC
	signal areturn_flag             : std_logic;
    signal putfid_sic_flag          : std_logic;
	signal Mthod_exit_flag          : std_logic;
	signal Mthod_exit_flag_2cy      : std_logic;
	signal Mthod_enter_flag         : std_logic;
	signal Mthod_enter_flag_f       : std_logic;
	signal Mthod_enter_flag_f_2cy   : std_logic;
	signal Mthod_enter_flag_2cy     : std_logic;
	signal astore_stall_flag        : std_logic;
	signal Alloc_en_w               : std_logic;
	signal Alloc_en_r               : std_logic;
	signal debug_clinit_stop        : std_logic;
	signal GC_Clinit_Stop_count     : std_logic_vector(4 downto 0); 
	signal clini_leave_count        : std_logic_vector(4 downto 0); 
	signal GC_arrayAlloc_en_2cy     : std_logic;
	signal GC_arrayAlloc_en         : std_logic;	
	
    begin
	
	CTRL_state_out <= CTRL_state;
	clsiAddr <= clsiAddr_tmp;
	objSize <= DynamicResolution(21 downto 16);
	Alloc_en_w	<= '1' when(CTRL_state = Wait4GC) else  -- new obj
				   '0';
	Alloc_en <= Alloc_en_w and not Alloc_en_r;	
                -- modified by T.H.Wu , 2013.7.15 , for integrating multi-thread and string accelerator
	AllocSize	<= x"00" & "00" & objSize when (CTRL_state = Wait4GC) else
				   arrayAllocSize;
	arrayAlloc_en <= '1' when (AASM = wrLen and Runnable_access_cmplt = '1') else
				     '0';
    arrayAllocSize	<=  (arrayLengthAligned(15 downto 2) & "00") + x"2" when (A_dly(11 downto 0) = x"004" or A_dly(11 downto 0) = x"008") else -- boolean, byte
						(arrayLengthAligned(15 downto 1) & "0")  + x"2" when (A_dly(11 downto 0) = x"005" or A_dly(11 downto 0) = x"009") else -- short, char
						(arrayLength(15 downto 0))               + x"2" when (A_dly(11 downto 0) = x"00A")	else -- int
						(arrayLength(14 downto 0)    & "0") 	 + x"2" when (A_dly(11 downto 0) = x"00B")		else -- long
						(arrayLength(15 downto 0))               + x"2" when (A_dly(23 downto 16) = x"01")	else -- 1-dim array of reference type 
						(others => '0');
						
	arrayLength <= B (15 downto 0); 
	arrayLengthAligned <= B(15 downto 0) + x"3" when (A(11 downto 0) = x"004" or A(11 downto 0) = x"008") else
						  B(15 downto 0) + x"1" when (A(11 downto 0) = x"005" or A(11 downto 0) = x"009") else
						  (others => '0');
       -- 2013.7.12 , useless signal can be hidden ,
 	--arrayTag	<= A(3 downto 0) & x"0000000" when(A(23 downto 16) = x"00") else	-- 1-dim primitive type array	
	--			   A(27 downto 24) & x"0000000" when(A(23 downto 16) = x"01") else	-- 1-dim reference type array
	--			   x"66666666";		
	-- modified by T.H.Wu , 2013.9.16 , reducing the bit needed by array Tag
 	arrayTag	<= A(3 downto 0) & x"0"		when(A(23 downto 16) = x"00") else	-- 1-dim primitive type array	
				   A(27 downto 24) & x"0"	when(A(23 downto 16) = x"01") else	-- 1-dim reference type array
				   x"66";												-- multi-dim array, not finished yet
        -- modified by T.H.Wu , 2013.7.26 ,  try to reduce some logic 
				   
				   
    interrupt_req      <= interrupt_req_tmp;
    -- why adding token_rw_tmp ??  2013.7.12 ??
	--external_load_req  <= external_load_req_tmp  and not external_load_req_reg  and not token_rw_tmp;	-- by fox
	--external_store_req <= external_store_req_tmp and not external_store_req_reg  and token_rw_tmp;	-- by fox
	external_load_req  <= external_load_req_tmp  and not external_load_req_reg ;
	external_store_req <= external_store_req_tmp and not external_store_req_reg ;
	-- modified by T.H.Wu , 2013.9.7 
	native_HW_cmplt_tmp <= native_HW_cmplt or native_HW_newTH_cmplt;
	native_HW_en <= native_HW_en_tmp_dly;
    native_HW_ID <= native_HW_ID_w_dly; 
	-- modified by T.H.Wu , 2014.2.11
	JAIP2COOR_cmd				<=	JAIP2COOR_cmd_reg;
	JAIP2COOR_info1_pipeline	<= JAIP2COOR_info1_reg; 
	JAIP2COOR_info2_pipeline	<= JAIP2COOR_info2_reg;	
	JAIP2COOR_pending_resMsgSent<= JAIP2COOR_pending_resMsgSent_reg;
	COOR_cmd_cmplt <= COOR_cmd_cmplt_reg;
	
	process(Clk, Rst)
	begin
		if(Rst = '1') then
			AASM <= normal;
		elsif(rising_edge(Clk)) then
			AASM <= AASM_next;
		end if;
	end process;
	
        -- modified this state controller by T.H.Wu , 2013.7.26
	process(AASM, Runnable_access_cmplt, token, newarray_flag,GC_Cmplt_in)
	begin
                AASM_next <= AASM;
		case AASM is
			when normal =>
				if(newarray_flag = '1') then
					AASM_next <= wrArr2Hp; 
				end if; 
			when wrArr2Hp=>
				if(GC_Cmplt_in='1') then
					AASM_next <= wrIDReq;
				else
					AASM_next <=AASM;
				end if;					
			when wrIDReq =>
                                if(token='0') then -- we need to send read request to token continously 
                                                                    -- until token switch to runnable thread
                                    AASM_next <= wrID;
                                end if;
			when wrID =>
				if(Runnable_access_cmplt = '1') then
					AASM_next <= wrLenReq; 
				end if; 
			when wrLenReq =>
                                AASM_next <= wrLen;
			when wrLen =>
				if(Runnable_access_cmplt = '1') then
					AASM_next <= normal; 
				end if; 
			when others =>
				AASM_next <= normal; 
		 end case; 
	end process;
	
    process(clk, Rst)  begin
        if(Rst = '1') then
            areturn_flag <= '0';
			putfid_sic_flag <= '0';
			GC_StackCheck_flag <= '0';
			astore_stall_flag<='0';
			Alloc_en_r  <= '0';
			GC_arrayAlloc_en<= '0';
			clini_leave_count <=(others => '0');
			GC_Clinit_Stop_count <=(others => '0');
			GC_Clinit_Stop<= '0';
        elsif(rising_edge(clk)) then
			if( instrs_pkg(7 downto 0)=x"EB" or instrs_pkg(7 downto 0)=x"E9") then
				putfid_sic_flag<='1';
			else
				putfid_sic_flag<='0';
			end if;
			
			if(putfid_sic_flag = '1' and A(31 downto 26) = "010111") then
				GC_StackCheck_flag<='1';
			else
				GC_StackCheck_flag<='0';
			end if;	
			
			if(ireturn_flag='1' and A(31 downto 26) = "010111") then
				areturn_flag<='1';
			else
				areturn_flag<='0';
			end if;

			if(CTRL_state = ClinitRetFrm2) then
				GC_Clinit_Stop_count<=GC_Clinit_Stop_count+1;
			elsif(GC_Clinit_Stop_count>0 and  instrs_pkg(7 downto 0)=x"E2" and clini_leave_count="00000") then
				GC_Clinit_Stop_count<=GC_Clinit_Stop_count-1;				
			end if;	
			
			if(GC_Clinit_Stop_count>0 and (instrs_pkg =x"00ED" or instrs_pkg =x"00EF")) then
				clini_leave_count <= clini_leave_count+1;
			elsif(clini_leave_count>0 and Mthod_exit_flag='1')then	
				clini_leave_count <=clini_leave_count-1;
			end if;	
			
			if(GC_Clinit_Stop_count >0) then
				GC_Clinit_Stop<='1';
			else
				GC_Clinit_Stop<='0';
			end if;	
			
			if(instrs_pkg(7 downto 0)=x"E3" or instrs_pkg(7 downto 0)=x"E2" or CTRL_state =Native_exit) then
				Mthod_exit_flag<='1';
			else
				Mthod_exit_flag<='0';
			end if;		

			if(Mthod_exit_flag='1') then
				Mthod_exit_flag_2cy<='1';
			else
				Mthod_exit_flag_2cy<='0';
			end if;	
			
			
		
			
			if(instrs_pkg(7 downto 0)=x"FC") then
				Mthod_enter_flag<='1';
			else
				Mthod_enter_flag<='0';
			end if;	
			
			
			if(instrs_pkg(7 downto 0)=x"FB" or CTRL_state = ClinitRetFrm2) then
				Mthod_enter_flag_f<='1';
			else
				Mthod_enter_flag_f<='0';
			end if;	
			
			
			
			if(Mthod_enter_flag='1') then
				Mthod_enter_flag_2cy<='1';
			else
				Mthod_enter_flag_2cy<='0';
			end if;		

			if(Mthod_enter_flag_f='1') then
				Mthod_enter_flag_f_2cy<='1';
			else
				Mthod_enter_flag_f_2cy<='0';
			end if;				
			
			
			if(newarray_flag = '1' and AASM=wrArr2Hp) then
				GC_arrayAlloc_en<='1';
			else
				GC_arrayAlloc_en<='0';
			end if;		
			
			if(GC_Cmplt_in ='1') then
				astore_stall_flag<='0';
			elsif(instrs_pkg(7 downto 0)=x"D5")then
				astore_stall_flag<='1';
			end if;			

			if(GC_arrayAlloc_en='1') then
				GC_arrayAlloc_en_2cy<='1';
			else
				GC_arrayAlloc_en_2cy<='0';
			end if;	
		
			
			if(instrs_pkg=x"34DF") then
				anewarray_flag2GC<='1';
			else
				anewarray_flag2GC<='0';
			end if;	
			
			
			Alloc_en_r <=Alloc_en_w;
			
					
        end if;
    end process;	

	 GC_areturn_flag_out <=areturn_flag;
	 Mthod_exit_flag_out     <=Mthod_exit_flag    and not Mthod_exit_flag_2cy;
	 Mthod_enter_flag_out    <=Mthod_enter_flag   and not Mthod_enter_flag_2cy;
     Mthod_enter_flag_f_out  <=Mthod_enter_flag_f and not Mthod_enter_flag_f_2cy;	
	 GC_arrayAlloc_en_out    <=GC_arrayAlloc_en   and not GC_arrayAlloc_en_2cy; 	
	
	newarrayStoreReq <= '1' when(AASM = wrIDReq or AASM = wrLenReq) else
					'0';
	 
        
    -- modified by T.H. Wu , 2013.8.1
	 -- modified by fox , for each thread terminated
	 -- modified by T.H.Wu , for new thread command in multi-core coordinator
	process(return_flag,A,TH_mgt_thread_number(4 downto 1), return_mask,act_dly2,set_act_reg ) begin  --return_mask
		set_act_w <= set_act_reg;
        if(return_flag = '1' and A = X"12345678" and return_mask = '0') then
        --if(return_flag = '1' and vp = "0000000000" and return_mask = '0') then
			--if(TH_mgt_thread_number = x"1") then -- modified by T.H.Wu , 2013.9.5
			if(TH_mgt_thread_number (4 downto 1) = "0000" ) then 
                set_act_w               <= act_dly2;
				TH_mgt_thread_dead		<= '1';
			else
                set_act_w               <= '0';
				TH_mgt_thread_dead		<= '1';
			end if;
		else
            set_act_w           <= '0';
			TH_mgt_thread_dead	<= '0';
		end if;
    end process;
		 
	the_core_act	<= act_dly2;
    TOS_A     <= A;
    TOS_B     <= B;
    TOS_C     <= C;

    write_ABC.Aen          <= '1' when	(ex2java_addr = "00000000000010" and ex2java_wen = '1') or
                                        (CTRL_state = Field_load and Runnable_access_cmplt = '1') or
										(CTRL_state = HeapAlloc and Runnable_access_cmplt = '1') or
										-- modified since 2014.1.22, for invoking sync method
										(invoke_sync_mthd_flag_dly = '1')
						else  '0';
    write_ABC.Ben          <= '1' when (ex2java_addr = "00000000000011" and ex2java_wen = '1') or
                                                        ((Runnable_access_cmplt and refload_req) = '1') else -- fox
					  '1' when (arrayAlloc_en = '1') else
                                            '0';
    write_ABC.Cen          <= '1' when ex2java_addr = "00000000000100" and ex2java_wen = '1' else '0'; 
    external_load_data_s   <= external_load_data(15 downto  0) when array_s_access_addr(1) = '1' else
                                                    external_load_data(31 downto 16);
                              
    external_load_data_b   <=  external_load_data( 7 downto  0) when array_b_access_addr(1 downto 0) = "11" else
                                                    external_load_data(15 downto  8) when array_b_access_addr(1 downto 0) = "10" else 
                                                    external_load_data(23 downto 16) when array_b_access_addr(1 downto 0) = "01" else
                                                    external_load_data(31 downto 24);
    
    write_ABC.data         <=		current_heap_ptr		when (CTRL_state = HeapAlloc and Runnable_access_cmplt = '1') 
							else	current_heap_ptr + 8	when (arrayAlloc_en = '1') 
							else	external_load_data		when refAcs_sel = "00" or CTRL_state = Field_load
								-- modified since 2014.1.15, for invoking sync method
								-- [note] store sync bit to return frame of every single sync method
							else	A_dly(31 downto 11) & '1' & A_dly(9 downto 0)	when (invoke_sync_mthd_flag_dly = '1') 
                            else	x"000000" & external_load_data_b	when refAcs_sel = "10" 
							else	x"0000" &  external_load_data_s		when refAcs_sel = "01"
							else	ex2java_data ;
                              
        DR_reg_en              <= '1' when ex2java_addr = "00000000000111" and ex2java_wen = '1' else '0';
     --ClsProfileTable_Wen    <= '1' when ex2java_addr = "00001100" and ex2java_wen = '1' else '0';
	CSTProfileTable_Wen    <= '1' when ex2java_addr = "00000000001100" and ex2java_wen = '1' else '0';
	MthdProfileTable_wen   <= '1' when ex2java_addr = "00000000001101" and ex2java_wen = '1' else '0';
        interrupt_cmplt             <= '1' when ex2java_addr = "00000000011011" and ex2java_wen = '1' else '0'; 
        -- add for thread management , 2013.7.8
        TH_mgt_SetTimeSlices_Wen_w  <= ex2java_wen when ex2java_addr = "00000000100000" else '0';
	
	prsr2ER_LUT_wen        <= '1' when ex2java_addr = "00000000011100" and ex2java_wen = '1' else '0';
	prsr2ER_LUT_addr       <= ex2java_data(25 downto 16);
	prsr2ER_LUT_di         <= ex2java_data(15 downto  0);

    field_access_addr      <= DynamicResolution                         when static_flag = '1' else
                              A_dly + (DynamicResolution(11 downto 0)&"00") when CTRL_state = Field_load else
                              B_dly + (DynamicResolution(11 downto 0)&"00");

    array_w_access_addr    <= (B(29 downto 0) & "00") + C when Runnable_store_req = '1' else -- by fox
                              (A(29 downto 0) & "00") + B;
                              
    array_s_access_addr    <= (B(30 downto 0) & '0') + C when Runnable_store_req = '1' else-- by fox
                              (A(30 downto 0) & '0') + B;
                              
    array_b_access_addr    <= B + C when Runnable_store_req = '1' else -- by fox
                              A + B;
                              
    array_access_addr      <= current_heap_ptr + 4 when (AASM = wrLen or AASM = wrLenReq) else
                                                current_heap_ptr when (AASM = wrID or AASM = wrIDReq ) else
                                                array_w_access_addr when refAcs_sel = "00" else
                                                array_s_access_addr when refAcs_sel = "01" else
                                                --array_b_access_addr when refAcs_sel = "10";
                                                array_b_access_addr ;
                                                -- the latch will affect system ?? modified for test , by T.H.Wu , 2013.7.24

    external_access_addr     <= external_access_addr_tmp when token_tmp = '0' else  -- by fox
								( STACK_AREA_DDR_ADDRESS & core_id_reg & stackMgt2DDR_addr);
    external_access_addr_tmp <=  
								A   when   external_load_EID_req = '1' else -- load obj class ID
								MA_base_mem_addr + "0100" when external_load_LVcnt_req = '1' else -- load LV cnt
                                -- modified  address from CST/MA controller , for loading current method , by T.H.Wu , 2013.7.24 
								--CSTLoading_ex_addr        when  CSTLoading_req = '1'         else
								--MthdLoading_ex_addr       when MthdLoading_req = '1'       else
								CSTLoading_ex_addr        when  CSTLoading_stall_dly = '1'         else
								MthdLoading_ex_addr       when MthdLoading_stall_dly = '1'       else
                                DR_addr                   when CTRL_state = Get_ObjClsID  or
                                                               CTRL_state = Offset_access  or
                                                               CTRL_state = invoke_objref_ListClsID or
                                                               --CTRL_state = invoke_objref_next or
																CTRL_state = Get_ArgSize      else
                                field_access_addr         when CTRL_state = Field_load or
                                                               CTRL_state = Field_store      else
								current_heap_ptr		  when CTRL_state = HeapAlloc		 else
                                array_access_addr ;

     --- ********************************************************************************
    -- by fox  --  a token which may switch the bus lock between runnable thread and stack management
    -- if they required the lock simultaneously 
    -- 2013.7.15 , one bug , load request / store request may be active simultaneously  
    -- ex. runnable thread wanna load method image and stack management wanna store its previous stack back to DDR memory
    external_load_req_tmp  <= (not token_tmp and Runnable_load_req) or (token_tmp and prepare_stack_load_req);
    --external_load_req_tmp  <= Runnable_load_req or prepare_stack_load_req;
    Runnable_load_req           <= refload_req  or DynamicResolution_load_req or CSTLoading_req or MthdLoading_req or 
                                                    external_load_EID_req or external_load_LVcnt_req;--or ClsLoading_req;
    external_store_req_tmp <= (not token_tmp and Runnable_store_req) or (token_tmp and backup_stack_store_req ); 
   -- external_store_req_tmp <= Runnable_store_req or backup_stack_store_req ; 
   -- modified by T.H.Wu 2013.9.7
    Runnable_store_req          <= refstore_req or	DynamicResolution_store_req or newarrayStoreReq;
    
	Runnable_access_ack		<= external_MstRd_CmdAck 	and not token ;
	Runnable_access_cmplt	<= external_access_cmplt 	and not token ;
	StackSpace_access_ack	<= external_MstRd_CmdAck 	and token ;
	StackSpace_access_cmplt	<= external_access_cmplt 	and token ;
	 Runnable_MstRd_burst_data_rdy <= external_MstRd_burst_data_rdy when token ='0' else '1' ;
	 Runnable_MstWr_burst_data_rdy <= external_MstWr_burst_data_rdy when token ='0' else '1' ;
	 StackSpace_MstRd_burst_data_rdy <= external_MstRd_burst_data_rdy when token = '1' else '1';
	 StackSpace_MstWr_burst_data_rdy <= external_MstWr_burst_data_rdy when token = '1' else '1';
        
        -- it will enter the state controller of stack management
        -- added by fox , modified by T.H.Wu , 2013.8.19 , stack management / method area controller
        -- will be halt forever by executing one case, 
        -- it's better to use token_tmp than token
        bus_occupied_by_run_thread <= (not token) and (Runnable_load_req or Runnable_store_req);
        
        -- external_access_busy	<= external_load_req_reg or external_store_req_reg; -- origin by fox
        -- modified by T.H.Wu , for fixing token bug between stack management and MA controller / CST controller , 2013.7.24
        -- modified by T.H.Wu , for fixing token bug between stack management and newarray stack controller , 2013.7.26
        --external_access_busy	<= external_load_req_reg or external_store_req_reg 
        --                                          or  (CSTLoading_stall_dly or MthdLoading_stall_dly ) or (bus_occupied_by_AASM); 
        external_access_busy	<= external_load_req_reg or external_store_req_reg  or  
                                                            (not token and (CSTLoading_stall_dly or MthdLoading_stall_dly or bus_occupied_by_AASM)) ; 
        
        -- added by fox , modified by T.H.Wu , 2013.7.15
        --I guess there's one issue about the"token"
	process(external_access_busy,Runnable_load_req,Runnable_store_req,prepare_stack_load_req,
                        backup_stack_store_req, token, token_rw
        ) begin
		token_tmp		<= token;
		token_rw_tmp	<= token_rw;
		if(external_access_busy = '0') then 
			if(Runnable_load_req = '1')then
				token_tmp		<= '0';
				token_rw_tmp	<= '0';
			elsif(Runnable_store_req = '1') then
				token_tmp		<= '0';
				token_rw_tmp	<= '1';
			elsif(prepare_stack_load_req = '1') then
				token_tmp		<= '1';
				token_rw_tmp	<= '0';
			elsif(backup_stack_store_req = '1' ) then
				token_tmp		<= '1';
				token_rw_tmp	<= '1';
			--else 
				--token_tmp		<= '0';
				--token_rw_tmp	<= '0';
			end if; 
		end if;
	end process;
     --- ********************************************************************************

    IP2Bus_Mst_BE_b        <= x"1" when array_b_access_addr(1 downto 0) = "11" else
                              x"2" when array_b_access_addr(1 downto 0) = "10" else
                              x"4" when array_b_access_addr(1 downto 0) = "01" else
                              x"8";
    
    IP2Bus_Mst_BE_s        <= x"3" when array_s_access_addr(1) = '1' else
                              x"C";
                              
    IP2Bus_Mst_BE          <= IP2Bus_Mst_BE_b when refAcs_sel = "10" else
                              IP2Bus_Mst_BE_s when refAcs_sel = "01" else
                              x"F";
        -- added by T.H.Wu , 2013.8.7 , for changing bus transfer mode in pipeline
        -- It might be a problem when exception handler and stack management acquire bus request concurrently.
        -- xcptn_stall = '1' 
        jpl_mst_transfer_Type  <=  CSTLoading_stall_dly or MthdLoading_stall_dly or  
									(token_tmp and prepare_stack_load_req) or
									(token_tmp and backup_stack_store_req);
        
  -- by fox
    external_store_data		<= external_store_data_tmp when token_tmp = '0' else  stack_backup_data;
   -- modified by T.H.Wu , 2013.7.12 , we may delay one clock to switch the data
   -- modified by T.H.Wu , 2013.8.1  , for solving store request by stack management and array in heapp cache
   --                                                   , a better way is needed
    --external_store_data		<= external_store_data_tmp when token = '0' else  stack_backup_data;
                              
    external_store_data_tmp   <=  A(7 downto 0) & A(7 downto 0) & A(7 downto 0) & A(7 downto 0) when refAcs_sel = "10" else
								  A(15 downto 0) & A(15 downto 0)                               when refAcs_sel = "01" else
								  x"00000" & "0" & clsiAddr_tmp(11 downto 1)	when (CTRL_state = HeapAlloc) else -- new instance
								  (X"0000" & arrayLength(15 downto 0))			when (AASM = wrLenReq or AASM = wrLen) else
								  (arrayTag & x"000000")	 					when (AASM = wrIDReq or AASM = wrID) else
								  A;										 	-- refAcs_sel = "11"
        
   -- MethodArea_Wen  <=  MainClsLoading_Wen or ClsLoading_Wen ;

	DR2CST_ctrlr_cls_id <= clinitClsID when(clinitEN = '1') else
						   DynamicResolution(31 downto 16); 
	DR2MA_mgt_mthd_id   <= clinitMthdID when(clinitEN = '1') else
						   DynamicResolution(15 downto  0); 
 
    
   	CST_buffer_addr    <=  CST_ctrlr2buffer_addr when CST_ctrlr2buffer_wen = '1' else
                                                        search_ptr(11 downto 0) ;
					   
	CST_buffer_wen     <= CST_ctrlr2buffer_wen ;
	CST_buffer_wr_data <=  -- CST_ctrlt2buffer_data; -- modified by T.H. Wu , 2013.6.20 
                           external_loaded_buffer;
    
    MethodArea_addr <=  Mgt2MA_addr    when Mgt2MA_wen     = '1'      else 
                                        jpc(11 downto 0);   
					   
	MethodArea_Wen  <= Mgt2MA_wen ;
	 
    MethodArea_data <=  external_loaded_buffer;    -- Mgt2MA_data;
     
    --- ISR from decode stage , JUST for multinewarray , 2013.7.12
    interrupt_req_tmp <= interrupt_req_decode or interrupt_req_DR or interrupt_req_xcptn; 
    interrupt_func    <= interrupt_func_xcptn  when interrupt_req_xcptn = '1' else
                                        interrupt_func_decode when CTRL_state = Normal       else
                                        interrupt_func_DR;
    
     
    
    -- all control registers in soj will be gathered HERE , 2013.7.8
    process(clk)  begin
        if(rising_edge(clk)) then
            
            if(Rst = '1') then
				TH_mgt_thread_dead_reg <= '0';
				act_dly <= '0';
				set_act_reg <= '0';
				JAIP2COOR_cmd_reg <= "000"; 
				JAIP2COOR_cmd_newTH_req <= '0';
				JAIP2COOR_info1_reg	<= (others=>'0'); 
				JAIP2COOR_info2_reg	<= (others=>'0');
				sync_mthd_invoke_rtn_cmplt	<=	'0';
				COOR_res_msg_hold	<= ("111"&"111"&"00"& x"00");
				COOR_res_msg_we_hold <= '0';
				JAIP2COOR_pending_resMsgSent_reg	<=	'0';
				COOR_cmd_cmplt_reg	<=	'0';
				newTH_sender_is_the_core	<=	'0';
				newTH_receive_is_not_the_core <= '0';
				newTH_from_TH_mgt_cmplt		<= '0';
				native_HW_newTH_cmplt <= '0';
				now_thread_monitorenter_succeed	<=	'0';
				now_thread_monitorenter_fail	<=	'0'; 
				soj_now_TH_monitorenter_fail_hold	<=	'0';
				monitorexit_sender_is_the_core	<=	'0';
				monitorexit_receiver_is_the_core<=	'0';
				monitorexit_lockfree			<=	'0';
				monitorexit_nextowner_here		<=	'0';
				monitorexit_nextowner_thread_slot_idx	<=	(others=>'0');
				monitorenter_cmplt_from_TH_mgt	<=	'0';
				monitorexit_cmplt_from_TH_mgt	<=	'0';
				JAIP2COOR_cmd_monitor_stall_reg	<=	'0'; 
			else
				if(TH_mgt_thread_dead='1') then
					TH_mgt_thread_dead_reg <= '1';
                elsif (TH_mgt_runnable_thread_backup_flag='1') then
					TH_mgt_thread_dead_reg <= '0';
				end if; 
				-- --
				act_dly <= act_w;
				set_act_reg <= set_act_w;
				--- added by T.H.Wu , 2013.9.7
				JAIP2COOR_cmd_reg <= JAIP2COOR_cmd_reg_w; 
				JAIP2COOR_cmd_newTH_req <= JAIP2COOR_cmd_newTH_req_w;
				JAIP2COOR_info1_reg	<=	JAIP2COOR_info1_reg_w; 
				JAIP2COOR_info2_reg	<=	JAIP2COOR_info2_reg_w;
				sync_mthd_invoke_rtn_cmplt	<=	sync_mthd_invoke_rtn_cmplt_w;
				COOR_res_msg_hold	<=	COOR_res_msg_hold_w;
				COOR_res_msg_we_hold<=	COOR_res_msg_we_hold_w;
				JAIP2COOR_pending_resMsgSent_reg	<=	JAIP2COOR_pending_resMsgSent_reg_w;
				COOR_cmd_cmplt_reg	<=	COOR_cmd_cmplt_reg_w;
				newTH_sender_is_the_core <= newTH_sender_is_the_core_w;
				newTH_receive_is_not_the_core <= newTH_receive_is_not_the_core_w;
				newTH_from_TH_mgt_cmplt <= newTH_from_TH_mgt_cmplt_w;
				native_HW_newTH_cmplt <= native_HW_newTH_cmplt_w;
				now_thread_monitorenter_succeed	<=	now_thread_monitorenter_succeed_w;
				now_thread_monitorenter_fail	<=	now_thread_monitorenter_fail_w;
				soj_now_TH_monitorenter_fail_hold	<=	soj_now_TH_monitorenter_fail_hold_w;
				monitorexit_sender_is_the_core	<=	monitorexit_sender_is_the_core_w;
				monitorexit_receiver_is_the_core<=	monitorexit_receiver_is_the_core_w;
				monitorexit_lockfree			<=	monitorexit_lockfree_w;
				monitorexit_nextowner_here		<=	monitorexit_nextowner_here_w;
				monitorexit_nextowner_thread_slot_idx	<=	monitorexit_nextowner_thread_slot_idx_w;
				monitorenter_cmplt_from_TH_mgt	<=	monitorenter_cmplt_from_TH_mgt_w;
				monitorexit_cmplt_from_TH_mgt	<=	monitorexit_cmplt_from_TH_mgt_w;
				JAIP2COOR_cmd_monitor_stall_reg	<=	JAIP2COOR_cmd_monitor_stall_reg_w; 
            end if;	
			----
			 
			-- modified by T.H.Wu , 2013.9.8
            act_dly2 <= act_dly;
			core_id_reg <= core_id;
			A_dly	<=	A;
			B_dly	<=	B;
			C_dly	<=	C;
			native_HW_en_tmp_dly	<=	native_HW_en_tmp;
			native_HW_ID_w_dly		<=	native_HW_ID_w;
			Runnable_access_cmplt_dly <= Runnable_access_cmplt; 
            return_mask <= return_flag;
			invoke_sync_mthd_flag_dly	<=	invoke_sync_mthd_flag;
            -- modified by T.H.Wu , 2013.8.19
             -- modified for thread management, 2013.7.18
             TH_state_dly <= TH_state_dly_w;
             TH_mgt_SetTimeSlices_Wen  <= TH_mgt_SetTimeSlices_Wen_w;  
             TH_new_thread_flag <= TH_new_thread_flag_w;
			 Thread_start_cmplt_flag_dly <= Thread_start_cmplt_flag;
             TH_data_in_transfer_cnt_dly    <=  TH_data_in_transfer_cnt;
             TH_data_out_transfer_cnt_dly <= TH_data_out_transfer_cnt_dly_w;
             TH_data_out_dly <= TH_data_out_dly_w;
             TH_mgt_runnable_thread_backup_flag <= TH_mgt_runnable_thread_backup_flag_w;
             TH_trigger_MA_ctrl_en_dly <= TH_trigger_MA_ctrl_en;
			 JAIP2COOR_cmd_monitor_enter_req_dly	<=	JAIP2COOR_cmd_monitor_enter_req;
			 JAIP2COOR_cmd_monitor_exit_req_dly		<=	JAIP2COOR_cmd_monitor_exit_req;
			 now_thread_monitorenter_fail_dly		<=	now_thread_monitorenter_fail;
             -- added for fixing the bug associated with token and MA controller / CST controller , 2013.7.24
             CSTLoading_stall_dly   <= CSTLoading_stall;
             MthdLoading_stall_dly <= MthdLoading_stall;  
			 --
			 
             -- add for thread management,2013.7.8
			 -- note by T.H.Wu, there's a problem here, creating new thread (TH_new_thread_flag) could be overlapped with previous thread back-up
			 -- (TH_state_dly=Backup_previous_thread_TCBinfo), we have to try to add one state in Thread state controller in order to
			 -- make each update correct..... 2014.3.6
             if(TH_mgt_SetTimeSlices_Wen_w='1') then
                    TH_data_in <= ex2java_data;
             elsif(TH_new_thread_flag='1') then 
                    case TH_data_in_transfer_cnt is
                        when x"2" =>        TH_data_in <= COOR_info1_bak; 
                        when x"5" =>        TH_data_in <= X"12345678";
                        when x"6" =>        TH_data_in <= X"22000000"; 
                        when x"8" =>        TH_data_in <= COOR_info2_bak;
                        when others =>      TH_data_in <=  X"00000000"; -- x"3" or x"4"
                    end case; 
             else -- if TH_state_dly=Backup_previous_thread_TCBinfo .... for this case , 2013.7.18
                    case TH_data_in_transfer_cnt is
                        when x"2" =>        TH_data_in <= TH_prev_thread_cls_id & TH_prev_thread_mthd_id;
                        when x"3" =>        TH_data_in <= "000000" & TH_prev_thread_vp & "000000" & TH_prev_thread_sp;
                        when x"4" =>        TH_data_in <= x"000" & TH_prev_thread_reg_valid & TH_prev_thread_jpc ;
                        when x"5" =>        TH_data_in <= TH_prev_thread_A;
                        when x"6" =>        TH_data_in <= TH_prev_thread_B;
                        when x"7" =>        TH_data_in <= TH_prev_thread_C;
                        when others =>      TH_data_in <= (others=>'0');
                    end case; 
             end if;
             -- modified by T.H.Wu , 2013.8.1 
			 if(TH_data_out_transfer_cnt_dly=x"1") then -- for other threads invoking run method at beginning 
                TH_mgt_ready_thread_cls_id_mthd_id <= TH_data_out_dly;
             end if;
             -- modified by T.H.Wu , 2013.7.18
             if(TH_data_out_transfer_cnt_dly=x"3") then
                    TH_mgt_thread_jpc <= TH_data_out_dly (15 downto 0) ;
              end if;
             -- modified by T.H.Wu , 2013.7.18 , backup previous thread , regardless if the thread terminates 
              if( TH_mgt_runnable_thread_backup_flag_w ='1' and TH_mgt_runnable_thread_backup_flag='0') then
                 TH_prev_thread_cls_id      <= cls_id;
                 TH_prev_thread_mthd_id     <= now_mthd_id;
                 TH_prev_thread_vp               <= vp;
                 TH_prev_thread_sp               <= sp;
                 TH_prev_thread_reg_valid <= reg_valid;
                 TH_prev_thread_jpc            <= TH_mgt_thread_trigger;
                 TH_prev_thread_A               <= A;
                 TH_prev_thread_B               <= B;
                 TH_prev_thread_C               <= C;
              end if;
             --
             --
             if(Rst = '1') then
                    execute_push <= '0';
                    TH_data_in_transfer_cnt <= (others=>'0'); 
                     -- token               <= '1'; -- by fox , default is 1
                    token	  				<= '0'; -- 0=runnable thread , 1=stack management
                    token_rw				<= '0'; -- 0=read , 1=write
             else
                    execute_push <= decode_push;
                    TH_data_in_transfer_cnt <= TH_data_in_transfer_cnt_w;
                    if(external_access_busy = '0') then
						token		<= token_tmp;
						token_rw	<= token_rw_tmp;
                    end if;
             end if; 
            --  
			-- origin by fox , modified by T.H.Wu , 2013.7.17
		-- for another stack in execution stage backup/restore use , 2013.7.12
		-- 2013.7.12 , how to examine if the read/write operations are from stack management ? 
		if(
			(external_load_req_tmp='1' and external_load_req_reg='0') or
			(external_store_req_tmp='1' and external_store_req_reg='0')
		) then
			stack_mgt_transfer_counter_reg <= (others => '0');
		elsif(StackSpace_MstWr_burst_data_rdy = '0' or StackSpace_MstRd_burst_data_rdy='0') then
			stack_mgt_transfer_counter_reg <= stack_mgt_transfer_counter_reg + "01";		
		end if;
            -- 
        end if;
    end process; 
    
    ---- modified the backup of thread control block by T.H. Wu , 2013.7.9
	-- modified for communicating with multi-core coordinator.
    process(
		TH_new_thread_flag, TH_data_in_transfer_cnt, native_HW_ID_w_dly, native_HW_en_tmp_dly,
		act_dly, JAIP2COOR_cmd_newTH_req, JAIP2COOR_info1_reg, newTH_sender_is_the_core,
		JAIP2COOR_info2_reg, newTH_from_TH_mgt_cmplt, native_HW_newTH_cmplt, TH_state_dly_w,
		core_id_reg, DynamicResolution, invoke_objref_reg_2_TH_mgt, monitorenter_cmplt, TH_state_dly,
		JAIP2COOR_cmd_monitor_enter_req_dly, JAIP2COOR_cmd_monitor_exit_req_dly, A_dly, COOR_res_msg_bak,
		COOR_cmd_cmplt_reg, Thread_start_cmplt_flag, set_act_reg, COOR_res_msg_we_hold, JAIP2COOR_cmd_reg,
		COOR_res_msg_we_sync, COOR_res_msg_hold, TH_mgt_thread_number, monitorexit_receiver_is_the_core,
		monitorexit_sender_is_the_core, monitorexit_lockfree, monitorexit_nextowner_here, monitorexit_cmplt,
		monitorexit_nextowner_thread_slot_idx, monitorenter_cmplt_from_TH_mgt, monitorexit_cmplt_from_TH_mgt,
		JAIP2COOR_cmd_monitor_stall_reg, JAIP2COOR_cmd_monitor_enter_req, JAIP2COOR_cmd_monitor_exit_req,
		now_thread_monitorenter_succeed, now_thread_monitorenter_fail, COOR_res_msg_sync, current_run_thread_slot_idx,
		newTH_receive_is_not_the_core, Thread_start_cmplt_flag_dly, now_thread_monitorenter_fail_dly,
		TH_data_out_transfer_cnt_dly_w, soj_now_TH_monitorenter_fail_hold, sync_mthd_invoke_rtn_cmplt,
		block_COOR_msg_we_before_16clk_now_TH_timeout_w, JAIP2COOR_pending_resMsgSent_reg,
		now_TH_start_exec_over_28clk
	)  begin
        act_w <= act_dly;
		TH_new_thread_flag_w <= TH_new_thread_flag;
		JAIP2COOR_cmd_newTH_req_w <= JAIP2COOR_cmd_newTH_req;
		JAIP2COOR_cmd_reg_w	<=	JAIP2COOR_cmd_reg;
		JAIP2COOR_info1_reg_w <= JAIP2COOR_info1_reg;
		JAIP2COOR_info2_reg_w <= JAIP2COOR_info2_reg;
		COOR_res_msg_we_hold_w<= COOR_res_msg_we_hold;
		COOR_res_msg_hold_w <= COOR_res_msg_hold;
		JAIP2COOR_pending_resMsgSent_reg_w	<=	JAIP2COOR_pending_resMsgSent_reg;
		sync_mthd_invoke_rtn_cmplt_w <= sync_mthd_invoke_rtn_cmplt;
		newTH_sender_is_the_core_w	<=	newTH_sender_is_the_core;
		newTH_receive_is_not_the_core_w <= newTH_receive_is_not_the_core;
		newTH_from_TH_mgt_cmplt_w <= newTH_from_TH_mgt_cmplt;
		native_HW_newTH_cmplt_w <= native_HW_newTH_cmplt;
		now_thread_monitorenter_succeed_w <= now_thread_monitorenter_succeed;
		now_thread_monitorenter_fail_w <= now_thread_monitorenter_fail;
		soj_now_TH_monitorenter_fail_hold_w	<=	soj_now_TH_monitorenter_fail_hold;
		monitorexit_sender_is_the_core_w	<=	monitorexit_sender_is_the_core;
		monitorexit_receiver_is_the_core_w	<=	monitorexit_receiver_is_the_core;
		monitorexit_lockfree_w				<=	monitorexit_lockfree;
		monitorexit_nextowner_here_w		<=	monitorexit_nextowner_here;
		monitorexit_nextowner_thread_slot_idx_w	<=	monitorexit_nextowner_thread_slot_idx;
		monitorenter_cmplt_from_TH_mgt_w	<=	monitorenter_cmplt_from_TH_mgt;
		monitorexit_cmplt_from_TH_mgt_w		<=	monitorexit_cmplt_from_TH_mgt;
		JAIP2COOR_cmd_monitor_stall_reg_w	<=	JAIP2COOR_cmd_monitor_stall_reg; 
		
		----------------- JAIP core sends "new thread" command , start -----------------
		-- modified by T.H.Wu , 2014.2.11 
		-- when this JAIP core invokes Thread.start() , send bus request to multi-core coordinator
		if(native_HW_ID_w_dly = "01000" and native_HW_en_tmp_dly='1') then
			JAIP2COOR_cmd_newTH_req_w <= '1';
		else
			JAIP2COOR_cmd_newTH_req_w <= '0';
		end if;
		
		--
		if(JAIP2COOR_cmd_newTH_req='1') then -- send new thread command
			JAIP2COOR_info1_reg_w <= x"0" & DynamicResolution(28 downto 17)	& x"0" & DynamicResolution(11 downto 0) ; 
			JAIP2COOR_info2_reg_w <= invoke_objref_reg_2_TH_mgt;
		elsif (JAIP2COOR_cmd_monitor_enter_req_dly='1' or JAIP2COOR_cmd_monitor_exit_req_dly='1') then
		--elsif((JAIP2COOR_cmd_monitor_enter_req='1' or JAIP2COOR_cmd_monitor_exit_req='1') ) then
			JAIP2COOR_info1_reg_w <= A_dly; -- 2013.10.5 , the design synchronized method has been pending. 
			JAIP2COOR_info2_reg_w <= x"0000000" & current_run_thread_slot_idx;
		-- modified by T.H.Wu , 2013.10.30, if the last ready thread fails to acquire lock after monitorenter.
		elsif(COOR_cmd_cmplt_reg='1' or now_thread_monitorenter_fail='1') then
			-- modified by T.H.Wu , 2013.10.21, debug for cache coherence module.
			JAIP2COOR_info1_reg_w <= x"00000000"; 
			JAIP2COOR_info2_reg_w <= x"00000000"; 
		end if;
		--
		-- modified by T.H.Wu, 2014.2.11, for optimizing coordinator
		-- when each JAIP core sends a command to multi-core coordinator in a hard-wired way
		if (JAIP2COOR_cmd_monitor_enter_req_dly='1') then -- monitorenter 
			JAIP2COOR_cmd_reg_w	<=	"001";
		elsif (JAIP2COOR_cmd_monitor_exit_req_dly='1') then -- monitorexit 
			JAIP2COOR_cmd_reg_w	<=	"010";
		elsif (JAIP2COOR_cmd_newTH_req='1') then -- new thread
			JAIP2COOR_cmd_reg_w	<=	"011";
		elsif (COOR_res_msg_bak(9 downto 6)/="0000" and COOR_res_msg_bak(12 downto 10)=("0"&core_id_reg) ) then 
			-- previous command done, fix a problem under multi-core case, we must recognize the sender
			JAIP2COOR_cmd_reg_w	<=	"000";
		end if;
        
		----------------- JAIP core sends "new thread" command , end -----------------
		
		----------------- JAIP core receives response message of "new thread" command , start -----------------
		-- response message (from multi-core coordinator)
		if(
			COOR_res_msg_bak(9 downto 6)/="0000" and
			(COOR_res_msg_bak(15 downto 13)=("0"&core_id_reg) or COOR_res_msg_bak(12 downto 10)=("0"&core_id_reg)) 
		) then -- there's any response message to this core. 
			COOR_res_msg_we_hold_w<= '1';
			COOR_res_msg_hold_w <= COOR_res_msg_bak;
		elsif(COOR_res_msg_we_sync='1') then
			COOR_res_msg_we_hold_w<= '0';
		end if;
		---
		if(COOR_res_msg_we_sync='1') then
			COOR_res_msg_sync <= COOR_res_msg_hold;
		else
			COOR_res_msg_sync <= ("111"&"111"&"00"& x"00");
		end if;
		-- read response message from multi-core coordinator  
		-- note by T.H.Wu , 2013.9.8  
		-- response message , new thread, -- check new thread is assigned to itself ?
		-- 
		-- added for monitorenter / moniterexit in java language. by T.H.Wu , 2013.10.5
		--	the format
		--	[15:13] : the core ID of receiver
		--	[12:10] : the core ID of sender
		--	[9:6] : response message
		--	[5:0] : reserved
		--		if [9:6]=0100, succeed to moniterenter, [5:0] will be useless.
		--		if [9:6]=0101, fail to moniterenter, [5:0] will be currently run thread ID of this core. 
		--		if [9:6]=0110, the other thread from other cores , or currently run thread in this core
		--						executes moniterexit, and multi-core coordinator evaluated and discovered
		--						that the next owner of the specific object lock is sent to some
		--						specific thread in this core. 
		--		if [9:6]=0111, the other thread from other cores , or currently run thread in this core
		--						executes moniterexit, and multi-core coordinator evaluated and discovered
		--						that no any thread is still waiting for the specific object lock. 
		--						[2013.10.8 by T.H.Wu]
		--						Another situation using this response : 
		--						the current owner lock the specific object more than twice, so when the owner (thread)
		--						executes monitorexit, it will affect anything on each JAIP core.
		case (COOR_res_msg_sync(9 downto 7)) is
			when "001" =>
				if( COOR_res_msg_sync(15 downto 13)=("0"&core_id_reg) ) then 
					TH_new_thread_flag_w <= '1' ;  
				end if;
				if(("0"&core_id_reg)=COOR_res_msg_sync(12 downto 10)) then
					newTH_sender_is_the_core_w <= '1' ;
				end if; 
				if(("0"&core_id_reg)/=COOR_res_msg_sync(15 downto 13)) then
					newTH_receive_is_not_the_core_w <= '1';
				end if; 
			when "010" =>
				now_thread_monitorenter_succeed_w	<=	not COOR_res_msg_sync(6);
				now_thread_monitorenter_fail_w		<=		COOR_res_msg_sync(6); 
				soj_now_TH_monitorenter_fail_hold_w	<=		COOR_res_msg_sync(6); 
			when "011" => 
				-- check next owner of the lock
				if(COOR_res_msg_sync(15 downto 13)=("0"&core_id_reg)) then
					if( COOR_res_msg_sync(6)='1' ) then
						monitorexit_lockfree_w <= '1';
					else
						monitorexit_nextowner_here_w <= '1';
						monitorexit_nextowner_thread_slot_idx_w <= COOR_res_msg_sync(3 downto 0); 
						-- recheck if current thread wait for some object lock previously
						-- but last owner release lock soon, and next owner is current thread immediately.
						if( COOR_res_msg_sync(3 downto 0)=current_run_thread_slot_idx ) then
							now_thread_monitorenter_succeed_w	<=	'1';
							--now_thread_monitorenter_fail_w		<=	'0';
						end if; 
					end if;
				end if;
				-- check if the core is the sender of monitorexit throughout
				if(("0"&core_id_reg)=COOR_res_msg_sync(12 downto 10)) then
					monitorexit_sender_is_the_core_w <= '1' ;
				end if;
				if(("0"&core_id_reg)=COOR_res_msg_sync(15 downto 13)) then
					monitorexit_receiver_is_the_core_w <= '1' ;
				end if;
			when others =>
				--if (TH_data_in_transfer_cnt_dly>=x"9") then -- modified by T.H.Wu , 2013.11.19, mismatch ?
				if (TH_data_in_transfer_cnt>=x"9") then
					TH_new_thread_flag_w <= '0'; 
				end if;
				if(COOR_cmd_cmplt_reg='1') then
					newTH_sender_is_the_core_w			<=	'0';
					monitorexit_sender_is_the_core_w	<=	'0';
				end if;
				if(COOR_cmd_cmplt_reg='1' or monitorexit_sender_is_the_core='0') then
					monitorexit_receiver_is_the_core_w	<=	'0';
				end if;
				-- 2014.1.9, fix the bug for a thread if it acquires monitor (monitorenter) so many times during one time slicing
				if(TH_state_dly_w=Check_Timeout or now_thread_monitorenter_succeed='1') then
					soj_now_TH_monitorenter_fail_hold_w <= '0';
				end if;
				newTH_receive_is_not_the_core_w		<=	'0';
				now_thread_monitorenter_succeed_w	<=	'0';
				now_thread_monitorenter_fail_w		<=	'0';
				monitorexit_nextowner_here_w		<=	'0';
				monitorexit_lockfree_w				<=	'0';
		end case;
		-- modified by T.H.Wu, 2014.2.10, fix a problem of sync method under multi-core JAIP environment.
		-- we just check whether the sender is this core.
		if (COOR_res_msg_sync(12 downto 10)=("0"& core_id_reg)) then
			sync_mthd_invoke_rtn_cmplt_w	<=	'1' ;
		else
			sync_mthd_invoke_rtn_cmplt_w	<=	'0';
		end if;
		
		-- generate complete signal while thread management finish creating a new thread
		-- if this core is not receiver of response message , then we don't need to wait for Thread_start_cmplt_flag 
		-- modified by T.H.Wu , 2013.10.16
		-- [note] A in A out , A in B out,
		if(newTH_sender_is_the_core='1') then
			if (
				Thread_start_cmplt_flag='1' or newTH_receive_is_not_the_core='1' 
			) then
				newTH_from_TH_mgt_cmplt_w <= '1';
			elsif(COOR_cmd_cmplt_reg='1')then
				newTH_from_TH_mgt_cmplt_w <= '0';
			end if;
		end if;
		-- signal for Native Hardware complete 
		-- check if this core is command sender of new thread 
		if(	COOR_cmd_cmplt_reg='1' and newTH_sender_is_the_core='1' ) then 
			native_HW_newTH_cmplt_w <= '1';
		elsif (native_HW_newTH_cmplt='1') then
			native_HW_newTH_cmplt_w <= '0';
		end if;
		-- complete singal for monitor enter success
		-- monitor enter  
		if( monitorenter_cmplt='1' ) then
			monitorenter_cmplt_from_TH_mgt_w <= '1';
		elsif(COOR_cmd_cmplt_reg='1') then
			monitorenter_cmplt_from_TH_mgt_w <= '0';
		end if;
		-- monitor exit 
		-- check if this core is command sender of monitorexit
		-- if sender = A,	and receiver = A (monitorexit_cmplt='1')
		--					and receiver = B (other cores)(monitorexit_receiver_is_the_core='1')
		-- if sender = B,	and receiver = A (keep this unchanged, because A is not stalled) 
		-- 					and receiver = B (keep this unchanged, none of A's business)
		if( monitorexit_sender_is_the_core='1') then -- A send, A receive ,or -- A send, B receive
			if(COOR_cmd_cmplt_reg='1') then
				monitorexit_cmplt_from_TH_mgt_w <= '0';
			elsif(monitorexit_cmplt='1' or (not monitorexit_receiver_is_the_core='1')) then
				monitorexit_cmplt_from_TH_mgt_w <= '1';
			end if;
		end if;
		-- --
		if(
			JAIP2COOR_cmd_monitor_enter_req='1' or JAIP2COOR_cmd_monitor_exit_req='1'
		) then
			JAIP2COOR_cmd_monitor_stall_reg_w <=  '1';
		elsif(
				-- modified by T.H.Wu , 2013.10.23  
				now_thread_monitorenter_succeed='1' or 
				--
				--modified by T.H.Wu , 2014.1.2 
				--(TH_state_dly_w=Prepare_next_thread_TCB_info and TH_data_out_transfer_cnt_dly_w>=x"8" and 
				--	soj_now_TH_monitorenter_fail_hold='1') or
				(TH_state_dly_w=Prepare_next_thread_TCB_info and TH_data_out_transfer_cnt_dly_w=x"8" and 
					soj_now_TH_monitorenter_fail_hold='1' and now_thread_monitorenter_fail='0') or
				--(TH_state_dly_w=Check_Timeout  and now_thread_monitorenter_fail='1')
				(TH_state_dly_w=Check_Timeout  and now_thread_monitorenter_fail_dly='1')
					-- for executing monitorenter
				--(now_thread_monitorenter_succeed='1' or TH_state_dly=ContextSwitch)-- for executing monitorenter
					-- for executing monitorenter, just cancel stall for one clock, for adjusting
					-- current thread's TCB
			or	(monitorexit_sender_is_the_core='1' and COOR_cmd_cmplt_reg='1')-- for executing monitorexit 
			-- A send monitorexit , wakeup A (1 thread , n threads)
			-- A send monitorexit , wakeup B (1 thread , n threads)
			or	(monitorexit_sender_is_the_core='0' and monitorexit_cmplt='1' and TH_mgt_thread_number="00001")-- for executing monitorexit 
			-- B send monitorexit , wakeup A, and 
			-- when only one thread in each core, monitor exit may go wrong, modified by T.H.Wu , 2013.10.9
		) then
			JAIP2COOR_cmd_monitor_stall_reg_w <=  '0';
		end if;
		
		-- added by T.H.Wu, 2014.3.6, keep each requests from Data Coherence Controller sequential
		-- This port is critical for mutex hardware controller !! Maybe potential problems may probably happen!
		if(before_16clk_now_TH_timeout_out='1') then
			if(TH_state_dly=ContextSwitch) then
				JAIP2COOR_pending_resMsgSent_reg_w	<=	'1';
			elsif (TH_state_dly=Check_Timeout or TH_state_dly=Prepare_next_thread_TCB_info) then
				JAIP2COOR_pending_resMsgSent_reg_w	<=	block_COOR_msg_we_before_16clk_now_TH_timeout_w;
			end if;
		elsif(now_TH_start_exec_over_28clk='1') then
			JAIP2COOR_pending_resMsgSent_reg_w	<=	'0';
		end if;
			
		-- --
		COOR_cmd_cmplt_reg_w <= (newTH_from_TH_mgt_cmplt or monitorenter_cmplt_from_TH_mgt or monitorexit_cmplt_from_TH_mgt);
		 
		if (Thread_start_cmplt_flag_dly='1' and TH_mgt_thread_number="00001") then 
			act_w <= '1'; 
		elsif (set_act_reg='1') then
			act_w <= '0';
		end if;
		----------------- JAIP core receives response message of "new thread" command , end ----------------- 
    end process; 
	
	-- modified by T.H.Wu , 2014.3.6
	block_COOR_msg_we_before_16clk_now_TH_timeout_w <= '1' when
										(
											-- if this core is the sender to multicore coordinator (new thread, monitor enter/exit)
											(not JAIP2COOR_cmd_monitor_stall='1') -- or (now_thread_monitorenter_fail_hold='1')) 
											and
											-- modified by T.H.Wu , 2013.12.4
											-- below should be added into this condition, but there's a weird problem about XPS tool
											-- something can make unrelated part of JAIP wrong
											-- (e.g. translate correct byte-codes to an incorrect j-code pair) 
											CTRL_state /= Native_HW
											and
											before_16clk_now_TH_timeout_out='1'
										)
										or -- modified by T.H.Wu , 2013.11.22 , fixed the problem for 4-core
										(
											JAIP2COOR_cmd_monitor_stall='1' and
										-- let it know current thread failed to acquire a object lock
											soj_now_TH_monitorenter_fail_hold ='1' and
											before_16clk_now_TH_timeout_out='1'
										)
										or	-- modified by T.H.Wu , 2013.12.4 updated
											-- fixed the problem for creating new thread
											-- we may modify it in this way because creating new thread is part of Thread.start()
											-- invocation, any method invocation is translated to a complex j-code sequence
										(	
											native_HW_ID_w_dly /= "01000"
											and
											CTRL_state = Native_HW
											and
											before_16clk_now_TH_timeout_out='1'
										)
										-- cannot use native_HW_en_tmp_dly, it keeps logically 1 just for 1 clock 
									else '0';
									
	-- modified by T.H.Wu , 2013.10.29
	COOR_res_msg_we_sync <= '0' when 
									( -- if the sending operation and does not overlap
										TH_state_dly=Backup_previous_thread_TCBinfo	or
										TH_state_dly=ContextSwitch	or
										block_COOR_msg_we_before_16clk_now_TH_timeout_w='1'
									)
							else	COOR_res_msg_we_hold; 
							
	JAIP2COOR_cmd_monitor_stall	<=	JAIP2COOR_cmd_monitor_stall_reg; 
	--
	
    ----
    process(TH_data_in_transfer_cnt,TH_new_thread_flag, TH_state_dly)  begin
         TH_data_in_transfer_cnt_w <= TH_data_in_transfer_cnt;
         if(TH_new_thread_flag='1' or TH_state_dly=Backup_previous_thread_TCBinfo) then
                TH_data_in_transfer_cnt_w <= TH_data_in_transfer_cnt + x"1"; 
         else
                TH_data_in_transfer_cnt_w <= x"0";
         end if;
    end process;  
    --
    process (TH_mgt_runnable_thread_backup_flag, TH_state_dly_w) begin
        TH_mgt_runnable_thread_backup_flag_w <= TH_mgt_runnable_thread_backup_flag;
        if(TH_state_dly_w=ContextSwitch ) then
            TH_mgt_runnable_thread_backup_flag_w <= '1';
        else
            TH_mgt_runnable_thread_backup_flag_w <= '0';
        end if;
    end process;
    --
	 -- is it correct ??
	 -- for another stack in execution stage backup/restore use , 2013.7.17
	stack_mgt_transfer_counter <= stack_mgt_transfer_counter_reg + x"01" 
							when(StackSpace_MstWr_burst_data_rdy='0' and stack_mgt_transfer_counter_reg /= "0000000000") else
							stack_mgt_transfer_counter_reg;
    
    
    
    
    
        -- it will be modified , when act=0 , we should disable CST/MA controller , 2013.7.12
        -- modified by T.H.Wu , 2013.8.1 
	buffer_check_by_retrun <= '1' when return_flag = '1' and return_mask = '0' and A /= X"12345678" else  '0' ; 
	rtn_frm_sync_mthd_flag	<=	(A(10) and not ireturn_flag) or (B(10) and ireturn_flag) when buffer_check_by_retrun='1'	else	'0';
							  
    RefCls_en          <= '1' when CTRL_state = Enable_MA_management else '0'; 
	
    --jing  , modifed by fox
	CST_checking_en    <= (buffer_check_by_retrun or RefCls_en or xcptn_cst_mthd_check_en or TH_trigger_MA_ctrl_en) 
                                                --and not interrupt_req_tmp; 
                                                ; 
	
	ClsLoading_stall   <= CSTLoading_stall or MthdLoading_stall;
    -- by fox
	-- modified by T.H.Wu , 2013.11.1, jpc should be stalled immediate when we are sure that some threads terminate
    stall_all <= (not act_dly) or interrupt_req_tmp or CSTLoading_stall or MthdLoading_stall or --ClsLoading_stall
                   Runnable_load_req or Runnable_store_req or  JAIP2COOR_cmd_monitor_stall or
                   alu_stall or xcptn_stall or stall_all_AASM_Heap or clsiLoading;
                   -- or clsiStoring
				   
	clsiInternLoadReq <= clsiLoadReq_tmp;
	clsiInternStoreReq <= clsiStoreReq_tmp;
        -- modified by T.H.Wu , 2013.7.26 , for fixing the bug about 
        -- newarray and stack management send store request simultaneously .
	--stall_all_AASM_Heap <= '1' when (AASM /= normal) else   '0';
	bus_occupied_by_AASM <= '1' when (AASM = wrLenReq or AASM = wrLen or AASM = wrID)  else   '0'; 
	stall_all_AASM_Heap <= '1' when (AASM /= normal)  or (CTRL_state = Wait4GC) else   '0';
                                  
                                  
				   
    stall_jpc             <= stall_jpc_f or stall_all or TH_mgt_thread_dead_reg;
    
    stall_translate_stage <= '0'       when xcptn_flush_pipeline = '1'        else
	                         stall_all;
    
    stall_fetch_stage     <= '0'       when xcptn_flush_pipeline = '1'        else
							 '1'       when 
											CTRL_state = Get_ArgSize   or 
											CTRL_state = Get_LV1_XRT_ref or
											CTRL_state = Save_objref_fm_heap or
                                            CTRL_state = Get_ObjClsID  or
                                            CTRL_state = Offset_access or
                                            CTRL_state = IllegalOffset or 
											CTRL_state = ClinitRetFrm3 or
                                            CTRL_state = invoke_objref_ListClsID or 
                                            CTRL_state = Native_start or
                                            CTRL_state = Native_HW or
											CTRL_state = Native_StackAdjusting1 or
                                            CTRL_state = Native_StackAdjusting2 or
                                            CTRL_state = Native_ArgExporting_Reg or
                                            CTRL_state = Native_ArgExporting_DDR or
                                            CTRL_state = Enable_MA_management
						else stall_all;
    
    stall_decode_stage    <= '0'       when xcptn_flush_pipeline = '1'        else
							 '0'	   when (decode_push = '1') else
	                         stall_all ;
    stall_execution_stage <= '0'	   when (execute_push = '1') else
							 stall_all ; 
                             
    -- Push flags is for emptying a slot of stack, I want to do it even if the pipeline is stalled.
	decode_push	<= '1' when(push1_flag_tmp = '1' or push2_flag_tmp = '1') else
				   '0';
	
    jpc_ctrl_logic : jpc_ctrl
    generic map(
        RAMB_S18_AWIDTH             => RAMB_S18_AWIDTH
    )
    port map( 
        clk                         => clk,
        act                         => act_dly, 
        stall_jpc                   => stall_jpc,
        CTRL_state                  => CTRL_state, 
        stjpc_flag                  => stjpc_flag,
        native_flag                 => native_flag,
        branch                      => branch_flag,
        branch_destination          => branch_destination,
        TOS_A                       => A (15 downto 0) ,
        TOS_B                       => B (15 downto 0) ,
        jpc_reg_out                 => jpc_reg,
        jpc                         => jpc,
        switch_instr_branch => switch_instr_branch ,
                        -- thread mgt   -- by fox
                        TH_mgt_thread_jpc     => TH_mgt_thread_jpc,
			context_switch		=> TH_mgt_context_switch,
			jpc_backup			=> TH_mgt_jpc_backup,
			clean_pipeline_cmplt=> TH_mgt_clean_execute,
		-- xcptn hdlrr
		xcptn_jpc_wen               => xcptn_jpc_wen,
		xcptn_jpc                   => xcptn_jpc,
		adjust_jpc2xcptn_instr      => adjust_jpc2xcptn_instr,
		xcptn_stall                 => xcptn_stall
    );
	
	CST_check_id <= cls_id when xcptn_cst_mthd_check_IDs_en = '1'  else
                                        -- by fox , but we should not add it directly , 2013.7.19
                                        -- because we send the same info to Dynamic Resolution
					--TH_mgt_ready_thread_cls_id_mthd_id(31 downto 16) when TH_trigger_MA_ctrl_en = '1' or TH_mgt_switch_state = '1' else
					TH_mgt_ready_thread_cls_id_mthd_id(31 downto 16) when (TH_trigger_MA_ctrl_en_dly or TH_trigger_MA_ctrl_en) = '1'  else
					DR2CST_ctrlr_cls_id;
	MTHD_check_id <= now_mthd_id when xcptn_cst_mthd_check_IDs_en = '1' else
                                        -- by fox , but we should not add it directly , 2013.7.19
					 TH_mgt_ready_thread_cls_id_mthd_id(15 downto 0)	when (TH_trigger_MA_ctrl_en_dly or TH_trigger_MA_ctrl_en) = '1'  else
					DR2MA_mgt_mthd_id;

    ClassSymbolTableController: class_symbol_table_controller 
	generic map(
        RAMB_S18_AWIDTH             => RAMB_S18_AWIDTH,
        METHOD_AREA_DDR_ADDRESS     => METHOD_AREA_DDR_ADDRESS
    )
	port map (
          Rst					=> Rst,
          clk 					=> clk,
          CST_checking_en 		=> CST_checking_en,
          DR2CST_ctrlr_cls_id   => CST_check_id,--DR2CST_ctrlr_cls_id,
          A_23_16				=> A(23 downto 16) ,
          B_23_16				=> B(23 downto 16) ,
          return_flag 			=> return_flag,
          ireturn_flag 			=> ireturn_flag,
		  CST_check_done        => CST_check_done, 
		  --external_loaded_buffer=> external_loaded_buffer,
		  -- (slave) write from external part(power PC)
          CSTProfileTable_Wen   => CSTProfileTable_Wen,
          CSTProfileTable_idx   => CSTProfileTable_idx,
          CSTProfileTable_di    => CSTProfileTable_di, 
		  -- (master) external memory access
          -- added by T.H. Wu , 2013.6.20 
        external_MstRd_CmdAck => Runnable_access_ack, -- external_MstRd_CmdAck,  -- fox
        external_MstRd_burst_data_rdy  => Runnable_MstRd_burst_data_rdy, --external_MstRd_burst_data_rdy , -- fox
          external_access_cmplt => Runnable_access_cmplt, -- external_access_cmplt -- fox
          --external_load_data    => external_load_data,
          CSTLoading_req 		=> CSTLoading_req,
          CSTLoading_ex_addr    => CSTLoading_ex_addr,
          CSTLoading_stall		=> CSTLoading_stall,
		  --trigger MA checking
          MA_checking_done 		=> MA_checking_done,
		  --CST
          CST_ctrlr2buffer_wen  => CST_ctrlr2buffer_wen,
          CST_ctrlr2buffer_addr => CST_ctrlr2buffer_addr,
          --CST_ctrlt2buffer_data => CST_ctrlt2buffer_data, -- marked by T.H. Wu , 2013.6.20
          CST_ctrlr2buffer_block_base => CST_ctrlr2buffer_block_base,
          cls_id 				=> cls_id,
		  rtn_frm_sync_mthd_flag=> rtn_frm_sync_mthd_flag,
		  sync_mthd_invoke_rtn_cmplt => sync_mthd_invoke_rtn_cmplt,
		  --
		  -- xcptn hdlr
		  ret_frm_regs_wen		=> ret_frm_regs_wen,
		  get_parent_EID        => get_parent_EID,
		  ret_frm_cls_id		=>  StackRAM_RD1 (31 downto 16),
		  --ret_frm_cls_id		=> ret_frm_cls_id,
		  compared_EID          => compared_EID,
		  CST_FSM_Check_offset  => CST_FSM_Check_offset,
		  parent_EID            => parent_EID,
          --debug_cs_CSTctrl        =>  debug_cs_CSTctrl  ,
          debug_flag 			=> debug_flag,
          debug_addr 			=> debug_addr,
          debug_data 			=> debug_data_CST
    );
	
	ClassSymbolTableBuffer: class_symbol_table_buffer 
	port map (
        Rst                         => Rst,
        clk                         => clk,
        address                     => CST_buffer_addr,
        block_select_base           => CST_ctrlr2buffer_block_base,
        CST_buffer_wen              => CST_buffer_wen,
        CST_buffer_wr_data          => CST_buffer_wr_data,
        CST_entry                   => CST_entry
    );	
	
	MethodAreaController: method_area_controller 
	generic map(
        RAMB_S18_AWIDTH             => RAMB_S18_AWIDTH,
        METHOD_AREA_DDR_ADDRESS     => METHOD_AREA_DDR_ADDRESS
    )
	port map(
          Rst 					=> Rst,
          clk 					=> clk,
          MA_mgt_en 			=> CST_checking_en,
          DR2MA_mgt_mthd_id 	=> MTHD_check_id,--DR2MA_mgt_mthd_id,
          C_25_16 				=> C(25 downto 16) ,
          B_25_16 				=> B(25 downto 16) , 
          return_flag 			=> return_flag,
          ireturn_flag 			=> ireturn_flag,
		  CST_check_done        => CST_check_done,
		  Mthd_check_done       => Mthd_check_done, 
		  -- external loaded buffer
		  -- external_loaded_buffer=> external_loaded_buffer,
		  -- (slave) write from external part(power PC) 
          MthdProfileTable_wen  => MthdProfileTable_wen,
          MthdProfileTable_idx  => MthdProfileTable_idx,
          MthdProfileTable_info => MthdProfileTable_info, 
		  -- (master) external memory access
          -- added by T.H. Wu , 2013.6.20 
        external_MstRd_CmdAck => Runnable_access_ack, -- external_MstRd_CmdAck, --fox
        external_MstRd_burst_data_rdy  => Runnable_MstRd_burst_data_rdy, --external_MstRd_burst_data_rdy , -- fox
          external_access_cmplt => Runnable_access_cmplt, --external_access_cmplt, --fox
          --external_load_data 	=> external_load_data,
          MthdLoading_req 		=> MthdLoading_req,
          MthdLoading_ex_addr   => MthdLoading_ex_addr,
		  --
         -- Mthd_Loading_done 	=> MA_checking_done,
		  MthdLoading_stall     => MthdLoading_stall,
		  --to method area buffer
          Mgt2MA_wen 			=> Mgt2MA_wen,
          Mgt2MA_addr 			=> Mgt2MA_addr,
         -- Mgt2MA_data 			=> Mgt2MA_data,
          Mgt2MA_block_base_sel => Mgt2MA_block_base_sel,
		  --
          now_mthd_id 			=> now_mthd_id,
		  rtn_frm_sync_mthd_flag=> rtn_frm_sync_mthd_flag,
		  sync_mthd_invoke_rtn_cmplt => sync_mthd_invoke_rtn_cmplt,
		  -- xcptn hdlr
		  CST_FSM_Check_offset  => CST_FSM_Check_offset,
		  ret_frm_regs_wen		=> ret_frm_regs_wen,                     
		  --ret_frm_mthd_id		=> ret_frm_mthd_id,
		  ret_frm_mthd_id		=>  StackRAM_RD2 (31 downto 16) ,
		  ER_info_addr_rdy      => ER_info_addr_rdy,   
		  MA_base_mem_addr_wen  => MA_base_mem_addr_wen,
		  ER_info               => ER_info,
		  ER_info_wen_MA_ctrlr  => ER_info_wen_MA_ctrlr,
		  MA_base_mem_addr      => MA_base_mem_addr,
		  --
		  --check_mthd_id         => check_mthd_id,
		  --
         debug_cs_MActrl         =>    debug_cs_MActrl  ,
          debug_flag 			=> debug_flag,
          debug_addr			=> debug_addr,
          debug_data 			=> debug_data_MA
		  --
		  --debug_MA_state		=> debug_MA_state,
		  --debug_loading_size		=> debug_loading_size, 
		  --debug_DR2MA_mgt_mthd_id => debug_DR2MA_mgt_mthd_id,
		  --debug_check_mthd_id	=> debug_check_mthd_id,
		  --debug_overwrite_mthd_id => debug_overwrite_mthd_id,
		  --debug_ResidenceTable_Wen => debug_ResidenceTable_Wen,
		  --debug_malloc => debug_malloc, 
    );
		
	MathodAreaBuffer: method_area_buffer 
	port map(
        Rst                         => Rst,
        clk                         => clk,
        --act                         => act_dly ,
        address                     => MethodArea_addr,
        block_select_base           => Mgt2MA_block_base_sel, 
        methodarea_wr_en            => MethodArea_Wen,
        methodarea_wr_val           => MethodArea_data,
        stall_instruction_buffer    => stall_jpc,
		--out
        instruction_buffer_2        => instruction_buffer_2,
        instruction_buffer_1        => instruction_buffer_1,
        bytecodes                   => bytecodes,
		-- thread management , by fox
		clear_buffer		 => TH_trigger_MA_ctrl_en,
		-- xcptn
		xcptn_flush_pipeline  => xcptn_flush_pipeline,
		mask_insr1                  => mask_insr1,
        -- debug
        debug_flag                  => debug_flag,
        debug_addr                  => debug_addr,
        debug_data                  => debug_bytecode
	--	debug_block_select_base		=> debug_block_select_base,
	--	debug_MA_address			=> debug_MA_address,
	--	debug_RAM_addr				=> debug_RAM_addr,
	--	debug_RAM_we_en				=> debug_RAM_we_en
    );


    DynamicResolution_management_Unit : DynamicResolution_management
    generic map(
        ENABLE_JAIP_PROFILER  =>  ENABLE_JAIP_PROFILER ,
        RAMB_S18_AWIDTH             => RAMB_S18_AWIDTH
    )
    port map(
        -- ctrl signal
        Rst                         => Rst,
        clk                         => clk,
        --act                         => act_dly,
        -- (slave) write from external part(power PC) to DynamicResolution_management
        DR_reg_en                   => DR_reg_en,
        ex2java_data                => ex2java_data,
		--GC
		GC_Cmplt_in                 => GC_Cmplt_in,	        
        -- (master) external memory access
        external_access_cmplt    =>  Runnable_access_cmplt, --external_access_cmplt, --fox
        external_load_req           => Runnable_load_req, --external_load_req_tmp, -- fox
        external_store_req          => Runnable_store_req, --external_store_req_tmp, --fox
        external_load_data          => external_load_data,
        DynamicResolution           => DynamicResolution,
		DR_addr                     => DR_addr,
        DynamicResolution_load_req  => DynamicResolution_load_req,
        DynamicResolution_store_req => DynamicResolution_store_req,
		
		-- class info table
		clsiInternLoadReq					=> clsiLoadReq_tmp,
		clsiInternStoreReq				=> clsiStoreReq_tmp,
		clsiAddr					=> clsiAddr_tmp,
		clsInfo_in					=> clsInfo,
		clsiCmplt					=> clsiCmplt,
		clsiInternWrData					=> clsiInternWrData,
		
		-- clinit
		clinitClsID					=> clinitClsID,
		clinitMthdID				=> clinitMthdID,
		clinitEN					=> clinitEN,

        -- method area
        CST_entry                   => CST_entry,
        operand0                    => operand0,
        operand1                    => operand1,
        search_ptr_out              => search_ptr,

        -- interrupt 
        interrupt_cmplt             => interrupt_cmplt,
        interrupt_req_DR            => interrupt_req_DR,
        interrupt_func_DR           => interrupt_func_DR,
        
        -- invoke
        invoke_objref_from_exe_stage =>  StackRAM_RD1, 
        ArgSize                     => ArgSize,
        
        -- for thread management 
        invoke_objref_reg_2_TH_mgt    =>  invoke_objref_reg_2_TH_mgt,
		new_thread_execute		        => TH_mgt_new_thread_execute,
		TH_mgt_ready_thread_cls_id_mthd_id	=> TH_mgt_ready_thread_cls_id_mthd_id, 
		invoke_sync_mthd_flag		=>	invoke_sync_mthd_flag,
		sync_mthd_invoke_rtn_cmplt	=>	sync_mthd_invoke_rtn_cmplt,
        
        -- flag in
        ClsLoading_stall            => ClsLoading_stall,--CSTLoading_stall,
        invoke_flag                 => invoke_flag,
        static_flag                 => static_flag,
        field_wr                    => field_wr,
        new_obj_flag                => new_obj_flag,
		ldc_flag                    => ldc_flag,
		ldc_w_flag                    => ldc_w_flag,
		getStatic                   => getStatic,

        DynamicResolution_en        => DynamicResolution_en,
        CTRL_state_out              => CTRL_state,
        
        -- Native
        Native_ArgCnt               => Native_ArgCnt,
        Native_CycCnt               => Native_CycCnt,
        native_flag                 => native_flag,
        pop1_flag                   => pop1_flag,
        pop2_flag                   => pop2_flag,
        set_ucodePC                 => set_ucodePC,
		native_HW_en				=> native_HW_en_tmp,
		native_HW_ID				=> native_HW_ID_w,
		native_HW_cmplt				=> native_HW_cmplt_tmp,
        -- debug
        debug_flag                  => debug_flag,
        debug_addr                  => debug_addr,
        debug_data                  => debug_data_DR ,
	-- cs debug
        -- prof
	prof_native_mthd_id				=> prof_native_mthd_id
    );

    Translate_Unit : Translate
    generic map(
        ENABLE_JAIP_PROFILER   => ENABLE_JAIP_PROFILER  ,
        RAMB_S18_AWIDTH             => RAMB_S18_AWIDTH
    )
    port map(
        -- ctrl signal
        Rst                         => Rst,
        clk                         => clk,
        stall_translate_stage       => stall_translate_stage,

        -- method area
        bytecodes                   => bytecodes,
        instruction_buffer_1        => instruction_buffer_1,

        -- fetch stage
        instr_buf_ctrl              => instr_buf_ctrl,
        semitranslated_code         => semitranslated_code,
        complex                     => complex,
        opd_num                     => opd_num,
		prof_issued_bytecodes_T		=> prof_issued_bytecodes_T
    );

    Fetch_Unit : Fetch
    generic map(
        ENABLE_JAIP_PROFILER   => ENABLE_JAIP_PROFILER   ,
        C_MAX_AR_DWIDTH             => C_MAX_AR_DWIDTH,
        RAMB_S9_AWIDTH              => RAMB_S9_AWIDTH,
        RAMB_S18_AWIDTH             => RAMB_S18_AWIDTH
    )
    port map(
        -- ctrl signal
        Rst                         => Rst,
        clk                         => clk,
        stall_fetch_stage           => stall_fetch_stage,
        CTRL_state                  => CTRL_state,
        set_ucodePC                 => set_ucodePC,
        native_flag                 => native_flag,
        switch_instr_branch => switch_instr_branch,
        ISFrom_ROM                  => ISFrom_ROM,

        -- method area
        jpc_reg                     => jpc_reg,
        stall_jpc                   => stall_jpc_f,

        -- translate stage
        semitranslated_code         => semitranslated_code,
        complex                     => complex,
        opd_num                     => opd_num,
        instr_buf_ctrl              => instr_buf_ctrl,

        -- decode stage
        stjpc_flag                  => stjpc_flag,
        invoke_flag                 => invoke_flag,
        return_flag                 => return_flag,
        branch_trigger              => branch_trigger,
        instrs_pkg                  => instrs_pkg,
        opd_source                  => opd_source,
        nop_1                       => nop_1,
        nop_2                       => nop_2,
		clinitEN		=> clinitEN, 
		is_switch_instr_start => is_switch_instr_start ,
		switch_instr_revert_code_seq => switch_instr_revert_code_seq,
        -- execute stage
        A_0                         => A(0),
        B_0                         => B(0),
        branch_destination          => branch_destination,
        branch                      => branch_flag,
        
		-- xcptn
		xcptn_flush_pipeline        => xcptn_flush_pipeline,          
		-- thread management  	-- by fox
		TH_mgt_clean_pipeline				=> TH_mgt_clean_pipeline ,	 
		TH_mgt_clean_decode				    => TH_mgt_clean_decode ,	 
		TH_mgt_context_switch				=> TH_mgt_context_switch ,
		TH_mgt_new_thread_execute		    => TH_mgt_new_thread_execute,
		TH_mgt_thread_jpc                   => TH_mgt_thread_jpc,
		TH_mgt_thread_trigger				=> TH_mgt_thread_trigger,
		TH_mgt_simple_mode					=> TH_mgt_simple_mode,
		TH_mgt_reset_mode					=> TH_mgt_reset_mode,
		-- modified by T.H.Wu , 2014.1.22, for invoking/returning sync method.
		invoke_sync_mthd_flag_dly			=>	invoke_sync_mthd_flag_dly,
		rtn_frm_sync_mthd_flag				=>	rtn_frm_sync_mthd_flag,
		COOR_cmd_cmplt_reg					=>	COOR_cmd_cmplt_reg,
		
        --debug_cs_fetch      		=>  debug_cs_fetch    ,
        -- debug
        debug_flag                  => debug_flag (7 downto 0)  ,
        debug_addr                  => debug_addr (7 downto 0) ,
        debug_data                  => debug_data_fetch,
		prof_simple_issued_A		=> prof_simple_issued_A,
		prof_simple_issued_B		=> prof_simple_issued_B,
		prof_complex_issued			=> prof_complex_issued,
		prof_issued_bytecodes_T		=> prof_issued_bytecodes_T,
		prof_issued_bytecodes_F		=> prof_issued_bytecodes_F	 
    );

    Decode_Unit : decode
    generic map(
        ENABLE_JAIP_PROFILER   => ENABLE_JAIP_PROFILER  ,
        RAMB_S18_AWIDTH             => RAMB_S18_AWIDTH
    )
    port map(
        -- ctrl signal
        Rst                         => Rst,
        clk                         => clk,
        stall_decode_stage          => stall_decode_stage,
        CTRL_state                  => CTRL_state,

		-- ldc
        DR_addr                     => DR_addr,
        -- method area
        instruction_buffer_2        => instruction_buffer_2,
        instruction_buffer_1        => instruction_buffer_1,
        bytecodes                   => bytecodes,
        --cls_num                    => cls_num,
		now_cls_id                  => cls_id,
		now_mthd_id		=> now_mthd_id,
        -- jpc CtrlLogic
        branch_destination          => branch_destination,

        -- fetch stage
        branch_trigger              => branch_trigger,
        instrs_pkg                  => instrs_pkg,
        opd_source                  => opd_source,
        nop_1                       => nop_1,
        nop_2                       => nop_2,
	is_switch_instr_start => is_switch_instr_start,
        switch_instr_revert_code_seq => switch_instr_revert_code_seq ,

        -- execte stage
        vp                          => vp,
        sp                          => sp,
        branch                      => branch_flag,
        reg_valid                   => reg_valid,
        load_immediate1             => load_immediate1,
        load_immediate2             => load_immediate2,
        store1_addr                 => store1_addr,
        store2_addr                 => store2_addr,
        W1_RegFlag                  => W1_RegFlag,
        W2_RegFlag                  => W2_RegFlag,
        MemRead_ctrl                => MemRead_ctrl,
        ctrl                        => ctrl,
        mem2LVreg_1_decode            => mem2LVreg_1_decode,
        mem2LVreg_2_decode            => mem2LVreg_2_decode,
        stsp_s_flag                 => stsp_s_flag,

        -- opd out
        operand0_out                => operand0,
        operand1_out                => operand1,
        operand2_out                => operand2,
        operand3_out                => operand3,

        -- flag & req in
        pop1_flag                   => pop1_flag,
        pop2_flag                   => pop2_flag,
	push1_flag                  => push1_flag_tmp,
        push2_flag                  => push2_flag_tmp,
        interrupt_req               => interrupt_req_tmp,
        interrupt_cmplt             => interrupt_cmplt,
        external_load_req            => Runnable_load_req, --external_load_req_tmp, -- fox
        external_store_req          => Runnable_store_req, --external_store_req_tmp,
        external_access_cmplt    => Runnable_access_cmplt, --external_access_cmplt,

        -- flag & req out
        DynamicResolution_en        => DynamicResolution_en,
        invoke_flag                 => invoke_flag,
	new_obj_flag                => new_obj_flag,
	static_flag                 => static_flag,
        field_wr                    => field_wr,
	ldc_flag                    => ldc_flag,
	ldc_w_flag			=> ldc_w_flag,
        stjpc_flag                  => stjpc_flag,
        return_flag                 => return_flag,
        ireturn_flag                => ireturn_flag,
	newarray_flag				=> newarray_flag,
	getStatic					=> getStatic,
		
        interrupt_req_decode        => interrupt_req_decode,
        refload_req                 => refload_req,
        refstore_req                => refstore_req,
        refAcs_sel                 => refAcs_sel,

        interrupt_func_decode       => interrupt_func_decode,
        -- thread management , by fox
		TH_mgt_clean_decode			=> TH_mgt_clean_decode,
		TH_mgt_clean_execute		=> TH_mgt_clean_execute,
		TH_mgt_context_switch		=> TH_mgt_context_switch,
		TH_mgt_CS_reset_lv			=> TH_mgt_CS_reset_lv, 
		-- to multi-core coordinator , added by T.H.Wu , 2013.9.7
		JAIP2COOR_cmd_monitor_enter_req =>	JAIP2COOR_cmd_monitor_enter_req ,
		JAIP2COOR_cmd_monitor_exit_req =>	JAIP2COOR_cmd_monitor_exit_req ,
		
		-- prof
		prof_simple_issued_A		=> prof_simple_issued_A,
		prof_simple_issued_B		=> prof_simple_issued_B,
		prof_complex_issued			=> prof_complex_issued,
		prof_issued_bytecodes_F		=> prof_issued_bytecodes_F,
		prof_simple_issued_A_D		=> prof_simple_issued_A_D_tmp,
		prof_simple_issued_B_D		=> prof_simple_issued_B_D_tmp,
		prof_complex_issued_D		=> prof_complex_issued_D_tmp,
		prof_issued_bytecodes_D		=> prof_issued_bytecodes_D_tmp,
		--debug_cs_decode                 => debug_cs_decode    ,
		--xcptn thrown by bytecode
		xcptn_done                  => xcptn_done,
		xcptn_thrown_bytecode       => xcptn_thrown_bytecode
    );

    Execution_Unit : execution
    generic map(
        RAMB_S36_AWIDTH             => RAMB_S36_AWIDTH
    )
    port map(
        -- ctrl signal
        Rst                         => Rst,
        clk                         => clk,
		act_dly						=>	act_dly,
        stall_execution_stage       => stall_execution_stage, 
        bytecodes                   => bytecodes,
	cst_entry                   => CST_entry(15 downto 0),
        CTRL_state                  => CTRL_state,
        Native_ArgCnt               => Native_ArgCnt,

        -- decode stage
        load_immediate1             => load_immediate1,
        load_immediate2             => load_immediate2,
        store1_addr                 => store1_addr,
        store2_addr                 => store2_addr,
        W1_RegFlag                  => W1_RegFlag,
        W2_RegFlag                  => W2_RegFlag,
        MemRead_ctrl                => MemRead_ctrl,
        ctrl                                       => ctrl,
        mem2LVreg_1_decode          => mem2LVreg_1_decode,
        mem2LVreg_2_decode          => mem2LVreg_2_decode,
        stsp_s_flag                 => stsp_s_flag,
        
        -- flag & req in
        write_ABC                   => write_ABC,
        invoke_flag                 => invoke_flag,
		static_flag					=> static_flag,
        return_flag                 => return_flag,
		clinitEN					=> clinitEN,
		push1_flag  				=> push1_flag_tmp,
        push2_flag                  => push2_flag_tmp,
		
        -- out
        TOS_A                       => A,
        TOS_B                       => B,
        TOS_C                       => C,
        vp                          => vp,
        sp                          => sp,
        reg_valid                   => reg_valid,
        branch_flag                 => branch_flag,
        alu_stall                   => alu_stall,
        StackRAM_RD1                => StackRAM_RD1,
        StackRAM_RD2                => StackRAM_RD2,

        -- invoke
       -- invoke_objref               => invoke_objref,
        ArgSize                     => ArgSize,
		external_access_cmplt  => Runnable_access_cmplt, --external_access_cmplt, --fox
		
		--xcptn hdlr 
		xcptn_en                    => xcptn_en, 
		xcptn_thrown_bytecode       => xcptn_thrown_bytecode,	
		xcptn_stall                 => xcptn_stall,
		xcptn_flush_pipeline        => xcptn_flush_pipeline,
		-- external memory access 
		external_load_data          => external_load_data,
		external_load_EID_req       => external_load_EID_req,
		external_load_LVcnt_req     => external_load_LVcnt_req,
		-- parser to ER_LUT 
		prsr2ER_LUT_di   	        => prsr2ER_LUT_di,
		prsr2ER_LUT_addr            => prsr2ER_LUT_addr,
		prsr2ER_LUT_wen             => prsr2ER_LUT_wen,	
		--to mthd ctrlr	
		now_mthd_id                 => now_mthd_id,
		ER_info                     => ER_info,
		ER_info_wen_MA_ctrlr        => ER_info_wen_MA_ctrlr,
		check_CST_MA_done           => Mthd_check_done,
		update_return_regs     		=> update_return_regs,
		ret_frm_regs_wen		    => ret_frm_regs_wen,                     
		--ret_frm_mthd_id				=> ret_frm_mthd_id, 
		ER_info_addr_rdy            => ER_info_addr_rdy,    
		MA_base_mem_addr_wen        => MA_base_mem_addr_wen,	
		--to jpc ctrlr
		stall_jpc                   => stall_jpc,
		JPC                         => jpc_reg,
		xcptn_jpc_wen				=> xcptn_jpc_wen,
		xcptn_jpc                   => xcptn_jpc,
		adjust_jpc2xcptn_instr      => adjust_jpc2xcptn_instr,
		--to cst_controller
		now_cls_id                  => cls_id,
		parent_EID                  => parent_EID,
		--ret_frm_cls_id				=> ret_frm_cls_id,
		xcptn_cst_mthd_check_en  	=> xcptn_cst_mthd_check_en,
		xcptn_cst_mthd_check_IDs_en	=> xcptn_cst_mthd_check_IDs_en,
		get_parent_EID              => get_parent_EID,
		compared_EID                => compared_EID,
		--to instr buffer          
		xcptn_clean_buffer          => xcptn_clean_buffer,
		mask_insr1                  => mask_insr1,
		--to decode
		xcptn_done                  => xcptn_done,
		-- interrupt req
		interrupt_cmplt             => interrupt_cmplt,
		interrupt_req_xcptn			=> interrupt_req_xcptn,
		interrupt_func_xcptn        => interrupt_func_xcptn,
		-- native HW
		xcptn_thrown_Native_HW		=> xcptn_thrown_Native_HW,
		Native_HW_thrown_ID			=> Native_HW_thrown_ID,
		-- end xcptn hdlr
            -- thread management , by fox
		TH_mgt_clean_execute		=> TH_mgt_clean_execute,
                -- modified by T.H.Wu , 2013.8.8 , for solving critical path
		--TH_mgt_clean_pipeline_cmplt	=> TH_mgt_clean_pipeline_cmplt,
		stack_mgt_transfer_counter   => stack_mgt_transfer_counter, -- this is only for stack backup/restore -- thread mgt   -- by fox
		TH_mgt_context_switch		=> TH_mgt_context_switch,
		TH_mgt_new_thread_execute	=> TH_mgt_new_thread_execute,
		TH_mgt_LVreg2mem_CS			=> TH_mgt_LVreg2mem_CS,
                TH_data_out_dly                            => TH_data_out_dly ,
                TH_data_out_transfer_cnt_dly  => TH_data_out_transfer_cnt_dly ,
		--thread_stack_vp			=> thread_stack_info(31 downto 16),
		--thread_stack_sp			=> thread_stack_info(15 downto 0),
		--thread_stack_A              => thread_stack_A,
                --thread_stack_B              => thread_stack_B,
                --thread_stack_C              => thread_stack_C,
		--TH_mgt_thread_reg_valid  => TH_mgt_thread_reg_valid,
		--thread_obj	              	=> thread_obj,
		
                --for stack management 
                external_store_data         =>    stack_backup_data,
                stackMgt2exe_base_addr   =>     stackMgt2exe_base_addr,
                stackMgt2exe_rw_stk_en   =>     stackMgt2exe_rw_stk_en ,
               -- debug_cs_4portbank           =>     debug_cs_4portbank ,
                --debug_cs_exe                       =>     debug_cs_exe ,
                --debug_cs_xcptn                   =>     debug_cs_xcptn ,
                -- debug
                debug_flag                  => debug_flag (11 downto 0),
                debug_addr                  => debug_addr (11 downto 0),
                debug_data                  => debug_data_execute 
		-- cs
		--debug_stack_wdaddr			=> debug_stack_wdaddr,
		--debug_stack_rdaddr			=> debug_stack_rdaddr
    );
    
    
    
	-- by fox
	thread_management_Unit : thread_management
    generic map(
        RAMB_S18_AWIDTH             => RAMB_S18_AWIDTH,
		RAMB_S36_AWIDTH            => RAMB_S36_AWIDTH,
		Max_Thread_Number	=> Max_Thread_Number
    )
    port map(
                debug_cs_thread_mgt                 => debug_cs_thread_mgt ,
		-- ctrl signal
		Rst                         => Rst,
		clk                         => clk,
		act_dly                     => act_dly,
		SetTimeSlices_Wen           => TH_mgt_SetTimeSlices_Wen, 
		context_switch	        	=> TH_mgt_context_switch, 
		thread_number			=> TH_mgt_thread_number,
        -- stack backup/restore
		stack_rw_cmplt				=> StackMgt_rw_cmplt,
		thread_base					=> TH_mgt_thread_base,
		stack_length				=> TH_mgt_stack_length,
		stack_rw_enable				=> TH_mgt_stack_rw_enable,
		sdram_rw_flag				=> TH_mgt_sdram_rw_flag,
		jpc_backup					=> TH_mgt_jpc_backup,
		-- unified 32-bit input / output data port HERE !
		TH_data_in_valid			=> TH_data_in_valid,
		TH_data_in                  => TH_data_in,
		TH_data_out_valid		    => TH_data_out_valid,
		TH_data_out                                 => TH_data_out_dly_w,
		TH_data_in_transfer_cnt_dly   => TH_data_in_transfer_cnt_dly,
		TH_data_out_transfer_cnt       => TH_data_out_transfer_cnt_dly_w,
		thread_ctrl_state_out              => TH_state_dly_w ,
		-- method area 	
		ClsLoading_stall                       => ClsLoading_stall,
		TH_trigger_MA_ctrl_en		=> TH_trigger_MA_ctrl_en, 
		--from dynamic resolution (new thread)
		new_thread_flag				=> TH_new_thread_flag, 
		Thread_start_cmplt_flag          => Thread_start_cmplt_flag ,
		new_thread_execute			=> TH_mgt_new_thread_execute,
		-- from fetch stage
		simple_mode					=> TH_mgt_simple_mode,
		reset_mode					=> TH_mgt_reset_mode,
		-- from decode stage 
		CS_reset_lv					=> TH_mgt_CS_reset_lv,
		-- from execute stage 
		LVreg2mem_CS				=> TH_mgt_LVreg2mem_CS,  
		-- from soj
		before_16clk_now_TH_timeout_out	=>	before_16clk_now_TH_timeout_out,
		now_TH_start_exec_over_28clk	=>	now_TH_start_exec_over_28clk,
		thread_dead_flag			=> TH_mgt_thread_dead,
		interrupt_req				=> interrupt_req_tmp,
		-- from/to multi-core coordinator
		current_run_thread_slot_idx		=>	current_run_thread_slot_idx, 
	 	now_thread_monitorenter_succeed	=>	now_thread_monitorenter_succeed,
	 	now_thread_monitorenter_fail	=>	now_thread_monitorenter_fail,
		monitorexit_sender_is_the_core	=>	monitorexit_sender_is_the_core, 
		monitorexit_lockfree			=>	monitorexit_lockfree, -- more actually, nothing to do , not just lock is free
	 	monitorexit_nextowner_here		=>	monitorexit_nextowner_here,
		monitorexit_nextowner_thread_slot_idx	=>	monitorexit_nextowner_thread_slot_idx,
	 	monitorenter_cmplt				=>	monitorenter_cmplt,
	 	monitorexit_cmplt				=>	monitorexit_cmplt, 
		clean_pipeline_cmplt		=> TH_mgt_clean_execute,
		clean_pipeline				=> TH_mgt_clean_pipeline,
		stall_all_flag				=> stall_all
    );
    
	-- by fox
	stack_access_management_Unit : stack_access_management
    generic map(
        RAMB_S36_AWIDTH             => RAMB_S36_AWIDTH,
		STACK_AREA_DDR_ADDRESS		=> STACK_AREA_DDR_ADDRESS,
		BURST_LENGTH				=> BURST_LENGTH,  
		Max_Thread_Number			=> Max_Thread_Number
    )
    port map(
          debug_cs_stk_mgt            =>  debug_cs_stk_mgt   ,
       -- ctrl signal
		Rst                         => Rst,
                clk                         => clk,
		bus_busy					=> bus_occupied_by_run_thread,
		-- thread mgt
		stack_rw_cmplt				=> StackMgt_rw_cmplt,
		thread_base					=> TH_mgt_thread_base,
		stack_length				=> TH_mgt_stack_length,
		stack_rw_enable				=> TH_mgt_stack_rw_enable,
		sdram_rw_flag				=> TH_mgt_sdram_rw_flag,		
		-- (master) external memory access
		external_access_ack			=> StackSpace_access_ack,
		external_access_cmplt              => StackSpace_access_cmplt,
		prepare_stack_load_req		=> prepare_stack_load_req,
		stack_in_sdram_addr			=> stackMgt2DDR_addr,
		backup_stack_store_req		=> backup_stack_store_req,
		-- 4-port stack
		stack_base					=> stackMgt2exe_base_addr, 
		stack_rw					=> stackMgt2exe_rw_stk_en
    );
    
    Host_arg1 <= Host_arg1_reg;
    Host_arg2 <= Host_arg2_reg;
    Host_arg3 <= Host_arg3_reg when (CTRL_state = Native_interrupt or CTRL_state = Native_HW) else
				 "00000" & clsiAddr_tmp(11 downto 1) & x"0000"  when (new_obj_flag = '1') else
                 DynamicResolution;
    Host_arg4 <= Host_arg4_reg when (CTRL_state = Native_interrupt or CTRL_state = Native_HW) else
                 x"0000" & cls_id;
    Host_arg5 <= Host_arg5_reg when (CTRL_state = Native_interrupt or CTRL_state = Native_HW) else
	             x"0000" & interrupt_func_xcptn(15 downto 0) when interrupt_req_xcptn = '1'     else
				 -- The thrown ID, it's not essential to write thrown ID into this reg, 
				 --since "interrupt_func_xcptn" have been sent by IPC interface.
				 x"88014" & clsiAddr_tmp(9 downto 0) & "00" when (new_obj_flag = '1') else
                 DR_addr;
     
    
    reg_CtrlUnit :
    process(clk) begin
		if(rising_edge(clk)) then
        if(Rst = '1') then
            Host_arg1_reg <= (others => '0');
            Host_arg2_reg <= (others => '0');
            Host_arg3_reg <= (others => '0');
            Host_arg4_reg <= (others => '0');
            Host_arg5_reg <= (others => '0');
			clsiLoading <= '0';
			clsiStoring <= '0';
            external_store_req_reg <= '0'; 
            external_loaded_buffer <= (others => '0');
        else
            external_load_req_reg  <= external_load_req_tmp;
            external_store_req_reg <= external_store_req_tmp; 
            -- marked by T.H. Wu , for CST/MA buffer burst transfer , 2013.6.21 
			external_loaded_buffer <= external_load_data; 
			
			
            if(CTRL_state = Native_ArgExporting_Reg) then
                case Native_CycCnt is
                    when "01" =>   Host_arg1_reg <= StackRAM_RD1;
                                   Host_arg2_reg <= StackRAM_RD2;
                    when "10" =>   Host_arg3_reg <= StackRAM_RD1;
                                   Host_arg4_reg <= StackRAM_RD2;
                    when "11" =>   Host_arg5_reg <= StackRAM_RD1;
                    when others => null;
                end case;
            end if;
			
			if(clsiLoadReq_tmp = '1') then
				clsiLoading <= '1';
			elsif(clsiCmplt = '1') then
				clsiLoading <= '0';
			end if;
			
			if(clsiStoreReq_tmp = '1') then
				clsiStoring <= '1';
			elsif(clsiCmplt = '1') then
				clsiStoring <= '0';
			end if; 
        end if;
        end if;
    end process;
	  
	


--  debug_part ============================================================================
    -- *************************** debug circuit start ************************ 
    labal_hide_module_0 : if HIDE_MODULE = 0 generate
	
    debug_data <= 
                  --debug_data_DR          when  debug_flag = x"0000000F"  else
                  (x"00000" & jpc(11 downto 0)) when  debug_flag(31 downto 0) = x"00000010"  else
                  instruction_buffer_2 & instruction_buffer_1 when  debug_flag = x"00000012"  else
                  x"0000" & bytecodes    when  debug_flag = x"00000018"  else
                  x"000000" & "00" & debug_CTRL_state      when (debug_flag = x"00000003") else
                  debug_bram_out         when (debug_flag = x"00000004") else
                  debug_bytecode         when (debug_flag = x"00000005") else
                  debug_invoke           when (debug_flag = x"00000006") else
                 -- debug_invoke_cycle_cnt when (debug_flag = x"00000007") else
                  debug_get_fd           when (debug_flag = x"00000008") else
                 -- debug_get_fd_cycle_cnt when (debug_flag = x"00000009") else
                  debug_put_fd           when (debug_flag = x"0000000A") else
                  debug_put_fd_cycle_cnt when (debug_flag = x"0000000B") else
                  x"0000" & debug2_bram_out when (debug_flag = x"00000013") else
                  debug2_cls0_cnt        when (debug_flag = x"00000014") else
                  x"00000" & "00" & vp   when (debug_flag = x"00000015") else
                  x"00000" & "00" & sp   when (debug_flag = x"00000016") else
                  debug2_cls0_cnt2       when (debug_flag = x"00000017") else
                  double_issue           when (debug_flag = x"0000001A") else
                  not_double_issue       when (debug_flag = x"0000001B") else
                  nopnop                 when (debug_flag = x"0000001C") else
                  x"0000" & cls_id      when (debug_flag = x"0000001D") else
                  Normal_nopnop          when (debug_flag = x"0000001E") else
                  instrs_pkg_FF          when (debug_flag = x"0000001F") else
                  debug_data_execute     when (debug_flag = x"00000020" or
                                               debug_flag = x"00000021") else
                  ucode_nopnop           when (debug_flag = x"00000022") else
                  debug_data_fetch       when (debug_flag = x"00000023") else
                  nopflag                when (debug_flag = x"00000024") else
                  stall_all_reg          when (debug_flag = x"00000025") else
                  stall_fetch_stage_reg  when (debug_flag = x"00000026") else 
				  field_access_cnt       when (debug_flag = x"00000028") else
				  methd_invoke_cnt       when (debug_flag = x"00000029") else
				  
				  debug_data_CST         when (debug_flag = x"0000002a") else
                  debug_data_MA          when (debug_flag = x"0000002b") else 
				  external_loaded_buffer when (debug_flag = x"0000002d") else
				  x"000000"&"000"&CST_ctrlr2buffer_block_base                     when (debug_flag = x"0000002e") else
				  CSTLoading_ex_addr     when (debug_flag = x"0000002f") else
				  x"0000000"&"000"&CST_check_done                      when (debug_flag = x"00000030") else 
                  AS                     when (debug_flag = x"00000031") else
				  AA                     when (debug_flag = x"00000032") else
				  debug_data_execute     when (debug_flag = x"00000033") or 
                                              (debug_flag = x"00000034") or 
                                              (debug_flag = x"00000035") else
											  
                  x"000000"&"000"&Mgt2MA_block_base_sel when (debug_flag = x"00000036") else											  
                  x"FF000000" ;

                  
                  
    debug_bram_data_in <= external_access_addr_tmp when (refload_req  or DynamicResolution_load_req or refstore_req or DynamicResolution_store_req) ='1' else
                         x"F000" & "00" & ex2java_addr; 
    
    debug_bram_we_tmp  <= (refload_req  or DynamicResolution_load_req or refstore_req or DynamicResolution_store_req) or
                          write_ABC.Aen or write_ABC.Ben or write_ABC.Cen or interrupt_cmplt; --or ClsProfileTable_Wen;
    
    debug_bram_address <= debug_addr when debug_flag = x"00000004" else
                          debug_bram_counter;
                          
    debug_bram_we      <= '0' when debug_flag = x"00000004" else
                          debug_bram_we_tmp;
    
    process(clk, Rst) begin
        if(Rst = '1') then
            debug_bram_counter    <= (others => '0');
            debug_bram_we_tmp_reg <= '0';
        elsif(rising_edge(clk)) then
            debug_bram_we_tmp_reg <= debug_bram_we_tmp;
            if(act_dly= '1' and debug_bram_we_tmp_reg = '0' and debug_bram_we_tmp = '1') then
                debug_bram_counter <= debug_bram_counter + 1;
            end if;
        end if;
    end process;
    
    debug : RAMB16_S36
    port map (
        DI    => debug_bram_data_in,
        DIP   => (others => '0'),
        ADDR  => debug_bram_address(8 downto 0),
        DO    => debug_bram_out,
        CLK   => clk,
        EN    => '1',
        SSR   => Rst,
        WE    => debug_bram_we
    ); 
    
    debug2_bram_we_tmp  <= '1' when CTRL_state = Method_exit or (return_flag ='1' and stjpc_flag = '1') else '0';
    
    debug2_bram_address <= debug_addr when debug_flag = x"00000013" else
                           debug2_bram_counter;
                          
    debug2_bram_we      <= '0' when debug_flag = x"00000013" else
                          debug2_bram_we_tmp;
                          
    cls_num_serial: process(clk, Rst) begin
        if(Rst = '1') then
            debug2_bram_counter    <= (others => '0');
            debug2_bram_we_tmp_reg <= '0';
            debug2_cls_num_tmp     <= (others => '0');
            debug2_cls0_cnt        <= (others => '0');
            debug2_cls0_cnt2       <= (others => '0');
        elsif(rising_edge(clk)) then
            debug2_cls_num_tmp <= cls_num;
            if(act_dly= '1' and debug2_bram_we_tmp = '1') then
                debug2_bram_counter <= debug2_bram_counter + 1;
            end if;
            if(act_dly= '1' and debug2_cls_num_tmp /= cls_num and cls_num = x"0000") then
                debug2_cls0_cnt <= debug2_cls0_cnt + 1;
            end if;
            if(act_dly= '1' and debug2_cls_num_tmp /= cls_num and cls_num = x"0004") then
                debug2_cls0_cnt2 <= debug2_cls0_cnt2 + 1;
            end if;
        end if;
    end process;
    
    debug2 : RAMB16_S18
    port map (
        DI    => cls_num,
        DIP   => (others => '0'),
        ADDR  => debug2_bram_address(9 downto 0),
        DO    => debug2_bram_out,
        CLK   => clk,
        EN    => '1',
        SSR   => Rst,
        WE    => debug2_bram_we
    );  
     
 
	debug_nb_di <= now_mthd_id(7 downto 0 ) & jpc_reg(11 downto 0) & jpc(11 downto 0); 
	
	debug_SW_rd      <= debug_nb_SW(9);
	debug_nb_SW_addr <= debug_nb_SW(8 downto 0);
	
	debug_nb_addr <= debug_nb_cnt	  when debug_SW_rd = '0' else
			         debug_nb_SW_addr;
	
	process( clk, Rst ) is
    begin
      if (Rst = '1') then
          debug_nb_cnt <= (others => '0') ;
      elsif ( rising_edge (clk) ) then
		if debug_nb_cnt = "111111111" then
			debug_nb_cnt <= debug_nb_cnt;
		elsif( act_dly = '1' ) and (jpc_reg /= jpc) then
            debug_nb_cnt <= debug_nb_cnt + 1 ;  
        end if;
      end if;
    end process;
	
	debug_nb_wen <= '0' when debug_SW_rd = '1' else
					'0' when debug_nb_cnt = "111111111" or act_dly = '0' or jpc_reg = jpc else
					'1';
		

    debug_part :
    process( clk ) is
    begin
      if (Rst = '1') then
          debug_dynamic_resolution <= (others => '0') ;
          debug_invoke             <= (others => '0') ;
          debug_get_fd             <= (others => '0') ;
          debug_put_fd             <= (others => '0') ;
          debug_invoke_cycle_cnt   <= (others => '0') ;
          debug_get_fd_cycle_cnt   <= (others => '0') ;
          debug_put_fd_cycle_cnt   <= (others => '0') ;
      elsif ( rising_edge (clk) ) then
          if( act_dly = '1' ) then 
              if(CTRL_state /= Normal) then
                  if (debug_dynamic_resolution = "00") then
                      debug_invoke_cycle_cnt <= debug_invoke_cycle_cnt +'1';
                  elsif (debug_dynamic_resolution = "01") then
                      debug_get_fd_cycle_cnt <= debug_get_fd_cycle_cnt +'1';
                  elsif (debug_dynamic_resolution = "10") then
                      debug_put_fd_cycle_cnt <= debug_put_fd_cycle_cnt +'1';
                  end if;
              end if; 
          end if;
      end if;
    end process;
    end generate;
    -- *************************** debug circuit end ************************ 
    
    
    -- *************************** old profile circuit start ************************ 
    labal_hide_module_1 : if HIDE_MODULE = 0 generate
    process(clk, Rst) begin
        if(Rst = '1') then
            double_issue      <= (others => '0') ;
            not_double_issue  <= (others => '0') ;
            nopnop            <= (others => '0') ;
            Normal_nopnop     <= (others => '0') ;
            instrs_pkg_FF     <= (others => '0') ;
            ucode_nopnop      <= (others => '0') ;
            nopflag           <= (others => '0') ;
            stall_all_reg     <= (others => '0') ;
            stall_fetch_stage_reg     <= (others => '0') ;
			ll 				  <= (others => '0') ;
	        lA 				  <= (others => '0') ;
	        lS 				  <= (others => '0') ;
	        Sl 				  <= (others => '0') ;
	        SA 				  <= (others => '0') ;
	        SS 				  <= (others => '0') ;
			Al				  <= (others => '0') ;
		    AS                <= (others => '0') ;
			AA                <= (others => '0') ;
        elsif(rising_edge(clk)) then
            if (stall_all = '0') then
                if(instrs_pkg = x"FFFF") then
                    instrs_pkg_FF      <= instrs_pkg_FF + 1;
                end if;
                if (nop_1 = '1') then -- nop_1 = nop_2
                    nopflag <= nopflag + 1;
                end if;
                if (instrs_pkg = x"FFFF" or nop_1 = '1') then -- nop_1 = nop_2
                    nopnop      <= nopnop + 1;
                    if(CTRL_state = Normal) then
                        Normal_nopnop      <= Normal_nopnop + 1;
                    end if;
                    if(ISFrom_ROM = '1') then
                        ucode_nopnop      <= ucode_nopnop + 1;
                    end if;
                elsif (instrs_pkg(15 downto 8) = x"FF" and instrs_pkg(7 downto 0)/= x"FF") then
                    not_double_issue  <= not_double_issue + 1;
                elsif (instrs_pkg(7 downto 0) = x"FF" and instrs_pkg(15 downto 8)/= x"FF") then
                    not_double_issue  <= not_double_issue + 1;
                else
                    double_issue      <= double_issue + 1;
					if(instrs_pkg(15 downto 14)="00" and instrs_pkg(7 downto 6)="00") then ll <= ll +'1'; end if;			
					if(instrs_pkg(15 downto 14)="00" and instrs_pkg(7 downto 6)="10") then lA <= lA +'1'; end if;			
					if(instrs_pkg(15 downto 14)="00" and instrs_pkg(7 downto 6)="01") then lS <= lS +'1'; end if;			
					if(instrs_pkg(15 downto 14)="01" and instrs_pkg(7 downto 6)="00") then Sl <= Sl +'1'; end if;			
					if(instrs_pkg(15 downto 14)="01" and instrs_pkg(7 downto 6)="10") then SA <= SA +'1'; end if;			
					if(instrs_pkg(15 downto 14)="01" and instrs_pkg(7 downto 6)="01") then SS <= SS +'1'; end if;			
					if(instrs_pkg(15 downto 14)="10" and instrs_pkg(7 downto 6)="00") then Al <= Al +'1'; end if;			
					if(instrs_pkg(15 downto 14)="10" and instrs_pkg(7 downto 6)="01") then AS <= AS +'1'; end if;			
					if(instrs_pkg(15 downto 14)="10" and instrs_pkg(7 downto 6)="10") then AA <= AA +'1'; end if;
                end if;
            end if;
            if((interrupt_req_tmp or ClsLoading_stall or
                   external_load_req_tmp or external_store_req_tmp or alu_stall) = '1') then
                stall_all_reg <= stall_all_reg + 1;
            end if;
            if(stall_fetch_stage = '1' and stall_decode_stage = '0') then
                stall_fetch_stage_reg <= stall_fetch_stage_reg + 1;
            end if;
        end if;
    end process;
    end generate;
    -- *************************** old profile circuit end ************************ 
    
-- End debug ============================================================================

-- cs debug
	With CTRL_state Select
		debug_CTRL_state <= "000000" when Normal,
                                                        "000001" when  HeapAlloc,
							"000010" when Get_LV1_XRT_ref,
							"000011" when Offset_access, 
							"000100" when IllegalOffset,
							"000101" when Enable_MA_management, 
							"000110" when CLassLoading, 
							"000111" when Method_entry, 
							"001000" when Method_flag, 
							"001001" when arg_size, 
							"001010" when max_stack, 
							"001011" when max_local, 
							"001100" when Method_exit, 
							"001101" when Field_store, 
							"001110" when Field_load, 
							"001111" when Field_exit,
							"010000" when Get_ArgSize, 
							"010001" when Get_ObjClsID, 
							"010010" when invoke_objref_ListClsID, 
							--"010011" when invoke_objref_next,
							"010100" when Save_objref_fm_heap,
							"010101" when Native_start,
							"010110" when Native_StackAdjusting1, 
							"010111" when Native_StackAdjusting2, 
							"011000" when Native_StackAdjusting3,
							"011001" when Native_ArgExporting_Reg, 
							"011010" when Native_ArgExporting_DDR,
							"011011" when Native_interrupt, 
							"011100" when Native_SpAdjusting,
							"011101" when Native_StackAdjustingReturn1, 
							"011110" when Native_StackAdjustingReturn2,
							"011111" when Native_exit,
							"100001" when Native_HW,
							"100010" when ClinitRetFrm1,
							"100011" when ClinitRetFrm2,
							"100100" when ClinitRetFrm3,
							"101000" when Wait_monEnter_succeed,
							"110110" when Wait4GC,
							"100101" when Others; 
     
     
	
        debug_cs_soj(5 downto 0)  <= debug_CTRL_state;
        debug_cs_soj(21 downto 6) <=  instrs_pkg; 
		debug_cs_soj(22) <= stall_all;
        debug_cs_soj(25 downto 23) <= 
                                                                    "001" when AASM = normal else
                                                                 "010" when AASM = wrIDReq else
                                                                "011" when AASM = wrID else
                                                                 "100" when AASM = wrLenReq else
                                                                   "101" when AASM = wrLen else
                                                                 "111";  
          
    
        
	------------------------
        -- mmes profiler
        ------------------------  
        label_enable_jaip_profiler_0 : if ENABLE_JAIP_PROFILER = 1 generate 
	prof_invoke_flag			<= '1' when(CTRL_state = Method_exit) else 
										'1' when(native_HW_en_tmp_dly = '1') else			-- prof for native HW
										'0';
	prof_return_flag			<= '1' when (instrs_pkg(7 downto 1) = "1110001" and stall_decode_stage = '0' and branch_flag = '0' and interrupt_req_tmp = '0') else
										'1' when (native_HW_cmplt_tmp = '1') else		-- prof for native HW
										'0';
	prof_DSRU_on				<= '0' when(CTRL_state = Normal) else
										'1';	 
	
	process(Clk)
	begin
                if(rising_edge(Clk)) then
                    if(Rst = '1') then
			mem_access_flag <= '0';
                    else
			if((external_load_req_tmp = '1' and external_load_req_reg = '0') or (external_store_req_tmp = '1' and external_store_req_reg = '0')) then
				mem_access_flag <= '1';
			elsif(external_access_cmplt = '1') then 
				mem_access_flag <= '0';
			end if;
                    end if;
                    ----
			if(CTRL_state = Native_start) then
				prof_DR2MA_mgt_mthd_id 		<= prof_native_mthd_id;
			elsif(CTRL_state = Method_entry) then
				prof_DR2MA_mgt_mthd_id 		<= DR2MA_mgt_mthd_id;
			end if; 
                    ----
		end if;
	end process;
	prof_mem_access_on <= mem_access_flag;
	
	prof_simple_issued_A_D <= prof_simple_issued_A_D_tmp;
	prof_simple_issued_B_D <= prof_simple_issued_B_D_tmp;
	prof_issued_bytecodes_D <= prof_issued_bytecodes_D_tmp;
        end generate;
    
-- end cs debug
end architecture rtl;