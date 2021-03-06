/* ////////////////////////////////////////////////////////////////// */
/*																	*/
/*   System Software of Dual-Core Java Runtime Environment			*/
/*																	*/
/* ------------------------------------------------------------------ */
/*   File: class_loader.c											*/
/*   Author: Chun-Jen Tsai											*/
/*   Date: Mar/18/2007												*/
/* ------------------------------------------------------------------ */
/*   Implement the generator to convert Java class file into Java	*/
/*   runtime image.												*/
/*																	*/
/*																	*/
/*   Copyright, 2007.												*/
/*   Multimedia Embedded Systems Lab.								*/
/*   Department of Computer Science and Information engineering	*/
/*   National Chiao Tung University, Hsinchu 300, Taiwan			*/
/* ------------------------------------------------------------------ */
/*   MODIFICATIONS													*/
/*																	*/
/*   Author: Kuan-Nian Su											*/
/*   Date: Dec/2008, Apr/2009										*/
/* ------------------------------------------------------------------ */
/*   MODIFICATIONS													*/
/*																	*/
/*   Author: Han-Wen Kuo											*/
/*   Date: Aug/13/2010												*/
/*   for print instruction											*/
/* ------------------------------------------------------------------ */
/*   MODIFICATIONS													*/
/*																	*/
/*   Author: Han-Wen Kuo											*/
/*   Date: Sem/05/2010												*/
/*   for new Run-Time Image										*/
/* ------------------------------------------------------------------ */
/*   MODIFICATIONS													*/
/*																	*/
/*   Author: Zi-Gang Lin											*/
/*   Date: Feb/16/2011												*/
/*   for inherit													*/
/* ------------------------------------------------------------------ */
/*   MODIFICATIONS													*/
/*																	*/
/*   Author: Zi-Gang Lin											*/
/*   Date: May/27/2011												*/
/*   for ldc instruction											*/
/* ------------------------------------------------------------------ */
/*   MODIFICATIONS													*/
/*																	*/
/*   Author: Zi-Jing Guo											*/
/*   Date: April/23/2012											*/
/*   for exception table											*/
/* ////////////////////////////////////////////////////////////////// */

#include <string.h>
#include "../include/metypes.h"
#include "../include/class_loader.h"
#include "../include/class_manager.h"
#include "../include/class_structure.h"
#include "../include/class_mt_manager.h"
#include "../include/file.h"
#include "../include/mmes_jpl.h"
#include "../include/heap_manager.h"
#include "../include/debug_option.h"
#include <xparameters.h>

volatile unsigned short *METHOD_AREA_ADDR  = (unsigned short *)METHOD_AREA_ADDRESS ;

extern unsigned char sys_jar_image[MAX_BUFFER_SIZE];
extern unsigned long sys_jar_size;
//extern volatile unsigned int CURRENT_HEAP_PTR;
// for fixing multiple main method bug , 2013.7.16
extern char *main_class_fully_qualified_name;

int cp_info_size[] = { 0, 3, 0, 5, 5, 9, 9, 3, 3, 5, 5, 5, 5, 0, 0, 0 };

#if cst_32
//for cst32 testing toc
unsigned int cp_toc32	[256];
#endif

uint mt_table_count = 0;
// profiling about the number used for field info/method info in cross reference table .
uint num_entry_xrt_field_count = 0;
uint num_entry_xrt_method_count = 0;

volatile uint *LEVEL1_XRT_PTR = (uint *) LEVEL1_XRT_BASE_ADDRESS;

uint try_block_offset = 0;
uint ER_LUT_addr = 12;

/* Java class runtime cross reference table. Note: "x_" stands for "cross" */
class_cross_reference_table x_ref_tbl[MAX_CLASS_NUMBER];

// added by fox , 2013.7.10
unsigned int	is_thread_class_flag = 0;
uint	*start_method_info_ptr = 0; // point to the first entry of start method
uint16	run_method_global_mthd_idx = 0;

// modified by T.H.Wu , 2013.9.10
static uint is_main_method_found = 0;
uint16 main_cls_id ;
uint16 main_mthd_id;


uint16 JavaLangString;
/* ------------------------------------------------------------------ */
/* Initialize the class structure									*/
/* ------------------------------------------------------------------ */
int
initialize_class_structure()
{
	// header
	cls_image.field_addr = 0 ;
	cls_image.method_addr = 0 ;

	// class info
	memset((void *)cls_image.cls_name, 0, STRING_SIZE*sizeof(uint8));
	cls_image.main_max_local  = 0 ;

	// program counter info
	cls_image.main_pc = 0 ;
	cls_image.clinit_offset = 0 ;

	// constant pool info
	memset((void *)cls_image.cp_toc, 0, TOC_SIZE*sizeof(uint16));
	//memset((void *)cls_image.cp_data, 0, MAX_SIZE*sizeof(uint8));
	cls_image.cp_nbytes = 0 ;

	// field info
	memset((void *)cls_image.fd_idx_img2cls, 0, TOC_SIZE*sizeof(uint16));
	//memset((void *)cls_image.fd_data, 0, MAX_SIZE*sizeof(uint8));
	cls_image.fd_nbytes = 0 ;

	// method info
	memset((void *)cls_image.mt_idx_img2cls, 0, TOC_SIZE*sizeof(uint16));
	memset((void *)cls_image.mt_code, 0, MAX_SIZE*sizeof(uint8));
	cls_image.mt_nbytes = 0 ;

	// initialize some misc flags
	is_main_method_found = 0;
	main_cls_id = 0;
	main_mthd_id = 0;

	return 0 ;
}

/* ---------------------------------------------------------------- */
/*  Read unsigned value form cf_ptr								*/
/* ---------------------------------------------------------------- */
uint16
read_uint16(uint8 *p)
{
	return (p[0] << 8) + p[1];
}

uint32
read_uint32(uint8 *p)
{
	return (p[0] << 24) + (p[1] << 16) + (p[2] << 8) + p[3];
}

// field descriptors analyzer
uint8 field_descriptor_analyzer(char * descriptor){
	uint8 descriptor_flag;
	if(descriptor[0] == 'B'){
		descriptor_flag = 4;
	}
	else if(descriptor[0] == 'C'){
		descriptor_flag = 4;
	}
	else if(descriptor[0] == 'D'){
		xil_printf("Double is not suppled!!\n");
		descriptor_flag = -1;
	}
	else if(descriptor[0] == 'F'){
		xil_printf("Float is not suppled!!\n");
		descriptor_flag = -1;
	}
	else if(descriptor[0] == 'I'){
		descriptor_flag = 4;
	}
	else if(descriptor[0] == 'J'){
		descriptor_flag = 6;
	}
	else if(descriptor[0] == 'L'){
		descriptor_flag = 0;
	}
	else if(descriptor[0] == 'S'){
		descriptor_flag = 4;
	}
	else if(descriptor[0] == 'Z'){
		descriptor_flag = 4;
	}
	else if(descriptor[0] == '['){
		descriptor_flag = 1;
	}
	else descriptor_flag = -1;

	return descriptor_flag;
}

// method descriptors analyzer
int method_descriptor_analyzer(char* desname){
	int idx = 1;
	int parameter_count = 0;
	while(desname[idx] != ')'){
		//printf("desname[idx]:%X\n", desname[idx]);
		if(desname[idx] == 'L'){
			parameter_count++;
			do{
				idx++;
			} while(desname[idx] != ';');
		}
		else if(desname[idx] == '['){

			parameter_count++;
			do{
				idx++;
			} while(desname[idx] == '[');

			if(desname[idx] == 'L'){
				do{
					idx++;
				} while(desname[idx] != ';');
			}
		}
		//CYC 141221 for 64-bits arguments
		else if (desname[idx] == 'J' || desname[idx] == 'D')
			parameter_count+=2;
		else
			parameter_count++;
			
		idx++;
	}
	return parameter_count;
}


// add for parsing Thread.start() , Thread.tun() , 2013.7.12
unsigned int check_if_extended_from_Thread_class(){
	// added by fox , for getting global ID of run method , copy it into start method, 2013.7.10
	//if( !(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)) ){
	//	is_thread_class_flag = 1;
	//}
	//else{
	//	is_thread_class_flag = 0;
	//}
	return is_thread_class_flag;
}

// add for parsing Thread.start() , Thread.tun() , 2013.7.12
void set_thread_class_flag (unsigned int f){
	is_thread_class_flag = f;
}

//added for updating argument size / return size of all native methods
// by T.H.Wu , 2013.9.18
void update_cst_entry_for_native_method
	(
		uint16 cls_gnum,
		uint16 mtnamel,
		uint16 desnamel,
		uint8 *methodname,
		uint8 *desname,
		uint *address
	)
{

	// method_name string copy
	//printf("[class_loader,1859] methodname:%s , desname:%s \n", methodname , desname);
	// modified argument size for native method info again ,  by T.H.Wu , 2013.8.28, 1717
	//printf("[class_loader,269] methodname:%s,  , method info: %x \n" , methodname, *address);

	// test by T.H.Wu , try to modify the method info format
	if(mtnamel == 7 && desnamel == 37
			&& !strncmp(methodname, "forName", mtnamel)
			&& !strncmp(desname, "(Ljava/lang/String;)Ljava/lang/Class;", desnamel)
			){
		(*address) = (1<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 11 && desnamel == 20
			&& !strncmp(methodname, "newInstance", mtnamel)
			&& !strncmp(desname, "()Ljava/lang/Object;", desnamel)
			){
		(*address) = (1<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 6 && desnamel == 4
			&& !strncmp(methodname, "write0", mtnamel)
			&& !strncmp(desname, "(I)V", desnamel)
			&& !strncmp(x_ref_tbl[cls_gnum].class_name, "com/sun/cldc/io/ConsoleOutputStream", 35)
			){
		(*address) = (0<<24) | (0x02<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 5 && desnamel == 3
			&& !strncmp(methodname, "yield", mtnamel)
			&& !strncmp(desname, "()V", desnamel)
			){
		(*address) = (0<<24) | (0<<24) | (0x00<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 9 && desnamel == 42
			&& !strncmp(methodname, "arraycopy", mtnamel)
			&& !strncmp(desname, "(Ljava/lang/Object;ILjava/lang/Object;II)V", desnamel)
			){
		(*address) = (0<<24) | (0x05<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 7 && desnamel == 22
			&& !strncmp(methodname, "indexOf", mtnamel)
			&& !strncmp(desname, "(Ljava/lang/String;I)I", desnamel)
			){
		(*address) = (1<<24) | (0x03<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 7 && desnamel == 5
			&& !strncmp(methodname, "indexOf", mtnamel)
			&& !strncmp(desname, "(II)I", desnamel)
			){
		(*address) = (1<<24) | (0x03<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 7 && desnamel == 22
		&& !strncmp(methodname, "indexOf", mtnamel)
		&& !strncmp(desname, "(Ljava/lang/Object;I)I", desnamel)
		){
		(*address) = (1<<24) | (0x03<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 11 && desnamel == 5
			&& !strncmp(methodname, "lastIndexOf", mtnamel)
			&& !strncmp(desname, "(II)I", desnamel)
			){
		(*address) = (1<<24) | (0x03<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 17 && desnamel == 3
			&& !strncmp(methodname, "currentTimeMillis", mtnamel)
			&& !strncmp(desname, "()J", desnamel)
			){
		(*address) = (2<<24) | (0x00<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 12 && desnamel == 38
			&& !strncmp(methodname, "getProperty0", mtnamel)
			&& !strncmp(desname, "(Ljava/lang/String;)Ljava/lang/String;", desnamel)
			){
		(*address) = (1<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 6 && desnamel == 21
			&& !strncmp(methodname, "equals", mtnamel)
			&& !strncmp(desname, "(Ljava/lang/Object;)Z", desnamel)
			){
		(*address) = (1<<24) | (0x02<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 6 && desnamel == 27
			&& !strncmp(methodname, "append", mtnamel)
			&& !strncmp(desname, "(I)Ljava/lang/StringBuffer;", desnamel)
			){
		(*address) = (1<<24) | (0x02<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 6 && desnamel == 44
			&& !strncmp(methodname, "append", mtnamel)
			&& !strncmp(desname, "(Ljava/lang/String;)Ljava/lang/StringBuffer;", desnamel)
			){
		(*address) = (1<<24) | (0x02<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 8 && desnamel == 20
			&& !strncmp(methodname, "toString", mtnamel)
			&& !strncmp(desname, "()Ljava/lang/String;", desnamel)
			&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/String", 16)
			){
		(*address) = (1<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 16 && desnamel == 4
			&& !strncmp(methodname, "checkSystemState", mtnamel)
			&& !strncmp(desname, "(I)V", desnamel)
			){
		(*address) = (0<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 6 && desnamel == 4
			&& !strncmp(methodname, "charAt", mtnamel)
			&& !strncmp(desname, "(I)C", desnamel)){
		(*address) = (1<<24) | (0x02<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 7 && desnamel == 4
			&& !strncmp(methodname, "indexOf", mtnamel)
			&& !strncmp(desname, "(I)I", desnamel)){
		(*address) = (1<<24) | (0x02<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 7 && desnamel == 5
			&& !strncmp(methodname, "indexOf", mtnamel)
			&& !strncmp(desname, "(II)I", desnamel)){
		(*address) = (1<<24) | (0x03<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 8 && desnamel == 20
			&& !strncmp(methodname, "toString", mtnamel)
			&& !strncmp(desname, "()Ljava/lang/String;", desnamel)
			&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/StringBuffer", 22)){
		(*address) = (1<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 7 && desnamel == 20
			&& !strncmp(methodname, "getName", mtnamel)
			&& !strncmp(desname, "()Ljava/lang/String;", desnamel)){
		(*address) = (1<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 8 && desnamel == 19
			&& !strncmp(methodname, "getClass", mtnamel)
			&& !strncmp(desname, "()Ljava/lang/Class;", desnamel)){
		(*address) = (1<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 19 && desnamel == 3
			&& !strncmp(methodname, "currentTimeMillisHW", mtnamel)
			&& !strncmp(desname, "()J", desnamel)
			){
		(*address) = (2<<24) | (0x00<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 23 && desnamel == 3
			&& !strncmp(methodname, "currentTimeMillisINTRPT", mtnamel)
			&& !strncmp(desname, "()J", desnamel)
			){
		(*address) = (2<<24) | (0x00<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 9 && desnamel == 3
			&& !strncmp(methodname, "hashCode0", mtnamel)
			&& !strncmp(desname, "()I", desnamel)
			&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Object", 16)
			){
		(*address) = (1<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
	}

	else if(mtnamel == 9 && desnamel == 3
			&& !strncmp(methodname, "profileOn", mtnamel)
			&& !strncmp(desname, "()V", desnamel)
			&& !strncmp(x_ref_tbl[cls_gnum].class_name, "MMESProfiler", 12)
			){
		(*address) = (0<<24) | (0x00<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 10 && desnamel == 3
			&& !strncmp(methodname, "profileOff", mtnamel)
			&& !strncmp(desname, "()V", desnamel)
			&& !strncmp(x_ref_tbl[cls_gnum].class_name, "MMESProfiler", 12)
			){
		(*address) = (0<<24) | (0x00<<16) | ((*address) & 0xFF00FFFF);
	}
	else if(mtnamel == 5 && desnamel == 3
			&& !strncmp(methodname, "start", mtnamel)
			&& !strncmp(desname, "()V", desnamel)
			&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)
			){
		(*address) = (0<<24) | (0x01<<16) | ((*address) & 0xFF00FFFF);
		//xil_printf("[class_parser.c] find Thread.start() \r\n");
	}
	else{
	}
	/* */
}


/* -------------------------------------------------------------- */
/*  Parse a class file and generate a Class Runtime Image (CRTI)  */
/* -------------------------------------------------------------- */
/*  Note:														*/
/*	cp_toc   - the addr of each constant pool item in cp_data  */
/*	cls_gnum - is the Global ID of this class.				*/
/* -------------------------------------------------------------- */
int
parse_classfile(uint8	core_id,
				uint8  *classfile,	uint16 *parent_index,
				uint16 *CPcount,		uint16 *cp_toc,
				uint8  *cp_data,		uint32 *cp_nbytes,
				uint16 *fd_idx_img2cls, uint8  *fd_data,
				uint32 *fd_nbytes,
				uint16 *mt_idx_img2cls, uint8  *mt_code,
				uint32 *mt_nbytes,
				uint16 *main_pc,		uint16 *clinit_pc,
				uint8  *cls_name,	uint16 *main_locals,
				int cls_gnum)
{
	uint16 cp_offset, cp_bias;
	uint16 classfile_cp_toc[1024];
	/* CP data offset in original classfile  */

	uint16 string_idx_cls2sp[1024];
	uint16 cls_idx_img2cls [1024];
	uint16 ldc_idx_img2cls [1024];
	uint type, dim_num;

	uint16 sp_ptr;
	uint16 nitems;
	uint16 idx, jdx, kdx, zdx ,fdx, core_idx;
	uint16 str_length, max_locals, max_stacks, code_size;
	uint16 fd_cnt, mt_cnt, cls_cnt, intf_cnt, ldc_cnt, nonstatic;

	uint   temp1, temp, attribute_size;
	uint16 uint16_temp, uint16_temp2;
	uint16 access_flags;
	uint8  descriptor_flag;

	uint16 ref_field_cnt, ref_method_cnt, string_cnt;
	uint   ref_field_addr[1024],ref_method_addr[1024],cls_tag[1024],ldc_data[1024];
	uint16 ref_method_arg[1024];
	uint16 *store_data;

	uint8 tag, ldc_string_flag=0;;
	volatile uint address = 0;

	uint8 tmp[4];

	uint8 *sp_data, *fieldname, *methodname, *desname, *attrname, *classname;
	uint8 parse_classname[80], token , parse_classname2[80];
	uint16 fdnameid, mtnameid, desid, cnamel, fdnamel, mtnamel,
		desnamel, attr_count, attrid, attrnamel;

	uint8 *cf_ptr; /* cf_ptr points to current posistion in class file */
	uint mt_offset; /* mt_ptr points to current posistion in mt_code	*/
	uint IsClinit;

	uint16 ref_data_0,ref_data_1;
	
	//added by -ji-jing
	uint mthd_offset;
	unsigned short address_main = 0;
	unsigned short *data_main ; // modified by T.H. Wu, 2013.6.24
	unsigned short data_main_tmp =0;
	uint mt_offset_pre;
	uint data_main_ptr;
	uint aligment_shift_first_mthd;
	uint aligment_shift;
	//exception variables added by zi-jing 2012/6/8
	uint16 edx;
	uint16 ER_cnt;
	//uint16 try_blk_offset = 0;
	uint16 EID = 0;
	//uint routione_cnt_in_one_try = 0;
	uint16 rountine_jpc = 0;
	uint start_end_pc = 0;
	uint start_end_pc_read = 0;
	uint xcptn_read_offset = 0;
	
	// init
	core_idx = 0;
	

	

	/* skip magic number, minor, and major version numbers */
	cf_ptr = classfile;
	cf_ptr += 8;
	/* read constant pool count (2 bytes) */
	nitems = (uint16) read_uint16(cf_ptr);
	cf_ptr += 2;


	fd_cnt = mt_cnt = cls_cnt = ldc_cnt = nonstatic = dim_num= 0;
	/* Parsing Constant Pool */
	sp_data = x_ref_tbl[cls_gnum].string_pool;
	// the ptr in cp_data ,cp_data is a data array
	sp_ptr = 0;
	ref_field_cnt = 0;
	ref_method_cnt = 0;
	string_cnt = 0;

	for (idx = 1; idx < nitems; idx++)
	{
		tag = *cf_ptr;
		str_length = 0;
		classfile_cp_toc[idx] = (uint16) (cf_ptr - classfile);

			// test for inner class parsing , 2013.7.10 , added by T.H. Wu
		//if( !(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)) ){
		//	xil_printf("[class_loader.c] constant pool tag : %x  \r\n", tag);
		//}

		switch (tag)
		{

		case CP_Utf8:
			str_length = read_uint16(cf_ptr + 1);
			// store CP_Utf8 type data in string_pool
			memcpy(sp_data + sp_ptr, cf_ptr + 3, str_length);
			x_ref_tbl[cls_gnum].string_pool_offset[string_cnt] = sp_ptr;
			sp_ptr += str_length;
			cf_ptr += (cp_info_size[tag] + str_length);
			string_idx_cls2sp[idx] = string_cnt;
			string_cnt++;
			break;

		case CP_Long: // CYC 20140926
		case CP_Double:
		
			cp_toc[ldc_cnt] = idx;
			cf_ptr += cp_info_size[tag];
			//x_ref_tbl[cls_gnum].ldc_idx_img2cls[ldc_cnt] = idx;
			ldc_idx_img2cls[ldc_cnt] = idx;
			idx ++;
			ldc_cnt++;
			cp_toc[ldc_cnt] = idx;
			ldc_idx_img2cls[ldc_cnt] = idx;
			ldc_cnt++;
			break;
			
		case CP_String:
			ldc_string_flag = 1;
		case CP_Integer:
		case CP_Float:
	
			cp_toc[ldc_cnt] = idx;
			cf_ptr += cp_info_size[tag];
			//x_ref_tbl[cls_gnum].ldc_idx_img2cls[ldc_cnt] = idx;
			ldc_idx_img2cls[ldc_cnt] = idx;
			ldc_cnt++;
			break;

		case CP_Class:
			cf_ptr += cp_info_size[tag];
			cls_idx_img2cls[cls_cnt] = idx;
			cls_cnt++;
			break;

		case CP_Fieldref:
			cf_ptr += cp_info_size[tag];
			fd_idx_img2cls[ref_field_cnt] = idx;
			ref_field_cnt++;
			break;

		case CP_Methodref:
			cf_ptr += cp_info_size[tag];
			mt_idx_img2cls[ref_method_cnt] = idx;
			ref_method_cnt++;
			break;

		case CP_InterfaceMethodref:
			cf_ptr += cp_info_size[tag];
			mt_idx_img2cls[ref_method_cnt] = idx;
			ref_method_cnt++;
			break;

		case CP_NameAndType:
			cf_ptr += cp_info_size[tag];
			break;
		} /* end switch on tag */
	} /* end for-loop on idx */

	store_data = (uint16 *)ref_field_addr;
	for(idx = 0; idx < ldc_cnt ; idx++){
		store_data[idx] = cp_toc[idx];
	}
	for(idx = 0; idx < ref_method_cnt ; idx++){
		store_data[ldc_cnt + idx] = mt_idx_img2cls[idx];
	}
	uint16_temp = ldc_cnt + ref_method_cnt;
	for(idx = 0; idx < ref_field_cnt ; idx++){
		store_data[uint16_temp + idx] = fd_idx_img2cls[idx];
	}

	// decide size of last string - by G
	x_ref_tbl[cls_gnum].string_pool_offset[string_cnt] = sp_ptr;


	// 0xB it means that this class actually is an interface
	if((read_uint16(cf_ptr)&0x0200) != 0) x_ref_tbl[cls_gnum].isIntf = 1;
	else x_ref_tbl[cls_gnum].isIntf = 0;

	//access flag + this class index
	cf_ptr += 4;

	//super class index
	if (x_ref_tbl[cls_gnum].class_namel == 16
		&& !(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Object", 16)))
	{
		x_ref_tbl[cls_gnum].parent_index = 999;
	}
	else{
		// get super_class
		temp = read_uint16(cf_ptr);
		// find super_class in org class CP
		temp = classfile_cp_toc[temp];
		// get Class(07)
		temp = read_uint16(classfile + temp + 1);
		// find name_index
		temp = classfile_cp_toc[temp];
		// get lengh
		cnamel = read_uint16(classfile + temp + 1);
		// get class_name string
		classname = classfile + temp + 3;

		for (idx = 0; idx < global_num; idx++)
		{
			if (x_ref_tbl[idx].class_namel == cnamel
				&& !(strncmp(x_ref_tbl[idx].class_name, classname, cnamel)))
				break;
		}

		if(idx == global_num || x_ref_tbl[idx].IsCache == 0){
			memcpy(parse_classname, classname, cnamel);
			memcpy(parse_classname+cnamel, ".class\0", 7);

			jar_load_class(core_id, sys_jar_image, sys_jar_size, parse_classname,&IsClinit);
			//x_ref_tbl[cls_gnum].base_address = get_starting_address();
		}
		x_ref_tbl[cls_gnum].parent_index = idx;
		*parent_index = idx;
		// [2013.7.12] check whether currently parsing class is Thread class
		// or its parent is Thread class , because we need to modified of start method of
		// any class which inherited Thread class.
		// 2013.9.10 , for multi-core
		if(
			!(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)) ||
			!(strncmp(x_ref_tbl[x_ref_tbl[cls_gnum].parent_index].class_name, "java/lang/Thread", 16))
		){
			//printf("[class_loader, 494] set_thread_class_flag = 1 \n");
			set_thread_class_flag(1);
			//is_thread_class_flag = 1;
		}
	}

	//skip super class index
	cf_ptr += 2;


	/* resolve the Interface of Super Class*/
	temp1 = x_ref_tbl[cls_gnum].parent_index;
	if(temp1 != 999){
		memcpy(x_ref_tbl[cls_gnum].intf,x_ref_tbl[x_ref_tbl[cls_gnum].parent_index].intf
			,x_ref_tbl[x_ref_tbl[cls_gnum].parent_index].intf_cnt<<1);
		x_ref_tbl[cls_gnum].intf_cnt = x_ref_tbl[x_ref_tbl[cls_gnum].parent_index].intf_cnt;
	}
	//interface_count
	intf_cnt = read_uint16(cf_ptr);
	cf_ptr += 2;

	// add interfaces info to this class
	for (idx = 0; idx < intf_cnt; idx++){
		// get interface
		temp = read_uint16(cf_ptr);
		// find interface in org class CP
		temp = classfile_cp_toc[temp];
		// get interface(07)
		temp = read_uint16(classfile + temp + 1);
		// find name_index
		temp = classfile_cp_toc[temp];
		// get lengh
		cnamel = read_uint16(classfile + temp + 1);
		// get class_name string
		classname = classfile + temp + 3;

		// check interface has already been parsed
		for (jdx = 0; jdx < global_num; jdx++)
		{
			if (x_ref_tbl[jdx].class_namel == cnamel
				&& !(strncmp(x_ref_tbl[jdx].class_name, classname, cnamel)))
				break;
		}
		if(jdx == global_num || x_ref_tbl[jdx].IsCache == 0){
			memcpy(parse_classname, classname, cnamel);
			memcpy(parse_classname+cnamel, ".class\0", 7);
			jar_load_class(core_id, sys_jar_image, sys_jar_size, parse_classname,&IsClinit);
			//x_ref_tbl[cls_gnum].base_address = get_starting_address();
		}

		// search interface of this class, make sure no dup interface
		for (zdx = 0 ; zdx < x_ref_tbl[cls_gnum].intf_cnt ; zdx++){
			if(x_ref_tbl[cls_gnum].intf[zdx] == jdx)
				break;
		}
		if(zdx == x_ref_tbl[cls_gnum].intf_cnt){
			x_ref_tbl[cls_gnum].intf[zdx] = jdx;
			x_ref_tbl[cls_gnum].intf_cnt++;
		}

		// search interface of this class's interface, make sure no dup interface
		for (zdx = 0 ; zdx < x_ref_tbl[jdx].intf_cnt ; zdx++){
			for (kdx = 0 ; kdx < x_ref_tbl[cls_gnum].intf_cnt ; kdx++){
				if(x_ref_tbl[cls_gnum].intf[kdx] == x_ref_tbl[jdx].intf[zdx])
					break;
			}
			if(kdx == x_ref_tbl[cls_gnum].intf_cnt){
				x_ref_tbl[cls_gnum].intf[kdx] = x_ref_tbl[jdx].intf[zdx];
				x_ref_tbl[cls_gnum].intf_cnt++;
			}
		}

		cf_ptr += 2;
	}

	store_data = (uint16 *)ref_field_addr;
	for(idx = 0; idx < ldc_cnt ; idx++){
		cp_toc[idx] = store_data[idx];
	}
	for(idx = 0; idx < ref_method_cnt ; idx++){
		mt_idx_img2cls[idx] = store_data[ldc_cnt + idx];
	}
	for(idx = 0; idx < ref_field_cnt ; idx++){
		fd_idx_img2cls[idx] = store_data[uint16_temp + idx];
	}


	x_ref_tbl[cls_gnum].base_address = get_starting_address();
	*cp_nbytes = ((ref_field_cnt + ref_method_cnt + cls_cnt + ldc_cnt)<<2) + (ref_method_cnt<<1);

	// get the number of field which is belong to this class
	fd_cnt = read_uint16(cf_ptr);
	cf_ptr += 2;

	// get the number of field
	// those fields are belong to this class and fields' info has been constructed
	// uint16_temp : nonstatic_field_cnt
	uint16_temp  = 1;

	// uint16_temp2 : now_total_field_cnt
	uint16_temp2 = x_ref_tbl[cls_gnum].field_cnt;

	/* resolve the Field Data of Super Class*/
	temp1 = x_ref_tbl[cls_gnum].parent_index;
	if(temp1 != 999){
		x_ref_tbl[cls_gnum].obj_size = x_ref_tbl[temp1].obj_size;
		for (idx = 0; idx < x_ref_tbl[temp1].field_cnt; idx++)
		{
			fdnamel   = x_ref_tbl[temp1].field[idx].field_namel;
			fieldname = x_ref_tbl[temp1].field[idx].field_name;
			temp = x_ref_tbl[temp1].field[idx].cls_id;
			for (jdx = 0; jdx < uint16_temp2; jdx++){
				if( temp ==  x_ref_tbl[cls_gnum].field[jdx].cls_id &&
					fdnamel == x_ref_tbl[cls_gnum].field[jdx].field_namel &&
					strncmp(fieldname, x_ref_tbl[cls_gnum].field[jdx].field_name, fdnamel)== 0)
					break;
			}


			// if this field's info doesn't exist
			if(jdx == uint16_temp2)
			{
				x_ref_tbl[cls_gnum].field[jdx].field_namel = fdnamel;
				x_ref_tbl[cls_gnum].field[jdx].field_name = fieldname;
				x_ref_tbl[cls_gnum].field[jdx].cls_id = temp;
				address = (0x0000 << 16) | (mt_table_count<<2); // LEVEL1_XRT_BASE_ADDRESS
				//address = mt_table_count;
				mt_table_count ++;
				num_entry_xrt_field_count ++;
				//x_ref_tbl[cls_gnum].field[jdx].field_address = temp1 << 16 | ((unsigned int)address & 0x0000FFFF);
				x_ref_tbl[cls_gnum].field[jdx].field_address = address;
				uint16_temp2++;
			}
			else
				address = x_ref_tbl[cls_gnum].field[jdx].field_address;

			x_ref_tbl[cls_gnum].field[jdx].field_tag = x_ref_tbl[temp1].field[idx].field_tag;
			//*GET_LV1_XRT_ABS_ADDR(address) = *((uint*)x_ref_tbl[temp1].field[idx].field_address);

			for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
				*GET_LV1_XRT_ABS_ADDR(core_idx, address) =
							*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[temp1].field[idx].field_address);
			}

			//if((x_ref_tbl[temp1].field[idx].field_tag & 0x0800) == 0){ //CYC141117
			if((x_ref_tbl[temp1].field[idx].field_tag & 0x10) == 0){
				// non-static field data
				if ((x_ref_tbl[temp1].field[idx].field_tag & 0x1) == 0x1){
					// long
					uint16_temp+=2;
				}
				else uint16_temp++; // other type
			} 
			
			// solve ref field bug 2011/10/20 
			for (jdx = 0; jdx < uint16_temp2; jdx++){
				if( temp !=  x_ref_tbl[cls_gnum].field[jdx].cls_id &&
					fdnamel == x_ref_tbl[cls_gnum].field[jdx].field_namel &&
					strncmp(fieldname, x_ref_tbl[cls_gnum].field[jdx].field_name, fdnamel)== 0)
					break;
			}

			// if this field's info doesn't exist
			if(jdx == uint16_temp2)
			{
				continue;
			}
			else{
				address = x_ref_tbl[cls_gnum].field[jdx].field_address;
				//*GET_LV1_XRT_ABS_ADDR(address) = *((unsigned int*)x_ref_tbl[temp1].field[idx].field_address);
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address) =
							*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[temp1].field[idx].field_address);
				}
			}
		}
	}

	/* resolve the Field Data */
	for (idx = 0; idx < fd_cnt; idx++)
	{
		// get access_flags
		access_flags = read_uint16(cf_ptr);
		cf_ptr += 2;

		// get field name
		temp = read_uint16(cf_ptr);
		temp = classfile_cp_toc[temp];

		fdnamel = read_uint16(classfile+temp+1);
		fieldname = classfile+temp+3;
		// 20110913
		/*
		fdnamel = read_uint16(classfile+temp+1);
		memcpy(fieldname, (uint8 *) (classfile + temp + 3), fdnamel);
		*/
		cf_ptr += 2;

		// get descriptor
		temp = read_uint16(cf_ptr);
		temp = classfile_cp_toc[temp];
		descriptor_flag = field_descriptor_analyzer((uint8 *) (classfile + temp + 3));
		cf_ptr += 2;
		

		//attribute count
		attr_count = read_uint16(cf_ptr);
		cf_ptr += 2;
		for (zdx = 0; zdx < attr_count ; zdx++){
			//skip attributes name
			cf_ptr += 2;
			attribute_size = read_uint32(cf_ptr);
			cf_ptr += 4;
			//skip attributes info
			cf_ptr += attribute_size;
		}


		// find out this field's info has been construct or not
		// jdx : target_field_num
		if ((access_flags & 0x8) != 0){
			//static field
			for (jdx = 0; jdx < uint16_temp2; jdx++){
				if( fdnamel == x_ref_tbl[cls_gnum].field[jdx].field_namel &&
					strncmp(fieldname, x_ref_tbl[cls_gnum].field[jdx].field_name,fdnamel) == 0)
					break;
			}
		}
		else{
			//non-static field
			for (jdx = 0; jdx < uint16_temp2; jdx++){
				if( cls_gnum == x_ref_tbl[cls_gnum].field[jdx].cls_id &&
					fdnamel == x_ref_tbl[cls_gnum].field[jdx].field_namel &&
					strncmp(fieldname, x_ref_tbl[cls_gnum].field[jdx].field_name,fdnamel) == 0)
					break;
			}
		}

		// if this field's info doesn't exist
		if(jdx == uint16_temp2)
		{
			//x_ref_tbl[cls_gnum].field[jdx].cls_id = cls_gnum;
			x_ref_tbl[cls_gnum].field[jdx].field_namel = fdnamel;
			x_ref_tbl[cls_gnum].field[jdx].field_name = fieldname;
			address = (0x0000 << 16) | (mt_table_count<<2); // LEVEL1_XRT_BASE_ADDRESS
			mt_table_count ++;
			num_entry_xrt_field_count ++;
			//x_ref_tbl[cls_gnum].field[jdx].field_address = cls_gnum << 16 | ((unsigned int)address & 0x0000FFFF);
			x_ref_tbl[cls_gnum].field[jdx].field_address = address;
			uint16_temp2++;
		}
		else{
			address = x_ref_tbl[cls_gnum].field[jdx].field_address;
			//xil_printf("address  %X\r\n", address);
			//xil_printf("x_ref_tbl[cls_gnum].parent_index %X\r\n", x_ref_tbl[cls_gnum].parent_index);
			//if(x_ref_tbl[cls_gnum].field[jdx].cls_id == x_ref_tbl[cls_gnum].parent_index){ // field override
			//	x_ref_tbl[cls_gnum].field[jdx].cls_id = cls_gnum;
			//}
		}

		x_ref_tbl[cls_gnum].field[jdx].cls_id = cls_gnum;
		
		//x_ref_tbl[cls_gnum].field[jdx].field_tag = (access_flags<<8) | descriptor_flag; //CYC141117
		if (descriptor_flag == 0x6)
			x_ref_tbl[cls_gnum].field[jdx].field_tag = (access_flags<<1) | 0x1;
		else
			x_ref_tbl[cls_gnum].field[jdx].field_tag = (access_flags<<1);

		if ((access_flags & 0x8) != 0){
			// static field
			// we can't allocate address that most right 16 bit are all zero
			heap_align32();
			if((CURRENT_HEAP_PTR & 0x0000FFFF) == 0) CURRENT_HEAP_PTR +=4;
			for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
				*GET_LV1_XRT_ABS_ADDR(core_idx, address) = CURRENT_HEAP_PTR;
			}

			if(descriptor_flag == 0x6) CURRENT_HEAP_PTR+=8;
			else CURRENT_HEAP_PTR+=4;
			heap_align32();
		}
		else{
			// non-static field
			//if(((*address) & 0x0000FFFF) == 0){
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx,address) = (cls_gnum<<16) | uint16_temp;
				}
				if(descriptor_flag == 0x6){
					// long
					x_ref_tbl[cls_gnum].obj_size = x_ref_tbl[cls_gnum].obj_size + 2;
					uint16_temp+=2;
				}
				else{
					// int or short or char or boolean or array or obj
					x_ref_tbl[cls_gnum].obj_size = x_ref_tbl[cls_gnum].obj_size + 1;
					uint16_temp++;
				}
			//}
		}
	}
	x_ref_tbl[cls_gnum].field_cnt = uint16_temp2;

	mt_cnt = read_uint16(cf_ptr);
	cf_ptr += 2;

	/* Method code segement count */
	/* Copy method code to method data */
	mt_offset = 0;
	// uint16_temp : now_total_method_cnt
	uint16_temp = x_ref_tbl[cls_gnum].method_cnt;

	/* resolve the Method of Super Class*/
	if(x_ref_tbl[cls_gnum].isIntf != 1){
		if(temp1 != 999){
			for (idx = 0; idx < x_ref_tbl[temp1].method_cnt; idx++)
			{
				mtnamel = x_ref_tbl[temp1].method[idx].method_namel;
				methodname = x_ref_tbl[temp1].method[idx].method_name;
				desnamel = x_ref_tbl[temp1].method[idx].descript_namel;
				desname = x_ref_tbl[temp1].method[idx].descript_name;
				for (jdx = 0; jdx < uint16_temp; jdx++){
					if (x_ref_tbl[cls_gnum].method[jdx].method_namel == mtnamel
						&& x_ref_tbl[cls_gnum].method[jdx].descript_namel == desnamel
						&& !(strncmp(x_ref_tbl[cls_gnum].method[jdx].method_name,
								methodname, mtnamel))
						&& !(strncmp(x_ref_tbl[cls_gnum].method[jdx].descript_name,
								desname, desnamel))
						)
						break;
				}
				// if this method's info doesn't exist
				if(jdx == uint16_temp)
				{
					x_ref_tbl[cls_gnum].method[jdx].method_name = methodname;
					x_ref_tbl[cls_gnum].method[jdx].descript_name = desname;
					x_ref_tbl[cls_gnum].method[jdx].method_namel = mtnamel;
					x_ref_tbl[cls_gnum].method[jdx].descript_namel = desnamel;
					x_ref_tbl[cls_gnum].method[jdx].arg_size = x_ref_tbl[temp1].method[idx].arg_size;

					address = (x_ref_tbl[cls_gnum].method[jdx].arg_size<<16) | (mt_table_count<<2); // LEVEL1_XRT_BASE_ADDRESS
					mt_table_count +=2;
					num_entry_xrt_method_count += 2;
					x_ref_tbl[cls_gnum].method[jdx].method_offset = address;
					uint16_temp++;
					//if ( !(strncmp(x_ref_tbl[cls_gnum].method[jdx].method_name,"execute", 7)) ){
					//	xil_printf("[class_loader.c] debug 1 \r\n");
					//	xil_printf("[class_loader.c] execute is found, its arg:%x \r\n", x_ref_tbl[temp1].method[idx].arg_size );
					//}
				}
				else{
					address = x_ref_tbl[cls_gnum].method[jdx].method_offset;
					//if ( !(strncmp(x_ref_tbl[cls_gnum].method[jdx].method_name,"execute", 7)) ){
				// 	xil_printf("[class_loader.c] debug 2 \r\n");
				// }
				}



				x_ref_tbl[cls_gnum].method[jdx].access_flag =  x_ref_tbl[temp1].method[idx].access_flag;


				if((x_ref_tbl[temp1].method[idx].access_flag & 0x0400 )!=0){
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						// abstract
						// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0xFFFFFFFF;
						*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0x8000FFFF;
					}
				}
				else if((x_ref_tbl[temp1].method[idx].access_flag & 0x0100)!=0){
					// note by T.H.Wu , 2014.1.7, synchronized bit should be erased for new overriden  sync method
					// native // ... modified by T.H.Wu , 2013.7.10
					//*GET_LV1_XRT_ABS_ADDR(address) 	= *((uint *)x_ref_tbl[temp1].method[idx].method_offset + 0);
					//*GET_LV1_XRT_ABS_ADDR(address+1) = *((uint *)x_ref_tbl[temp1].method[idx].method_offset + 1);
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
						*GET_LV1_XRT_ABS_ADDR(core_idx,address) 	=
							(0x7FFF0000) | (0x8000FFFF & *GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[temp1].method[idx].method_offset + 0));
						*GET_LV1_XRT_ABS_ADDR(core_idx,address+(1<<2)) =
							*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[temp1].method[idx].method_offset + (1<<2));
						//*GET_LV1_XRT_ABS_ADDR(core_idx,address+(2<<2)) = 0xFFFFFFFF;
					}
				}
				else if((x_ref_tbl[temp1].method[idx].access_flag & 0x0008)!=0){
					// note by T.H.Wu , 2014.1.7, synchronized bit should be erased for new overriden  sync method
					// static
					//*GET_LV1_XRT_ABS_ADDR(address) = (*((uint *)x_ref_tbl[temp1].method[idx].method_offset) & 0xFFFF0000) | cls_gnum;
					//*GET_LV1_XRT_ABS_ADDR(address+1) = *((uint *)x_ref_tbl[temp1].method[idx].method_offset + 1);
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
						*GET_LV1_XRT_ABS_ADDR(core_idx, address) =
							//(*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[temp1].method[idx].method_offset) & 0xFFFF0000) | cls_gnum;
							0x7FFF0000 | cls_gnum;
						*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[temp1].method[idx].method_offset + (1<<2));
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) = 0xFFFFFFFF;
					}
				}
				else{
					// note by T.H.Wu , 2014.1.7, synchronized bit should be erased for new overriden  sync method
					// non-static and non-native
					//*GET_LV1_XRT_ABS_ADDR(address) = (*((uint *)x_ref_tbl[temp1].method[idx].method_offset) & 0xFFFF0000) | cls_gnum;
					//*GET_LV1_XRT_ABS_ADDR(address+1) = *((uint *)x_ref_tbl[temp1].method[idx].method_offset + 1);
					//*GET_LV1_XRT_ABS_ADDR(address+2) = LEVEL1_XRT_PTR + mt_table_count;

					// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						*GET_LV1_XRT_ABS_ADDR(core_idx, address) =
							//(*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[temp1].method[idx].method_offset) & 0xFFFF0000) | cls_gnum;
							((0x7FFF & mt_table_count)<<(16+2)) | cls_gnum;
						*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[temp1].method[idx].method_offset + (1<<2));
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) = LEVEL1_XRT_PTR + mt_table_count;
					}
					mt_table_count +=2;
					num_entry_xrt_method_count += 2;
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						//*((uint*)*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2))) = 0xFFFFFFFF;
						*GET_LV1_XRT_ABS_ADDR(core_idx,
								*GET_LV1_XRT_ABS_ADDR(core_idx, address)>>16
						) = 0x8000FFFF;
					}
				}
			}
		}
	}

	// resolve the Method of interface
	// resolve interface extend multi-interface
	if(x_ref_tbl[cls_gnum].isIntf == 1){

		for (idx = 0; idx < x_ref_tbl[cls_gnum].intf_cnt; idx++)
		{
			uint16_temp2 = x_ref_tbl[cls_gnum].intf[idx];
			for (jdx = 0; jdx < x_ref_tbl[uint16_temp2].method_cnt; jdx++)
			{
				mtnamel	= x_ref_tbl[uint16_temp2].method[jdx].method_namel;
				methodname = x_ref_tbl[uint16_temp2].method[jdx].method_name;
				desnamel   = x_ref_tbl[uint16_temp2].method[jdx].descript_namel;
				desname	= x_ref_tbl[uint16_temp2].method[jdx].descript_name;

				//serach method in class
				for (zdx = 0; zdx < uint16_temp; zdx++)
				{
					if (x_ref_tbl[cls_gnum].method[zdx].method_namel == mtnamel
						&& x_ref_tbl[cls_gnum].method[zdx].descript_namel == desnamel
						&& !(strncmp(x_ref_tbl[cls_gnum].method[zdx].method_name,methodname,mtnamel))
						&& !(strncmp(x_ref_tbl[cls_gnum].method[zdx].descript_name,desname,desnamel))
					)break;
				}

				// if this method's info doesn't exist
				if(zdx == uint16_temp)
				{
					x_ref_tbl[cls_gnum].method[uint16_temp].method_name = methodname;
					x_ref_tbl[cls_gnum].method[uint16_temp].descript_name = desname;
					x_ref_tbl[cls_gnum].method[uint16_temp].method_namel = mtnamel;
					x_ref_tbl[cls_gnum].method[uint16_temp].descript_namel = desnamel;
					x_ref_tbl[cls_gnum].method[uint16_temp].arg_size = x_ref_tbl[uint16_temp2].method[jdx].arg_size;
					// modified by T.H.Wu , 2013.8.23 ,
					address = (x_ref_tbl[cls_gnum].method[uint16_temp].arg_size<<16) | (mt_table_count<<2); //LEVEL1_XRT_BASE_ADDRESS

					// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0xFFFFFFFF;
						*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0x8000FFFF;
					}
					mt_table_count +=2;
					num_entry_xrt_method_count += 2;
					x_ref_tbl[cls_gnum].method[uint16_temp].method_offset = address;
					uint16_temp++;
				}
			}
		}
	}
	
	//cls_size = cls_image.CPcount+ cls_image.cp_nbytes>>1 ;;	//added by zi-jing
	//mt_offset = (nitems<<1) + (*cp_nbytes) + 4 + (x_ref_tbl[cls_gnum].base_address<<1);
   //aligment_shift_first_mthd = mt_offset % 4 ;
	//mt_offset = 4 - aligment_shift_first_mthd;
	mt_offset = (nitems<<1) + (*cp_nbytes) + 4 + (x_ref_tbl[cls_gnum].base_address<<1);
	aligment_shift_first_mthd = aligment_shift = mt_offset % 4 ;
	mt_offset = 4 - aligment_shift;


	//aligment_shift_first_mthd = 4-(mt_offset % 4 );
	//mt_offset = 4 - aligment_shift_first_mthd;
	
	for (idx = 0; idx < mt_cnt; idx++)
	{
		// Parse the method code data
		
		//added by zi-jing
		mt_offset_pre = mt_offset ;

		aligment_shift = (mt_offset+aligment_shift_first_mthd) % 4 ;
		if(aligment_shift!=0){
			mt_offset += 4 - aligment_shift;
		}
		
		//aligment_shift=4- ((mt_offset + aligment_shift_first_mthd)%4);
		//mt_offset += aligment_shift;

		access_flags = read_uint16(cf_ptr);
		
		// access flag : static flag
		if ((access_flags & 0x0008) != 0)
			nonstatic = 0;
		else
			nonstatic = 1;
	
		memcpy(mt_code + mt_offset, cf_ptr, 2);
		cf_ptr += 2;
		// get method name index;
		mtnameid = read_uint16(cf_ptr);
		cf_ptr += 2 ;
		// find Utf8(01)
		temp = classfile_cp_toc[mtnameid];
		// get length
		mtnamel = read_uint16(classfile + temp + 1);
		// get name string
		methodname = classfile + temp + 3;

		// get descripter name index;
		desid = read_uint16(cf_ptr);
		cf_ptr += 2;
		// find Utf8(01)
		temp = classfile_cp_toc[desid];
		// get length
		desnamel = read_uint16(classfile + temp + 1);
		// get name string
		desname = classfile + temp + 3;

		// find out this method's info has been construct or not
		// jdx : target_method_num
		for (jdx = 0; jdx < uint16_temp; jdx++){
			if (x_ref_tbl[cls_gnum].method[jdx].method_namel == mtnamel
				&& x_ref_tbl[cls_gnum].method[jdx].descript_namel == desnamel
				&& !(strncmp(x_ref_tbl[cls_gnum].method[jdx].method_name,methodname, mtnamel))
				&& !(strncmp(x_ref_tbl[cls_gnum].method[jdx].descript_name,desname, desnamel))
				)
				break;
		}

		/*xil_printf("mtnamel: %d\r\n", mtnamel);
		xil_printf("desnamel: %d\r\n", desnamel);
		xil_printf("methodname: %s\r\n", methodname);
		xil_printf("desname: %s\r\n", desname);
		xil_printf("x_ref_tbl[cls_gnum].class_name: %s\r\n", x_ref_tbl[cls_gnum].class_name);*/
		
		// if this method's info doesn't exist
		if(jdx == uint16_temp)
		{
			x_ref_tbl[cls_gnum].method[jdx].method_name = methodname;
			x_ref_tbl[cls_gnum].method[jdx].method_namel = mtnamel;
			x_ref_tbl[cls_gnum].method[jdx].descript_name = desname;
			x_ref_tbl[cls_gnum].method[jdx].descript_namel = desnamel;
			x_ref_tbl[cls_gnum].method[jdx].arg_size = method_descriptor_analyzer(desname) + nonstatic;
			// modified by T.H.Wu , 2013.8.15, modified for the structure of a method info in CST entry
			//2013.9.23 ,
			address = (x_ref_tbl[cls_gnum].method[jdx].arg_size<<16) | (mt_table_count<<2); // LEVEL1_XRT_BASE_ADDRESS
			x_ref_tbl[cls_gnum].method[jdx].method_offset = address;
			uint16_temp ++;
			mt_table_count +=2;
			num_entry_xrt_method_count += 2;
		}
		else{
			// test by T.H.Wu , 2013.8.28
			x_ref_tbl[cls_gnum].method[jdx].arg_size = method_descriptor_analyzer(desname) + nonstatic;
			// this method's info exist, write down the addr
			//address = x_ref_tbl[cls_gnum].method[jdx].method_offset;
			//2013.9.23 ,
			address =	(x_ref_tbl[cls_gnum].method[jdx].arg_size<<16) |
						(x_ref_tbl[cls_gnum].method[jdx].method_offset & 0xFF00FFFF);
		}

	// if ( !(strncmp(x_ref_tbl[cls_gnum].method[jdx].method_name,"checkSystemState", 16)) ){
	////	xil_printf("[class_loader.c] debug 4 \r\n");
		//	xil_printf("[class_loader.c] checkSystemState is found, its arg:%x \r\n", x_ref_tbl[cls_gnum].method[jdx].arg_size );
		//}
		//address = (0x01<<16) | (address & 0xFF00FFFF);
		x_ref_tbl[cls_gnum].method[jdx].access_flag = access_flags;

		// class's method
		if((access_flags & 0x0400) != 0){
			// abstract method
			// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
			for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
				//*GET_LV1_XRT_ABS_ADDR(core_idx, address)   = 0xFFFFFFFF;
				*GET_LV1_XRT_ABS_ADDR(core_idx, address)   = 0x8000FFFF;
			}
		}
		else if((access_flags & 0x0100) != 0){
			// native
			// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
			for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
				//*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0x80000000 | (x_ref_tbl[cls_gnum].method[jdx].arg_size<<16);
				*GET_LV1_XRT_ABS_ADDR(core_idx, address) = (0xFFFF<<16) | cls_gnum;
			}
			// The Appending of method id is for profiler
			// is bit [23:16] for native method argument ?? how about profiler ?? , 2013.6.27
			if(mtnamel == 7 && desnamel == 37
					&& !strncmp(methodname, "forName", mtnamel)
					&& !strncmp(desname, "(Ljava/lang/String;)Ljava/lang/Class;", desnamel)
					){
				//*(address+1) = 0xFF010108; // modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17)   | (0<<12) | (0x008);
				}
			}
			else if(mtnamel == 11 && desnamel == 20
					&& !strncmp(methodname, "newInstance", mtnamel)
					&& !strncmp(desname, "()Ljava/lang/Object;", desnamel)
					){
				//*(address+1) = 0xFF010109;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17)  | (0<<12) | (0x009);
				}
			}
			else if(mtnamel == 6 && desnamel == 4
					&& !strncmp(methodname, "write0", mtnamel)
					&& !strncmp(desname, "(I)V", desnamel)
					&& !strncmp(x_ref_tbl[cls_gnum].class_name, "com/sun/cldc/io/ConsoleOutputStream", 35)
					){
				//*(address+1) = 0xFF020032;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17) | (0<<12) | (0x032);
				}
			}
			else if(mtnamel == 5 && desnamel == 3
					&& !strncmp(methodname, "yield", mtnamel)
					&& !strncmp(desname, "()V", desnamel)
					){
				//*(address+1) = 0xFF000013;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17)  |(0<<12) | (0x013);
				}
			}
			else if(mtnamel == 9 && desnamel == 42
					&& !strncmp(methodname, "arraycopy", mtnamel)
					&& !strncmp(desname, "(Ljava/lang/Object;ILjava/lang/Object;II)V", desnamel)
					){
				//*(address+1) = 0x80050080 | (global_mthd_id << 24);//HW native, added by C.C.H.
				// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
				// new format :
				// 		native_flag [31]
				//		native_HW_flag [30]
				//		return number of native method [29:28]
				//		class ID of the native method [27:21]
				//		argument size of the native method [20:16]
				//		native HW sequence number (when native_HW_flag is active) [15:12]
				//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (1<<30)  | (cls_gnum<<17)  | (0<<12) | (global_mthd_id);
				}
				//*(address+1) = 0xFF050021 ;		//software native
			}
			else if(mtnamel == 7 && desnamel == 22
					&& !strncmp(methodname, "indexOf", mtnamel)
					&& !strncmp(desname, "(Ljava/lang/String;I)I", desnamel)
					){
					//*(address+1) = 0x80030181 | (global_mthd_id << 24);		//HW native, added by C.C.H.
					// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
					// new format :
					// 		native_flag [31]
					//		native_HW_flag [30]
					//		return number of native method [29:28]
					//		class ID of the native method [27:21]
					//		argument size of the native method [20:16]
					//		native HW sequence number (when native_HW_flag is active) [15:12]
					//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (1<<30)  | (cls_gnum<<17) |(1<<12) | (global_mthd_id);
				}
				//xil_printf("address+1: %X\r\n", address+1);
			}
			else if(mtnamel == 7 && desnamel == 5
					&& !strncmp(methodname, "indexOf", mtnamel)
					&& !strncmp(desname, "(II)I", desnamel)
					){
				//*(address+1) = 0x80030185 | (global_mthd_id << 24);		//HW native, added by C.C.H.
				// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
				// new format :
				// 		native_flag [31]
				//		native_HW_flag [30]
				//		return number of native method [29:28]
				//		class ID of the native method [27:21]
				//		argument size of the native method [20:16]
				//		native HW sequence number (when native_HW_flag is active) [15:12]
				//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (1<<30) | (cls_gnum<<17) | (5<<12) | (global_mthd_id);
				}
				//xil_printf("address+1: %X\r\n", address+1);
			}
			else if(mtnamel == 7 && desnamel == 22
				&& !strncmp(methodname, "indexOf", mtnamel)
				&& !strncmp(desname, "(Ljava/lang/Object;I)I", desnamel)
				){
				//*(address+1) = 0x80030187 | (global_mthd_id << 24);		//HW native, added by C.C.H.
				// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
				// new format :
				// 		native_flag [31]
				//		native_HW_flag [30]
				//		return number of native method [29:28]
				//		class ID of the native method [27:21]
				//		argument size of the native method [20:16]
				//		native HW sequence number (when native_HW_flag is active) [15:12]
				//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (1<<30) | (cls_gnum<<17) | (7<<12) | (global_mthd_id);
				}
			}
			else if(mtnamel == 11 && desnamel == 5
					&& !strncmp(methodname, "lastIndexOf", mtnamel)
					&& !strncmp(desname, "(II)I", desnamel)
					){
				//*(address+1) = 0x80030186 | (global_mthd_id << 24);		//HW native, added by C.C.H.
				// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
				// new format :
				// 		native_flag [31]
				//		native_HW_flag [30]
				//		return number of native method [29:28]
				//		class ID of the native method [27:21]
				//		argument size of the native method [20:16]
				//		native HW sequence number (when native_HW_flag is active) [15:12]
				//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (1<<30) | (cls_gnum<<17)  | (6<<12) | (global_mthd_id);
				}
				//xil_printf("address+1: %X\r\n", address+1);
			}
			else if(mtnamel == 17 && desnamel == 3
					&& !strncmp(methodname, "currentTimeMillis", mtnamel)
					&& !strncmp(desname, "()J", desnamel)
					){
				// *(address+1) = 0xFF000222;
				// *(address+1) = 0x80000282 | (global_mthd_id << 24);		//HW native, added by C.C.H.
				// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
				// new format :
				// 		native_flag [31]
				//		native_HW_flag [30]
				//		return number of native method [29:28]
				//		class ID of the native method [27:21]
				//		argument size of the native method [20:16]
				//		native HW sequence number (when native_HW_flag is active) [15:12]
				//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							// hidden by T.H.Wu , 2013.1.7, for executing Jembench correctly.
							//(1<<31) | (1<<30)  | (cls_gnum<<17) |  (2<<12) | (global_mthd_id);
							(1<<31) | (0<<30)  | (cls_gnum<<17) |  (2<<12) | (0x022);
				}
			}
			else if(mtnamel == 12 && desnamel == 38
					&& !strncmp(methodname, "getProperty0", mtnamel)
					&& !strncmp(desname, "(Ljava/lang/String;)Ljava/lang/String;", desnamel)
					){
				//*(address+1) = 0xFF010123;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17)  | (0<<12) | (0x023);
				}
			}
			else if(mtnamel == 6 && desnamel == 21
					&& !strncmp(methodname, "equals", mtnamel)
					&& !strncmp(desname, "(Ljava/lang/Object;)Z", desnamel)
					){
				//*(address+1) = 0xFF020126;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17)  | (0<<12) | (0x026);
				}
			}
			else if(mtnamel == 6 && desnamel == 27
					&& !strncmp(methodname, "append", mtnamel)
					&& !strncmp(desname, "(I)Ljava/lang/StringBuffer;", desnamel)
					){
				//*(address+1) = 0xFF02012A;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17)  | (0<<12) | (0x02A);
				}
			}
			else if(mtnamel == 6 && desnamel == 44
					&& !strncmp(methodname, "append", mtnamel)
					&& !strncmp(desname, "(Ljava/lang/String;)Ljava/lang/StringBuffer;", desnamel)
					){
				//*(address+1) = 0xFF02012B;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17) | (0<<12) | (0x02B);
				}
			}
			else if(mtnamel == 8 && desnamel == 20
					&& !strncmp(methodname, "toString", mtnamel)
					&& !strncmp(desname, "()Ljava/lang/String;", desnamel)
					&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/String", 16)
					){
				//*(address+1) = 0xFF01012C;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17) | (0<<12) | (0x02C);
				}
			}
			else if(mtnamel == 16 && desnamel == 4
					&& !strncmp(methodname, "checkSystemState", mtnamel)
					&& !strncmp(desname, "(I)V", desnamel)
					){
				//*(address+1) = 0xFF010033;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17)  | (0<<12) | (0x033);
				}
			}
			else if(mtnamel == 6 && desnamel == 4
					&& !strncmp(methodname, "charAt", mtnamel)
					&& !strncmp(desname, "(I)C", desnamel)){
				//*(address+1) = 0xFF020125;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17) | (0<<12) | (0x025);
				}
			}
			else if(mtnamel == 7 && desnamel == 4
					&& !strncmp(methodname, "indexOf", mtnamel)
					&& !strncmp(desname, "(I)I", desnamel)){
				//*(address+1) = 0xFF020127;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17) | (0<<12) | (0x027);
				}
			}
			else if(mtnamel == 7 && desnamel == 5
					&& !strncmp(methodname, "indexOf", mtnamel)
					&& !strncmp(desname, "(II)I", desnamel)){
				//*(address+1) = 0xFF030128;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17) | (0<<12) | (0x028);
				}
			}
			else if(mtnamel == 8 && desnamel == 20
					&& !strncmp(methodname, "toString", mtnamel)
					&& !strncmp(desname, "()Ljava/lang/String;", desnamel)
					&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/StringBuffer", 22)){
				//*(address+1) = 0xFF01012C;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17)  | (0<<12) | (0x02C);
				}
			}
			else if(mtnamel == 7 && desnamel == 20
					&& !strncmp(methodname, "getName", mtnamel)
					&& !strncmp(desname, "()Ljava/lang/String;", desnamel)){
				//*(address+1) = 0xFF01010A;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17)  | (0<<12) | (0x00A);
				}
			}
			else if(mtnamel == 8 && desnamel == 19
					&& !strncmp(methodname, "getClass", mtnamel)
					&& !strncmp(desname, "()Ljava/lang/Class;", desnamel)){
				//*(address+1) = 0xFF010100;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17)  | (0<<12) | (0x000);
				}
			}
			else if(mtnamel == 19 && desnamel == 3
					&& !strncmp(methodname, "currentTimeMillisHW", mtnamel)
					&& !strncmp(desname, "()J", desnamel)
					){
				//*(address+1) = 0xFF000234;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17)  | (0<<12) | (0x034);
				}
			}
			else if(mtnamel == 23 && desnamel == 3
					&& !strncmp(methodname, "currentTimeMillisINTRPT", mtnamel)
					&& !strncmp(desname, "()J", desnamel)
					){
				//*(address+1) = 0xFF000235;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17) | (0<<12) | (0x035);
				}
			}
			// modified by T.H.Wu , 2013.8.13 , because JAIP has not support native method info list in
			// cross reference table, so we can not let child class override the native method of parent class
			/*
			else if(mtnamel == 8 && desnamel == 3
					&& !strncmp(methodname, "hashCode", mtnamel)
					&& !strncmp(desname, "()I", desnamel)
					&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Object", 16)
					){
				//*(address+1) = 0xFF010101;// modified by T.H.Wu, 2013.7.11
				*(address+1) = (1<<31) | (0<<30) | (1<<28) | (cls_gnum<<21) | (1<<16) |
								(0<<12) | (0x001);
			}
			*/
			else if(mtnamel == 9 && desnamel == 3
					&& !strncmp(methodname, "hashCode0", mtnamel)
					&& !strncmp(desname, "()I", desnamel)
					&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Object", 16)
					){
				//*(address+1) = 0xFF010101;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30)  | (cls_gnum<<17) | (0<<12) | (0x001);
				}
			}

			else if(mtnamel == 9 && desnamel == 3
					&& !strncmp(methodname, "profileOn", mtnamel)
					&& !strncmp(desname, "()V", desnamel)
					&& !strncmp(x_ref_tbl[cls_gnum].class_name, "MMESProfiler", 12)
					){
				//*(address+1) = 0x80000083 | (global_mthd_id << 24); // added by C.C.H.
				// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
				// new format :
				// 		native_flag [31]
				//		native_HW_flag [30]
				//		return number of native method [29:28]
				//		class ID of the native method [27:21]
				//		argument size of the native method [20:16]
				//		native HW sequence number (when native_HW_flag is active) [15:12]
				//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (1<<30)  | (cls_gnum<<17) | (3<<12) | (global_mthd_id);
				}
			}
			else if(mtnamel == 10 && desnamel == 3
								&& !strncmp(methodname, "profileOff", mtnamel)
								&& !strncmp(desname, "()V", desnamel)
								&& !strncmp(x_ref_tbl[cls_gnum].class_name, "MMESProfiler", 12)
								){
				//*(address+1) = 0x80000084 | (global_mthd_id << 24);
				// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
				// new format :
				// 		native_flag [31]
				//		native_HW_flag [30]
				//		return number of native method [29:28]
				//		class ID of the native method [27:21]
				//		argument size of the native method [20:16]
				//		native HW sequence number (when native_HW_flag is active) [15:12]
				//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (1<<30)  | (cls_gnum<<17)  | (4<<12) | (global_mthd_id);
				}
			}
			// add by T.H.Wu , 2013.7.8 , for Thread.start()
			//  Thread.start() non-static native method. so
			//
			else if(mtnamel == 5 && desnamel == 3
					&& !strncmp(methodname, "start", mtnamel)
					&& !strncmp(desname, "()V", desnamel)
					&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)
					){
				//*(address+1) = 0x80010088 | (global_mthd_id << 24);
				// HW native , modified by T.H.Wu , 2013.7.11 , for executing Thread.start
				// new format :
				// 		native_flag [31]
				//		native_HW_flag [30]
				//		return number of native method [29:28]
				//		class ID of the native method [27:21]
				//		argument size of the native method [20:16]
				//		native HW sequence number (when native_HW_flag is active) [15:12]
				//		global method ID [11:0]
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (1<<30) | (cls_gnum<<17)  | (8<<12) | (global_mthd_id);
				}
				//xil_printf("[class_parser.c] find Thread.start() \r\n");
			}
			else{
				//*(address+1) = 0xFF000000;// modified by T.H.Wu, 2013.7.11
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							(1<<31) | (0<<30) | (cls_gnum<<17) | (0<<12) | (0x02B);
				}/*
				printf("This native method not support!! \n");
				printf("method name: %s\n", methodname);
				printf("descriptor name: %s\n", desname);*/
			}
			// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
			//for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
			//	*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) = 0xFFFFFFFF;
			//}
		}
		else if(nonstatic == 0){
			// static
			// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
			for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
				//*GET_LV1_XRT_ABS_ADDR(core_idx, address)   = ((method_descriptor_analyzer(desname) + nonstatic)<<16) | cls_gnum;
				*GET_LV1_XRT_ABS_ADDR(core_idx, address)   = (0x7FFF<<16) | cls_gnum;
				*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) = (cls_gnum << 16) | global_mthd_id;
				//*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) = 0xFFFFFFFF;
			}
			//added by ji-jing
			mthd_offset = (nitems<<1) + (*cp_nbytes) + 4 + mt_offset + (x_ref_tbl[cls_gnum].base_address<<1);
			
		}
		else{
			// non-static and non-native
			// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
			for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
				//*GET_LV1_XRT_ABS_ADDR(core_idx, address)   =
				//		((method_descriptor_analyzer(desname) + nonstatic)<<16) | cls_gnum;
				*GET_LV1_XRT_ABS_ADDR(core_idx, address) = ((0x7FFF & mt_table_count)<<(16+2)) | cls_gnum;
				*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) = (cls_gnum << 16) | global_mthd_id;
				//*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) = LEVEL1_XRT_PTR + mt_table_count;
				//*((uint*)*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2))) = 0xFFFFFFFF;
				*GET_LV1_XRT_ABS_ADDR(core_idx,
						*GET_LV1_XRT_ABS_ADDR(core_idx, address)>>16
					) = 0x8000FFFF;
			}
			mt_table_count +=2;
			num_entry_xrt_method_count += 2;
			//added by ji-jing
			mthd_offset = (nitems<<1) + (*cp_nbytes) + 4 + mt_offset + (x_ref_tbl[cls_gnum].base_address<<1);
		}

		// modified by T.H.Wu , 2014.1.16, for invoking syn method
		//printf("mthd name:%s, global mthd id:%x, access_flags: %x \r\n",
		//	x_ref_tbl[cls_gnum].method[jdx].method_name,
		//	(global_mthd_id + 1),
		//	access_flags
		//);
		// if any synchronized flag is detected
		// note that if synchronized method is overwritten, the override method is no longer synchronized.

		if((access_flags & 0x0020)!= 0x0){
			uint tmp_mthd_entry = 0;
			for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
				tmp_mthd_entry = *GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2));
				*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) = (tmp_mthd_entry | 0x20000000);
			}
			/*
			printf("mthd name:%s, address:%x %x , new mthd entry: %x  %x \r\n",
					x_ref_tbl[cls_gnum].method[jdx].method_name,
					GET_LV1_XRT_ABS_ADDR(0, address+(1<<2)),
						address,
					tmp_mthd_entry,
						(tmp_mthd_entry | 0x20000000)
			);
		*/
		}

		
		if (mtnamel == 8
			&& desnamel == 3
			&& !(strncmp(methodname,(char*)"<clinit>",8))
			&& !(strncmp(desname,(char*)"()V",3))){
				x_ref_tbl[cls_gnum].clinit_ID = global_mthd_id;
		}
		
		// access flag
		mt_offset += 2;

		// resolute the parameters number by descriptor
		// tmp here is used to be store parameters
		*tmp = 0;
		*(tmp + 1) = method_descriptor_analyzer(desname) + nonstatic;
		//xil_printf("%x %s %s %x %x\r\n",*(tmp + 1),methodname,desname,access_flags,mthd_offset);
		memcpy(mt_code + mt_offset, tmp, 2);

		attr_count = read_uint16(cf_ptr);
		// skip attribute count
		cf_ptr += 2;

		for(zdx = 0 ; zdx < attr_count ; zdx ++){
			attrid = read_uint16(cf_ptr);
			cf_ptr += 2;
			temp = classfile_cp_toc[attrid];
			attrnamel = read_uint16(classfile + temp + 1);
			attrname = classfile + temp + 3;
			// test for inner class parser, 2013.7.10
  			//xil_printf("[class_loader.c] method attribute name : %s  \r\n", attrname);

			if (attrnamel == 4 && strncmp(attrname, "Code", 4) == 0){

				attribute_size = read_uint32(cf_ptr);
				cf_ptr += 4;
				max_stacks = read_uint16(cf_ptr);
				max_locals = read_uint16(cf_ptr + 2);
				
				// modify - by G
				// modified by T.H.Wu , 2013.7.16 , for fixing the bug about multiple main methods
				if (	!strncmp(x_ref_tbl[cls_gnum].class_name ,
										main_class_fully_qualified_name ,
									x_ref_tbl[cls_gnum].class_namel) &&
						!strncmp(methodname, "main", 4) &&
						// !strncmp(desname, "()", 4)  &&
						is_main_method_found == 0)
				{
					*main_pc = 4 + (nitems<<1) + (*cp_nbytes) + mt_offset + 6;
					// +6 skip parameter numbers and max_stack, max_local
					*main_locals = max_locals;
					// add by T.H. Wu , for invoking main method use , write cls/mthd id to  , 2013.7.3
					// modified by T.H.Wu , 2013.9.9 , for multi-core execution
					// this is disabled for multi-core execution, 2013.9.12
					//*GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG3) = (cls_gnum<<16) | global_mthd_id;
					// this is enabled for multi-core execution, 2013.9.12
					main_cls_id = cls_gnum;
					main_mthd_id = global_mthd_id;
					is_main_method_found = 1;
				}
				// modify - by G
				mt_offset += 2;

				memcpy(mt_code + mt_offset, cf_ptr, 4);
				mt_offset += 4;
				code_size = read_uint32(cf_ptr + 4);
				//code_size+=4; //modified by jing 10/29
				memcpy(mt_code + mt_offset, cf_ptr + 8, code_size);
				
				//modified by zi-jing

				//has bug
				//aligment_shift = 4 - ( (code_size-aligment_shift_first_mthd) % 4 );
				//mt_offset += aligment_shift + code_size ;

				//modified by zi-jing
				aligment_shift = 4 - ( code_size % 4 );
				mt_offset += aligment_shift + code_size ;


				// modify - by G
				/*if (code_size % 2 == 1){
					mt_offset = mt_offset + code_size + 1;
				}
				else{
					mt_offset += code_size;
				}*/
				// ignore LineNumberTable and LocalVarableTable

#if exception_en	
				xcptn_read_offset = cf_ptr+8+code_size ;
				ER_cnt = read_uint16(xcptn_read_offset);  //exception routine counts
				xcptn_read_offset += 2;
			
				if (ER_cnt > 0) {
					#if exception_debug	
						xil_printf("\r\n =============================== Exception Information ========================================= \r\n");
						xil_printf("method id:%x has exception ER_cnt = %x \r\n",global_mthd_id,ER_cnt);
						xil_printf("*JPL_METHOD_TABLE_REG = %x \r\n",((((unsigned int) global_mthd_id << 2) + 3) << 16 ) |  (ER_LUT_addr << 6) |  ER_cnt);
					#endif
					for(core_idx=0; core_idx< JAIP_CORE_NUM; core_idx++){
						volatile uint *JPL_MA_LUT_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_idx,JPL_MA_LUT_REG);
						*JPL_MA_LUT_REG_volatile =
								((((unsigned int) global_mthd_id << 2) + 3) << 16 )
								|(ER_LUT_addr << 6) | ER_cnt;
					}
				
				}else{
					for(core_idx=0; core_idx< JAIP_CORE_NUM; core_idx++){
						volatile uint *JPL_MA_LUT_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_idx,JPL_MA_LUT_REG);
						*JPL_MA_LUT_REG_volatile =
							((((unsigned int) global_mthd_id << 2) + 3) << 16 ) |  0;
					}
				}
					

				
				for (edx = 0 ; edx < ER_cnt ; edx++){	
					start_end_pc_read = read_uint32(xcptn_read_offset); //get start_end_pc
					xcptn_read_offset += 4 ;
					
					rountine_jpc = read_uint16(xcptn_read_offset); //get rountine_jpc
					xcptn_read_offset +=2 ;
					
					temp = read_uint16(xcptn_read_offset); //get CP offset of exception class id
					if(temp == 0) {
						ER_cnt = 0;
						break;
					}
					xcptn_read_offset +=2 ;	

					// find super_class in org class CP
					temp = classfile_cp_toc[temp];

					// get Class(07)
					temp = read_uint16(classfile + temp + 1);

					// find name_index
					temp = classfile_cp_toc[temp];

					// get length
					cnamel = read_uint16(classfile + temp + 1);

					// get class_name string
					classname = classfile + temp + 3;

					for (fdx = 0; fdx < global_num; fdx++)
					{
						//xil_printf(" x_ref_tblclassname %s \r\n",x_ref_tbl[fdx].class_name);
						if (x_ref_tbl[fdx].class_namel == cnamel && !(strncmp(x_ref_tbl[fdx].class_name, classname, cnamel)))
							break;
					}

					if(fdx == global_num || x_ref_tbl[fdx].IsCache == 0){
						memcpy(x_ref_tbl[fdx].class_name, classname, cnamel);
						x_ref_tbl[fdx].class_namel = cnamel;
						x_ref_tbl[fdx].IsCache = 0;
						x_ref_tbl[fdx].base_address = 0;
						x_ref_tbl[fdx].image_size = 0;
						x_ref_tbl[fdx].parent_index = 999;
						x_ref_tbl[fdx].method_cnt = 0;
						x_ref_tbl[fdx].field_cnt = 1;
						x_ref_tbl[fdx].intf_cnt = 0;
						x_ref_tbl[fdx].obj_size = 1;

						global_num ++;

					}

					EID = fdx;
					for(core_idx=0; core_idx< JAIP_CORE_NUM; core_idx++){
						volatile uint *JPL_XCPTN_LUT2JAIP_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_idx, JPL_XCPTN_LUT2JAIP);
						//  bytecode opcode
						*JPL_XCPTN_LUT2JAIP_volatile = ( ER_LUT_addr << 16 ) | (( start_end_pc_read >> 16)+8);
						#if exception_debug
							xil_printf("%x \r\n",( ER_LUT_addr << 16 ) | (( start_end_pc_read >> 16)+8));
						#endif
						ER_LUT_addr++;
						*JPL_XCPTN_LUT2JAIP_volatile = ( ER_LUT_addr << 16 ) | (( start_end_pc_read & 0x0000FFFF )+8);
						#if exception_debug
							xil_printf("%x \r\n",( ER_LUT_addr << 16 ) | (( start_end_pc_read & 0x0000FFFF )+8));
						#endif
						ER_LUT_addr++;
						*JPL_XCPTN_LUT2JAIP_volatile = ( ER_LUT_addr << 16 ) | (rountine_jpc + 8); // jpc needs +8 because method code has extra 8 byte header
						#if exception_debug
							xil_printf("%x \r\n",( ER_LUT_addr << 16 ) | (rountine_jpc + 8));
						#endif
						ER_LUT_addr++;
						*JPL_XCPTN_LUT2JAIP_volatile = ( ER_LUT_addr << 16 ) | EID;
						#if exception_debug
							xil_printf("%x \r\n", ( ER_LUT_addr << 16 ) | EID);
						#endif
						ER_LUT_addr++;
					}
					
					
					#if exception_debug				
						xil_printf("ER_LUT_addr = %8x | start_end_pc = %8x | rountine_jpc = %8x | EID : %8x \r\n",ER_LUT_addr-4,start_end_pc_read,rountine_jpc,EID);




						//xil_printf(" start_end_pc = %32x \r\n",start_end_pc_read);					
						//xil_printf(" rountine_jpc = %32x \r\n",rountine_jpc);				
						//xil_printf(" ER_LUT_addr = %32x \r\n",ER_LUT_addr);
					#endif										
				}		
#endif			
	

				cf_ptr += attribute_size;
			}
			else if(attrnamel == 10 && strncmp(attrname, "Exceptions", 10) == 0){
				attribute_size = read_uint32(cf_ptr);
				cf_ptr += 4;
				cf_ptr += attribute_size;

			}
			else if(attrnamel == 9 && strncmp(attrname, "Synthetic", 9) == 0){
				// test for inner class parsing , 2013.7.10 , added by T.H. Wu
				uint32 synthetic_attri_length = read_uint32(cf_ptr);
				//xil_printf("[class_loader.c] method attribute name : %s, length:%d \r\n", attrname, synthetic_attri_length);
				cf_ptr += 4;
				cf_ptr += synthetic_attri_length;
				// modified by T.H.Wu , 2013.7.10 , for inner class parsing
				// cf_ptr += 8;
			}
			// modified by T.H.Wu , 2013.7.10 , for Thread class parsing
		// else if(attrnamel == 10 && strncmp(attrname, "Exceptions", 10) == 0){
			//}
			else{
				printf("The attribute \"%X\" (%s) has not difined, attribute length: %u\n", attrname, attrname, attrnamel);
				system("PAUSE");
			}
		}
		
		//xil_printf("mthd_id: %4x, mthd_offset:%x, code_size:%x \r\n",global_mthd_id, mthd_offset, code_size);
		for(core_idx=0; core_idx< JAIP_CORE_NUM; core_idx++){
			// must be declared as volatile.
			volatile uint *JPL_MA_LUT_REG_volatile = (uint*)GET_CTRL_REG_MEM0ADDR(core_idx,JPL_MA_LUT_REG);
			// added by T.H. Wu , 2013.7.3 , for fixing main method (CST) loading
			*JPL_MA_LUT_REG_volatile =	(((unsigned int) global_mthd_id << 2) + 0) << 16 | 0xFFFF;	// block index
			//added by zi-jing
			*JPL_MA_LUT_REG_volatile =	(((unsigned int) global_mthd_id << 2) + 1) << 16 | mthd_offset;
			// test by T.H.Wu , 2014.1.28
				//  ((x_ref_tbl[cls_gnum].base_address) << 1);
			//xil_printf("Mana %.8x\r\n", );
			*JPL_MA_LUT_REG_volatile =	(((unsigned int) global_mthd_id << 2) + 2) << 16 | ((code_size+8)); //modified by ji-jing
			//xil_printf("Mana %.8x\r\n", );
			*JPL_MA_LUT_REG_volatile = 0xFFFF0000; // <= bug
		}

		global_mthd_id++;
		
	}
	//printf("[class_loader.c] debug1 \n");
	// finish pass all methods of this class
	x_ref_tbl[cls_gnum].method_cnt = uint16_temp;
	*mt_nbytes = mt_offset;


	/* Parsing Reference Method Information */
	for (idx = 0; idx < ref_method_cnt; idx++)
	{
		//printf("[class_loader.c] debug 1-1-2 \n");
		// method_start
		// find Methodref_info(0A)
		temp = classfile_cp_toc[mt_idx_img2cls[idx]];
		// get tag (referenced method / reference interface method)
		tag = *(uint8*)(classfile + temp);
		// get class_index
		temp1 = read_uint16(classfile + temp + 1);
		// find Class(07)
		temp1 = classfile_cp_toc[temp1];
		// get name_index
		temp1 = read_uint16(classfile + temp1 + 1);
		// find Utf8(01)
		temp1 = classfile_cp_toc[temp1];
		// get length
		cnamel = read_uint16(classfile + temp1 + 1);
		// get class_name string
		classname = classfile + temp1 + 3;

		// get method name&type_index
		temp = read_uint16(classfile + temp + 3);
		// find Name&type_info(0C)
		temp = classfile_cp_toc[temp];
		// get name_index
		mtnameid = read_uint16(classfile + temp + 1);
		// get descripter name index;
		desid = read_uint16(classfile + temp + 3);
		// get the addr of name_index in org class
		temp = classfile_cp_toc[mtnameid];
		// get the string length of method name
		mtnamel = read_uint16(classfile + temp + 1);
		// method_name string copy
		methodname = classfile + temp + 3;

		// get the addr of name_index in org class
		temp = classfile_cp_toc[desid];
		// get length
		desnamel = read_uint16(classfile + temp + 1);
		// get name string
		desname = classfile + temp + 3;

		//  by T.H.Wu , 2013.8.23
		// access flag : static flag
		if (tag != 0xB){nonstatic = 1;}
		else{nonstatic = 0;}


		// find out which class this method really belong to
		// jdx : target_class
		if (x_ref_tbl[cls_gnum].class_namel == cnamel
			&& !(strncmp(x_ref_tbl[cls_gnum].class_name, classname, cnamel)))
		{
			jdx = cls_gnum;
		}
		else
		{
			for (jdx = 0; jdx < global_num; jdx++)
			{
				if (x_ref_tbl[jdx].class_namel == cnamel
					&& !(strncmp(x_ref_tbl[jdx].class_name, classname, cnamel)))
					break;
			}
		}

		if(jdx == global_num)
		{
			// the reference class of this method has not been detected
			// create the reference class' info in cross reference table
			kdx = 0;
			memcpy(x_ref_tbl[jdx].class_name, classname, cnamel);
			x_ref_tbl[jdx].class_namel = cnamel;
			x_ref_tbl[jdx].IsCache = 0;
			x_ref_tbl[jdx].base_address = 0;
			x_ref_tbl[jdx].image_size = 0;
			x_ref_tbl[jdx].parent_index = 999;
			x_ref_tbl[jdx].method_cnt = 1;
			x_ref_tbl[jdx].field_cnt = 0;
			x_ref_tbl[jdx].intf_cnt = 0;
			x_ref_tbl[jdx].obj_size = 1;
			x_ref_tbl[jdx].method[kdx].method_name = methodname;
			x_ref_tbl[jdx].method[kdx].method_namel = mtnamel;
			x_ref_tbl[jdx].method[kdx].descript_name = desname;
			x_ref_tbl[jdx].method[kdx].descript_namel = desnamel;
			x_ref_tbl[jdx].method[kdx].arg_size = method_descriptor_analyzer(desname) + nonstatic;
			address = (x_ref_tbl[jdx].method[kdx].arg_size<<16) | (mt_table_count<<2); // LEVEL1_XRT_BASE_ADDRESS
			mt_table_count +=2;
			num_entry_xrt_method_count += 2;
			// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
			if (tag != 0xB){
				x_ref_tbl[jdx].isIntf = 0;
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					//*GET_LV1_XRT_ABS_ADDR(core_idx, address)   =
					//		((method_descriptor_analyzer(desname) + 1)<<16) | jdx;
					*GET_LV1_XRT_ABS_ADDR(core_idx, address)   = (0x7FFF<<16) | jdx;
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) = jdx << 16;
					//*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) = 0xFFFFFFFF;
				}
			}
			else{
				x_ref_tbl[jdx].isIntf = 1;
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					//*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0xFFFFFFFF;
					*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0x8000FFFF;
				}
			}

			x_ref_tbl[jdx].method[kdx].method_offset = address;
			global_num ++;
			// test by T.H.Wu , 2013.8.28, 1717
			/*
			printf("[pre-parse 1] method: %s %s , address:%x \n",
					x_ref_tbl[jdx].method[kdx].method_name,
					x_ref_tbl[jdx].method[kdx].descript_name,
					x_ref_tbl[jdx].method[kdx].method_offset );
			*/
		}
		else
		{
			// searching all the method used in jdx class
			// uint16_temp : reduce structure access
			uint16_temp = x_ref_tbl[jdx].method_cnt;
			// kdx : target_method_num
			for (kdx = 0; kdx < uint16_temp; kdx++)
			{
				if (x_ref_tbl[jdx].method[kdx].method_namel == mtnamel
					&& x_ref_tbl[jdx].method[kdx].descript_namel == desnamel
					&& !(strncmp(x_ref_tbl[jdx].method[kdx].method_name,methodname,mtnamel))
					&& !(strncmp(x_ref_tbl[jdx].method[kdx].descript_name,desname,desnamel))
					)
					break;
			}

			if(kdx == uint16_temp)
			{
				x_ref_tbl[jdx].method[uint16_temp].method_name = methodname;
				x_ref_tbl[jdx].method[uint16_temp].method_namel = mtnamel;
				x_ref_tbl[jdx].method[uint16_temp].descript_name = desname;
				x_ref_tbl[jdx].method[uint16_temp].descript_namel = desnamel;
				x_ref_tbl[jdx].method[uint16_temp].arg_size = method_descriptor_analyzer(desname) + nonstatic;
				address = ( x_ref_tbl[jdx].method[uint16_temp].arg_size <<16) | (mt_table_count<<2); // LEVEL1_XRT_BASE_ADDRESS
				mt_table_count +=2;
				num_entry_xrt_method_count += 2;

				// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
				if (tag != 0xB){
					x_ref_tbl[jdx].isIntf = 0;
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address)   = ((method_descriptor_analyzer(desname) + 1)<<16) | jdx;
						*GET_LV1_XRT_ABS_ADDR(core_idx, address)   = (0x7FFF<<16) | jdx;
						*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) = jdx << 16;
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) = 0xFFFFFFFF;
					}
				}
				else{
					x_ref_tbl[jdx].isIntf = 1;
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0xFFFFFFFF;
						*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0x8000FFFF;
					}
				}

				x_ref_tbl[jdx].method[uint16_temp].method_offset = address;
				x_ref_tbl[jdx].method_cnt++;
				// test by T.H.Wu , 2013.8.28, 1717
				/*
				printf("[pre-parse 2] method: %s %s , address:%x \n",
						x_ref_tbl[jdx].method[kdx].method_name,
						x_ref_tbl[jdx].method[kdx].descript_name,
						x_ref_tbl[jdx].method[kdx].method_offset );
				*/
			}
			else
			{
				address = x_ref_tbl[jdx].method[kdx].method_offset;
			}
		}

		// modified by T.H.Wu , 2013.9.18
		// Dynamic Resolution fetched arg size from upper 16 bits of cst entry (method info)
		update_cst_entry_for_native_method(
			cls_gnum,	mtnamel, desnamel,
			methodname, desname, &address
		);

		// modified argument size for native method info again ,  by T.H.Wu , 2013.8.28, 1717
		//printf("[class_loader,2322] methodname:%s,  , method info: %x \n" , methodname, address);
		// debug for multi-core, 2013.10.18
		//for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
			//*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0xFFFFFFFF;
			//uint xrt_addr = *GET_LV1_XRT_ABS_ADDR(core_idx, address);
		//}



		// because its arg info is useful when invoke virtual
		ref_method_arg[idx] = method_descriptor_analyzer(desname) + 1;
		// modified by T.H.Wu ,2013.8.14 , reduce unnecessary part of the entry in CST circular buffer
		ref_method_addr[idx] = address;
		//ref_method_addr[idx] = (0x0000FFFF & (uint)address);
	} // the work of one method is finished



	// added by fox , 2013.7.10
	// *********** 2013.7.12 , for modifying method info of Thread.start() , T.H.Wu  **********
	// Because this is Thread (or other class inherited from it) start()
	// so we need to modify its global method ID of "start method" to
	// the global method ID of "run method"
	if(check_if_extended_from_Thread_class()){
		for(idx=0; idx<x_ref_tbl[cls_gnum].method_cnt ; idx++ ){
			methodname	=	x_ref_tbl[cls_gnum].method[idx].method_name;
			desname		=	x_ref_tbl[cls_gnum].method[idx].descript_name;
			mtnamel		=	x_ref_tbl[cls_gnum].method[idx].method_namel;
			desnamel	=	x_ref_tbl[cls_gnum].method[idx].descript_namel;

			if(mtnamel == 3 && desnamel == 3
					&& !strncmp(methodname, "run", mtnamel)
					&& !strncmp(desname, "()V", desnamel)
				//&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)
			){
				run_method_global_mthd_idx =
						*GET_LV1_XRT_ABS_ADDR(core_id, x_ref_tbl[cls_gnum].method[idx].method_offset + (1<<2))
						& 0x00000FFF;
				//printf("[class_loader, 485] when I'm in %s , run_method_global_mthd_idx = %x \n",
				//		x_ref_tbl[cls_gnum].class_name, run_method_global_mthd_idx
				//);
			}
			else if(mtnamel == 5 && desnamel == 3
					&& !strncmp(methodname, "start", mtnamel)
					&& !strncmp(desname, "()V", desnamel)
				//&& !strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)
			){
				start_method_info_ptr =
						GET_LV1_XRT_ABS_ADDR(core_id, x_ref_tbl[cls_gnum].method[idx].method_offset) + 1;
			}
		}
		if(start_method_info_ptr){
			// reset original class id & global method id
			// *(start_method_info_ptr) = (*(start_method_info_ptr) & 0xF01FF000) | (cls_gnum<<21) | (run_method_global_mthd_idx);
			*(start_method_info_ptr) = (*(start_method_info_ptr) & 0xE001F000) | (cls_gnum<<17) | (run_method_global_mthd_idx);
			//(1<<31) | (1<<30) | (0<<28) | (cls_gnum<<21) | (1<<16) |
			//(8<<12) | (global_mthd_id);
		}
	}



	// for checking method info list of Thread.start() and Thread.run()
	// added by T.H. Wu , 2013.7.11
	//if(
	//	!(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)) ||
	//	!(strncmp(x_ref_tbl[cls_gnum].class_name, "jembench/EnumeratedExecutor$Worker", 34))
	//){
	//	for(idx=0; idx<x_ref_tbl[cls_gnum].method_cnt ; idx++ ){
	//		printf("[class_loader,1833] method name:%s %s\n",
	//						x_ref_tbl[cls_gnum].method[idx].method_name ,
	//						x_ref_tbl[cls_gnum].method[idx].descript_name);
	//		printf("method ID (local):%X , start address in xrt: %x \n",
	//				idx ,
	//				x_ref_tbl[cls_gnum].method[idx].method_offset);
	//	}
	//}
	// for debug , modified by T.H.Wu , 2013.8.26
	/*
	printf("class: %s  \r\n", x_ref_tbl[cls_gnum].class_name);
	for(idx=0; idx<x_ref_tbl[cls_gnum].method_cnt ; idx++ ){
		printf("method: %s %s , address:%x \n",
				x_ref_tbl[cls_gnum].method[idx].method_name,
				x_ref_tbl[cls_gnum].method[idx].descript_name,
				x_ref_tbl[cls_gnum].method[idx].method_offset );
	}
	*/
	//printf("[class_loader.c] line 1920 , mt_table_count:%d \n",mt_table_count);

	// add method offset to interfac's and super class's method list if
	// this method is an implementation of some interface or for polymorphism
	if(x_ref_tbl[cls_gnum].isIntf != 1){
		for (idx = 0; idx < x_ref_tbl[cls_gnum].method_cnt; idx++)
		{
			mtnamel	= x_ref_tbl[cls_gnum].method[idx].method_namel;
			methodname   = x_ref_tbl[cls_gnum].method[idx].method_name;
			desnamel	= x_ref_tbl[cls_gnum].method[idx].descript_namel;
			desname	= x_ref_tbl[cls_gnum].method[idx].descript_name;
			access_flags = x_ref_tbl[cls_gnum].method[idx].access_flag;
			/*if(cls_gnum = 25){
				xil_printf("mtnamel:%d\r\n",mtnamel);
				xil_printf("methodname:%s\r\n",methodname);
				xil_printf("desnamel:%d\r\n",desnamel);
				xil_printf("desname:%s\r\n",desname);
				xil_printf("access_flags:%X\r\n",access_flags);
			}*/
			// Zigang 2011/09/01
			// <init>   offset is reserved for native method newInstance
			// <clinit> offset is reserved for parse class in first time
			if (mtnamel == 8
				&& desnamel == 3
				&& !(strncmp(methodname,(char*)"<clinit>",8))
				&& !(strncmp(desname,(char*)"()V",3))){

				x_ref_tbl[cls_gnum].clinit_offset =
						GET_LV1_XRT_ABS_ADDR(core_id, x_ref_tbl[cls_gnum].method[idx].method_offset);
				continue;

			}
			if (mtnamel == 6
				&& desnamel == 3
				&& !(strncmp(methodname,(char*)"<init>",6))
				&& !(strncmp(desname,(char*)"()V",3))){

				x_ref_tbl[cls_gnum].init_offset =
						GET_LV1_XRT_ABS_ADDR(core_id, x_ref_tbl[cls_gnum].method[idx].method_offset);
				continue;
			}

			//if( !(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 16)) ){
			//if( !(strncmp(x_ref_tbl[cls_gnum].class_name, "jembench/EnumeratedExecutor$Worker", 34)) ){
			//	printf("[class_loader.c] debug1-1-3, method name: %s \n", methodname);
			//	printf("[class_loader.c] debug1-1-3, access_flags: %x \n", access_flags);
		// 	printf("[class_loader.c] debug1-1-3, intf_cnt: %x \n", x_ref_tbl[cls_gnum].intf_cnt);
			//}

			// add method sto interface and super class's method list
			// static method and native method no need
			if ((access_flags & 0x0008) != 0 || (access_flags & 0x0100) != 0 ||
				(access_flags & 0x0400) !=0) continue;

			uint addr2nxt_mthd_info = 0;

			// add to interface's method list
			for (jdx = 0; jdx < x_ref_tbl[cls_gnum].intf_cnt; jdx++)
			{
				uint16_temp = x_ref_tbl[cls_gnum].intf[jdx];
				for (zdx = 0; zdx < x_ref_tbl[uint16_temp].method_cnt; zdx++)
				{
					if (x_ref_tbl[uint16_temp].method[zdx].method_namel == mtnamel
						&& x_ref_tbl[uint16_temp].method[zdx].descript_namel == desnamel
						&& !(strncmp(x_ref_tbl[uint16_temp].method[zdx].method_name,methodname,mtnamel))
						&& !(strncmp(x_ref_tbl[uint16_temp].method[zdx].descript_name,desname,desnamel))
					)break;
				}

				if( zdx == x_ref_tbl[uint16_temp].method_cnt) continue;
				access_flags = x_ref_tbl[uint16_temp].method[zdx].access_flag;
				if ((access_flags & 0x0008) != 0 || (access_flags & 0x0100) != 0) continue;

				//serach interface's method list's last node
				// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
				address = x_ref_tbl[uint16_temp].method[zdx].method_offset;
				//while(*GET_LV1_XRT_ABS_ADDR(core_id,address) != 0xFFFFFFFF){
				while( (*GET_LV1_XRT_ABS_ADDR(core_id,address) & 0xFFFF) != 0xFFFF){
					// added for debug.... by T.H.Wu , 2013.7.10
					//if( !(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 34)) ){
					//	printf("[class_loader.c] polymorphism case 1. \n");
					//}
					//address = *GET_LV1_XRT_ABS_ADDR(core_id, address+(2<<2));
					address = *GET_LV1_XRT_ABS_ADDR(core_id, address) >> 16;
				}
				//*GET_LV1_XRT_ABS_ADDR(address) = *((uint*)x_ref_tbl[cls_gnum].method[idx].method_offset);
				//*GET_LV1_XRT_ABS_ADDR(address+1) = *((uint*)x_ref_tbl[cls_gnum].method[idx].method_offset+1);
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					//*GET_LV1_XRT_ABS_ADDR(core_idx,address) =
					//		*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[cls_gnum].method[idx].method_offset);
					//uint xrt_addr_src = (uint)GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[cls_gnum].method[idx].method_offset);
					//uint xrt_addr_dst = (uint)GET_LV1_XRT_ABS_ADDR(core_idx, address);
					//printf("[multicore xrt mthd info] xrt_addr_src: %x \n",xrt_addr_src);
					//printf("[multicore xrt mthd info] xrt_addr_dst: %x \n",xrt_addr_dst);
					//
					*GET_LV1_XRT_ABS_ADDR(core_idx,address) = 0x00000000;
					*GET_LV1_XRT_ABS_ADDR(core_idx,address) = (mt_table_count<<(16+2))	|
							(0xFFFF & *GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[cls_gnum].method[idx].method_offset));
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) = 0x00000000;
					*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
							*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[cls_gnum].method[idx].method_offset + (1<<2));
					//*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) =
					//		LEVEL1_XRT_BASE_ADDRESS | (mt_table_count<<2);
					//address = *GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2));
					addr2nxt_mthd_info =  *GET_LV1_XRT_ABS_ADDR(core_idx,address) >> 16 ;
					//*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0xFFFFFFFF;
					*GET_LV1_XRT_ABS_ADDR(core_idx, addr2nxt_mthd_info) = 0x8000FFFF;
				}
				mt_table_count += 2;
				num_entry_xrt_method_count += 2;
			}

			uint16_temp = x_ref_tbl[cls_gnum].parent_index;
			while(uint16_temp!= 999){
				// added for debug.... by T.H.Wu , 2013.7.10
				//if( !(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 34)) ){
				//	printf("[class_loader.c] polymorphism case 2. super class:%s \n", x_ref_tbl[uint16_temp].class_name );
				//}
				//
				for (zdx = 0; zdx < x_ref_tbl[uint16_temp].method_cnt ; zdx++){
					if (mtnamel == x_ref_tbl[uint16_temp].method[zdx].method_namel
						&& desnamel == x_ref_tbl[uint16_temp].method[zdx].descript_namel
						&& !(strncmp(methodname, x_ref_tbl[uint16_temp].method[zdx].method_name, mtnamel))
						&& !(strncmp(desname, x_ref_tbl[uint16_temp].method[zdx].descript_name, desnamel))
						)
						break;
				}

				access_flags = x_ref_tbl[uint16_temp].method[zdx].access_flag;
				if ((access_flags & 0x0008) != 0 || (access_flags & 0x0100) != 0) break;
					
				if(zdx != x_ref_tbl[uint16_temp].method_cnt){
					//serach super class's method list's last node
					// modified by T.H.Wu , 2013.9.23 , for reducing DR method info
					address = x_ref_tbl[uint16_temp].method[zdx].method_offset;
					//while(*GET_LV1_XRT_ABS_ADDR(core_id, address) != 0xFFFFFFFF){
					while( (*GET_LV1_XRT_ABS_ADDR(core_id, address) & 0xFFFF) != 0xFFFF){
						//if(mt_table_count>5120){break;}
						// added for debug.... by T.H.Wu , 2013.7.10
					// if( !(strncmp(x_ref_tbl[cls_gnum].class_name, "jembench/EnumeratedExecutor$Worker", 34)) ){
						//if( !(strncmp(x_ref_tbl[cls_gnum].class_name, "java/lang/Thread", 34)) ){
							//printf("[class_loader.c] polymorphism case 3. "
							//		"address:%4x , content:%4x\n"
							//		,  GET_LV1_XRT_ABS_ADDR(core_id, address)
							//		, *GET_LV1_XRT_ABS_ADDR(core_id, address)
							//);
						//}
						//address = *GET_LV1_XRT_ABS_ADDR(core_id, address+(2<<2));
						address = *GET_LV1_XRT_ABS_ADDR(core_id, address)>>16;
					}
					//*GET_LV1_XRT_ABS_ADDR(address) = *((uint*)x_ref_tbl[cls_gnum].method[idx].method_offset);
					//*GET_LV1_XRT_ABS_ADDR(address+1) = *((uint*)x_ref_tbl[cls_gnum].method[idx].method_offset+1);
					for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address) =
						//		*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[cls_gnum].method[idx].method_offset);
						*GET_LV1_XRT_ABS_ADDR(core_idx, address) =
								0x00000000 | (mt_table_count<<(16+2)) |
								(0xFFFF & *GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[cls_gnum].method[idx].method_offset));
						*GET_LV1_XRT_ABS_ADDR(core_idx, address+(1<<2)) =
								*GET_LV1_XRT_ABS_ADDR(core_idx, x_ref_tbl[cls_gnum].method[idx].method_offset + (1<<2));
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2)) =
						//		LEVEL1_XRT_BASE_ADDRESS | (mt_table_count<<2) ;
						//address = *GET_LV1_XRT_ABS_ADDR(core_idx, address+(2<<2));
						addr2nxt_mthd_info =  *GET_LV1_XRT_ABS_ADDR(core_idx,address)>>16 ;
						//*GET_LV1_XRT_ABS_ADDR(core_idx, address) = 0xFFFFFFFF;
						*GET_LV1_XRT_ABS_ADDR(core_idx, addr2nxt_mthd_info) = 0x8000FFFF;
					}
					mt_table_count += 2;
					num_entry_xrt_method_count += 2;
				}
				else break;
				uint16_temp = x_ref_tbl[uint16_temp].parent_index;
			}
		}
	}

	//printf("[class_loader.c] debug2 \n");

	/* Parsing Reference Field Information */
	for (idx = 0; idx < ref_field_cnt; idx++)
	{
		// find Fieldref_info(09)
		temp = classfile_cp_toc[fd_idx_img2cls[idx]];
		// get class_index
		temp1 = read_uint16(classfile + temp + 1);
		// find Class(07)
		temp1 = classfile_cp_toc[temp1];
		// get name_index
		temp1 = read_uint16(classfile + temp1 + 1);
		// find Utf8(01)
		temp1 = classfile_cp_toc[temp1];
		// get length
		cnamel = read_uint16(classfile + temp1 + 1);
		// get class_name string
		classname = classfile + temp1 + 3;

		// get field name&type_index
		temp = read_uint16(classfile + temp + 3);
		// find Name&type_info(0C)
		temp = classfile_cp_toc[temp];
		// get name_index
		fdnameid = read_uint16(classfile + temp + 1);
		// find name_index in image CP
		temp = classfile_cp_toc[fdnameid];

		fdnamel = read_uint16(classfile + temp + 1);
		fieldname = classfile + temp + 3;
		//20110913
		/*
		// get length
		fdnamel = read_uint16(classfile + temp + 1);
		// get field_name string
		memcpy(fieldname, (uint8 *) (classfile + temp + 3), fdnamel);
		*/

		// find out which class this method really belong to
		// jdx : target_class
		if (x_ref_tbl[cls_gnum].class_namel == cnamel
			&& !(strncmp(x_ref_tbl[cls_gnum].class_name, classname, cnamel)))
		{
			jdx = cls_gnum;
		}
		else
		{
			for (jdx = 0; jdx < global_num; jdx++){
				if (x_ref_tbl[jdx].class_namel == cnamel
					&& !(strncmp(x_ref_tbl[jdx].class_name, classname, cnamel)))
					break;
			}
		}

		if(jdx == global_num)
		{
			// the reference class of this field has not been detected
			// create the reference class' info in cross reference table
			memcpy(x_ref_tbl[jdx].class_name, classname, cnamel);
			x_ref_tbl[jdx].class_namel = cnamel;
			x_ref_tbl[jdx].IsCache = 0;
			x_ref_tbl[jdx].base_address = 0;
			x_ref_tbl[jdx].image_size = 0;
			x_ref_tbl[jdx].parent_index = 999;
			x_ref_tbl[jdx].method_cnt = 0;
			x_ref_tbl[jdx].field_cnt = 1;
			x_ref_tbl[jdx].intf_cnt = 0;
			x_ref_tbl[jdx].obj_size = 1;
			x_ref_tbl[jdx].field[0].cls_id = jdx;
			x_ref_tbl[jdx].field[0].field_namel = fdnamel;
			x_ref_tbl[jdx].field[0].field_name = fieldname;
			address = (0x0000<<16) | (mt_table_count<<2); // LEVEL1_XRT_BASE_ADDRESS
			for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
				*GET_LV1_XRT_ABS_ADDR(core_idx, address) = jdx << 16;
			}
			mt_table_count ++;
			num_entry_xrt_field_count ++ ;
			//x_ref_tbl[jdx].field[0].field_address = jdx << 16 | ((unsigned int)address & 0x0000FFFF);
			x_ref_tbl[jdx].field[0].field_address = address;
			ref_field_addr[idx] = x_ref_tbl[jdx].field[0].field_tag<<27 | ( (x_ref_tbl[jdx].field[0].cls_id << 16) & 0x07ff0000 ) | ((uint)address & 0x0000FFFF);
			global_num ++;
		}
		else
		{
			// searching all the field in jdx class
			// uint16_temp : reduce structure access
			uint16_temp = x_ref_tbl[jdx].field_cnt;
			// kdx : target_field_num
			for (kdx = 0; kdx < uint16_temp; kdx++)
			{
				if( //jdx == x_ref_tbl[jdx].field[kdx].cls_id &&	//not sure if this statement is necessary, but it seems that there are some bugs when we referencing to fields inherited from super class. (by C.C. Hsu)
					fdnamel == x_ref_tbl[jdx].field[kdx].field_namel &&
					strncmp(fieldname,x_ref_tbl[jdx].field[kdx].field_name,fdnamel) == 0)
					break;
			}

			if(kdx == uint16_temp)
			{
				x_ref_tbl[jdx].field[uint16_temp].cls_id = jdx; 
				x_ref_tbl[jdx].field[uint16_temp].field_namel = fdnamel;
				x_ref_tbl[jdx].field[uint16_temp].field_name = fieldname;
				address = (0x0000 << 16) | (mt_table_count<<2) ;
				mt_table_count ++;
				num_entry_xrt_field_count ++ ;
				for(core_idx=0; core_idx<JAIP_CORE_NUM; core_idx++){
					*GET_LV1_XRT_ABS_ADDR(core_idx, address) = jdx << 16;
				}
				//x_ref_tbl[jdx].field[uint16_temp].field_address = jdx << 16 | ((unsigned int)address & 0x0000FFFF);
				x_ref_tbl[jdx].field[uint16_temp].field_address = address;
				ref_field_addr[idx] = x_ref_tbl[jdx].field[uint16_temp].field_tag<<27 | ( (x_ref_tbl[jdx].field[uint16_temp].cls_id << 16) & 0x07ff0000 ) | ((uint)address & 0x0000FFFF);
				x_ref_tbl[jdx].field_cnt++;
			}
			else
			{
				address = x_ref_tbl[jdx].field[kdx].field_address;
				ref_field_addr[idx] = x_ref_tbl[jdx].field[kdx].field_tag<<27 | ( (x_ref_tbl[jdx].field[kdx].cls_id << 16) & 0x07ff0000 ) | ((uint)address & 0x0000FFFF);
			}
		} 
		//ref_field_addr[idx] = address;
	}

	// modified by T.H.Wu , 2013.8.5 , for debug use
	if( mt_table_count > ((0x1000)<<0) ){
		printf("[class_loader.c] line 2153,  while class=%s , XRT size usage: %x \n",
				x_ref_tbl[cls_gnum].class_name , mt_table_count );
	}

	//printf("[class_loader.c] debug3 \n");

	/* resolve the class Data */
	for (idx = 0; idx < cls_cnt; idx++)
	{
		dim_num = 0;
		type = 0;
		zdx = 0xFFFF;

		// find cls_info
		temp = classfile_cp_toc[cls_idx_img2cls[idx]];
		// get name_index
		temp = read_uint16(classfile + temp + 1);
		// find Utf8(01)
		temp = classfile_cp_toc[temp];
		// get length
		cnamel = read_uint16(classfile + temp + 1);
		temp = temp+3;
		for(jdx = 0 ; jdx< cnamel ; jdx++){
			if(*(classfile + temp + jdx) == '['){
				dim_num++;
			}
			else if(dim_num == 0){ //class
				type = 0;
				dim_num = 1;
				classname = classfile + temp + jdx;
				for (zdx = 0; zdx < global_num; zdx++){
					if (x_ref_tbl[zdx].class_namel == cnamel
						&& !(strncmp(x_ref_tbl[zdx].class_name, classname, cnamel)))
						break;
				}

				if(zdx == global_num)
				{
					// the reference class of this field has not been detected
					// create the reference class' info in cross reference table
					memcpy(x_ref_tbl[zdx].class_name, classname, cnamel);
					x_ref_tbl[zdx].class_namel = cnamel;
					x_ref_tbl[zdx].IsCache = 0;
					x_ref_tbl[zdx].base_address = 0;
					x_ref_tbl[zdx].image_size = 0;
					x_ref_tbl[zdx].parent_index = 999;
					x_ref_tbl[zdx].method_cnt = 0;
					x_ref_tbl[zdx].field_cnt = 0;
					x_ref_tbl[zdx].intf_cnt = 0;
					x_ref_tbl[zdx].obj_size = 1;
					global_num ++;
				}
				break;
			}
			else if(*(classfile + temp + jdx) == 'B'){
				type = 8;
				break;
			}
			else if(*(classfile + temp + jdx) == 'C'){
				type = 5;
				break;
			}
			else if(*(classfile + temp + jdx) == 'D'){
				type = 7;
				break;
			}
			else if(*(classfile + temp + jdx) == 'F'){
				type = 6;
				break;
			}
			else if(*(classfile + temp + jdx) == 'I'){
				type = 10;
				break;
			}
			else if(*(classfile + temp + jdx) == 'J'){
				type = 11;
				break;
			}
			else if(*(classfile + temp + jdx) == 'L'){ //array of obj
				type = 0;
				cnamel = cnamel-dim_num-2;
				classname = classfile + temp + jdx +1;
				for (zdx = 0; zdx < global_num; zdx++){
					if (x_ref_tbl[zdx].class_namel == cnamel
						&& !(strncmp(x_ref_tbl[zdx].class_name, classname, cnamel)))
						break;
				}

				if(zdx == global_num)
				{
					// the reference class of this field has not been detected
					// create the reference class' info in cross reference table
					memcpy(x_ref_tbl[zdx].class_name, classname, cnamel);
					x_ref_tbl[zdx].class_namel = cnamel;
					x_ref_tbl[zdx].IsCache = 0;
					x_ref_tbl[zdx].base_address = 0;
					x_ref_tbl[zdx].image_size = 0;
					x_ref_tbl[zdx].parent_index = 999;
					x_ref_tbl[zdx].method_cnt = 0;
					x_ref_tbl[zdx].field_cnt = 0;
					x_ref_tbl[zdx].intf_cnt = 0;
					x_ref_tbl[zdx].obj_size = 1;
					global_num ++;
				}
				break;
			}
			else if(*(classfile + temp + jdx) == 'S'){
				type = 9;
				break;
			}
			else if(*(classfile + temp + jdx) == 'Z'){
				type = 4;
				break;
			}
		}
		
		cls_tag[idx] = type<<24 | dim_num<<16 | zdx;
		// modified by C.C. Hsu
		/*printf("Constant Pool[%x] : %x ; type : %x ; dim : %x ; zdx : %x\r\n"
			,idx,cls_tag[idx],type,dim_num,zdx);*/
	}

	//printf("[class_loader.c] debug4 \n");
	/* resolve the ldc Data */
	
	for (idx = 0; idx < ldc_cnt; idx++)
	{
		// find ldc data idx : CP_Integer, CP_Float, CP_Long, CP_Double, CP_String
		temp = classfile_cp_toc[ldc_idx_img2cls[idx]];
		token = *(uint8*)(classfile + temp);
		//x_ref_tbl[cls_gnum].ldc[idx].type = token;
		switch (token)
		{
		case CP_String:
			// get String_index
			uint16_temp = read_uint16(classfile + temp +1);
			// find String
			uint16_temp = classfile_cp_toc[uint16_temp];
			// get the string size
			uint16_temp2 = read_uint16(classfile + uint16_temp +1);
			
			heap_align32();
			ldc_data[idx] = CURRENT_HEAP_PTR;
			//JavaLangString = jar_load_class(core_id, sys_jar_image,sys_jar_size,(char *) "java/lang/String.class",&IsClinit);
			// 2014.1.7 , fix the bug for class ID of string primitive.
			//*(unsigned int*)CURRENT_HEAP_PTR = 16;
			*(unsigned int*)CURRENT_HEAP_PTR = 0x00000000 | (JavaLangString);
			CURRENT_HEAP_PTR+=4;
			*(unsigned int*)CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + 0x14;
			CURRENT_HEAP_PTR+=4;
			*(unsigned int*)CURRENT_HEAP_PTR = 0;
			CURRENT_HEAP_PTR+=4;
			*(unsigned int*)CURRENT_HEAP_PTR = uint16_temp2;
			CURRENT_HEAP_PTR+=4;
			*(unsigned int*)CURRENT_HEAP_PTR = 0x50000000;						// modified by C.C. Hsu
			CURRENT_HEAP_PTR+=4;
			*(unsigned int*)CURRENT_HEAP_PTR = uint16_temp2;
			CURRENT_HEAP_PTR+=4;

			//*(unsigned int*)(CURRENT_HEAP_PTR - 12) = recursive_new_array(5, 0, 1);
			//memcpy((unsigned int*)CURRENT_HEAP_PTR, classfile + uint16_temp +3, uint16_temp2);
			char * utf8_ptr = (char *)(classfile + uint16_temp +3);				// modified by C.C. Hsu
			for(jdx = 0; jdx < uint16_temp2;jdx++){
				((unsigned short *)CURRENT_HEAP_PTR)[jdx] = utf2unicode(&utf8_ptr);
			}

			if((uint16_temp2 & 0x00000001) != 0){
				CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + ((uint16_temp2<<1)&0xFFFFFFFC) + 4;	// modified by C.C. Hsu
			}
			else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (uint16_temp2<<1);					// modified by C.C. Hsu
			heap_align32();
			
			break;

		case CP_Float:
		case CP_Integer:
			
			tmp[0] = *((uint8*)classfile + temp + 1);
			tmp[1] = *((uint8*)classfile + temp + 2);
			tmp[2] = *((uint8*)classfile + temp + 3);
			tmp[3] = *((uint8*)classfile + temp + 4);
			ldc_data[idx] = *(int*)tmp;
			break;
			
		case CP_Long:
		case CP_Double:
			
			tmp[0] = *((uint8*)classfile + temp + 1);
			tmp[1] = *((uint8*)classfile + temp + 2);
			tmp[2] = *((uint8*)classfile + temp + 3);
			tmp[3] = *((uint8*)classfile + temp + 4);
			ldc_data[idx] = *(int*)tmp;
			idx++;
			
			tmp[0] = *((uint8*)classfile + temp + 5);
			tmp[1] = *((uint8*)classfile + temp + 6);
			tmp[2] = *((uint8*)classfile + temp + 7);
			tmp[3] = *((uint8*)classfile + temp + 8);
			ldc_data[idx] = *(int*)tmp;
			break;
			
		}
	}
	
	//printf("[class_loader.c] debug5 \n");
   // x_ref_tbl[cls_gnum].ldc_cnt = ldc_cnt;
	cp_bias = 4 + (nitems<<1);
	cp_offset = 0;
#if cst_32
	xil_printf("\r\n  computes cp_toc & cp_data \r\n ");
	xil_printf("\r\n  cls \r\n ");

	xil_printf("\r\n  cp_bias:%x nitems:%x \r\n ",cp_bias,nitems);

	xil_printf("\r\n  cls_cnt:%x ref_field_cnt:%x ref_method_cnt:%x \r\n ",cls_cnt,ref_field_cnt,ref_method_cnt);

	for(idx=0;idx<256;idx++){
			cp_toc32[idx]=0;
	}

	//cp_toc32[0]=0x4D4D4553;
#endif

	for (idx = 0; idx < ldc_cnt; idx++)
	{
		//cp_toc[ldc_idx_img2cls[idx]] = cp_bias + cp_offset;
		address = ldc_data[idx];

		ref_data_0=(uint)address & 0x0000ffff;
		ref_data_1= ((uint)address>>16) ;
		cp_toc[ldc_idx_img2cls[idx]*2]= ref_data_1;
		cp_toc[ldc_idx_img2cls[idx]*2+1]= ref_data_0;
#if cst_32
		xil_printf("ldc_idx_img2cls[idx]:%x  cp_bias + cp_offset:%x\r\n",ldc_idx_img2cls[idx],cp_bias + cp_offset);
		xil_printf("address:%x\r\n",address);


		cp_toc32[ldc_idx_img2cls[idx]]=address;

#endif

		//tmp[0] = (uint)address >> 24;
		//tmp[1] = ((uint)address >> 16) & 0xff;
		//tmp[2] = ((uint)address >> 8) & 0xff;
		//tmp[3] = (uint)address & 0xff;
		//memcpy(cp_data + cp_offset, tmp, 4);
		cp_offset += 4;
	}
	for (idx = 0; idx < cls_cnt; idx++)
	{
		//cp_toc[cls_idx_img2cls[idx]] = cp_bias + cp_offset;
		address = cls_tag[idx];

#if cst_32
		xil_printf("cls_idx_img2cls[idx]:%x  cp_bias + cp_offset:%x\r\n",cls_idx_img2cls[idx],cp_bias + cp_offset);
		xil_printf("address:%x\r\n",address);
		cp_toc32[cls_idx_img2cls[idx]]=address;


		ref_data_0=(uint)address & 0x0000ffff;
		ref_data_1= ((uint)address>>16) ;
		//xil_printf("ref_data_0:%x   ref_data_1:%x\n",ref_data_0,ref_data_1);
		cp_toc[cls_idx_img2cls[idx]*2]= ref_data_1;
		cp_toc[cls_idx_img2cls[idx]*2+1]= ref_data_0;
#endif
		ref_data_0=(uint)address & 0x0000ffff;
		ref_data_1= ((uint)address>>16) ;
		cp_toc[cls_idx_img2cls[idx]*2]= ref_data_1;
		cp_toc[cls_idx_img2cls[idx]*2+1]= ref_data_0;

		//tmp[0] = (uint)address >> 24;
		//tmp[1] = ((uint)address >> 16) & 0xff;
		//tmp[2] = ((uint)address >> 8) & 0xff;
		//tmp[3] = (uint)address & 0xff;
		//memcpy(cp_data + cp_offset, tmp, 4);
		cp_offset += 4;
	}
#if cst_32
	xil_printf("\r\n  ref_field \r\n ");
#endif
	for (idx = 0; idx < ref_field_cnt; idx++)
	{
		//cp_toc[fd_idx_img2cls[idx]] = cp_bias + cp_offset;
		address = ref_field_addr[idx];
#if cst_32
		xil_printf("fd_idx_img2cls[idx]:%x  cp_bias + cp_offset:%x\r\n",fd_idx_img2cls[idx],cp_bias + cp_offset);
		xil_printf("address:%x\r\n",address);
		cp_toc32[fd_idx_img2cls[idx]]=address;

		ref_data_0=(uint)address & 0x0000ffff;
		ref_data_1= ((uint)address>>16) ;
		//xil_printf("ref_data_0:%x   ref_data_1:%x\n",ref_data_0,ref_data_1);
		cp_toc[fd_idx_img2cls[idx]*2]= ref_data_1;
		cp_toc[fd_idx_img2cls[idx]*2+1]= ref_data_0;
#endif
		ref_data_0=(uint)address & 0x0000ffff;
		ref_data_1= (uint)address>>16;
		cp_toc[fd_idx_img2cls[idx]*2]= ref_data_1;
		cp_toc[fd_idx_img2cls[idx]*2+1]= ref_data_0;
		
		//xil_printf("%x\r\n",address);

		//tmp[0] = (uint)address >> 24;
		//tmp[1] = ((uint)address >> 16) & 0xff;
		//tmp[2] = ((uint)address >> 8) & 0xff;
		//tmp[3] = (uint)address & 0xff;
		//memcpy(cp_data + cp_offset, tmp, 4);
		cp_offset += 4;
	}
#if cst_32
	xil_printf("\r\n  ref_method \r\n ");
#endif
	for (idx = 0; idx < ref_method_cnt; idx++)
	{
	// cp_toc[mt_idx_img2cls[idx]] = cp_bias + cp_offset;
		//tmp[0] = ref_method_arg[idx] >> 8;
		//tmp[1] = ref_method_arg[idx] & 0x00ff;
#if cst_32
		xil_printf("mt_idx_img2cls[idx]:%x  cp_bias + cp_offset:%x\r\n",mt_idx_img2cls[idx],cp_bias + cp_offset);
		xil_printf("ref_method_arg[idx]:%x\r\n",ref_method_arg[idx]);
#endif
		//memcpy(cp_data + cp_offset, tmp, 2);
		cp_offset += 2;
		address = ref_method_addr[idx];
#if cst_32
		xil_printf("address:%x\r\n",address);
		cp_toc32[mt_idx_img2cls[idx]]=address;

		ref_data_0=(uint)address & 0x0000ffff;
		ref_data_1= ((uint)address>>16) ;
		//xil_printf("ref_data_0:%x   ref_data_1:%x\n",ref_data_0,ref_data_1);
		cp_toc[mt_idx_img2cls[idx]*2]= ref_data_1;
		cp_toc[mt_idx_img2cls[idx]*2+1]= ref_data_0;
#endif
		ref_data_0=(uint)address & 0x0000ffff;
		//ref_data_1= 0x0000 ;
		ref_data_1= ((uint)address>>16) ;
		cp_toc[mt_idx_img2cls[idx]*2]= ref_data_1;
		cp_toc[mt_idx_img2cls[idx]*2+1]= ref_data_0;

		//tmp[0] = (uint)address >> 24;
		//tmp[1] = ((uint)address >> 16) & 0xff;
		//tmp[2] = ((uint)address >> 8) & 0xff;
		//tmp[3] = (uint)address & 0xff;
		//memcpy(cp_data + cp_offset, tmp, 4);
		cp_offset += 4;
	}

#if cst_32
		xil_printf("\nprint fake cst32 TOC \r\n");

		xil_printf("\r\n	0:	4D4D	4553");
		for(idx=0;idx<256;idx++){
			if(((idx+1)%4)==0)	xil_printf("\r\n %8x:",(idx+1)*4);

			xil_printf(" %4x ",cp_toc32[idx]);

		}
#endif

	//*cp_nbytes = (ref_field_cnt + ref_method_cnt + cls_cnt) << 2;
	
	// added by ji-jing
	x_ref_tbl[cls_gnum].cst_size = 4 + (nitems<<1) + *cp_nbytes; // added by ji-jing
	

	x_ref_tbl[cls_gnum].image_size = 4 + (nitems<<1) + *cp_nbytes + *mt_nbytes;
	*CPcount = nitems;
	
/*
	//test string pool by G
	for (idx = 0; idx < string_cnt; idx++)
	{
		printf("string %d ",idx);
		//length
		uint16_temp = x_ref_tbl[cls_gnum].string_pool_offset[idx+1] - x_ref_tbl[cls_gnum].string_pool_offset[idx];
		for (jdx = 0; jdx < uint16_temp; jdx++){
			printf("%c",x_ref_tbl[cls_gnum].string_pool[x_ref_tbl[cls_gnum].string_pool_offset[idx] + jdx]);
		}
		printf("\n");
	}
*/

	return 0;

}

/* ------------------------------------------------------------------------- */
/* <clinit> initialzer													*/
/* Update the field value for global static field							*/
/* ------------------------------------------------------------------------- */
int
clinit_initializer(uint16 *cp_toc, uint8 *cp_data,
				uint8 *fd_data, uint8 *mt_code,
				uint16 *clinit_pc)
{
	uint16 temp, codes, value, fd_name_idx;

	temp = *clinit_pc;
	codes = (uint16) mt_code[temp];

	// Get the field value
	switch (codes)
	{
	case 0x10: /* bipush */
		value = (uint16) mt_code[temp + 1];
		temp = read_uint16(mt_code + temp + 3); // get field index
		break;
	case 0x11: /* sipush */
		value = read_uint16(mt_code + temp + 1);
		temp = read_uint16(mt_code + temp + 4); // get field index
		break;
	case 0x03: /* iconst_0 */
		value = 0;
		temp = read_uint16(mt_code + temp + 2); // get field index
		break;
	case 0x04: /* iconst_1 */
		value = 1;
		temp = read_uint16(mt_code + temp + 2); // get field index
		break;
	case 0x05: /* iconst_2 */
		value = 2;
		temp = read_uint16(mt_code + temp + 2); // get field index
		break;
	case 0x06: /* iconst_3 */
		value = 3;
		temp = read_uint16(mt_code + temp + 2); // get field index
		break;
	case 0x07: /* iconst_4 */
		value = 4;
		temp = read_uint16(mt_code + temp + 2); // get field index
		break;
	case 0x08: /* iconst_5 */
		value = 5;
		temp = read_uint16(mt_code + temp + 2); // get field index
		break;
	default:
		value = 0;
		temp = read_uint16(mt_code + temp + 2); // get field index
		break;
	}

	/* resolution to get the index of field name */
	temp = read_uint16((uint8 *) (cp_toc + temp));
	temp = temp - (read_uint16((uint8 *) cp_toc) << 1) - 8;
	temp = read_uint16(cp_data + temp + 3);
	temp = read_uint16((uint8 *) (cp_toc + temp));
	temp = temp - (read_uint16((uint8 *) cp_toc) << 1) - 8;
	fd_name_idx = read_uint16(cp_data + temp + 1);

	/* Compare with the name index in field data */
	temp = read_uint16(fd_data + 2);
	if (temp == fd_name_idx)
	{
		memcpy((void *) (fd_data + 8), (void *) &value, 2);
	}
	return 0;
}

/*=========================================================================
 * AUTHOR:		Frank Yellin
 * FUNCTION:	utf2unicode
 * OVERVIEW:	Converts UTF8 string to unicode char.
 *
 *   parameters:  utfstring_ptr: pointer to a UTF8 string. Set to point 
 *				to the next UTF8 char upon return.
 *   returns	unicode char
 *=======================================================================*/
 short utf2unicode(const char **utfstring_ptr)					
{
	unsigned char *ptr = (unsigned char *) (*utfstring_ptr);
	unsigned char ch, ch2, ch3;
	int	length = 1;		/* default length */
	short   result = 0x80;	/* default bad result; */

	switch ((ch = ptr[0]) >> 4)
	{
	default:
		result = ch;
		break;

	case 0x8:
	case 0x9:
	case 0xA:
	case 0xB:
	case 0xF:
		/* Shouldn't happen. */
		break;

	case 0xC:
	case 0xD:
		/* 110xxxxx  10xxxxxx */
		if (((ch2 = ptr[1]) & 0xC0) == 0x80)
		{
			unsigned char high_five = ch & 0x1F;
			unsigned char low_six = ch2 & 0x3F;
			result = (high_five << 6) + low_six;
			length = 2;
		}
		break;

	case 0xE:
		/* 1110xxxx 10xxxxxx 10xxxxxx */
		if (((ch2 = ptr[1]) & 0xC0) == 0x80)
		{
			if (((ch3 = ptr[2]) & 0xC0) == 0x80)
			{
				unsigned char high_four = ch & 0x0f;
				unsigned char mid_six = ch2 & 0x3f;
				unsigned char low_six = ch3 & 0x3f;
				result = (((high_four << 6) + mid_six) << 6) + low_six;
				length = 3;
			}
			else
			{
				length = 2;
			}
		}
		break;
	}						/* end of switch */

	*utfstring_ptr = (char *) (ptr + length);
	return result;
}
