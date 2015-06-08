/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*																								*/ 
/*   System Software of Dual-Core Java Runtime Environment										*/
/*																								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: mmes_jpl.h																			*/
/*   Author: Kuan-Nian Su																		*/
/*   Date: Apr/10/2009																			*/
/* ----------------------------------------------------------------------------------------------- */
/*   1. Registers declaration for Java bytecode execution engine								*/
/*																								*/
/*   Copyright, 2007.																			*/
/*   Multimedia Embedded Systems Lab.															*/
/*   Department of Computer Science and Information engineering									*/
/*   National Chiao Tung University, Hsinchu 300, Taiwan										*/
/* ----------------------------------------------------------------------------------------------- */
/*   MODIFICATIONS																				*/
/*																								*/
/*   Author:																					*/
/*   Date:																						*/
/* /////////////////////////////////////////////////////////////////////////////////////////////// */

#ifndef _MMES_JPL_H_
#define _MMES_JPL_H_

// ISR enable for JAIP core 1 / core 2 / core 3

#define XPAR_XPS_INTC_0_JAIP_1_IP2INTC_IRPT_INTR 1
#define XPAR_XPS_INTC_0_JAIP_2_IP2INTC_IRPT_INTR 2
#define XPAR_XPS_INTC_0_JAIP_3_IP2INTC_IRPT_INTR 3

// modified by T.H.Wu ,2013.9.3 , for enabling JAIP core 1
#define ENABLE_JAIP_CORE1 0
#define JAIP_CORE_NUM	1
// modified all control registers address format which accessed in RISC , by T.H.Wu , 2013.9.5

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*	Registers definition for Java Bytecode Execution Engine									*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/

#define JPL_MEM_ADDRESS			XPAR_JAIP_0_MEM0_BASEADDR
#define COOR_MEM_ADDRESS  		XPAR_DATA_COHERENCE_CONTROLLER_0_MEM0_BASEADDR

// added by T.H.Wu , 2013.9.5
// for C_BASEADDR (ex. 0x88010000)
#define GET_CTRL_REG_MEM0ADDR(core_id , ctrl_reg_offset) \
		((volatile uint*)(JPL_MEM_ADDRESS | ((core_id)<<17)) + ctrl_reg_offset)
// added by T.H.Wu , 2013.9.5
// for C_MEM0_BASEADDR (ex. 0x88000000)
#define GET_CTRL_REG_BASEADDR(core_id , ctrl_reg_offset) \
		((volatile uint*)(XPAR_JAIP_0_BASEADDR | ((core_id)<<17)) + ctrl_reg_offset)

// Control Register
// |-----------------------------------------------------------|
// |  0 | 1 | 2 |		... reserve ...				| 31 |
// |-----------------------------------------------------------|
//
// * Bit 0 : Enable the Java bytecode execution engine. '1' is active ; '0' is not active. 
//		Note that this bit is always keeping in active until the Java core finish executing the application.
			
// * Bit [1:2] : core ID for the specified JAIP
//
// * Bit 31: Start to load main class. '1' is start to loading ; '0' is stop.

#define JPL_CTRL_REG			0x0

// Host Service ID Reginster
// |-----------------------------------------------------------|
// |	... reserve ...				| 28 | 29 | 30 | 31 |
// |-----------------------------------------------------------|
//
// * Bit [28 : 31] : Indicate the ID of host service routine.

#define JPL_SERVICE_ID		0x1

// Register for caching up top three elemets of java stack
// |-----------------------------------------------------------|
// |  0 |				... ...						| 31 |
// |-----------------------------------------------------------|
//
// * Bit [0 : 31] : Cache up the top three elements of java stack.
// A is top of stack element; B is second of stack element; C is thrid of stack element

//#define JPL_TOS_A				((volatile int *)JPL_MEM_ADDRESS + 0x2) // depreciated
#define JPL_TOS_A				0x2
#define JPL_TOS_B				0x3
#define JPL_TOS_C				0x4

// Register for caching up parameter of host service
// |-----------------------------------------------------------|
// |  0 |				... ...						| 31 |
// |-----------------------------------------------------------|
//
// * Bit [0 : 31] : Cache up the three parameters of host service routine.

#define JPL_SERVICE_ARG1		0x5
#define JPL_SERVICE_ARG2		0x6
#define JPL_SERVICE_ARG3		0x7
#define JPL_SERVICE_ARG4		0x8
#define JPL_SERVICE_ARG5		0x9

// Register for class manage table
// |-----------------------------------------------------------|
// |  0 |	...	| 15 | 16 |		...		| 31 |
// |-----------------------------------------------------------|
//
// * Bit [0 : 15] : Indicate the index of table
// * Bit [15: 31] : Indicate the infomation of table
#define JPL_CST_LUT_REG	0xC
#define JPL_MA_LUT_REG		0xD // added by ji-jing
#define JPL_DEBUG_REG		0x1111

// Register for exception table
// |-----------------------------------------------------------|
// |  0 |	...	| 15 | 16 |		...		| 31 |
// |-----------------------------------------------------------|
//

// methid [] & cnt[1:0] & jpc_boundary_or_offset[0]
#define JPL_XCPTN_LUT2JAIP	0x1C
#define JPL_XCPTN_ENABLE		0x1D


// Register for timer 
// |-----------------------------------------------------------|
// |  0 |				... ...						| 31 |
// |-----------------------------------------------------------|
//
// * Bit [0 : 31] : Indicate the number of cycles.
//
// TOTAL_TIME is total execution time
// NONINTRPT_TIME is the hw execution cycles except waitting for host service
// INTRPT_TIME is the cycles for executing the host service 

#define JPL_TOTAL_TIME_REG		0x14
#define JPL_NONINTRPT_TIME_REG	0x15
#define JPL_INTRPT_TIME_REG		0x16
#define JPL_INTRPT_CMPLT		0x1B
#define THREAD_MGT_TIME_SLICE	0x20

// note by T.H.Wu , 2013.9.9
// CURRENT_HEAP_PTR ,  data coherence for these control registers
#define CURRENT_HEAP_PTR_REG	((volatile int *)JPL_MEM_ADDRESS + 0x21)
#define CURRENT_HEAP_PTR		(*CURRENT_HEAP_PTR_REG)

// modified by Jeff , for flushing cache use
#define flush_cmplt32			0x85
#define cache_flush_en			0x86

#define JPL_debug_flag			0x80
#define JPL_debug_addr			0x81
#define JPL_debug_data			0x82
#define debug_userlogic			0x83
#define debug_userlogic2		0x84
#define JPL_MTHD_PROFILE		0x90
#define JPL_BC_PROFILE			0x91


/* for Data coherence controller use. */
/*
 *  Data coherence controller , control register format [important!!]
 * // |-----------------------------------------------------------|
 * // | 0 | 1 |	...	| 15 | 16 |		...		| 31 |
 * // |-----------------------------------------------------------|
 *
 * [0] : assign the first thread (main thread) to the first JAIP core (often JAIP 0) by DCC
 * [1] : the lock bit for RISC , when RISC want to read control registers from any specific JAIP core,
 * 		then RISC should get the lock by setting this bit to 1 , so the particular JAIP core will halt
 * 		if the JAIP core and RISC want to write the same control register concurrently , we prior to
 * 		let RISC access any registers which is protected by lock
 * */

//#define COOR_CTRL_REG  ((volatile int *)COOR_MEM_ADDRESS + 0x0)

#define COOR_CMD_MSG  ((volatile int *)COOR_MEM_ADDRESS + 0x1)

#define COOR_MAIN_CLS_MTHD_ID  ((volatile int *)COOR_MEM_ADDRESS + 0x8)



/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*	ISR Declaration																			*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/

void Host_Service_Routines(void *baseaddr_p) ;

// Generate java runtime image in method area
int Generate_Runtime_Image(char *class_name);
//int Generate_New_Image();

#endif

