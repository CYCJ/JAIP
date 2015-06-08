/* /////////////////////////////////////////////////////////////////// */
/*                                                                     */
/*   System Software of Dual-Core Java Runtime Environment             */
/*                                                                     */
/* ------------------------------------------------------------------- */
/*   File: file.c                                                      */
/*   Author: Chien-Fone Huang                                          */
/*   Date: Sep/2009                                                    */
/* ------------------------------------------------------------------- */
/*   Implement some function to open the Java class file and create    */
/*   Java Runtime image (.bin). Note that the file system is FAT16,    */
/*   so the .class must be renamed as .cls                             */
/*                                                                     */
/*   Copyright, 2009.                                                  */
/*   Multimedia Embedded Systems Lab.                                  */
/*   Department of Computer Science and Information engineering        */
/*   National Chiao Tung University, Hsinchu 300, Taiwan               */
/* ------------------------------------------------------------------- */
/*   MODIFICATIONS                                                     */
/*                                                                     */
/*   On Aug/5/2010 by Chun-Jen Tsai                                    */
/*   1. Each JAR file in the system class path directory is read only  */
/*      once upon boot time. Class search in the JAR file is done in   */
/*      memory.                                                        */
/*   2. Fix a bug that caused by declare a large array as a local      */
/*      variable, which corrupts the function call stack.              */
/*   3. Reformat the program using 'indent.'                           */
/* /////////////////////////////////////////////////////////////////// */
/* ------------------------------------------------------------------- */
/*   MODIFICATIONS                                                     */
/*   Author: Han-Wen Kuo                                               */
/*   Date: Aug/11/2009                                                 */
/*                                                                     */
/*   jar_load_class : modified the if equipment which identify the     */
/*                    main class for potential bug                     */
/* ------------------------------------------------------------------- */
/* /////////////////////////////////////////////////////////////////// */

#include <xparameters.h>
#include <string.h>
#include "../include/class_loader.h"
#include "../include/class_manager.h"
#include "../include/file.h"
#include "../include/class_mt_manager.h"
#include "../include/class_structure.h"
#include "../include/jpl.h"
#include "../include/mmes_jpl.h"
#include "../include/debug_option.h"

#include "xparameters.h"
//#define XPAR_CPU_PPC440_CORE_CLOCK_FREQ_HZ 100000000
extern volatile unsigned short *METHOD_AREA_PTR;

/* ------------------------------------------------------------------- */
/*                      Reading Buffer Declaration                     */
/* ------------------------------------------------------------------- */

// Extra data buffer for reading class
extern unsigned char classfile[MAX_BUFFER_SIZE];

unsigned int DDR_image_space_address = 0;
unsigned short global_num = 0;//, main_idx = -1;
unsigned int local_file_header = 0x04034b50;
int loading_times =0;

//added by ji-jing
unsigned short global_mthd_id = 1;
// modified by T.H.Wu , 2013.9.10
volatile uint8 lock_for_parser = 0xFF;
volatile uint8 core_wait_list [JAIP_CORE_NUM];

/* ------------------------------------------------------------------- */
/*               Open the class file (.jar) in CF card                 */
/* ------------------------------------------------------------------- */
int
read_little_endian(unsigned char *p, int nbytes)
{
    int value;

    if (nbytes == 2)
    {
        value = (p[1] << 8) + p[0];
    }
    else if (nbytes == 4)
    {
        value = (p[3] << 24) + (p[2] << 16) + (p[1] << 8) + p[0];
    }
    else
    {
        return p[0];
    }
    return value;
}


void init_temp_lock(){
	int i = 0;
	lock_for_parser = 0xFF;
	for(i=0; i<JAIP_CORE_NUM; i++){
		core_wait_list [i] = 0;
	}
}

void request_monitor_selfbuilt (uint8 core_id){
	if(lock_for_parser==0xFF){
		lock_for_parser = core_id;
	}
	else if(lock_for_parser==core_id){
	}
	else{
		core_wait_list[core_id] = 1;
		while( lock_for_parser!=core_id );
	}
}

void  release_monitor_selfbuilt(uint8 core_id){
	uint8 i ;
	for(i=0; i<JAIP_CORE_NUM; i++){
		if(core_wait_list[i]==1){
			break;
		}
	}
	if(i==JAIP_CORE_NUM){
		lock_for_parser = 0xFF;
	}
	else{
		core_wait_list[i] = 0;
		lock_for_parser = i;
	}
}

// modified by T.H.Wu , for multi-core JAIP use , 2013.9.9
//int jar_load_class(unsigned char *jar_image, unsigned long jar_size, char *target_class_name, int *IsClinit)
int jar_load_class(
		uint8 core_id, unsigned char *jar_image, unsigned long jar_size,
		char *target_class_name, int *IsClinit
	)
{
    char *  jar_class_name;
    int     header;
    int     class_size = 0;
    int     name_size = 0;
    char    temp[20];
    int     tmp, idx = 0, jdx = 0, zdx = 0;
    int     file_id = 0, numbyte = 0, start_addr = 0;
    unsigned int *address;
    unsigned int target_class_name_size, jar_ptr;
    char fieldname[80],methodname[80],desname[150];
#if parsingtime
    int     time_start, time_end;

    *JPL_CTRL_REG = 0x00000000;
    xil_printf("%s start cycles : %d \r\n", target_class_name, *JPL_TOTAL_TIME_REG);
    time_start = *JPL_TOTAL_TIME_REG;
    *JPL_CTRL_REG = 0x80000000;
#endif

#if view_jar
    view_memory((Xuint32 *) (jar_image+0x4dd30), 256);
    //view_memory((Xuint32 *) (0xb08ADFF8), 1024);
#endif

    target_class_name_size = (unsigned int)strlen(target_class_name);
    // Start searching from the beginning of the jar image
    jar_ptr = 0;
#if filedebug
    xil_printf("\r\njar_image addr: %x\r\n",jar_image);
    xil_printf("Try to load %s\r\n",target_class_name);
#endif
    while (1)
    {
        //xil_printf("parser debug 1 \r\n");
        if (jar_ptr >= jar_size)
        {
#if filedebug
            xil_printf("\r\nERROR: read beyond jar image size.\r\n");
#endif
            break;
        }
        //xil_printf("\r\njar_image + jar_ptr = %d \r\n",jar_image + jar_ptr);
        memcpy(&header, jar_image + jar_ptr, 4);
        jar_ptr += 4;

        //xil_printf("parser debug 2 \r\n");
        //xil_printf("header: %x  ,jar_ptr: %x\r\n",header,jar_ptr);
        if (header != 0x504B0304)
        {
#if filedebug
            xil_printf("File End \r\n");
#endif
            break;
        }

        //memcpy(&temp, jar_image + (jar_ptr += 14), 14);
        jar_ptr += 14;
        //memcpy(&temp, jar_image + jar_ptr, 4);
        class_size = read_little_endian(jar_image + jar_ptr, 4);
        jar_ptr += 4;

        //memcpy(&temp, jar_image + jar_ptr, 4);
        jar_ptr += 4;

        //memcpy(&temp, jar_image + jar_ptr, 2);
        
        name_size = read_little_endian(jar_image + jar_ptr, 2);
        jar_ptr += 2;

        //memcpy(&temp, jar_image + jar_ptr, 2);
        
        tmp = read_little_endian(jar_image + jar_ptr, 2);
        jar_ptr += 2;

        jar_class_name = jar_image + jar_ptr;
        jar_ptr += name_size;

        //memcpy(&temp, jar_image + jar_ptr, tmp);
        jar_ptr += tmp;

        //
        //        Update cross reference table
        //


        if ( class_size > 0 && target_class_name_size == name_size &&
            (strncmp(jar_class_name, target_class_name, name_size) == 0))
        {
#if filedebug
            xil_printf("%s found in jar.\r\n", target_class_name);
			xil_printf("and the jar_ptr is %x \r\n", jar_ptr);
#endif

	        // note by T.H.Wu , 2013.9.9
			for (idx = 0; idx < CNAME_SIZE; idx++)
            {
                x_ref_tbl[global_num].class_name[idx] = 0;
            }
			// find out this class's info has been construct or not
            // idx : this class's Global ID
            for(idx = 0; idx < global_num; idx++){
                if ((strncmp(x_ref_tbl[idx].class_name, target_class_name, name_size - 6) ==0)
                    && x_ref_tbl[idx].class_namel == name_size-6)
                    break;
            }

#if filedebug
            xil_printf("%s ",target_class_name);
            if(idx != global_num)
                xil_printf("has been found in x_ref_tbl.\r\n");
            else
                xil_printf("doesn't be found in x_ref_tbl.\r\n");
#endif


            // if this this class's info doesn't exist
            if(idx == global_num)
            {
#if filedebug
                xil_printf("And it's ");
                if(idx == 0)
                    xil_printf("a main class.\r\n");
                else
                    xil_printf("a parent class.\r\n");
#endif
                memcpy(x_ref_tbl[global_num].class_name,
                                                 target_class_name, name_size - 6);
                x_ref_tbl[global_num].class_namel = name_size - 6;
                
                x_ref_tbl[global_num].IsCache = 0;
                x_ref_tbl[global_num].base_address = 0;
                x_ref_tbl[global_num].image_size = 0;
                x_ref_tbl[global_num].parent_index = 999;
                x_ref_tbl[global_num].method_cnt = 0;
                x_ref_tbl[global_num].field_cnt = 0;
                x_ref_tbl[global_num].intf_cnt = 0;
                x_ref_tbl[global_num].obj_size = 1;

                //x_ref_tbl[global_num].base_address = get_starting_address();
                // Modify by G
                global_num ++;
                numbyte = Generate_New_Image(core_id, jar_image + jar_ptr, global_num - 1);
                *IsClinit = 0;
            }
            else if(x_ref_tbl[idx].IsCache == 0){
                // Modify by G
                //x_ref_tbl[idx].base_address = get_starting_address();
                numbyte = Generate_New_Image(core_id, jar_image + jar_ptr,idx);
                *IsClinit = 0;
            }
            else{
                *IsClinit = 1;
#if filedebug
                xil_printf(" * ");
#endif
            }

            //xil_printf("parser debug 3 : [%x] %s \r\n", idx, x_ref_tbl[idx].class_name);
            //xil_printf("parser debug 4 : %x \r\n", x_ref_tbl[idx].IsCache);
            break;
        }
        else
        {
            jar_ptr += class_size;
        }
    }

    //xil_printf("parser debug 5 : [%x] %s \r\n", idx, x_ref_tbl[idx].class_name);
    //xil_printf("parser debug 6 : %x \r\n", x_ref_tbl[idx].IsCache);

#if parsingtime
    *JPL_CTRL_REG = 0x00000000;
    //xil_printf("%s end cycles : %d \r\n", target_class_name, *JPL_TOTAL_TIME_REG);
    time_end = *JPL_TOTAL_TIME_REG;
    xil_printf("%s %d %d\r\n",target_class_name,class_size,time_end - time_start);
    *JPL_CTRL_REG = 0x80000000;
#endif

#if print_cross_ref_table_runtime
    xil_printf("\r\n====================================================\r\n");
    xil_printf("\r\n==              Cross Reference Table             ==\r\n");
    xil_printf("\r\n====================================================\r\n");

    for (tmp = 0; tmp < global_num; tmp++)
    {
        xil_printf("=Global Index : %d\r\n", tmp);
        xil_printf("=Class name   : %s\r\n", x_ref_tbl[tmp].class_name);
        xil_printf("=Parent Index : %d\r\n", x_ref_tbl[tmp].parent_index);
        xil_printf("=Base_addres  : %x\r\n", x_ref_tbl[tmp].base_address);
        xil_printf("=Image Size   : %x\r\n", numbyte);
        xil_printf("=Is Interface : %d\r\n", x_ref_tbl[tmp].isIntf);
        xil_printf("=Object Size  : %x\r\n", x_ref_tbl[tmp].obj_size);
        xil_printf("=Intf count   : %d\r\n", x_ref_tbl[tmp].intf_cnt);

        for (zdx = 0; zdx < x_ref_tbl[tmp].intf_cnt; zdx++)
        {
            xil_printf(" ==intface    : %16s\r\n",x_ref_tbl[x_ref_tbl[tmp].intf[zdx]].class_name);
        }

        xil_printf("=Method count : %d\r\n", x_ref_tbl[tmp].method_cnt);
        for (zdx = 0; zdx < x_ref_tbl[tmp].method_cnt; zdx++)
        {
            address = x_ref_tbl[tmp].method[zdx].method_offset;
            memcpy(methodname,x_ref_tbl[tmp].method[zdx].method_name,x_ref_tbl[tmp].method[zdx].method_namel);
            memcpy(methodname+x_ref_tbl[tmp].method[zdx].method_namel,"\0",1);
            memcpy(desname,x_ref_tbl[tmp].method[zdx].descript_name,x_ref_tbl[tmp].method[zdx].descript_namel);
            memcpy(desname+x_ref_tbl[tmp].method[zdx].descript_namel,"\0",1);
            xil_printf(" ==Method     : %16s    offset : %.8x - %.8x\r\n",
                methodname, x_ref_tbl[tmp].method[zdx].method_offset,
                *(address));
                  
            while(*address != 0xFFFFFFFF){
                xil_printf("%64.8x\r\n",*(address+1));
                if(*(address + 2) != 0xFFFFFFFF){
                    address = *(address + 2);
                    xil_printf("%64.8x\r\n",*(address));
                }
                else break;
            }

            xil_printf("   Descript   : %16s\r\n",desname);
        }
        
        xil_printf("=Field count  : %d\r\n", x_ref_tbl[tmp].field_cnt);
        xil_printf(" ==Non-Static Field count : %d\r\n", x_ref_tbl[tmp].obj_size - 1);
        xil_printf(" ==Static Field count     : %d\r\n", x_ref_tbl[tmp].field_cnt - (x_ref_tbl[tmp].obj_size - 1));
        for (zdx = 0; zdx < x_ref_tbl[tmp].field_cnt; zdx++)
        {
            memcpy(fieldname,x_ref_tbl[tmp].field[zdx].field_name,x_ref_tbl[tmp].field[zdx].field_namel);
            memcpy(fieldname+x_ref_tbl[tmp].field[zdx].field_namel,"\0",1);
            address =
                x_ref_tbl[tmp].field[zdx].field_address;
            xil_printf(" ==Field cls  :                            : %.8x\r\n",
                x_ref_tbl[tmp].field[zdx].cls_id);
            xil_printf(" ==Field tag  :                            : %.8x\r\n",
                x_ref_tbl[tmp].field[zdx].field_tag);
            xil_printf(" ==Field      : %16s    offset : %.8x - %.8x\r\n",
                fieldname,
                x_ref_tbl[tmp].field[zdx].field_address,
                *(address));
        }
        // xil_printf("=Field  count   :  %d\r\n", x_ref_tbl[tmp].field_cnt);
        xil_printf("====================================================\r\n");
    }

#endif

#if view_jar
    xil_printf("end jar_load_class()\r\n");
    view_memory((Xuint32 *) (jar_image+0x4dd30), 256);
    //view_memory((Xuint32 *) (0xb08ADFF8), 1024);
#endif

    return idx;
}

int
Generate_New_Image(uint8 core_id, char *classfile, int cls_gnum)
{
    int numbyte = 0, idx = 0, jdx = 0, ddx = 0; // number of bytes
    unsigned short address = 0;
    unsigned short initial_pc, initial_sp, initial_LVreg_valid;
    unsigned int cst_ptr;
	volatile uint * cls_info_table_ptr;
	
    unsigned int data;

    // profiling for all part through parser, added by T.H.Wu , 2013.8.15
    //int timer_profile_for_parser[4];
    //timer_profile_for_parser[0] = *JPL_TOTAL_TIME_REG;

    initialize_class_structure();

    // profiling for all part through parser, added by T.H.Wu , 2013.8.15
   // timer_profile_for_parser[1] = *JPL_TOTAL_TIME_REG;

    // parsing class file and saving runtime image information
    //cls_image.starting_addr = base_address ;
    //cls_image.nxt_cls_addr  = 0x0000 ;
    //printf("Generate Image Start Address %x \n",cls_image.starting_addr);
    parse_classfile(core_id,
    				classfile, &(cls_image.Parent_index),
                    &(cls_image.CPcount), cls_image.cp_toc,
                    cls_image.cp_data, &(cls_image.cp_nbytes),
                    cls_image.fd_idx_img2cls, cls_image.fd_data,
                    &(cls_image.fd_nbytes), cls_image.mt_idx_img2cls,
                    cls_image.mt_code, &(cls_image.mt_nbytes),
                    &(cls_image.main_pc), &(cls_image.clinit_offset),
                    cls_image.cls_name, &(cls_image.main_max_local),
                    cls_gnum);

    // profiling for all part through parser, added by T.H.Wu , 2013.8.15
    //timer_profile_for_parser[2] = *JPL_TOTAL_TIME_REG;


    x_ref_tbl[cls_gnum].IsCache = 1;
    // modified by C.C.Hsu , 2013.1 , added for updating class info table after parsing
    // modified by T.H.Wu , 2013.9.10 , for multi-core execution...
    for(idx=0; idx< JAIP_CORE_NUM; idx++){
    	cls_info_table_ptr = (volatile uint*)((CLS_INFO_TABLE_ADDRESS | ((idx)<<17))   + (cls_gnum << 3));
    	SET_BIT(cls_info_table_ptr, 31);
    	SET_VALUE(cls_info_table_ptr, 21, 16, x_ref_tbl[cls_gnum].obj_size);
    	SET_VALUE(cls_info_table_ptr, 15, 0, x_ref_tbl[cls_gnum].clinit_ID);
    }
	#if checking_cls_info_table
		xil_printf("checking cls info table ------------------------------\r\n");
		xil_printf("CLS_ID:%d\r\n", cls_gnum);
		xil_printf("enrty 1: %X\r\n", *(unsigned int*)cls_info_table_ptr);
		xil_printf("enrty 2: %X\r\n", *(unsigned int*)(cls_info_table_ptr+1));
		xil_printf("\r\n");
	#endif
    strcat(x_ref_tbl[cls_gnum].class_name,"\0");
    //printf("G: ",x_ref_tbl[cls_gnum].class_name);
    // Execute the <clinit>
    /* if ( cls_image.clinit_offset != 0 )
    {
        clinit_initializer(cls_image.cp_toc ,   cls_image.cp_data, cls_image.fd_data  ,
                           cls_image.mt_code, &(cls_image.clinit_offset)
                          );
    }*/

    numbyte = load_to_methodarea( cls_gnum );     // DDR
    address = 0;


    // profiling for all part through parser, added by T.H.Wu , 2013.8.15
    //timer_profile_for_parser[3] = *JPL_TOTAL_TIME_REG;
    //xil_printf("[parser profile] initialize_class_structure :%d \r\n", timer_profile_for_parser[1]-timer_profile_for_parser[0] );
    //xil_printf("[parser profile] parse_classfile :%d \r\n", timer_profile_for_parser[2]-timer_profile_for_parser[1] );
    //xil_printf("[parser profile] load_to_methodarea :%d \r\n", timer_profile_for_parser[3]-timer_profile_for_parser[2] );

    // write info to class manager at here because inheritance. modify by G
    // added by T.H.Wu , 2013.9.9 , for multi-core execution
    for(idx=0; idx< JAIP_CORE_NUM; idx++){
    	volatile uint *JPL_CST_LUT_REG_volatile = GET_CTRL_REG_MEM0ADDR(idx, JPL_CST_LUT_REG);
        *JPL_CST_LUT_REG_volatile = (((unsigned int) cls_gnum << 2) + 0) << 16 | 0xFFFF;
        // block index
        *JPL_CST_LUT_REG_volatile = (((unsigned int) cls_gnum << 2) + 1) << 16 |
                        ((x_ref_tbl[cls_gnum].base_address) << 1);
        //xil_printf("Mana %.8x\r\n", );
        *JPL_CST_LUT_REG_volatile = (((unsigned int) cls_gnum << 2) + 2) << 16 |
                        (x_ref_tbl[cls_gnum].cst_size );  //modified by zi-jing
                       // (x_ref_tbl[cls_gnum].image_size);  //image size

        *JPL_CST_LUT_REG_volatile = (((unsigned int) cls_gnum << 2) + 3) << 16 |
                           (x_ref_tbl[cls_gnum].parent_index);  //modified by zi-jing

        //xil_printf("Mana %.8x\r\n", );
        *JPL_CST_LUT_REG_volatile = 0xFFFF0000; // <= for fixing bug
    }

#if 0
#endif


#if print_testbench
    		xil_printf("cls_id: %4x\r\n",cls_gnum);
            xil_printf("addr data: %4x\r\n",(x_ref_tbl[cls_gnum].base_address) << 1);
            xil_printf("size data: %4x\r\n",x_ref_tbl[cls_gnum].cst_size);
#endif

    return numbyte;
}
