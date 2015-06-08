/* //////////////////////////////////////////////////////////////// */
/*																	*/
/*   System Software of Dual-Core Java Runtime Environment			*/
/*																	*/
/* ---------------------------------------------------------------- */
/*   File: main.c													*/
/*   Author: Kuan-Nian Su											*/
/*   Date: Feb/24/2007												*/
/* ---------------------------------------------------------------- */
/*   The system software of MMES dual-core Java Runtime Environment.*/
/*   There are some features as follows :							*/
/*	1. Convert Java class file into Java runtime image. But this  	*/
/*		is FAT16 file system, the class file renames as .cls.		*/
/*	2. Load Java runtime images into Method area and assign the   	*/
/*		initial pc & sp.											*/
/*	3. Trigger the Java Bytecode Execution Engine core.				*/
/*	4. Provide host service routine as ISR for Java Bytecode		*/
/*		Execution Engine core.										*/
/*																	*/
/*   Copyright, 2007.												*/
/*   Multimedia Embedded Systems Lab.								*/
/*   Department of Computer Science and Information engineering		*/
/*   National Chiao Tung University, Hsinchu 300, Taiwan			*/
/* ---------------------------------------------------------------- */
/*   MODIFICATIONS													*/
/*																	*/
/*   Author: Kuan-Nian Su											*/
/*   Date: Apr/2009													*/
/* ---------------------------------------------------------------- */
/*   MODIFICATIONS													*/
/*																	*/
/*   Author: Chien-Fong Huang										*/
/*   Date: 09/2009													*/
/* //////////////////////////////////////////////////////////////// */

// inclure xilinx library
#include <xio.h>
#include <xparameters.h>
#include <xutil.h>
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

/* ---------------------------------------------------------------------*/
/*			Extern Global Variables Declaration							*/
/* ---------------------------------------------------------------------*/

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
extern volatile unsigned int parameterSpace[8];
unsigned int debug_number[2048] = {0};
// for fixing multiple main method bug , 2013.7.16
char *main_class_fully_qualified_name;


char	name[] = { "system" };

#define JPL_debug_flag_off  0x00000000
#define cls_profile_table   0x00000001
#define cls_residence_table 0x00000002
#define CTRL_state			0x00000003
#define mem_access_list		0x00000004
#define cls_cache			0x00000005

#define double_issue		0x00000001
#define not_double_issue	0x00000002
#define nopnop				0x00000003
#define Normal_nopnop		0x00000004
#define instrs_pkg_FF		0x00000005
#define jcode_nopnop		0x00000006
#define debug_data_fetch	0x00000007
#define stall_all_reg		0x00000008
#define stall_fetch_stage_reg 0x00000009
#define ll					0x0000000A
#define la					0x0000000B
#define ls					0x0000000C
#define sl					0x0000000D
#define sa					0x0000000E
#define ss					0x0000000F
#define al					0x00000010
#define as					0x00000011
#define aa					0x00000012
#define invoke_cycle		0x00000013
#define get_fd_cycle		0x00000014
#define put_fd_cycle		0x00000015
#define nopflag				0x00000016

extern void print_reg(unsigned int type);

extern uint mt_table_count;
// profiling about the number used for field info/method info in cross reference table .
extern uint num_entry_xrt_field_count;
extern uint num_entry_xrt_method_count;

extern unsigned int recursive_new_array();

/* ---------------------------------------------------------------- */
/*						Main Function								*/
/* ---------------------------------------------------------------- */
/* The execution flow is as follows :								*/
/*   1. System Initialization										*/
/*   2. Load the main class file and generate it into runtime image	*/
/*   3. Load the other class files and link							*/
/*   4. Enable the Java Bytecode Execution Engine					*/
/* ---------------------------------------------------------------- */

int main(void)
{
	SYSACE_FILE *fptr;
	int	IsClinit = 0;

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

	xil_printf("\r\n=======================================================");
	xil_printf("\r\n--  MMES Dual-core Java Runtime Environment Running  --");
	xil_printf("\r\n=======================================================");
	xil_printf("\r\n");

	/// TMT GC version 1
	// Read system.jar into memory.
	if ((fptr = sysace_fopen("a:\\jar\\jembench.jar", "r")) == NULL)
	{
		xil_printf("ERROR: system.jar open failure.\r\n");
	}
	sys_jar_size = sysace_fread(sys_jar_image, 1, MAX_BUFFER_SIZE, fptr);

	//xil_printf("sys_jar_size:x\r\n",sys_jar_size);
	sysace_fclose(fptr);

	CURRENT_HEAP_PTR		= HEAP_MEM_AREA_ADDRESS;
	
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
	
	// set the fully-qualified main class name , before parsing any classes.
	main_class_fully_qualified_name = malloc(80*sizeof(uint8) );

	//main_class_fully_qualified_name = "Pi.class";
	//main_class_fully_qualified_name =  "mycaffeine/CFSTPT.class" ;
   //main_class_fully_qualified_name = "mycaffeine/CFSTSC.class";
	main_class_fully_qualified_name = "jembench/Main.class";
	//main_class_fully_qualified_name = "test.class";
	
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
	*COOR_MAIN_CLS_MTHD_ID = (main_cls_id<<16 | main_mthd_id);
	*COOR_CMD_MSG = (0x4<<29) | (0x3<<26) | (0x00000000);
	while( (*JPL0_CTRL_REG_volatile & 0x80000000)==0x0 );
	while(
		(*JPL0_CTRL_REG_volatile & 0x80000000)!=0x0
		//2014.3.17, the following 3 lines of code may lead to JAIP crash...
		//|| (*JPL1_CTRL_REG_volatile & 0x80000000)!=0x0
		//|| (*JPL2_CTRL_REG_volatile & 0x80000000)!=0x0
		//|| (*JPL3_CTRL_REG_volatile & 0x80000000)!=0x0
	)
	{

#if print_ddr
		xil_printf("\r\nMETHOD_AREA_ADDRESS\r\n");
		view_memory((Xuint32 * )METHOD_AREA_ADDRESS , 4096);
		xil_printf("\r\nHEAP\r\n");
	view_memory((Xuint32 * )HEAP_MEM_AREA_ADDRESS  , 1024);
#endif
	}

	xil_printf("\r\n========================================================");
	xil_printf("\r\n== Java Core Total Execution Time (cycles) : %d ", *JPL_TOTAL_TIME_REG_volatile );
	xil_printf("\r\n==			HW Execution Time (cycles) : %d ", *JPL_NONINTRPT_TIME_REG_volatile );
	xil_printf("\r\n==		INTRPT Execution Time (cycles) : %d ", *JPL_INTRPT_TIME_REG_volatile );
	xil_printf("\r\n========================================================");

	print_reg(double_issue);
	print_reg(not_double_issue);
	print_reg(nopnop);
	print_reg(Normal_nopnop);
	print_reg(instrs_pkg_FF);
	print_reg(jcode_nopnop);
	print_reg(debug_data_fetch);
	print_reg(nopflag);
	print_reg(stall_all_reg);
	print_reg(stall_fetch_stage_reg);
	print_reg(invoke_cycle);
	print_reg(get_fd_cycle);
	print_reg(put_fd_cycle);
	xil_printf("\r\n========================================================");
	xil_printf("\r\n");

	xil_printf("\r\n========================================================");
	xil_printf("\r\n mt_table_count: %d ",	mt_table_count);
	xil_printf("\r\n num_entry_xrt_field_count: %d ",	num_entry_xrt_field_count);
	xil_printf("\r\n num_entry_xrt_method_count: %d ",	num_entry_xrt_method_count);
	xil_printf("\r\n method_count: %d ",	global_mthd_id);
	xil_printf("\r\n========================================================");


	xil_printf("\r\n========================================================");
	xil_printf("\r\ninstruction matches");
	print_reg(ll);
	print_reg(la);
	print_reg(ls);
	print_reg(sl);
	print_reg(sa);
	print_reg(ss);
	print_reg(al);
	print_reg(as);
	print_reg(aa);
	xil_printf("\r\n========================================================\r\n");
	xil_printf("CURRENT_HEAP_PTR: %x\r\n", CURRENT_HEAP_PTR);

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


unsigned short
read_uint16_main(unsigned char *p)
{
	return (p[0] << 8) + p[1];
}

//modified by CYC  15.1.7
unsigned int recursive_new_array(){

	unsigned int return_value;
	int length = (int)parameterSpace[0];
	heap_align32();
	*(unsigned int*)CURRENT_HEAP_PTR = 0x50000000;
	CURRENT_HEAP_PTR +=4;
	*(unsigned int*)CURRENT_HEAP_PTR = length;
	CURRENT_HEAP_PTR +=4;
	return_value = CURRENT_HEAP_PTR;
	if((length & 0x00000001) != 0){
		CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + ((length<<1)&0xFFFFFFFC) + 4;
	}
	else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<1);
	heap_align32();
	return return_value;
}

//modified by CYC  15.1.7
void Host_Service_Routines(void *baseaddr_p)
{
	int	class_id;
	int	IsClinit = 0;
	unsigned int *ptr;
	uint32 isr_pack_msg;
	uint16 ISR_ID ;
	uint8 core_id; // modified by T.H.Wu , 2013.9.4

	uint8 classname[256]; // need remove, just test 20110305 G

	core_id = (((uint)baseaddr_p)>>17) & 0x07;
	volatile uint *JPL_SERVICE_ID_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id,JPL_SERVICE_ID);
	volatile uint *JPL_INTRPT_CMPLT_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id,JPL_INTRPT_CMPLT);
	volatile uint * JPL_SERVICE_ARG1_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1);
	volatile uint * JPL_SERVICE_ARG2_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG2);
	volatile uint * JPL_SERVICE_ARG3_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3);
	volatile uint * JPL_SERVICE_ARG4_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG4);
	volatile uint * JPL_SERVICE_ARG5_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG5);

	isr_pack_msg = *JPL_SERVICE_ID_volatile ;
	ISR_ID = 0x00FF & (isr_pack_msg>>16);

	// arrange the service routine according to Service ID (interrupt function)
	switch (ISR_ID){
		// native method
		case 1:
			(*nativeMethodTable[isr_pack_msg & 0x0000FFFF].invoke_native)( core_id );
			*JPL_INTRPT_CMPLT_volatile = 0x0000ffff;
			break;
		// I/O Service - for class loader parser !
		case 2:
			class_id = (*JPL_SERVICE_ARG3_volatile) >> 16;
			if(class_id==0x0){
				xil_printf("[debug from ISR]: class id error. JAIP crash \r\n" );
				while(1);
				break;
			}
			/*  Get class_name by global_index   */
			memcpy(classname, x_ref_tbl[class_id].class_name, x_ref_tbl[class_id].class_namel);
			memcpy(classname+x_ref_tbl[class_id].class_namel, ".class\0", 7);
			// added by T.H.Wu , 2013.9.10 , for parser
			//request_monitor_selfbuilt(core_id);
			jar_load_class(core_id, sys_jar_image, sys_jar_size, classname,&IsClinit);
			//release_monitor_selfbuilt(core_id);
			set_thread_class_flag(0);
			// reset Thread class flag regardless it has been parsed in this time
			ptr = *JPL_SERVICE_ARG5_volatile;
			*JPL_SERVICE_ARG3_volatile = *ptr;
			*JPL_INTRPT_CMPLT_volatile = 0x0000ffff;
			break;
		// new obj - for exception handler
		case 3:
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
			*(unsigned int*)CURRENT_HEAP_PTR = class_id;
			CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (x_ref_tbl[class_id].obj_size<<2);
			heap_align32();
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_INTRPT_CMPLT) = 0x0000ffff;
			break;
		default:
			xil_printf("ERROR: illegal ISR number %x . \r\n", isr_pack_msg);
			break;
	}
}

//modified by CYC  15.1.7
void print_reg(unsigned int type){
	uint8 core_id = 0;
	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_flag) = type;
	xil_printf("\r\n");
	switch (type){
		case  0x00000001:
			xil_printf("double_issue		%.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000002:
			xil_printf("not_double_issue	%.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000003:
			xil_printf("nopnop			%.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000004:
			xil_printf("Normal_nopnop		%.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000005:
			xil_printf("instrs_pkg_FF		%.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000006:
			xil_printf("jcode_nopnop		%.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000007:
			xil_printf("debug_data_fetch:\r\n");
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000000;
			xil_printf("branch_numreg 	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000001;
			xil_printf("cplx_mode	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000002;
			xil_printf("FFXX_opd	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000003;
			xil_printf("XXFF_opd	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000004;
			xil_printf("XXFF_c		%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000005;
			xil_printf("XXFF_s		%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000006;
			xil_printf("XXFF_h		%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000007;
			xil_printf("FFFF_opdopd  	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000008;
			xil_printf("FFFF_opds	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000A;
			xil_printf("FFFF_ROM	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000B;
			xil_printf("XXFF_ROM	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000C;
			xil_printf("FFXX_ROM	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000D;
			xil_printf("invoke_numreg	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000E;
			xil_printf("FFXX_branch	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x0000000F;
			xil_printf("FFFF_branch	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000010;
			xil_printf("FFFF_brs	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000011;
			xil_printf("single_issue	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000012;
			xil_printf("nop_flag_reg	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_addr ) = 0x00000013;
			xil_printf("counter		%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000008:
			xil_printf("stall_all_reg		%.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000009:
			xil_printf("stall_fetch_stage_reg	%.8d\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x0000000A:
			xil_printf("LL :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x0000000B:
			xil_printf("LA :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x0000000C:
			xil_printf("LS :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x0000000D:
			xil_printf("SL :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x0000000E:
			xil_printf("SA :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x0000000F:
			xil_printf("SS :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000010:
			xil_printf("AL :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000011:
			xil_printf("AS :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000012:
			xil_printf("AA :%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000013:
			xil_printf("invoke_cycle	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000014:
			xil_printf("get_fd_cycle	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000015:
			xil_printf("put_fd_cycle	%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		case  0x00000016:
			xil_printf("nopflag		%8d\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_data ));
			break;
		default:
			xil_printf("error type\r\n");
			break;
	}
	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_debug_flag) = 0x00000000;
}
