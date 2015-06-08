/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*																								*/ 
/*   System Software of Dual-Core Java Runtime Environment										*/
/*																								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: mem_dbg.c																			*/
/*   Author: Kuan-Nian Su																		*/
/*   Date: Apr/10/2009																			*/
/* ----------------------------------------------------------------------------------------------- */
/*   Declaration some debugging function														*/
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

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*								Showing Memory Function Implementation						*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/
void view_memory(Xuint32 * base_address, Xuint32 num_bytes)
{
	Xuint32 buf[16] ;
	Xuint32 ctr = 0;
	Xuint32 num = 0;
	
	xil_printf("\r\n-------------------------------------------------------------------------\r\n");
	xil_printf("| ADDRESS  |					MEMORY DATA							|\r\n");
	xil_printf("|		|  0001   0203   0405   0607	0809   0A0B   0C0D   0E0F   |");	
	xil_printf("\r\n-------------------------------------------------------------------------\r\n");
	
	while((ctr+ctr) < num_bytes)
	{
		num=*(((Xuint16 *) base_address)+ctr);
		
		if(!(ctr%8))
		{ 
			xil_printf("|");
			
			xil_printf("%4x",(((long) ((((Xuint16 *) base_address) + ctr))>> 16)&0x0000ffff));
			xil_printf(":");
			
			xil_printf("%4x",((long) ((((Xuint16 *)base_address) + ctr)) & 0x0000ffff));
			xil_printf(" | ");
		}
		
		if (num > 0x0FFF)
			xil_printf(" %4x ",num);
		else if (num > 0x00FF)
			xil_printf(" 0%3x ",num);
		else if (num > 0x000F)
			xil_printf(" 00%x ",num);
		else	
			xil_printf(" 000%x ",num);
		
		if(ctr%8==3) 
			xil_printf(" - ");
		else  
			xil_printf(" ");
		
		ctr+=1;
		if(!(ctr%8))
			xil_printf(" |\r\n");
	}
	xil_printf("-------------------------------------------------------------------------\n\r");
}
