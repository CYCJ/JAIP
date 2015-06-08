/* /////////////////////////////////////////////////////////////////////////////////////////////// */
/*                                                                                                 */ 
/*   System Software of Dual-Core Java Runtime Environment                                         */
/*                                                                                                 */ 
/* ----------------------------------------------------------------------------------------------- */
/*   File: class_structure.h                                                                       */
/*   Author: Chien-Fong Huang                                                                        */
/*   Date: 9/15/2009                                                                             */
/* ----------------------------------------------------------------------------------------------- */
/*   1. Java Runtime Image structure declaration                                                   */
/*   2. Linking structure declaration                                                              */ 
/*                                                                                                 */
/*   Copyright, 2007.                                                                              */
/*   Multimedia Embedded Systems Lab.                                                              */
/*   Department of Computer Science and Information engineering                                    */
/*   National Chiao Tung University, Hsinchu 300, Taiwan                                           */
/* ----------------------------------------------------------------------------------------------- */
/* /////////////////////////////////////////////////////////////////////////////////////////////// */
// This Table record the Class Index and method code address for Image TOC construct
//  
#include "metypes.h"
#define CNAME_SIZE       80
#define MAX_METHODNUM    30
#define MAX_CLASS_NUMBER 260
#define MAX_METHOD       200
#define MAX_TEMP_LIST    30
#define MAX_ldc_data          50
#define MAX_ldc_data_length   50
#define MAX_string_pool_SIZE  16384 // 16k
#define MAX_string_pool       512
//#define TEMP_API "java/io/PrintStream"
#define MAX_METHOD_TABLE 12288//3072//2048  //no use?
#define LEVEL1_XRT_BASE_ADDRESS      0x88018000 //0x88018000 // 0xB9000000//0xC1008000//0xffff8000//0xffff8000//0xC4008000//0xffff8000//0x00010000//
//#define CLS_INFO_TABLE_ADDRESS	  0x8801BFFC
#define CLS_INFO_TABLE_ADDRESS	  0x88014000

#define SET_BIT(ADDR, BIT) \
		*ADDR |= (1 << BIT);
#define SET_VALUE(ADDR, UPPER, LOWER, VALUE) \
		RANGE_CLEAR(ADDR, UPPER, LOWER)	\
		*ADDR |= (VALUE << LOWER) & ((1 << (UPPER + 1)) - 1);
#define RANGE_CLEAR(ADDR, UPPER, LOWER)	\
		*ADDR &= ((0xFFFFFFFF << (UPPER + 1)) | (0xFFFFFFFF >> (32 - LOWER)));
		
//unsigned int method_table[MAX_MATHOD_TABLE];

typedef struct
{
    uint8* method_name;
    uint16 method_namel;
    uint8* descript_name;
    uint16 descript_namel;
    uint   method_offset;
    uint16 access_flag;   
    uint8  arg_size; // added by T.H.Wu , 2013.8.23
} method_data;


typedef struct
{
    uint16 cls_id;
    uint8* field_name;
    uint16 field_namel;
    uint   field_address;     //class_num[16] | offset[12]
    uint16 field_tag;        // static flag| primitive flag | long type flag | array/obj flag
    //unsigned int block_field_address;
} field_data;


typedef struct
{
    unsigned char data[MAX_ldc_data_length];
    unsigned int type;
} ldc_data;
/*
  Structure store the public static method code or variable image address offset
*/
typedef struct
{
    //unsigned int global_index;
    uint8         class_name[CNAME_SIZE];
    uint16        class_namel;
    uint16        obj_size; // content class_num + field data
    uint8         IsCache;
    uint          parent_index;
    uint8         isIntf;
    uint16        intf_cnt;
    uint16        intf[MAX_CLASS_NUMBER];
    uint          base_address;
    uint          image_size;
    uint          cst_size; //added by -ji-jing
    uint          init_offset;
    uint          clinit_offset;
	uint16		  clinit_ID;	
    uint16        method_cnt;
    method_data   method[MAX_METHOD];
    uint16        field_cnt;
    field_data    field[MAX_METHOD];
    
	ldc_data      ldc[MAX_ldc_data];
    uint16        ldc_cnt;
    uint8         string_pool[MAX_string_pool_SIZE];
    uint16        string_pool_offset[MAX_string_pool];
    uint16        ldc_idx_img2cls[1024];  
} class_cross_reference_table ;
/*
  Define The Class Cross reference table 
*/

extern class_cross_reference_table  x_ref_tbl[MAX_CLASS_NUMBER];
