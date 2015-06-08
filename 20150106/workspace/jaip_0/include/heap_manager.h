/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*																								*/
/*   System Software of Dual-Core Java Runtime Environment										*/
/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*   File: heap_manage.h																		*/
/*   Author: Kuan-Nian Su																		*/
/*   Date: Jul/02/2009																			*/
/* ----------------------------------------------------------------------------------------------- */
/*   1. Function declaration & implementation in heap_manage.c									*/
/*   2. Heap memory area declaration															*/
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

#ifndef _HEAP_MANAGE_H_
#define _HEAP_MANAGE_H_

typedef unsigned char BYTE ;

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*						Heap Memory Area Declaration										*/
/* ----------------------------------------------------------------------------------------------- */
/*																								*/
// define the size of heap memory area 0x000A0000 ~ 0x00120000
#define HEAP_MEM_AREA_MAX_SIZE	0x02000000//8192 //16394//8192//2048 //524288
#define HEAP_MEM_AREA_ADDRESS	0x5C000000//DRAM:0x5d000000//ONCHIP:0x8801c000
/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*								Function Prototypes Declaration								*/
/* ----------------------------------------------------------------------------------------------- */
/*																								*/

int initialize_heapmemory() ;

void * mem_alloc(BYTE byte) ;
inline void heap_align32();
#endif

