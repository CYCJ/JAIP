/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*																								*/ 
/*   System Software of Dual-Core Java Runtime Environment										*/
/*																								*/ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: class_structure.h																	*/
/*   Author: Chun-Jen Tsai																		*/
/*   Date: Mar/18/2007																			*/
/* ----------------------------------------------------------------------------------------------- */
/*   1. Java Runtime Image structure declaration												*/
/*   2. Linking structure declaration															*/ 
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


#ifndef _CLASS_STRUCTURE_H_
#define _CLASS_STRUCTURE_H_


// Define SIZE
#define MAX_SIZE			16384 //16K
#define TOC_SIZE			1024  //1K
#define STRING_SIZE		100

/*																								*/
/*							Java Runtime Image structure declaration							*/
/* ----------------------------------------------------------------------------------------------- */
/* header :																						*/
/*		starting_addr - address of this runtime image in method area							*/
/*		field_addr	- address of field definition											*/
/*		method_addr   - address of method definition											*/
/*		nxt_class_addr- address of next runtime image in method area							*/
/* class info :																					*/
/*		cls_name	- this class name														*/
/*		max_local	- maximum local variables of main function								*/
/* program counter info :																		*/
/*		main_pc	- program counter of main function										*/
/*		clinit_offset - address offset of <clinit> function									*/
/* constant pool info :																			*/
/*		cp_toc		- table of constant.													*/
/*		cp_data	- constant pool															*/
/*		cp_nbytes	- size of constant pool													*/ 
/* field info :																					*/
/*		fd_info	- save the address and the index of each field							*/
/*		fd_data	- field definition														*/
/*		fd_nbytes	- size of field definition												*/ 
/* method info :																				*/
/*		mt_info	- save the address and the index of each method							*/
/*		mt_code	- method definition														*/
/*		mt_nbytes	- size of method definition												*/ 
/* additional :																					*/
/*		image_size	- size of this runtime image											*/ 
/* ----------------------------------------------------------------------------------------------- */
/*																								*/
typedef struct
{
	// header
	unsigned short CPcount				;
	unsigned short Parent_index		;
	//------------------------------------ 
	unsigned short starting_addr		;
	unsigned short field_addr			;
	unsigned short method_addr			;
	unsigned short nxt_cls_addr		;
	
  	unsigned short cp_cnt;
	// class info
	unsigned char  cls_name  [STRING_SIZE];
	unsigned short main_max_local		;
	//  unsigned short header	[4]		;
	// program counter info
	unsigned short main_pc				; 
	unsigned short clinit_offset		;
	
	// constant pool info
	unsigned short cp_toc		[TOC_SIZE];
	unsigned char  cp_data		[MAX_SIZE];
	unsigned long  cp_nbytes				; 
	
	// field info
	unsigned short fd_idx_img2cls [TOC_SIZE];
	unsigned char  fd_data		[MAX_SIZE];
	unsigned long  fd_nbytes				;
	
	// method info
	unsigned short mt_idx_img2cls [TOC_SIZE];
	unsigned char  mt_code		[MAX_SIZE];
	unsigned long  mt_nbytes				; 
	
} class_image ;

class_image		cls_image				;


#endif

