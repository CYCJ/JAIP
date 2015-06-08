/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*																								*/ 
/*   System Software of Dual-Core Java Runtime Environment										*/
/*																								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: heap_manage.h																		*/
/*   Author: Kuan-Nian Su																		*/
/*   Date: Jul/02/2009																			*/
/* ----------------------------------------------------------------------------------------------- */
/*   Implement some function to manage the 2nd-level method area							*/
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

#include <xio.h>

#include "../include/heap_manager.h"
#include "../include/class_mt_manager.h"
#include "../include/mmes_jpl.h"
#include <xparameters.h>
/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*								Global Variables Declaration									*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/

// defien the ptr of 2nd-level method area
volatile void *HEAP_MEM_AREA_PTR  = (void *)HEAP_MEM_AREA_ADDRESS ;

// record the heap allocation
BYTE HEAP_OFFSET = 0 ;

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*					Initialize the heap memory area										*/			
/* ----------------------------------------------------------------------------------------------- */
int initialize_heapmemory()
{
	// initial the heap memory area
	memset( (uint *)HEAP_MEM_AREA_PTR , 0x00000000, HEAP_MEM_AREA_MAX_SIZE);
	
	xil_printf("\r\n-- Memory allocate 0x%8x as heap memory area , total %ld bytes ... ", HEAP_MEM_AREA_PTR, HEAP_MEM_AREA_MAX_SIZE);
		
	return 0 ;
}

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*								Heap memory allocation										*/			
/* ----------------------------------------------------------------------------------------------- */
void* mem_alloc(BYTE byte)
{
	HEAP_OFFSET += byte ;
	
	if (HEAP_OFFSET == HEAP_MEM_AREA_MAX_SIZE)	
	{
		xil_printf("\r\n-- Heap Memory is full ... \r\n\r\n");
		
		HEAP_OFFSET = 0 ;		
	}  	
	
	return (HEAP_MEM_AREA_PTR + HEAP_OFFSET) ;
}

inline void heap_align32(){
	if(((unsigned int)CURRENT_HEAP_PTR & 31) != 0) {
				
		CURRENT_HEAP_PTR = (((unsigned int)CURRENT_HEAP_PTR >> 5) + 1) << 5;
			
	}
}



inline void cache_WB_flush(uint8 core_id)
{
	volatile uint *cache_flush_en_volatile	=	(uint*)GET_CTRL_REG_MEM0ADDR(core_id , cache_flush_en);
	volatile uint *flush_cmplt32_volatile	=	(uint*)GET_CTRL_REG_MEM0ADDR(core_id , flush_cmplt32);
	*cache_flush_en_volatile = 1;
	while (*flush_cmplt32_volatile  < 1);
	*cache_flush_en_volatile = 0;
}

