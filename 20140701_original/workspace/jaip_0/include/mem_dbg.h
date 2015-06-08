/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*                                                                                                 */ 
/*   System Software of Dual-Core Java Runtime Environment                                         */
/*                                                                                                 */ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: mem_dbg.h                                                                              */
/*   Author: Kuan-Nian Su                                                                          */
/*   Date: Apr/10/2009                                                                             */
/* ----------------------------------------------------------------------------------------------- */
/*   Declaration some debugging function                                                           */
/*                                                                                                 */
/*   Copyright, 2007.                                                                              */
/*   Multimedia Embedded Systems Lab.                                                              */
/*   Department of Computer Science and Information engineering                                    */
/*   National Chiao Tung University, Hsinchu 300, Taiwan                                           */
/* ----------------------------------------------------------------------------------------------- */
/*   MODIFICATIONS                                                                                 */
/*                                                                                                 */
/*   Author:                                                                                       */
/*   Date:                                                                                         */
/* /////////////////////////////////////////////////////////////////////////////////////////////// */

#ifndef _MEM_DEBUG_H_
#define _MEM_DEBUG_H_

/*                                                                                                 */
/* ----------------------------------------------------------------------------------------------- */
/*                               Debugging Mode Setting Option                                     */ 
/* ----------------------------------------------------------------------------------------------- */
/*                                                                                                 */
#define DEBUG_MODE                1
#define DEBUG_VIEWMEM_BYTE        500

/*                                                                                                 */
/* ----------------------------------------------------------------------------------------------- */
/*                                 Function Prototypes Declaration                                 */ 
/* ----------------------------------------------------------------------------------------------- */
/*                                                                                                 */

void view_memory(Xuint32 * base_address, Xuint32 num_bytes);


#endif

