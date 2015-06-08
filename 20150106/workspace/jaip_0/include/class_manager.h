/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*																								*/ 
/*   System Software of Dual-Core Java Runtime Environment										*/
/*																								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: class_manage.h																		*/
/*   Author: Kuan-Nian Su																		*/
/*   Date: Apr/14/2009																			*/
/* ----------------------------------------------------------------------------------------------- */
/*   1. Function declaration & implementation in class_manage.c									*/
/*   2. 2nd-level Method area declaration														*/
/*   3. Manage Table declaration																*/									
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

#ifndef _CLASS_MANAGE_H_
#define _CLASS_MANAGE_H_

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*							Method Area Declaration										*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/
// define the size of method area
#define METHOD_AREA_MAX_SIZE	0x80000 //524288
#define METHOD_AREA_ADDRESS		0x5a000000  //0x0002F000


/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*								Function Prototypes Declaration								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/

// initialize the 2nd-level method area
int initialize_methodarea( ) ; 

// Write the JAva Runtime Image into 2nd-level method area
int load_to_methodarea( uint16 cls_id ) ;

// get the starting address in method area before loading
int get_starting_address() ;

#endif

