/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*																								*/ 
/*   System Software of Dual-Core Java Runtime Environment										*/
/*																								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: class_loader.h																		*/
/*   Author: Chun-Jen Tsai																		*/
/*   Date: Mar/18/2007																			*/
/* ----------------------------------------------------------------------------------------------- */
/*   1. Function declaration & implementation in class_loader.c									*/
/*   2. Constant Pool tag info. declaration														*/
/*																								*/
/*   Copyright, 2007.																			*/
/*   Multimedia Embedded Systems Lab.															*/
/*   Department of Computer Science and Information engineering									*/
/*   National Chiao Tung University, Hsinchu 300, Taiwan										*/
/* ----------------------------------------------------------------------------------------------- */
/*   MODIFICATIONS																				*/
/*																								*/
/*   Author: Kuan-Nian Su																		*/
/*   Date: Dec/2008																				*/
/* ----------------------------------------------------------------------------------------------- */
/*   MODIFICATIONS																				*/
/*																								*/
/*   Author: Kuan-Nian Su																		*/
/*   Date: Apr/2009																				*/
/* /////////////////////////////////////////////////////////////////////////////////////////////// */


#ifndef _CLASS_LOADER_H_
#define _CLASS_LOADER_H_

# include "../include/metypes.h"

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*								Constant Pool Tag Declaration								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/
#define CP_Utf8			0x01
#define CP_Integer			0x03
#define CP_Float			0x04
#define CP_Long			0x05
#define CP_Double			0x06
#define CP_Class			0x07
#define CP_String			0x08
#define CP_Fieldref		0x09
#define CP_Methodref		0x0A
#define CP_InterfaceMethodref 0x0B
#define CP_NameAndType		0x0C

/*																								*/
/* ----------------------------------------------------------------------------------------------- */
/*								Function Prototypes Declaration								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/

//initialize xrt_ref
void initialize_xrt_ref();

//initialize the class structure
int initialize_class_structure() ;

// Read the entry in TOC											
unsigned short getCP_toc(unsigned char *p);

// add for parsing Thread.start() , Thread.tun() , 2013.7.12
unsigned int check_if_extended_from_Thread_class( );
// add for parsing Thread.start() , Thread.tun() , 2013.7.12
void set_thread_class_flag (unsigned int f);

// Parse the class file and generate the runtime omage
int  parse_classfile(uint8 core_id,
					unsigned char  *cf	, unsigned short *field_addr, unsigned short *method_addr,
					unsigned short *cp_toc , unsigned char  *cp_data   , unsigned long  *cp_nbytes ,
					unsigned short *fd_idx_img2cls, unsigned char  *fd_data   , unsigned long  *fd_nbytes ,
					unsigned short *mt_idx_img2cls, unsigned char  *mt_code   , unsigned long  *mt_nbytes ,
					unsigned short *main_pc, unsigned short *clinit_pc , 
					unsigned char  *cls_name,unsigned short *main_locals,int gdx) ;

// Update the field value for global static field
int clinit_initializer( unsigned short *cp_toc  , unsigned char  *cp_data , unsigned char  *fd_data ,
						unsigned char  *mt_code , unsigned short *clinit_pc ) ;

//convert utf8 to unicode
short utf2unicode(const char **utfstring_ptr);

// added by T.H.Wu , 2013.8.15
#define GET_LV1_XRT_ABS_ADDR(core_id, relative_addr) \
		(volatile uint*)( (LEVEL1_XRT_BASE_ADDRESS) | ((core_id)<<17) | (((uint)(relative_addr)) & 0x0000FFFF) )



#endif

