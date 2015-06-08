/* /////////////////////////////////////////////////////////////////// */
/*                                                                     */
/*   System Software of Dual-Core Java Runtime Environment             */
/*                                                                     */
/* ------------------------------------------------------------------- */
/*   File: main.c                                                      */
/*   Author: Kuan-Nian Su                                              */
/*   Date: Feb/24/2007                                                 */
/* ------------------------------------------------------------------- */
/*   The system software of MMES dual-core Java Runtime Environment.   */
/*   There are some features as follows :                              */
/*       1. Convert Java class file into Java runtime image. But this  */
/*          is FAT16 file system, the class file renames as .cls.      */
/*       2. Load Java runtime images into Method area and assign the   */
/*          initial pc & sp.                                           */
/*       3. Trigger the Java Bytecode Execution Engine core.           */
/*       4. Provide host service routine as ISR for Java Bytecode      */
/*          Execution Engine core.                                     */
/*                                                                     */
/*   Copyright, 2007.                                                  */
/*   Multimedia Embedded Systems Lab.                                  */
/*   Department of Computer Science and Information engineering        */
/*   National Chiao Tung University, Hsinchu 300, Taiwan               */
/* ------------------------------------------------------------------- */
/*   MODIFICATIONS                                                     */
/*                                                                     */
/*   Author: Kuan-Nian Su                                              */
/*   Date: Apr/2009                                                    */
/* ------------------------------------------------------------------- */
/*   MODIFICATIONS                                                     */
/*                                                                     */
/*   Author: Chien-Fong Huang                                          */
/*   Date: 09/2009                                                     */
/* /////////////////////////////////////////////////////////////////// */

// inclure xilinx library
#include <xio.h>
#include <xparameters.h>
#include <xutil.h>
#include <xexception_l.h>
#include <string.h>
#include <xintc_l.h>

// include self definition library
#include "../include/jpl.h"
#include "../include/mmes_jpl.h"
#include "../include/class_structure.h"
#include "../include/class_loader.h"
#include "../include/class_manager.h"
#include "../include/file.h"
#include "../include/mem_dbg.h"
#include "../include/heap_manager.h"
#include "../include/class_mt_manager.h"
#include "../include/native_method.h"
#include "../include/debug_option.h"

#include "xil_macroback.h"
#include "xintc_l.h"
#include "../include/jaip.h"
#include "mb_interface.h"

/* ------------------------------------------------------------------- */
/*               Extern Global Variables Declaration                   */
/* ------------------------------------------------------------------- */

// declaration the class file reading buffer
unsigned char classfile[MAX_BUFFER_SIZE];
unsigned char sys_jar_image[MAX_BUFFER_SIZE];
unsigned long sys_jar_size;

// defien the ptr of 2nd-level method area
extern volatile unsigned short *METHOD_AREA_PTR;
extern struct nativeMethod nativeMethodTable[54];
extern uint16 JavaLangString;
extern uint16 main_cls_id ;
extern uint16 main_mthd_id;
//extern volatile unsigned int CURRENT_HEAP_PTR;
//unsigned int parameterSpace[8] = {0};
extern volatile unsigned int parameterSpace[8];
unsigned int debug_number[2048] = {0};
// for fixing multiple main method bug , 2013.7.16
char *main_class_fully_qualified_name;


#if new_newarray_prof
	unsigned int new_total_time = 0;
	unsigned int new_array_total_time = 0;
	unsigned int num_of_time_new = 0;
	unsigned int num_of_time_newarray = 0;
#endif

char    name[] = { "system" };

#define JPL_debug_flag_off  0x00000000
#define cls_profile_table   0x00000001
#define cls_residence_table 0x00000002
#define CTRL_state          0x00000003
#define mem_access_list     0x00000004
#define cls_cache           0x00000005

#define invoke              0x00000006
#define invoke_cycle        0x00000007
#define get_fd              0x00000008
#define get_fd_cycle        0x00000009
#define put_fd              0x0000000A
#define put_fd_cycle        0x0000000B
#define debug_data_DR       0x0000000F
#define jpc                 0x00000010
#define instr2_1            0x00000012
#define bytecodes           0x00000018
#define SP_reg              0x00000016
#define VP_reg              0x00000015
#define userlogic_reg       0x00000019

#define double_issue        0x00000001
#define not_double_issue    0x00000002
#define nopnop              0x00000003
#define Normal_nopnop       0x00000004
#define instrs_pkg_FF       0x00000005
#define ucode_nopnop        0x00000006
#define nopflag             0x00000007

#define cls_num             0x0000001D
#define print_stack         0x00000020
#define print_LV            0x00000021
#define debug_data_fetch    0x00000023
#define stall_all_reg       0x00000025
#define stall_fetch_stage_reg 0x00000026
#define stack_depth         0x00000027
#define field_cnt         0x00000028
#define methd_cnt         0x00000029
#define ll                0x0000002a
#define la                0x0000002b
#define ls                0x0000002c
#define sl                0x0000002d
#define sa                0x0000002e
#define ss                0x0000002f
#define al                0x00000030
#define as                0x00000031
#define aa                0x00000032
#define exception_cycle   0x00000034
#define exception_LUT     0x00000035
#define MA_block_num      0x00000036

extern void print_reg(unsigned int type,unsigned int num);
//jpc history
#define JPC_debug                  ((volatile int *)JPL_MEM_ADDRESS + 0x20)
#define JPC_debug2                 ((volatile int *)JPL_MEM_ADDRESS + 0x24)

extern mt_table_count;
// profiling about the number used for field info/method info in cross reference table .
extern uint num_entry_xrt_field_count;
extern uint num_entry_xrt_method_count;

extern unsigned int recursive_new_array(unsigned char type, unsigned char number, unsigned char last_create_flag);
//extern global_mthd_id;

/* ------------------------------------------------------------------- */
/*                          Main Function                              */
/* ------------------------------------------------------------------- */
/* The execution flow is as follows :                                  */
/*   1. System Initialization                                          */
/*   2. Load the main class file and generate it into runtime image    */
/*   3. Load the other class files and link                            */
/*   4. Enable the Java Bytecode Execution Engine                      */
/* ------------------------------------------------------------------- */
/*                                                                     */
int
main(void)
{
    SYSACE_FILE *fptr;
    int     idx,khw;
    int     IsClinit = 0;


        unsigned int tmp0 ;
        unsigned int tmp1,i ;
        unsigned int now_mthd_id ;
        unsigned int jpc_reg ;
        unsigned int jpc_out ;

        unsigned int bytecodes_t ;
        unsigned int now_cls_id ;
        unsigned int B0 ;
        unsigned int B1 ;
        int tmp = 0,zdx=0;
          int numbyte =0;
          unsigned int *address;
          char fieldname[80],methodname[80],desname[150];
          uint8 default_core_id = 0;

    microblaze_enable_interrupts();

    volatile uint* JPL0_CTRL_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(0,JPL_CTRL_REG);
    volatile uint* JPL1_CTRL_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(1,JPL_CTRL_REG);
    volatile uint* JPL2_CTRL_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(2,JPL_CTRL_REG);
    volatile uint* JPL3_CTRL_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(3,JPL_CTRL_REG);
    volatile uint* JPL0_CTRL_REG_SlvAddr_volatile = (uint*)GET_CTRL_REG_BASEADDR(0,JPL_CTRL_REG);
    volatile uint* JPL1_CTRL_REG_SlvAddr_volatile = (uint*)GET_CTRL_REG_BASEADDR(1,JPL_CTRL_REG);
    volatile uint* JPL2_CTRL_REG_SlvAddr_volatile = (uint*)GET_CTRL_REG_BASEADDR(2,JPL_CTRL_REG);
    volatile uint* JPL3_CTRL_REG_SlvAddr_volatile = (uint*)GET_CTRL_REG_BASEADDR(3,JPL_CTRL_REG);
    volatile uint* JPL0_XCPTN_ENABLE_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(0,JPL_XCPTN_ENABLE);
    volatile uint* JPL1_XCPTN_ENABLE_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(1,JPL_XCPTN_ENABLE);
    volatile uint* JPL2_XCPTN_ENABLE_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(2,JPL_XCPTN_ENABLE);
    volatile uint* JPL3_XCPTN_ENABLE_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(3,JPL_XCPTN_ENABLE);
    volatile uint* JPL0_THREAD_MGT_TIME_SLICE_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(0,THREAD_MGT_TIME_SLICE);
    volatile uint* JPL1_THREAD_MGT_TIME_SLICE_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(1,THREAD_MGT_TIME_SLICE);
    volatile uint* JPL2_THREAD_MGT_TIME_SLICE_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(2,THREAD_MGT_TIME_SLICE);
    volatile uint* JPL3_THREAD_MGT_TIME_SLICE_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(3,THREAD_MGT_TIME_SLICE);
    volatile uint *JPL_TOTAL_TIME_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(default_core_id, JPL_TOTAL_TIME_REG);
    volatile uint *JPL_NONINTRPT_TIME_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(default_core_id, JPL_NONINTRPT_TIME_REG);
    volatile uint *JPL_INTRPT_TIME_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(default_core_id, JPL_INTRPT_TIME_REG);

    // assign core ID to each JAIP core
    *JPL0_CTRL_REG_volatile = (*JPL0_CTRL_REG_volatile & 0x9FFFFFFF) | (0<<29);
    *JPL1_CTRL_REG_volatile = (*JPL1_CTRL_REG_volatile & 0x9FFFFFFF) | (1<<29);
    *JPL2_CTRL_REG_volatile = (*JPL2_CTRL_REG_volatile & 0x9FFFFFFF) | (2<<29);
    *JPL3_CTRL_REG_volatile = (*JPL3_CTRL_REG_volatile & 0x9FFFFFFF) | (3<<29);

    // enable exception handler
    *JPL0_XCPTN_ENABLE_volatile = 0xF0000000;
    *JPL1_XCPTN_ENABLE_volatile = 0xF0000000;
    *JPL2_XCPTN_ENABLE_volatile = 0xF0000000;
    *JPL3_XCPTN_ENABLE_volatile = 0xF0000000;
    //*JPL_XCPTN_ENABLE = 0xF0000000;
    //0xFFFFFFFF;
    //*JPL_XCPTN_ENABLE = 0;

    xil_printf("\r\n=======================================================");
    xil_printf("\r\n--  MMES Dual-core Java Runtime Environment Running  --");
    xil_printf("\r\n=======================================================");
    xil_printf("\r\n");

    /// TMT GC version 1
    // Read system.jar into memory.
    if ((fptr = sysace_fopen("a:\\jar\\test.jar", "r")) == NULL)
    //if ((fptr = sysace_fopen("a:\\system.jar", "r")) == NULL)
    {
        xil_printf("ERROR: system.jar open failure.\r\n");
    }

    sys_jar_size = sysace_fread(sys_jar_image, 1, MAX_BUFFER_SIZE, fptr);

    //xil_printf("sys_jar_size:x\r\n",sys_jar_size);

    sysace_fclose(fptr);

    CURRENT_HEAP_PTR		   = HEAP_MEM_AREA_ADDRESS;
#if ENABLE_JAIP_CORE1
#endif
    //CURRENT_HEAP_PTR = ARRAY_POOL_ADDRESS;
    // Initialize the interrupt handling routine
   /* XExc_Init();
    XExc_RegisterHandler(XEXC_ID_CRITICAL_INT,
                         (XExceptionHandler) Host_Service_Routines, (void *) 0);
    JPL_EnableInterrupt((int *) XPAR_JAIP_0_BASEADDR);
    XExc_mEnableExceptions(XEXC_CRITICAL);*/
    // setup ISR function
    // core 0
    XIntc_RegisterHandler(XPAR_XPS_INTC_0_BASEADDR,
           		XPAR_XPS_INTC_0_JAIP_0_IP2INTC_IRPT_INTR,
           		(XInterruptHandler)Host_Service_Routines, (void *)JPL0_CTRL_REG_SlvAddr_volatile);
    JAIP_mWriteReg( (void *)JPL0_CTRL_REG_SlvAddr_volatile, JAIP_INTR_IPIER_OFFSET, 0x00000001);
    JAIP_mWriteReg( (void *)JPL0_CTRL_REG_SlvAddr_volatile, JAIP_INTR_DGIER_OFFSET, INTR_GIE_MASK);
    // core 1
   XIntc_RegisterHandler(XPAR_XPS_INTC_0_BASEADDR,
		   	   	   XPAR_XPS_INTC_0_JAIP_1_IP2INTC_IRPT_INTR,
		   	   	 (XInterruptHandler)Host_Service_Routines, (void *)JPL1_CTRL_REG_SlvAddr_volatile);
   JAIP_mWriteReg((void *)JPL1_CTRL_REG_SlvAddr_volatile, JAIP_INTR_IPIER_OFFSET, 0x00000001);
   JAIP_mWriteReg((void *)JPL1_CTRL_REG_SlvAddr_volatile, JAIP_INTR_DGIER_OFFSET, INTR_GIE_MASK);

   // core 2
   XIntc_RegisterHandler(XPAR_XPS_INTC_0_BASEADDR,
		   	   	   XPAR_XPS_INTC_0_JAIP_2_IP2INTC_IRPT_INTR,
		   	   	 (XInterruptHandler)Host_Service_Routines, (void *)JPL2_CTRL_REG_SlvAddr_volatile);
   JAIP_mWriteReg((void *)JPL2_CTRL_REG_SlvAddr_volatile, JAIP_INTR_IPIER_OFFSET, 0x00000001);
   JAIP_mWriteReg((void *)JPL2_CTRL_REG_SlvAddr_volatile, JAIP_INTR_DGIER_OFFSET, INTR_GIE_MASK);
   // core 3
   XIntc_RegisterHandler(XPAR_XPS_INTC_0_BASEADDR,
		   	   	   XPAR_XPS_INTC_0_JAIP_3_IP2INTC_IRPT_INTR,
		   	   	 (XInterruptHandler)Host_Service_Routines, (void *)JPL3_CTRL_REG_SlvAddr_volatile);
   JAIP_mWriteReg((void *)JPL3_CTRL_REG_SlvAddr_volatile, JAIP_INTR_IPIER_OFFSET, 0x00000001);
   JAIP_mWriteReg((void *)JPL3_CTRL_REG_SlvAddr_volatile, JAIP_INTR_DGIER_OFFSET, INTR_GIE_MASK);


       //JPL_EnableInterrupt((int *) XPAR_JAIP_0_BASEADDR);
       XIntc_mMasterEnable(XPAR_XPS_INTC_0_BASEADDR);
       XIntc_mEnableIntr(XPAR_XPS_INTC_0_BASEADDR, XPAR_JAIP_0_IP2INTC_IRPT_MASK);



    // initialize the heap memory area
    initialize_heapmemory();
    // initialize the 2vd-level method area
    initialize_methodarea();
    // init temp monitor
    init_temp_lock();

    // initialize level-1 cross reference table , modified by T.H.Wu , 2013.8.13
	//memset( (uint*)(0x88018000) , 0xFFFFFFFF, (0x5000>>2));

    // add this for time slice of each thread in thread management.
    // *THREAD_MGT_TIME_SLICE = 0x7a12;
    //*THREAD_MGT_TIME_SLICE = 8333 + 1*2200; // 2013.8.29
    //*THREAD_MGT_TIME_SLICE = 8333 + 1*3000; // 2013.8.29
    //*THREAD_MGT_TIME_SLICE = 8333 + 1*2337;
    //*THREAD_MGT_TIME_SLICE = 8333 + 1*2667;
    uint time_slice_specified = (83.3333 * 20) + 1;
    *JPL0_THREAD_MGT_TIME_SLICE_volatile = time_slice_specified;
    *JPL1_THREAD_MGT_TIME_SLICE_volatile = time_slice_specified;
    *JPL2_THREAD_MGT_TIME_SLICE_volatile = time_slice_specified;
    *JPL3_THREAD_MGT_TIME_SLICE_volatile = time_slice_specified;
    //*THREAD_MGT_TIME_SLICE = 12500;

    xil_printf("\r\n == %s ==\r\n", name);
    // main class name
    //jar_load_class(sys_jar_image, sys_jar_size, (char *) "bubmain.class",&IsClinit);

    //*(unsigned int *)0xc1008000 = 0x12345678;
    //xil_printf("%x\r\n",*(unsigned int *)0xc1008000);
	
    // set the fully-qualified main class name , before parsing any classes.
    main_class_fully_qualified_name = malloc(80*sizeof(uint8) );

  // **************** jembench serial benchmark test OK , 2013.8.1  *********************
   //main_class_fully_qualified_name = "jembench/kernel/BubbleSort_verify.class";
   //main_class_fully_qualified_name = "jembench/kernel/BubbleSort_profile.class";
   //main_class_fully_qualified_name = "jembench/kernel/Sieve_verify.class";
   //main_class_fully_qualified_name = "jembench/kernel/Sieve_profile.class";
   //main_class_fully_qualified_name = "jembench/application/BenchKfl_verify.class" ;
   //main_class_fully_qualified_name = "jembench/application/BenchKfl_profile.class" ;

   //main_class_fully_qualified_name =  "jembench/application/BenchLift_verify.class";
   //main_class_fully_qualified_name =  "jembench/application/BenchLift_profile.class";
   //main_class_fully_qualified_name =  "jembench/kernel/Pi_verify.class";
   //main_class_fully_qualified_name =  "jembench/kernel/Pi_profile.class";
   //main_class_fully_qualified_name =  "jembench/kernel/Logic_verify.class";
   //main_class_fully_qualified_name =  "jembench/kernel/Logic_profile.class";
   //main_class_fully_qualified_name =  "jembench/application/BenchUdpIp_verify.class";
   //main_class_fully_qualified_name =  "jembench/application/BenchUdpIp_profile.class";

    //main_class_fully_qualified_name = "Pi.class";
    //main_class_fully_qualified_name = "test/testobj.class";
   //main_class_fully_qualified_name = "areturn.class";
 	// *** for correctness test of StringAtom, caffeine mark
   // main_class_fully_qualified_name =  "mycaffeine/CFSTPT.class" ;
    // *** for performance test of StringAtom, caffeine mark
    //main_class_fully_qualified_name = "mycaffeine/CFSTSC.class";
    main_class_fully_qualified_name = "test.class";

    // ************* jembench parallel benchmark test OK , 2013.8.21 *************
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core1_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core2_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core3_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core4_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core5_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core8_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core10_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core12_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core14_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core16_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core24_verify.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core30_verify.class";
   //
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core1_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core2_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core3_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core4_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core5_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core8_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core10_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core12_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core14_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core16_profile.class";
    // it gets stuck at time slice 83.3*47 + 1
    //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core17_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core20_profile.class";
   // it may hang during execution
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core24_profile.class";
   //main_class_fully_qualified_name = "jembench/EnumeratedParallelBenchmark_main/core30_profile.class";

	  //main_class_fully_qualified_name = "jembench/parallel/Logic_main/core1_verify.class";
	  //main_class_fully_qualified_name = "jembench/parallel/Logic_main/core2_verify.class";
	  //main_class_fully_qualified_name = "jembench/parallel/Logic_main/core3_verify.class";
	  //main_class_fully_qualified_name = "jembench/parallel/Logic_main/core4_verify.class";
	  //main_class_fully_qualified_name = "jembench/parallel/Logic_main/core5_verify.class";
	  //main_class_fully_qualified_name = "jembench/parallel/Logic_main/core8_verify.class";
	  //main_class_fully_qualified_name = "jembench/parallel/Logic_main/core16_verify.class";
   	//
	//main_class_fully_qualified_name = "jembench/parallel/Logic_main/core1_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Logic_main/core2_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Logic_main/core3_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Logic_main/core4_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Logic_main/core5_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Logic_main/core8_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Logic_main/core16_profile.class";
	// it gets stuck at time slice 83.3*47 + 1 , 83.3*43 + 1

	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core1_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core2_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core3_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core4_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core5_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core8_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core10_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core12_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core14_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core15_verify.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core16_verify.class";
    //
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core1_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core2_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core3_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core4_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core5_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core8_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core10_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core12_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core14_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core15_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/Matrix_Mul_main/core16_profile.class";
	// it gets stuck at time slice 83.3*43 + 1
    //
    // note by T.H.Wu , 2013.10.31 , NQueen can not be examined yet  because current heap pointer.
    // in each JAIP core is inco nsistent, it leads to unexpected error during execution.
    //main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core1_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core2_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core3_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core4_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core5_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core8_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core10_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core12_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core14_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core15_profile.class";
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core16_profile.class";
	// it gets stuck at time slice 83.3*50 + 1  ,(83.333 * 47) + 61
	//main_class_fully_qualified_name = "jembench/parallel/NQueens_main/core32_profile.class"; // it may halt
	// can't execute with time slice 833*5 + 17

    // ************ XML parser ****************
    //main_class_fully_qualified_name = "nanoxml/txtNXML.class";



   //main_class_fully_qualified_name = "jembench/kernel/Pi_CJver.class";
   //main_class_fully_qualified_name = "jembench/kernel/Logic_CJver.class";

    // 2014.1.6, for executing original (unmodified) Jembench
   // main_class_fully_qualified_name = "jembench/Main.class";
    //main_class_fully_qualified_name = "jembench/cmp/EjipBenchCMP.class";



	//parse ArithmeticException.class and new a obj
    jar_load_class(default_core_id,sys_jar_image,sys_jar_size,
    				(char *) "java/lang/ArithmeticException.class",&IsClinit);
    jar_load_class(default_core_id,sys_jar_image,sys_jar_size,
    				(char *) "java/lang/ArrayIndexOutOfBoundsException.class",&IsClinit);
    jar_load_class(default_core_id,sys_jar_image,sys_jar_size,
    				(char *) "java/lang/ArrayStoreException.class",&IsClinit);
    jar_load_class(default_core_id,sys_jar_image,sys_jar_size,
    				(char *) "java/lang/NullPointerException.class",&IsClinit);
    jar_load_class(default_core_id,sys_jar_image,sys_jar_size,
    				(char *) "java/lang/Object.class",&IsClinit);
	//*(unsigned int*)CURRENT_HEAP_PTR = 0;
	//CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (x_ref_tbl[0].obj_size<<2);

    JavaLangString = jar_load_class(default_core_id, sys_jar_image,sys_jar_size,
    						(char *) "java/lang/String.class",&IsClinit);
    //MMES profiler disable
    //jar_load_class(sys_jar_image,sys_jar_size,(char *) "MMESProfiler.class",&IsClinit);
    jar_load_class(default_core_id, sys_jar_image,sys_jar_size,(char *) "java/lang/System.class",&IsClinit);
    //jar_load_class(sys_jar_image,sys_jar_size,(char *) "nanoxml/XMLParseException.class",&IsClinit);
    // added for test load Thread class
    //jar_load_class(sys_jar_image,sys_jar_size,(char *) "java/lang/Thread.class",&IsClinit);
    // finally parse main class
    //jar_load_class(sys_jar_image,sys_jar_size,(char *) "jembench/kfl_profile/Mast.class", &IsClinit);
    jar_load_class(default_core_id, sys_jar_image,sys_jar_size,(char *) main_class_fully_qualified_name, &IsClinit);
    xil_printf("\r-- Java core is Executing ... \r\n");
    

    // Enable the Java Bytecode Execution Engine
    // will be modified under multi-core JAIP execution , by T.H.Wu , 2013.9.9
    //*GET_CTRL_REG_MEM0ADDR(default_core_id,JPL_CTRL_REG) =
    //			(*GET_CTRL_REG_MEM0ADDR(0,JPL_CTRL_REG) & 0x7FFFFFFF) | (1<<31);

    /*
     *
     * COOR_MAIN_CLS_MTHD_ID = (main_cls_id<<16 | main_mthd_id);
     *
     * *COOR_CMD_MSG = (0x4<<29) | (0x3<<25) | (0x00000000);
     * *COOR_CMD_MSG = (0x00000000);
     *
     * while( (*GET_CTRL_REG_MEM0ADDR(0,JPL_CTRL_REG) & 0x80000000)==0x0 );
     * while(
     * 		(*GET_CTRL_REG_MEM0ADDR(0,JPL_CTRL_REG) & 0x80000000)!=0x0 ||
     * 		(*GET_CTRL_REG_MEM0ADDR(1,JPL_CTRL_REG) & 0x80000000)!=0x0 ||
     * 		(*GET_CTRL_REG_MEM0ADDR(2,JPL_CTRL_REG) & 0x80000000)!=0x0 ||
     * 		(*GET_CTRL_REG_MEM0ADDR(3,JPL_CTRL_REG) & 0x80000000)!=0x0
     * 		)
     *
     * */
    ///for(idx = 0 ;idx < 100;idx ++)jdx++;
    khw = 0;

    // note , 2013.9.5 , multicore JAIP
    // (including main thread to JAIP 0)

    *COOR_MAIN_CLS_MTHD_ID = (main_cls_id<<16 | main_mthd_id);

    //*(uint*)0x88080204 = (0x4<<29) | (0x3<<25) | (0x00000000);
    *COOR_CMD_MSG = (0x4<<29) | (0x3<<26) | (0x00000000);
    //*COOR_CMD_MSG = (0x00000000);
    while( (*JPL0_CTRL_REG_volatile & 0x80000000)==0x0 );
    //xil_printf("[JAIP debug] the first core is active now. \r\n");
    while(
          (*JPL0_CTRL_REG_volatile & 0x80000000)!=0x0
          //2014.3.17, the following 3 lines of code may lead to JAIP crash...
          //|| (*JPL1_CTRL_REG_volatile & 0x80000000)!=0x0
          //|| (*JPL2_CTRL_REG_volatile & 0x80000000)!=0x0
          //|| (*JPL3_CTRL_REG_volatile & 0x80000000)!=0x0
     )
    //while ( *GET_CTRL_REG_MEM0ADDR(default_core_id,JPL_CTRL_REG) )
    {
#if print_jpc_records
    	print_reg(exception_cycle, 0);
    	print_reg(MA_block_num, 0);
#endif
        //view_memory((Xuint32 * )METHOD_AREA_ADDRESS , 1024);
	    // xil_printf("%x\r\n",*(Xuint32 * )0xC4008000);
		// xil_printf("%x\r\n",*(Xuint32 * )0xC4008004);
		// xil_printf("%x\r\n",*(Xuint32 * )0xC4008008);
        //  xil_printf("Control  %x \r\n",*JPL_CTRL_REG);
        //  xil_printf("Control  %x \r\n",*JPL_SERVICE_ID);

#if maindebug

    	 xil_printf("\r\n========================================================");
    	    xil_printf("\r\n CST info");
    	    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x52;
    	    print_reg(ll,0);
    	    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x54;
    	    print_reg(ll,0);
    	    xil_printf("\r\n debug_data_MA");
    	    print_reg(la,0);
    	    print_reg(ls,0);
    	    print_reg(sl,0);
    	    print_reg(sa,0);
    	    print_reg(ss,0);
    	    print_reg(al,0);

    	khw++;

        xil_printf("\r\n--                    --\r\n");
        xil_printf("\r\n-- while loop in main --\r\n");
        xil_printf("\r\n--                    --\r\n");
        xil_printf("DynamicResolution        %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3));
        xil_printf("now cls ID               %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG4));
        xil_printf("class info               %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG5));
        xil_printf("A %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
        xil_printf("B %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
        xil_printf("C %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
        print_reg(SP_reg, 0);
        print_reg(VP_reg, 0);
        print_reg(CTRL_state, 0);
        print_reg(jpc, 0);
        print_reg(instr2_1, 0);
        print_reg(bytecodes, 0);
        print_reg(cls_num,0);
        print_reg(methd_cnt,0);
        xil_printf("\r\n--                    --\r\n");
        xil_printf("\r\n--   while loop end   --\r\n");
        xil_printf("\r\n--                    --\r\n");

#endif

#if newbufferedebug
        // debug_data=XPAR_JAIP_0_MEM0_BASEADDR;
#if print_ddr
        xil_printf("\r\nMETHOD_TABLE_ADDRESS\r\n");
        view_memory((Xuint32 *) METHOD_TABLE_ADDRESS, 2048);
        xil_printf("\r\nMETHOD_AREA_ADDRESS\r\n");
        view_memory((Xuint32 * )METHOD_AREA_ADDRESS , 4096);
        xil_printf("\r\nHEAP\r\n");
       view_memory((Xuint32 * )HEAP_MEM_AREA_ADDRESS  , 1024);
#endif



#endif

#if print_jpc_records
       print_reg(exception_cycle, 0);
       xil_printf("\r\nnow_cls_id now_mthd_id jpc_reg bytecodes_t \r\n");
       for( i=0;i<256;i++){
               	*JPC_debug = 1<<9|i ;
               	*JPC_debug2= 1<<9|i ;

               	tmp0 = *JPC_debug;
               	tmp1 = *JPC_debug2;


               	now_mthd_id = (tmp0 & 0xffC00000)>>24;
               	jpc_reg     = (tmp0 & 0x00fff000)>>12;
               	jpc_out     = (tmp0 & 0x00000fff)   ;

               	bytecodes_t = (tmp1 & 0x0000ffff)    ;
               	now_cls_id  = (tmp1 & 0x00ff0000)>>16;
               	B0          = (tmp1 & 0x0f000000)>>24;
               	B1          = (tmp1 & 0xf0000000)>>28;

               	//debug_data=
               	//xil_printf("Print debug data:%8x  debug2: %8x   \r\n",*JPC_debug,*JPC_debug2);

               	xil_printf("%2x        %2x        %3x     %4x  %x %x\r\n",now_cls_id,now_mthd_id,jpc_reg,bytecodes_t,B1,B0);

               }
               *JPC_debug = 0;
               *JPC_debug2 = 0;
#endif

#if print_cross_ref_table
    xil_printf("\r\n====================================================\r\n");
    xil_printf("\r\n==              Cross Reference Table             ==\r\n");
    xil_printf("\r\n====================================================\r\n");
    for ( tmp = 0; tmp < global_num; tmp++)
    {
        xil_printf("=Global Index : %d\r\n", tmp);
        xil_printf("=Class name   : %s\r\n", x_ref_tbl[tmp].class_name);
        xil_printf("=Parent Index : %d\r\n", x_ref_tbl[tmp].parent_index);
        xil_printf("=Base_addres  : %x\r\n", x_ref_tbl[tmp].base_address);
        xil_printf("=Image Size   : %x\r\n", numbyte);
        xil_printf("=Is Interface : %d\r\n", x_ref_tbl[tmp].isIntf);
        xil_printf("=Object Size  : %x\r\n", x_ref_tbl[tmp].obj_size);
        xil_printf("=Intf count   : %d\r\n", x_ref_tbl[tmp].intf_cnt);

        for (zdx = 0; zdx < x_ref_tbl[tmp].intf_cnt; zdx++)
        {
            xil_printf(" ==intface    : %16s\r\n",x_ref_tbl[x_ref_tbl[tmp].intf[zdx]].class_name);
        }

        xil_printf("=Method count : %d\r\n", x_ref_tbl[tmp].method_cnt);
        for (zdx = 0; zdx < x_ref_tbl[tmp].method_cnt; zdx++)
        {
            address = x_ref_tbl[tmp].method[zdx].method_offset;
            memcpy(methodname,x_ref_tbl[tmp].method[zdx].method_name,x_ref_tbl[tmp].method[zdx].method_namel);
            memcpy(methodname+x_ref_tbl[tmp].method[zdx].method_namel,"\0",1);
            memcpy(desname,x_ref_tbl[tmp].method[zdx].descript_name,x_ref_tbl[tmp].method[zdx].descript_namel);
            memcpy(desname+x_ref_tbl[tmp].method[zdx].descript_namel,"\0",1);
            xil_printf(" ==Method     : %16s    offset : %.8x - %.8x\r\n",
                methodname, x_ref_tbl[tmp].method[zdx].method_offset,
                *(address));

            while(*address != 0xFFFFFFFF){
                xil_printf("%64.8x\r\n",*(address+1));
                if(*(address + 2) != 0xFFFFFFFF){
                    address = *(address + 2);
                    xil_printf("%64.8x\r\n",*(address));
                }
                else break;
            }

            xil_printf("   Descript   : %16s\r\n",desname);
        }

       // xil_printf("=Field count  : %d\r\n", x_ref_tbl[tmp].field_cnt);
        //xil_printf(" ==Non-Static Field count : %d\r\n", x_ref_tbl[tmp].obj_size - 1);
        //xil_printf(" ==Static Field count     : %d\r\n", x_ref_tbl[tmp].field_cnt - (x_ref_tbl[tmp].obj_size - 1));
		/*
        for (zdx = 0; zdx < x_ref_tbl[tmp].field_cnt; zdx++)
        {
            memcpy(fieldname,x_ref_tbl[tmp].field[zdx].field_name,x_ref_tbl[tmp].field[zdx].field_namel);
            memcpy(fieldname+x_ref_tbl[tmp].field[zdx].field_namel,"\0",1);
            address =
                x_ref_tbl[tmp].field[zdx].field_address;
            xil_printf(" ==Field cls  :                            : %.8x\r\n",
                x_ref_tbl[tmp].field[zdx].cls_id);
            xil_printf(" ==Field tag  :                            : %.8x\r\n",
                x_ref_tbl[tmp].field[zdx].field_tag);
            xil_printf(" ==Field      : %16s    offset : %.8x - %.8x\r\n",
                fieldname,
                x_ref_tbl[tmp].field[zdx].field_address,
                *(address));
        }*/
        // xil_printf("=Field  count   :  %d\r\n", x_ref_tbl[tmp].field_cnt);


        xil_printf("====================================================\r\n");
    }
#endif

#if print_ddr
        xil_printf("\r\nMETHOD_TABLE_ADDRESS\r\n");
        view_memory((Xuint32 *) METHOD_TABLE_ADDRESS, 2048);
        xil_printf("\r\nMETHOD_AREA_ADDRESS\r\n");
        view_memory((Xuint32 * )METHOD_AREA_ADDRESS , 4096);
        xil_printf("\r\nHEAP\r\n");
       view_memory((Xuint32 * )HEAP_MEM_AREA_ADDRESS  , 1024);
#endif
    }
    //xil_printf("Control0  %.8x \r\n",*(0x00000004));
/*#if print_ddr
        xil_printf("\r\nMETHOD_TABLE_ADDRESS\r\n");
        view_memory((Xuint32 *) METHOD_TABLE_ADDRESS, 2048);
        xil_printf("\r\nMETHOD_AREA_ADDRESS\r\n");
        view_memory((Xuint32 * )METHOD_AREA_ADDRESS , 4096);
        xil_printf("\r\nHEAP\r\n");
       view_memory((Xuint32 * )HEAP_MEM_AREA_ADDRESS  , 1024);
#endif*/
#if maindebug
    xil_printf("invoke_data_signal or arg1 %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1));
    xil_printf("cross_table_address_reg    %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG2));
    xil_printf("mst_address_reg            %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3));
    xil_printf("A %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
    xil_printf("B %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
    xil_printf("C %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
    view_memory((Xuint32 *) METHOD_TABLE_ADDRESS, 1024);
    view_memory((Xuint32 * )METHOD_AREA_ADDRESS , 5120);
	view_memory((Xuint32 * )HEAP_MEM_AREA_ADDRESS  , 1024);
    //view_memory((Xuint32 * )HEAP_MEM_AREA_ADDRESS  , 4096+4096);
    for(idx = 0 ; idx < 300 ; idx ++){
        xil_printf("%d\r\n",debug_number[idx]);
    }
#endif

    xil_printf("\r\n========================================================");
    xil_printf("\r\n== Java Core Total Execution Time (cycles) : %d ", *JPL_TOTAL_TIME_REG_volatile );
    xil_printf("\r\n==              HW Execution Time (cycles) : %d ", *JPL_NONINTRPT_TIME_REG_volatile );
    xil_printf("\r\n==          INTRPT Execution Time (cycles) : %d ", *JPL_INTRPT_TIME_REG_volatile );
    xil_printf("\r\n========================================================");

#if print_stack_depth
	print_reg(stack_depth, 0);
	print_reg(field_cnt,0);
	print_reg(methd_cnt,0);

#endif
	//print_reg(exception_cycle, 0);
	//print_reg(exception_LUT, 0);
    print_reg(double_issue, 0);
    print_reg(not_double_issue, 0);
    print_reg(nopnop, 0);
    print_reg(Normal_nopnop,0);
    print_reg(instrs_pkg_FF,0);
    print_reg(ucode_nopnop,0);
    print_reg(debug_data_fetch,0);
    print_reg(nopflag,0);
    print_reg(stall_all_reg,0);
    print_reg(stall_fetch_stage_reg,0);
    xil_printf("\r\n========================================================");
    xil_printf("\r\n");

    xil_printf("\r\n========================================================");
    // profiling about the number used for field info/method info in cross reference table .
    xil_printf("\r\n mt_table_count: %d ",	mt_table_count);
    xil_printf("\r\n num_entry_xrt_field_count: %d ",	num_entry_xrt_field_count);
    xil_printf("\r\n num_entry_xrt_method_count: %d ",	num_entry_xrt_method_count);
    xil_printf("\r\n method_count: %d ",	global_mthd_id);
    xil_printf("\r\n========================================================");


    xil_printf("\r\n========================================================");
    xil_printf("\r\ninstruction matches");
    print_reg(ll,0);
    print_reg(la,0);
    print_reg(ls,0);
    print_reg(sl,0);
    print_reg(sa,0);
    print_reg(ss,0);
    print_reg(al,0);
    print_reg(as,0);
    print_reg(aa,0);
    xil_printf("\r\n========================================================\r\n");
    xil_printf("CURRENT_HEAP_PTR: %x\r\n", CURRENT_HEAP_PTR);

#if print_cross_ref_end
    xil_printf("\r\n====================================================\r\n");
    xil_printf("\r\n==              Cross Reference Table             ==\r\n");
    xil_printf("\r\n====================================================\r\n");
    for ( tmp = 0; tmp < global_num; tmp++)
    {
        xil_printf("=Global Index : %d\r\n", tmp);
        xil_printf("=Class name   : %s\r\n", x_ref_tbl[tmp].class_name);
        xil_printf("=Parent Index : %d\r\n", x_ref_tbl[tmp].parent_index);
        xil_printf("=Base_addres  : %x\r\n", x_ref_tbl[tmp].base_address);
        xil_printf("=Image Size   : %x\r\n", numbyte);
        xil_printf("=Is Interface : %d\r\n", x_ref_tbl[tmp].isIntf);
        xil_printf("=Object Size  : %x\r\n", x_ref_tbl[tmp].obj_size);
        xil_printf("=Intf count   : %d\r\n", x_ref_tbl[tmp].intf_cnt);

        for (zdx = 0; zdx < x_ref_tbl[tmp].intf_cnt; zdx++)
        {
            xil_printf(" ==intface    : %16s\r\n",x_ref_tbl[x_ref_tbl[tmp].intf[zdx]].class_name);
        }

        xil_printf("=Method count : %d\r\n", x_ref_tbl[tmp].method_cnt);
        for (zdx = 0; zdx < x_ref_tbl[tmp].method_cnt; zdx++)
        {
            address = x_ref_tbl[tmp].method[zdx].method_offset;
            memcpy(methodname,x_ref_tbl[tmp].method[zdx].method_name,x_ref_tbl[tmp].method[zdx].method_namel);
            memcpy(methodname+x_ref_tbl[tmp].method[zdx].method_namel,"\0",1);
            memcpy(desname,x_ref_tbl[tmp].method[zdx].descript_name,x_ref_tbl[tmp].method[zdx].descript_namel);
            memcpy(desname+x_ref_tbl[tmp].method[zdx].descript_namel,"\0",1);
            xil_printf(" ==Method     : %16s    offset : %.8x - %.8x\r\n",
                methodname, x_ref_tbl[tmp].method[zdx].method_offset,
                *(address));

            while(*address != 0xFFFFFFFF){
                xil_printf("%64.8x\r\n",*(address+1));
                if(*(address + 2) != 0xFFFFFFFF){
                    address = *(address + 2);
                    xil_printf("%64.8x\r\n",*(address));
                }
                else break;
            }

            xil_printf("   Descript   : %16s\r\n",desname);
        }

       // xil_printf("=Field count  : %d\r\n", x_ref_tbl[tmp].field_cnt);
        //xil_printf(" ==Non-Static Field count : %d\r\n", x_ref_tbl[tmp].obj_size - 1);
        //xil_printf(" ==Static Field count     : %d\r\n", x_ref_tbl[tmp].field_cnt - (x_ref_tbl[tmp].obj_size - 1));
		/*
        for (zdx = 0; zdx < x_ref_tbl[tmp].field_cnt; zdx++)
        {
            memcpy(fieldname,x_ref_tbl[tmp].field[zdx].field_name,x_ref_tbl[tmp].field[zdx].field_namel);
            memcpy(fieldname+x_ref_tbl[tmp].field[zdx].field_namel,"\0",1);
            address =
                x_ref_tbl[tmp].field[zdx].field_address;
            xil_printf(" ==Field cls  :                            : %.8x\r\n",
                x_ref_tbl[tmp].field[zdx].cls_id);
            xil_printf(" ==Field tag  :                            : %.8x\r\n",
                x_ref_tbl[tmp].field[zdx].field_tag);
            xil_printf(" ==Field      : %16s    offset : %.8x - %.8x\r\n",
                fieldname,
                x_ref_tbl[tmp].field[zdx].field_address,
                *(address));
        }*/
        // xil_printf("=Field  count   :  %d\r\n", x_ref_tbl[tmp].field_cnt);
        xil_printf("====================================================\r\n");
    }
#endif
#if new_newarray_prof
    xil_printf("new obj total time:%X\r\n", new_total_time);
    xil_printf("new array total time:%X\r\n", new_array_total_time);
    xil_printf("number of time new object: %X\r\n", num_of_time_new);
    xil_printf("number of time new array: %X\r\n", num_of_time_newarray);
#endif
#if print_method_profile || print_bytecode_profile
    unsigned int HW_time_tmp, Intrpt_time_tmp, DR_time_tmp, Mem_time_tmp ,Num_of_calls;
#endif

#if print_method_profile
    printf("-----------------------------------------------------\r\n");
    printf("--------------------Method Profile-------------------\r\n");
    printf("-----------------------------------------------------\r\n");
    for(i = 0; i < global_mthd_id ; ++i){
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 0;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 0;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 0;
    	HW_time_tmp = *JPL_MTHD_PROFILE;
    	printf("Method #%X HW time:%u \r\n", i, HW_time_tmp);

    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 1 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 1 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 1 << 2;
		Intrpt_time_tmp = *JPL_MTHD_PROFILE;
    	printf("Method #%X Intrpt time:%u \r\n", i, Intrpt_time_tmp);

    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 2 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 2 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 2 << 2;
		DR_time_tmp = *JPL_MTHD_PROFILE;
    	printf("Method #%X DR time:%u \r\n", i, DR_time_tmp);

    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 3 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 3 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 3 << 2;
    	Mem_time_tmp = *JPL_MTHD_PROFILE;
    	printf("Method #%X Mem time:%u \r\n", i, Mem_time_tmp);

    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 4 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 4 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 4 << 2;
    	Num_of_calls = *JPL_MTHD_PROFILE;
    	printf("Method #%X Number of calls:%u \r\n", i, Num_of_calls);
    	printf("-----------------------------------------------------\r\n");
    }
#endif
#if print_bytecode_profile
    printf("-----------------------------------------------------\r\n");
    printf("--------------------Bytecode Profile-------------------\r\n");
    printf("-----------------------------------------------------\r\n");
    for(i = 0; i < 256 ; ++i){
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 0;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 0;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 0;
    	HW_time_tmp = *JPL_BC_PROFILE;
    	printf("Bytecode #%X HW_Time: %u \r\n", i, HW_time_tmp);

    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 1 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 1 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 1 << 2;
		Intrpt_time_tmp = *JPL_BC_PROFILE;
    	printf("Bytecode #%X Intrpt_Time: %u \r\n", i, Intrpt_time_tmp);

    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 2 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 2 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 2 << 2;
		DR_time_tmp = *JPL_BC_PROFILE;
    	printf("Bytecode #%X DR_Time: %u \r\n", i, DR_time_tmp);

    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 3 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 3 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 3 << 2;
    	Mem_time_tmp = *JPL_BC_PROFILE;
    	printf("Bytecode #%X Mem_Time: %u \r\n", i, Mem_time_tmp);

    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 4 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 4 << 2;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i << 5 | 4 << 2;
    	Num_of_calls = *JPL_BC_PROFILE;
    	printf("Bytecode #%X #used: %u \r\n", i, Num_of_calls);
    	printf("-----------------------------------------------------\r\n");
    }
#endif

    xil_printf("\r\nfinish");




    return 0;
}

/* ------------------------------------------------------------------- */
/*                      Host Service Routines                          */
/* The service ID are as follows :                                     */
/*   ID 1. Memory allocation for new array                             */
/*   ID 7. I/O print out service                                       */
/* ------------------------------------------------------------------- */

unsigned short
read_uint16_main(unsigned char *p)
{
    return (p[0] << 8) + p[1];
}

unsigned int recursive_new_array(unsigned char type, unsigned char number, unsigned char last_create_flag){

    unsigned int return_value;
    int idx;
    int length = (int)parameterSpace[number];
    if(number == 0){

        if(last_create_flag == 1){
            if (type == 4) //boolean (use one byte represent)
            {
        #if nativedebug
                printf("new array with boolean type.\n");
        #endif
				heap_align32();
                *(unsigned int*)CURRENT_HEAP_PTR = 0x88000000;
                CURRENT_HEAP_PTR +=4;
                *(unsigned int*)CURRENT_HEAP_PTR = length;
                CURRENT_HEAP_PTR +=4;
                return_value = CURRENT_HEAP_PTR;
                
                if((length & 0x00000003) != 0){
                	CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length&0xFFFFFFFC) + 4;
                }
                else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + length;
				heap_align32();
                /*
                heap[mt_table_count++] = 0x88000000;
                heap[mt_table_count++] = length;
                return_value = (int)&heap[mt_table_count];
                if((length & 0x00000003) != 0){
                    mt_table_count = mt_table_count + (length>>2) + 1;
                }
                else mt_table_count = mt_table_count + (length>>2);
                */
            }
            else if (type == 5) //char
            {
        #if nativedebug
                printf("new array with char type.\n");
        #endif
				heap_align32();
                *(unsigned int*)CURRENT_HEAP_PTR = 0x50000000;				// modified by C.C. Hsu
                CURRENT_HEAP_PTR +=4;
                *(unsigned int*)CURRENT_HEAP_PTR = length;
                CURRENT_HEAP_PTR +=4;
                return_value = CURRENT_HEAP_PTR;
                if((length & 0x00000001) != 0){								// modified by C.C. Hsu
                	CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + ((length<<1)&0xFFFFFFFC) + 4;			// modified by C.C. Hsu
                }
                else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<1);							// modified by C.C. Hsu
				heap_align32();
                /*
                heap[mt_table_count++] = 0x88000000;
                heap[mt_table_count++] = length;
                return_value = (int)&heap[mt_table_count];
                if((length & 0x00000003) != 0){
                    mt_table_count = mt_table_count + (length>>2) + 1;
                }
                else mt_table_count = mt_table_count + (length>>2);
                */
            }
            else if (type == 6) //float
            {
        #if nativedebug
                printf("It's not support!!\n");
                printf("new array with float type.\n");
        #endif
            }
            else if (type == 7) //double
            {
        #if nativedebug
                printf("It's not support!!\n");
                printf("new array with double type.\n");
        #endif
            }
            else if (type == 8)   //byte
            {
        #if nativedebug
                printf("new array with byte type.\n");
        #endif
				heap_align32();
                *(unsigned int*)CURRENT_HEAP_PTR = 0x88000000;
                printf("%x - %x\n",(unsigned int*)CURRENT_HEAP_PTR,*(unsigned int*)CURRENT_HEAP_PTR);
                CURRENT_HEAP_PTR +=4;
                *(unsigned int*)CURRENT_HEAP_PTR = length;
                CURRENT_HEAP_PTR +=4;
                return_value = CURRENT_HEAP_PTR;
                if((length & 0x00000003) != 0){
                	CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length&0xFFFFFFFC) + 4;
                }
                else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + length;
				heap_align32();
                /*
                heap[mt_table_count++] = 0x88000000;
                heap[mt_table_count++] = length;
                return_value = (int)&heap[mt_table_count];
                if((length & 0x00000003) != 0){
                    mt_table_count = mt_table_count + (length>>2) + 1;
                }
                else mt_table_count = mt_table_count + (length>>2);
                */
            }
            else if (type == 9)   //short
            {
        #if nativedebug
                printf("new array with short type.\n");
        #endif
				heap_align32();
                *(unsigned int*)CURRENT_HEAP_PTR = 0x90000000;
                CURRENT_HEAP_PTR +=4;
                *(unsigned int*)CURRENT_HEAP_PTR = length;
                CURRENT_HEAP_PTR +=4;
                return_value = CURRENT_HEAP_PTR;
                if((length & 0x00000001) != 0){
                	CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + ((length<<1)&0xFFFFFFFC) + 4;
                }
                else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<1);
				heap_align32();
                /*
                heap[mt_table_count++] = 0x90000000;
                heap[mt_table_count++] = length;
                return_value = (int)&heap[mt_table_count];
                if((length & 0x00000001) != 0){
                    mt_table_count = mt_table_count + (length>>1) + 1;
                }
                else mt_table_count = mt_table_count + (length>>1);
                */
            }
            else if (type == 10)  //int
            {
        #if nativedebug
                printf("new array with integer type.\n");
        #endif
				heap_align32(); // marked by T.H.Wu , 2013.7.23
                *(unsigned int*)CURRENT_HEAP_PTR = 0xA0000000;
                CURRENT_HEAP_PTR +=4;
                *(unsigned int*)CURRENT_HEAP_PTR = length;
                CURRENT_HEAP_PTR +=4;
                return_value = CURRENT_HEAP_PTR;
                CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<2);
				heap_align32(); // marked by T.H.Wu , 2013.7.23
				#if tstCFST
                	printf("new int array ptr:%X\n", return_value);
                	//print_reg(print_stack,   20);
                #endif
                /*
                heap[mt_table_count++] = 0xA0000000;
                heap[mt_table_count++] = length;
                return_value = (int)&heap[mt_table_count];
                mt_table_count = mt_table_count + length;
                */
            }
            else if (type == 11)  //long
            {
        #if nativedebug
                printf("new array with long type.\n");
        #endif
				heap_align32();
                *(unsigned int*)CURRENT_HEAP_PTR = 0xC0000000;
                CURRENT_HEAP_PTR +=4;
                *(unsigned int*)CURRENT_HEAP_PTR = length;
                CURRENT_HEAP_PTR +=4;
                return_value = CURRENT_HEAP_PTR;
                CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<3);
				heap_align32();

            }
            else{ //Object array
        #if nativedebug
                printf("new array with obj type.\n");
        #endif
				heap_align32();
                *(unsigned int*)CURRENT_HEAP_PTR = 0x20000000;
                CURRENT_HEAP_PTR +=4;
                *(unsigned int*)CURRENT_HEAP_PTR = length;
                CURRENT_HEAP_PTR +=4;
                return_value = CURRENT_HEAP_PTR;
                CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<2);
				heap_align32();
            }
        }
        else{
			#if nativedebug
                printf("new array with array type.\n");
			#endif
			heap_align32();
            *(unsigned int*)CURRENT_HEAP_PTR = 0x24000000;
            CURRENT_HEAP_PTR +=4;
            *(unsigned int*)CURRENT_HEAP_PTR = length;
            CURRENT_HEAP_PTR +=4;
            return_value = CURRENT_HEAP_PTR;
            CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<2);
			heap_align32();
        }
    }
    else{ //multi-array
        #if nativedebug
            printf("new array with array type.\n");
        #endif
        heap_align32();
        *(unsigned int*)CURRENT_HEAP_PTR = 0x24000000;
        CURRENT_HEAP_PTR +=4;
        *(unsigned int*)CURRENT_HEAP_PTR = length;
        CURRENT_HEAP_PTR +=4;
        return_value = CURRENT_HEAP_PTR;
        CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<2);
		heap_align32();
        for(idx = 0; idx<length; idx++){
            *((unsigned int*)(return_value + (idx<<2))) = recursive_new_array(type, (number-1), last_create_flag);
            //xil_printf("[main.c] recursive_new_array , idx:%x sub-array address:%x \r\n", idx, return_value + (idx<<2) );
        }

        // useless code below ...
        /*
        heap[mt_table_count++] = 0x24000000;
        heap[mt_table_count++] = length;
        return_value = (int)&heap[mt_table_count];
        for(idx = 0; idx++ ; idx<length){
            heap[mt_table_count++] = recursive_new_array(type, (number-1));
        }
        */
        //xil_printf("[main.c] recursive_new_array , return_value:%x \r\n", return_value);
    }
    return return_value;
}

void
Host_Service_Routines(void *baseaddr_p)
{
    int    *p;
    //xil_printf("Interrupt!!\r\n");
    int     class_id;
    int     IsClinit = 0;
    unsigned int *ptr, temp, temp2, size, idx,jdx;
    unsigned int dim, dim_real;
    uint32 isr_pack_msg;
    uint16 ISR_ID ;
    uint8 core_id; // modified by T.H.Wu , 2013.9.4
    unsigned char type;

#if new_newarray_prof
    unsigned int start, end = 0;
#endif
    uint8 classname[256]; // need remove, just test 20110305 G

    //xil_printf("[ISR] test ISR source IP addr : %x \r\n", baseaddr_p );
    core_id = (((uint)baseaddr_p)>>17) & 0x07;
    volatile uint *JPL_SERVICE_ID_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id,JPL_SERVICE_ID);
    volatile uint *JPL_INTRPT_CMPLT_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id,JPL_INTRPT_CMPLT);
    volatile uint *JPL_TOS_A_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A);
    volatile uint *JPL_TOS_B_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B);
    volatile uint *JPL_TOS_C_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    volatile uint * JPL_SERVICE_ARG1_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1);
    volatile uint * JPL_SERVICE_ARG2_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG2);
    volatile uint * JPL_SERVICE_ARG3_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3);
    volatile uint * JPL_SERVICE_ARG4_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG4);
    volatile uint * JPL_SERVICE_ARG5_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG5);



    isr_pack_msg = *JPL_SERVICE_ID_volatile ;
    //xil_printf("[ISR] isr_pack_msg : %x \r\n", isr_pack_msg );
    ISR_ID = 0x00FF & (isr_pack_msg>>16);
    //xil_printf("[ISR] ISR_ID : %x \r\n", ISR_ID );
    //xil_printf("[debug from ISR]: ISR_ID:%x, \r\n", ISR_ID );

    // arrange the service routine according to Service ID (interrupt function)
#if maindebug
    xil_printf("\r\n\r\nHost_Service_Routines start\r\n");
    print_reg(cls_num,0);
    xil_printf("ISR_ID                 %.8x\r\n", ISR_ID);
    xil_printf("isr_pack_msg         %.8x\r\n", isr_pack_msg);
#endif
#if Chia_Che_Hsu_Debug
    xil_printf("\r\n\r\nHost_Service_Routines start\r\n");
    xil_printf("ISR_ID                 %.8x\r\n", ISR_ID);
    xil_printf("isr_pack_msg         %.8x\r\n", isr_pack_msg);
#endif
    if(ISR_ID == 1){
#if maindebug
        xil_printf("\r\nCase 1 : native\r\n");
        xil_printf("ISR ARG1         %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1));
        xil_printf("ISR ARG2         %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG2));
        xil_printf("ISR ARG3         %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3));
        xil_printf("ISR ARG4         %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG4));
        xil_printf("ISR ARG5         %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG5));
        xil_printf("A %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
        xil_printf("B %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
        xil_printf("C %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
        print_reg(CTRL_state,   0);
        print_reg(SP_reg,   0);
        print_reg(VP_reg,   0);
        print_reg(debug_data_DR,   0);
        print_reg(jpc,   0);
        print_reg(instr2_1,   0);
        print_reg(bytecodes,   0);
        print_reg(print_LV,   0);
        print_reg(print_stack,   20);
#endif
        (*nativeMethodTable[isr_pack_msg & 0x0000FFFF].invoke_native)( core_id );
        //nativeMethodTable[isr_pack_msg & 0x0000FFFF].invoke_native( core_id );
        //xil_printf("[debug from ISR]: native method index:%x \r\n", isr_pack_msg & 0x0000FFFF );
#if maindebug
        xil_printf("A %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
        xil_printf("B %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
        xil_printf("C %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
        xil_printf("CURRENT_HEAP_PTR: %x\r\n", CURRENT_HEAP_PTR);
        xil_printf("end Case 1\r\n");
#endif
        *JPL_INTRPT_CMPLT_volatile = 0x0000ffff;
    }
    else{
        
        switch (ISR_ID)
        {
            // Memory allocation - new object
        case 0:
            p = (int *) mem_alloc(8);
            *JPL_TOS_B_volatile = (int) *JPL_TOS_B_volatile;
            break;

            // Memory allocation - new array
        case 1:
            if (*JPL_TOS_A_volatile == 4)    //boolean
            {
                xil_printf("  new array with boolean type. \r\n");
                // create the array with boolean type ;  
            }
            else if (*JPL_TOS_A_volatile == 5)   //char
            {
                xil_printf("  new array with char type. \r\n");
                // create the array with char type   
            }
            else if (*JPL_TOS_A_volatile == 6)   //float
            {
                xil_printf("  new array with float type. \r\n");
                // create the array with float type  
            }
            else if (*JPL_TOS_A_volatile == 7)   //double
            {
                xil_printf("  new array with double type. \r\n");
                // create the array with double type  
            }
            else if (*JPL_TOS_A_volatile == 8)   //byte
            {
                xil_printf("  new array with byte type. \r\n");
                // create the array with byte type  
            }
            else if (*JPL_TOS_A_volatile == 9)   //short
            {
                xil_printf("  new array with short type. \r\n");
                // create the array with short type  
            }
            else if (*JPL_TOS_A_volatile == 10)  //int
            {
                //p = 0x000004FB ;
                p = (int *) mem_alloc(sizeof(int) * (*JPL_TOS_B_volatile ));
            }
            else                    //long
            {
                // create the array with long type 
                xil_printf("  new array with long type. \r\n");
            }

            *JPL_TOS_B_volatile = (int) p;
            break;

            // I/O Service - for class loader parser ! Service ID  = 0x111
            // 2013.9.4 , exception handler , for new exception object
        case 7:
    #if maindebug
            xil_printf("\r\nCase 7 : class loader\r\n");
            xil_printf("target class id & offset %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3));
            xil_printf("now cls ID               %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG4));
            xil_printf("class info               %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG5));
            xil_printf("A %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
            xil_printf("B %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
            xil_printf("C %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
            print_reg(CTRL_state,   0);
            print_reg(SP_reg,   0);
            print_reg(VP_reg,   0);
            print_reg(debug_data_DR,   0);
            print_reg(jpc,   0);
            print_reg(instr2_1,   0);
            print_reg(bytecodes,   0);
            print_reg(print_LV,   0);
            print_reg(print_stack,   20);
    #endif
            class_id = (*JPL_SERVICE_ARG3_volatile) >> 16;

            //xil_printf("[debug from ISR]: class_id:%x , name:%s \r\n",
            //		class_id,
            //		x_ref_tbl[class_id].class_name );
            // debug by T.H.wu , 2013.7.24
            if(class_id==0x0){
                xil_printf("[debug from ISR]: class id error. JAIP crash \r\n" );
            	while(1);
            	break; //return;
            }

	#if print_parsing_cls_ID
            xil_printf("GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3): %X\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3));
	#endif
            /*  Get class_name by global_index   */
    #if maindebug
            xil_printf("= Parsing %s.class in %s.jar\r\n",
                       x_ref_tbl[class_id].class_name, name);
    #endif
            memcpy(classname, x_ref_tbl[class_id].class_name, x_ref_tbl[class_id].class_namel);
            memcpy(classname+x_ref_tbl[class_id].class_namel, ".class\0", 7);
#if maindebug
            xil_printf("Parsing %s in %s.jar\r\n",
                       classname, name);
#endif

	        // added by T.H.Wu , 2013.9.10 , for parser
	        //request_monitor_selfbuilt(core_id);
            jar_load_class(core_id, sys_jar_image, sys_jar_size, classname,&IsClinit);
	        //release_monitor_selfbuilt(core_id);
        	set_thread_class_flag(0);
        	// reset Thread class flag regardless it has been parsed in this time
            ptr = *JPL_SERVICE_ARG5_volatile;
#if maindebug
            xil_printf("class info               %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG5));
            xil_printf("ptr                      %.8x\r\n", ptr);
            xil_printf("*ptr                     %.8x\r\n",*ptr);
#endif
            //view_memory((Xuint32 * )METHOD_AREA_ADDRESS , DEBUG_VIEWMEM_BYTE + 2000);
            *JPL_SERVICE_ARG3_volatile = *ptr;
#if maindebug
            xil_printf("target class id & offset %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3));
#endif
            *JPL_INTRPT_CMPLT_volatile = 0x0000ffff;
    #if maindebug
            //view_memory((Xuint32 * )METHOD_AREA_ADDRESS , 304 + 2048);
            xil_printf("\rend Case 7 \r\n\n");
    #endif
            break;

       // new obj
        case 8:
           #if maindebug
                   xil_printf("\r\nCase 8 : new obj\r\n");
                   xil_printf("DynamicResolution        %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3));
                   xil_printf("now cls ID               %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG4));
                   xil_printf("class info               %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG5));
                   xil_printf("A %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
                   xil_printf("B %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
                   xil_printf("C %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
                   print_reg(CTRL_state,   0);
                   print_reg(SP_reg,   0);
                   print_reg(VP_reg,   0);
                   print_reg(debug_data_DR,   0);
                   print_reg(jpc,   0);
                   print_reg(instr2_1,   0);
                   print_reg(bytecodes,   0);
                   print_reg(print_LV,   0);
                   print_reg(print_stack,   20);
           #endif
       #if new_newarray_prof
                    start =  *JPL_INTRPT_TIME_REG;
       #endif
                   class_id = isr_pack_msg & 0x0000FFFF;

                   if (x_ref_tbl[class_id].IsCache == 0){
                       memcpy(classname, x_ref_tbl[class_id].class_name, x_ref_tbl[class_id].class_namel);
                       memcpy(classname+x_ref_tbl[class_id].class_namel, ".class\0", 7);
                       // added by T.H.Wu , 2013.9.10 , for parser
                       //request_monitor_selfbuilt(core_id);
                       jar_load_class(core_id, sys_jar_image,sys_jar_size,classname,&IsClinit);
                       //release_monitor_selfbuilt(core_id);
                   }
                   else IsClinit = 1;
                  	heap_align32();
                   *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A) = CURRENT_HEAP_PTR;


       #if Chia_Che_Hsu_Debug
       	printf("new obj ref:%X\n", CURRENT_HEAP_PTR);
       #endif
           #if maindebug
                   xil_printf("\r\n WRITE TO TOS_a CURRENT_HEAP_PTR: %x\r\n", CURRENT_HEAP_PTR);
                   xil_printf("\r\n class id : %x\r\n", class_id);
           #endif
                   *(unsigned int*)CURRENT_HEAP_PTR = class_id;

                  	// marked by C.C.Hsu
                   //*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A) = (int)&heap[mt_table_count];
                   //heap[mt_table_count] = class_id;

                   CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (x_ref_tbl[class_id].obj_size<<2);
       			heap_align32();

                   /*
                   mt_table_count = mt_table_count + x_ref_tbl[class_id].obj_size;
                   */
           #if maindebug
                   xil_printf("A %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
                   xil_printf("B %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
                   xil_printf("C %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
                   xil_printf("CURRENT_HEAP_PTR: %x\r\n", CURRENT_HEAP_PTR);
                   xil_printf("\rend Case 8 \r\n");
           #endif
                   *GET_CTRL_REG_MEM0ADDR(core_id, JPL_INTRPT_CMPLT) = 0x0000ffff;

       #if new_newarray_prof
                   //printf("new obj class_id: %d\n", class_id);
                    end =  *JPL_INTRPT_TIME_REG;
                    new_total_time += end - start;
                    num_of_time_new ++;
       #endif
            break;

        case 11:
	#if maindebug
            xil_printf("[ISR]Case 11 : multi a new array\r\n");
    #endif
            //xil_printf("[ISR]Case 11 : multi a new array, modified by fox.\r\n");
            //xil_printf("invoke_data_signal or arg1 %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1));
            //xil_printf("cross_table_address_reg    %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG2));
            //xil_printf("mst_address_reg            %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3));
            //xil_printf("A(size) %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
            //xil_printf("B       %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
            //xil_printf("C       %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
            // modified by fox ,
            dim = (*GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1)>>16) & 0x000000FF;
            unsigned int dim_real = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A);
            unsigned char type = (unsigned char)((*GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1) >> 24) & 0x000000FF);
            // added by fox , force to insert dimension information
            parameterSpace[0] = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B);
            parameterSpace[1] = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
            type = 0xA ;
            // original code , hidden by T.H.Wu
            //if(dim > dim_real){
            //    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A) = recursive_new_array(type, dim_real-1, 0);
            //}
            //else *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A) = recursive_new_array(type, dim-1, 1);
            //
            uint return_ref = recursive_new_array(type, dim_real-1, 1);
            // by fox
            /*
            unsigned int return_ref,array_ref,sub_array_ref;
            int x,y,z,length,entry,slot;
            array_ref  = CURRENT_HEAP_PTR;
            *(unsigned int*)CURRENT_HEAP_PTR = 0xA0000000;
            CURRENT_HEAP_PTR +=4;
            *(unsigned int*)CURRENT_HEAP_PTR = parameterSpace[dim_real];
            CURRENT_HEAP_PTR +=4;
            return_ref = CURRENT_HEAP_PTR;
            CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (parameterSpace[dim_real]<<2);
            length	= 1;
            for(x=dim_real;x>1;x--){
            	entry = parameterSpace[x] * length;
            	slot = parameterSpace[x] + 2;
            	for(y=0;y<=entry;y++){
            		if(y % slot == 0)	array_ref = array_ref + 8;
            		*(unsigned int*)CURRENT_HEAP_PTR = 0xA0000000;
            		CURRENT_HEAP_PTR +=4;
            		*(unsigned int*)CURRENT_HEAP_PTR = parameterSpace[x-1];
            		CURRENT_HEAP_PTR +=4;
            		*(unsigned int*)(array_ref) = CURRENT_HEAP_PTR;
            		CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (parameterSpace[x-1]<<2);

            		array_ref = array_ref + 4;
            	}
            	//array_ref = sub_array_ref;
            	length = parameterSpace[x];
            }
            */
            //xil_printf("[main.c multi-anewarray] return_ref = %.8x \r\n", return_ref);

            if(dim_real==1){
            	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B) = return_ref;
            }
            else if(dim_real==2){
            	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = return_ref;
            }
            
            *GET_CTRL_REG_MEM0ADDR(core_id, JPL_INTRPT_CMPLT) = 0x0000ffff;

    #if maindebug
            xil_printf("CURRENT_HEAP_PTR: %x\r\n", CURRENT_HEAP_PTR);
            xil_printf("\rend Case 11 \r\n");
    #endif
            break;
            
            
        case 15:        
            xil_printf("\r\nCase print \r\n");
            xil_printf("print: %d \r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
            xil_printf("invoke_data_signal or arg1 %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1));
            xil_printf("cross_table_address_reg    %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG2));
            xil_printf("mst_address_reg            %.8x\r\n", (*GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3))>>2);
            xil_printf("A %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
            xil_printf("B %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
            xil_printf("C %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
    //         if(*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A) == 60)
    //         {        
    //             view_memory((Xuint32 *) METHOD_TABLE_ADDRESS, 512);
    //             view_memory((Xuint32 * )METHOD_AREA_ADDRESS , 11264);
    //         }
            xil_printf("\rend Case print \r\n\n");
            *GET_CTRL_REG_MEM0ADDR(core_id, JPL_INTRPT_CMPLT) = 0x0000ffff;  //interrupt return
            break;
        default:
            xil_printf("ERROR: illegal ISR number %x . \r\n", isr_pack_msg);
            break;
        } // END switch
    }
}

void print_reg(unsigned int type,unsigned int num){
    unsigned int i = 0;
    unsigned int ctr = 0;
    uint8 core_id = 0;
    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_flag) = type;
    xil_printf("\r\n");
    switch (type){
    	/*
        case  0x00000001:
            xil_printf("cls_profile_table:\r\n");
            for(;i<num*4;i+=4){
                xil_printf("%2d: ",i/4);
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
                xil_printf("block num: %8x\t",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i+1;
                xil_printf("mem_addr:  %8x\t",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i+2;
                xil_printf("size:      %8x\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            }
            break;
        case  0x00000002:
            xil_printf("cls_residence_table:\r\n");
            for(;i<32;i++){
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
                xil_printf("%2d: %8x\r\n", i, *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            }
            break;
        case  0x00000016:
            xil_printf("sp_reg:    %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000015:
            xil_printf("vp_reg     %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        */
        case  0x00000001:
            xil_printf("double_issue        %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000002:
            xil_printf("not_double_issue    %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000003:
            xil_printf("nopnop              %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        //case  0x0000001D:
        //    xil_printf("cls_num             %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
        //    break;
        case  0x00000004:
            xil_printf("Normal_nopnop       %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000005:
            xil_printf("instrs_pkg_FF       %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        /*
        case  0x0000000F:
            xil_printf("DynamicResolution_addr & Get_entry_tmp     %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000010:
            xil_printf("jpc     %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000012:
            xil_printf("instrbuf2 & instrbuf1     %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000018:
            xil_printf("bytecodes     %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;

        case  0x00000003:
        	xil_printf("CTRL_state:        ");
            switch(*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ))
            {
                case 0x00000017 : xil_printf("Get_entry2"); break;
                case 0x00000001 : xil_printf("CLassLoading"); break;
                case 0x00000002 : xil_printf("Normal"); break;
                case 0x00000003 : xil_printf("Get_entry"); break;
                case 0x00000004 : xil_printf("Upper_addr"); break;
                case 0x00000005 : xil_printf("Lower_addr"); break;
                case 0x00000006 : xil_printf("Offset_access"); break;
                case 0x00000007 : xil_printf("IllegalOffset"); break;
                case 0x00000008 : xil_printf("Enable_MA_management"); break;
                case 0x00000009 : xil_printf("Method_entry"); break;
                case 0x0000000A : xil_printf("Method_flag"); break;
                case 0x0000000B : xil_printf("arg_size"); break;
                case 0x0000000C : xil_printf("max_stack1"); break;
                case 0x0000000D : xil_printf("max_stack2"); break;
                case 0x0000000E : xil_printf("max_local"); break;
                case 0x0000000F : xil_printf("Method_exit"); break;
                case 0x00000010 : xil_printf("Field_store"); break;
                case 0x00000011 : xil_printf("Field_load"); break;
                case 0x00000012 : xil_printf("Field_exit"); break;
                case 0x00000013 : xil_printf("invokeinterface_obj_ClsNum"); break;
                case 0x00000014 : xil_printf("invokeinterface_list_ClsNum"); break;
                case 0x00000015 : xil_printf("invokeinterface_next"); break;
                case 0x00000016 : xil_printf("invokeinterface_OffsetAccess"); break;
                
                case 0x00000018 : xil_printf("Native_StackAdjusting2"); break;
                case 0x00000019 : xil_printf("Native_StackAdjusting3"); break;
                case 0x0000001A : xil_printf("Native_ArgExporting_Reg"); break;
                case 0x0000001B : xil_printf("Native_ArgExporting_DDR"); break;
                case 0x0000001C : xil_printf("Native_interrupt"); break;
                case 0x0000001D : xil_printf("Native_SpAdjusting"); break;
                case 0x0000001E : xil_printf("Native_StackAdjustingReturn1"); break;
                case 0x0000001F : xil_printf("Native_StackAdjustingReturn2"); break;
                case 0x00000020 : xil_printf("Native_exit"); break;
                case 0x00000021 : xil_printf("Native_StackAdjusting1"); break;
                
                case 0xFFFFFFFF : xil_printf("error state"); break;
                case 0x0000FFFF : xil_printf("initial state"); break;
                
                default:xil_printf("error GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data )     %.8x", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data )); break;
            }
            xil_printf("\r\n");
            break;
        case  0x00000004:
            xil_printf("mem_access_list:\r\n");
            for(;i<num;i++){
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
                xil_printf("%3d: %.8x\r\n", i, *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            }
            break;
        case  0x00000005:
            xil_printf("cls_cache:\r\n");
//             for(;i<num;i++){
//                 *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0;
//                 xil_printf("%3d: %.8x\r\n", i, *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
//             }
        	  
            ctr = 0;
            xil_printf("\r\n-------------------------------------------------------------------------\r\n");
            xil_printf(    "| ADDRESS  |                    cls_cache : %2d                          |\r\n", num);
            xil_printf(    "|          |  0001   0203   0405   0607     0809   0A0B   0C0D   0E0F   |");    
            xil_printf("\r\n-------------------------------------------------------------------------\r\n");
            for(; ctr<= 255;ctr++)
            {
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = (num << 10) + ctr;
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = (num << 10) + ctr;
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = (num << 10) + ctr;
            
                if(!(ctr%8))
                { 
                    xil_printf("|");
                    
                    xil_printf("%4x",(((long) ctr>> 16)& 0x0000ffff));
                    xil_printf(":");
                    
                    xil_printf("%4x",(((long) ctr<<  1) & 0x0000ffff));
                    xil_printf(" | ");
                }
                
                if (*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ) > 0x0FFF)
                    xil_printf(" %4x ",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                else if (*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ) > 0x00FF)
                    xil_printf(" 0%3x ",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                else if (*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ) > 0x000F)
                    xil_printf(" 00%x ",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                else    
                    xil_printf(" 000%x ",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                
                if(ctr%8==3) 
                    xil_printf(" - ");
                else  
                    xil_printf(" ");
                
                if((ctr%8) == 7)
                    xil_printf(" |\r\n");
            }
            xil_printf("-------------------------------------------------------------------------\n\r");
            
            break;
        case  0x00000013:
            xil_printf("cls_num_list:\r\n");
            for(;i<num;i++){
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
                xil_printf("%3d: %.8x\r\n", i, *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            }
            break;
        case  0x00000014:
            xil_printf("debug2_cls0_cnt:      %d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000017:
            xil_printf("debug2_cls0_cnt2      %d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            break;
        case  0x00000020:
            xil_printf("stack:\r\n");
            *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_flag) = 0x00000016;
            xil_printf("sp_reg:    %.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            ctr = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ); // sp_reg
            *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_flag) = 0x00000020;
            xil_printf("A\t:\t%.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A));
            xil_printf("B\t:\t%.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B));
            xil_printf("C\t:\t%.8x\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
            for(;i<num;i++){
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = ctr-i;
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = ctr-i;
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = ctr-i;
                if((ctr-i)<0)
                    break;
                xil_printf("%d\t:\t%8x\r\n", ctr-i, *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            }
            if((ctr-i)>0){
                xil_printf(" . \t \t  .  \r\n");
                xil_printf(" . \t \t  .  \r\n");
                xil_printf(" . \t \t  .  \r\n");
            }
            break;
        case  0x00000021:
            xil_printf("local variable:\r\n");
            *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_flag) = 0x00000021;
            for(;i<4;i++){
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
                *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
                xil_printf("LV%d :  %8x\r\n", i, *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            }
            break;
            */
        case  0x00000006:
                    xil_printf("ucode_nopnop        %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
                case  0x00000023:
                    xil_printf("debug_data_fetch:\r\n");
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000000;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000000;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000000;
                    xil_printf("branch_numreg :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000001;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000001;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000001;
                    xil_printf("cplx_mode     :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000002;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000002;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000002;
                    xil_printf("FFXX_opd      :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000003;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000003;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000003;
                    xil_printf("XXFF_opd      :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000004;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000004;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000004;
                    xil_printf("XXFF_c        :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000005;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000005;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000005;
                    xil_printf("XXFF_s        :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000006;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000006;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000006;
                    xil_printf("XXFF_h        :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000007;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000007;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000007;
                    xil_printf("FFFF_opdopd   :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000008;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000008;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000008;
                    xil_printf("FFFF_opds     :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000009;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000009;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000009;
                    xil_printf("stall_fetch_stage_reg        :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000A;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000A;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000A;
                    xil_printf("FFFF_ROM      :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000B;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000B;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000B;
                    xil_printf("XXFF_ROM      :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000C;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000C;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000C;
                    xil_printf("FFXX_ROM      :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000D;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000D;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000D;
                    xil_printf("invoke_numreg :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000E;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000E;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000E;
                    xil_printf("FFXX_branch   :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000F;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000F;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000F;
                    xil_printf("FFFF_branch   :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000010;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000010;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000010;
                    xil_printf("FFFF_brs      :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000011;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000011;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000011;
                    xil_printf("single_issue  :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000012;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000012;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000012;
                    xil_printf("nop_flag_reg  :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000013;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000013;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000013;
                    xil_printf("counter       :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;

                case  0x00000008:
                    xil_printf("nopflag             %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
                case  0x00000009:
                    xil_printf("stall_all_reg       %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
                case  0x0000000A:
                    xil_printf("stall_fetch_stage_reg %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
                case  0x00000027:
                    xil_printf("stack depth %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
                case  0x00000028:
                    xil_printf("field&static %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
                case  0x00000029:
                    xil_printf("method invoke cnt %.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
                case  0x0000002a:
                	xil_printf("LL :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                	break;
                case  0x0000002b:
                    xil_printf("LA :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
                case  0x0000002c:
                    xil_printf("LS :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
               case  0x0000002d:
                    xil_printf("SL :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
               case  0x0000002e:
                    xil_printf("SA:  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
               case  0x0000002f:
                    xil_printf("SS :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
               case  0x00000030:
                    xil_printf("AL :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
               case  0x00000031:
                    xil_printf("AS :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
               case  0x00000032:
                    xil_printf("AA :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
               case  0x00000034:
            	    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000000;
            	    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000000;
            	    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000000;
                    xil_printf("# Exception Handling Cycles :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000001;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000001;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000001;
                    xil_printf("# Catch search cnt :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000002;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000002;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000002;
                    xil_printf("# Method search cnt :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000003;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000003;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000003;
                    xil_printf("# Memory cycles to load lv-cnt(all) :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000004;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000004;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000004;
                    xil_printf("# xcptn_handling_cnt :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000005;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000005;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000005;
                     xil_printf("ER_cnt_record :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000006;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000006;
                    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000006;
                     xil_printf("# New_obj_time :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                    break;
               case  0x00000035:
            	    for(;i<100;i++){
            	    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
            	    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
            	    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = i;
            	    	if (i %4 ==0)   xil_printf("\r\n");
            	        xil_printf("%3d: %.8x\r\n", i, *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
            	    }
                    break;
               case  0x00000036:
                   xil_printf("method block number :  %8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
                   break;
        default:
            xil_printf("error type\r\n");
            break;
    }
	 *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_flag) = 0x00000000;
}
