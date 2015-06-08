/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*                                                                                                 */ 
/*   System Software of Dual-Core Java Runtime Environment                                         */
/*                                                                                                 */ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: class_manage.c                                                                          */
/*   Author: Kuan-Nian Su                                                                          */
/*   Date: Apr/14/2009                                                                             */
/* ----------------------------------------------------------------------------------------------- */
/*   Implement some function to manage the 2nd-level method area                        */
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

#include <xio.h>
#include "../include/metypes.h"

#include "../include/class_structure.h"
#include "../include/class_manager.h"
#include "../include/debug_option.h"

/*                                                                                                 */
/* ----------------------------------------------------------------------------------------------- */
/*                                 Global Variables Declaration                                    */ 
/* ----------------------------------------------------------------------------------------------- */
/*                                                                                                 */
volatile uint CLASS_OFFSET = 0;
// defien the ptr of 2nd-level method area
volatile unsigned short *METHOD_AREA_PTR  = (unsigned short *)METHOD_AREA_ADDRESS ;

// record the image allocation


/*                                                                                                 */
/* ----------------------------------------------------------------------------------------------- */
/*                       Initialize the 2nd-level method area                                      */              
/* ----------------------------------------------------------------------------------------------- */
int initialize_methodarea()
{
    // initial the 2nd-level method area
    memset((void *) METHOD_AREA_PTR , 0, METHOD_AREA_MAX_SIZE*sizeof(unsigned short));  
    CLASS_OFFSET = 0;
    xil_printf("\r\n-- Memory allocate 0x%8x as 2nd method area , total %ld bytes ...  \r\n\r\n", METHOD_AREA_PTR, (METHOD_AREA_MAX_SIZE*sizeof(unsigned short)));
         
    return 0 ;
}

/*                                                                                                 */
/* ----------------------------------------------------------------------------------------------- */
/*                   Get the starting address in method area before loading                        */              
/* ----------------------------------------------------------------------------------------------- */
int get_starting_address()
{
	// xil_printf("\r\n Get: Class offset %x\r\n",CLASS_OFFSET);
    return CLASS_OFFSET ;		
}

/* ----------------------------------------------------------------------------------------------- */
/*                    Write the Java Runtime Image into 2nd-level method area                      */              
/* ----------------------------------------------------------------------------------------------- */
int load_to_methodarea( uint16 cls_id )
{
	int cls_size = 0 ;  // unit : byte
	int idx = 0 ; 
    int adjust ;

    //added by jing
    uint16 cp_data_start_offset =0;
    uint16 cp_data_offset =0;
    uint16 *cp_toc  = cls_image.cp_toc;
    uint32 *cp_data = cls_image.cp_data;
    uint32 *cst_addr = 0;


    // Writting header
    *(METHOD_AREA_PTR + CLASS_OFFSET)    = 0x4D4D ;
    *(METHOD_AREA_PTR + CLASS_OFFSET +1) = 0x4553 ;
    //  modify by G
    // *(METHOD_AREA_PTR + CLASS_OFFSET +2) = cls_image.CPcount ;
    // *(METHOD_AREA_PTR + CLASS_OFFSET +3) = cls_image.Parent_index ;
    // cls_size += 4 ;
     cls_size += 2;
    
#if class_managedebug
    xil_printf("Writting TOC\r\n");
#endif
    // Writting TOC
    memcpy((unsigned short*)(METHOD_AREA_PTR + CLASS_OFFSET + cls_size),cls_image.cp_toc, cls_image.CPcount*4);
    cls_size += cls_image.CPcount ;
    //cls_size += cls_image.cp_toc[0] ;
#if class_managedebug
    xil_printf("Writting Constant Pool Data\r\n");
#endif
    // Writting Constant Pool Data
   // memcpy((unsigned short*)(METHOD_AREA_PTR + CLASS_OFFSET + cls_size),cls_image.cp_data, cls_image.cp_nbytes);
#if class_managedebug
    xil_printf("cls_image.cp_nbytes: %x\r\n",cls_image.cp_nbytes);
#endif

    //modify by G
    cls_size += cls_image.cp_nbytes>>1 ;
    memcpy((unsigned short*)(METHOD_AREA_PTR + CLASS_OFFSET + cls_size),cls_image.mt_code,cls_image.mt_nbytes);
    cls_size += cls_image.mt_nbytes>>1 ;
 
    // adjust the offset
    if( (cls_size & 0x7) == 0){
        CLASS_OFFSET = cls_size + CLASS_OFFSET + 8;
    }
    else{
        CLASS_OFFSET = (cls_size & 0xFFFFFFF8) + CLASS_OFFSET + 16;
    }

    return (cls_size<<1) ;
}

