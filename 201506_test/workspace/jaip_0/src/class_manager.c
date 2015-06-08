/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*																								*/ 
/*   System Software of Dual-Core Java Runtime Environment										*/
/*																								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: class_manage.c																		*/
/*   Author: Kuan-Nian Su																		*/
/*   Date: Apr/14/2009																			*/
/* ----------------------------------------------------------------------------------------------- */
/*   Implement some function to manage the 2nd-level method area						*/
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
#include "../include/metypes.h"

#include "../include/class_structure.h"
#include "../include/class_manager.h"
#include "../include/debug_option.h"

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*								Global Variables Declaration									*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/
volatile uint CLASS_OFFSET = 0;
// defien the ptr of 2nd-level method area
volatile unsigned short *METHOD_AREA_PTR  = (unsigned short *)METHOD_AREA_ADDRESS ;

// record the image allocation


/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*					Initialize the 2nd-level method area									*/			
/* ----------------------------------------------------------------------------------------------- */
int initialize_methodarea()
{
	// initial the 2nd-level method area
	memset((void *) METHOD_AREA_PTR , 0, METHOD_AREA_MAX_SIZE*sizeof(unsigned short));  
	CLASS_OFFSET = 0;
	xil_printf("\r\n-- Memory allocate 0x%8x as 2nd method area , total %ld bytes ...  \r\n\r\n", METHOD_AREA_PTR, (METHOD_AREA_MAX_SIZE*sizeof(unsigned short)));
		
	return 0 ;
}

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*				Get the starting address in method area before loading						*/			
/* ----------------------------------------------------------------------------------------------- */
int get_starting_address()
{
	return CLASS_OFFSET ;		
}

/* ----------------------------------------------------------------------------------------------- */
/*					Write the Java Runtime Image into 2nd-level method area					*/			
/* ----------------------------------------------------------------------------------------------- */
int load_to_methodarea( uint16 cls_id )
{
	int cls_size = 0 ;  // unit : byte

	// Writting header
	*(METHOD_AREA_PTR + CLASS_OFFSET)	= 0x4D4D ;
	*(METHOD_AREA_PTR + CLASS_OFFSET +1) = 0x4553 ;
	cls_size += 2;

	// Writting TOC
	memcpy((unsigned short*)(METHOD_AREA_PTR + CLASS_OFFSET + cls_size),cls_image.cp_toc, cls_image.CPcount*4);
	cls_size += cls_image.CPcount ;

	//modify by G
	cls_size += cls_image.cp_nbytes>>1 ;
	memcpy((unsigned short*)(METHOD_AREA_PTR + CLASS_OFFSET + cls_size),cls_image.mt_code,cls_image.mt_nbytes);
	cls_size += cls_image.mt_nbytes>>1 ;
 
	// adjust the offset
	if( (cls_size & 0x7) == 0)	CLASS_OFFSET = cls_size + CLASS_OFFSET + 8;
	else	CLASS_OFFSET = (cls_size & 0xFFFFFFF8) + CLASS_OFFSET + 16;

	return (cls_size<<1) ;
}

