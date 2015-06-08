#include "../include/native_method.h"
#include "../include/class_mt_manager.h"
#include "../include/debug_option.h"
#include "../include/file.h"
#include "../include/mmes_jpl.h"
#include "../include/heap_manager.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <file.h>
#include <xparameters.h>
//#include <mmes_jpl.h>

#define clock_rate 625//625//833

unsigned int threadCount = 0;
volatile char swithThread = 0;
uint16 JavaLangString;       //need intial, it means class number of Java/Lang/String
unsigned int JavaLangStringBuffer = 0; //need intial, it means class number of Java/Lang/StringBuffer
char stringTemp[256];

//extern unsigned int CURRENT_HEAP_PTR;// = (unsigned int)heap;
extern unsigned char sys_jar_image[MAX_BUFFER_SIZE];
extern unsigned long  sys_jar_size;
extern unsigned int debug_number[1024] ;
unsigned int parameterSpace[8]; // for multi-anewarray use , at most 8 dimension
//unsigned int CURRENT_HEAP_PTR;

unsigned int recursive_new_array(unsigned char type, unsigned char number, unsigned char last_create_flag);
void Java_java_lang_StringBuffer_expandCapacity(unsigned int* stringBufferObj, unsigned int minimunCapacity);
void print_reg(unsigned int type,unsigned int num);
short utf2unicode(const char **utfstring_ptr);





void debug_array_print(unsigned int* reference){

    unsigned int length;
    unsigned int idx;
    unsigned int flag;

    length = *(reference - 1);
    flag = *(reference - 2);

    xil_printf("-- Print array data start --\r\n");
    xil_printf("Array length = %d\r\n",length);
    if ( (flag & 0xFC000000) == 0xC0000000 ){
        // array data is long type
        for (idx=0 ; idx< (length<<1) ; idx++){
            xil_printf("%x\r\n",reference[idx]);
        }
    }
    else if( (flag & 0xFC000000) == 0xA0000000 ){
        // array data is int type
        for (idx=0 ; idx< length ; idx++){
            xil_printf("%x\r\n",reference[idx]);
        }
    }
    else if( (flag & 0xFC000000) == 0x90000000 ){
        // array data is short type
        if((length & 0x00000001) != 0){
            length = (length>>1) + 1;
        }
        else length = length>>1;

        for (idx=0 ; idx< length ; idx++){
            xil_printf("%x\r\n",reference[idx]);
        }
    }
    else if( (flag & 0xFC000000) == 0x88000000 ){
        // array data is char | byte | boolean type
        if((length & 0x00000003) != 0){
            length = (length>>2) + 1;
        }
        else length = length>>2;
        for (idx=0 ; idx< length ; idx++){
            xil_printf("%x\r\n",reference[idx]);
        }
    }
    else if( (flag & 0xFC000000) == 0x24000000 ){
        // array data is array type
        for (idx=0 ; idx<length ; idx++){
            debug_array_print((unsigned int *)reference[idx]);
        }
    }
    else if( (flag & 0xFC000000) == 0x20000000 ){
        // array data is obj type
        for (idx=0 ; idx<length ; idx++){
            debug_obj_print((unsigned int *)reference[idx]);
        }
    }
    else{
        xil_printf("debug print array data type error!!\r\n");
    }
    xil_printf("-- Print array data end --\r\n");
}

void debug_obj_print(unsigned int* reference){
    unsigned short idx;
    unsigned short cls_num;
    unsigned int   offset;
    unsigned short field_tag;

    cls_num = reference[0];

    xil_printf("class num : %d\r\n",cls_num);
    for (idx = 0; idx < x_ref_tbl[cls_num].field_cnt; idx++)
    {
        offset = *((unsigned int *)x_ref_tbl[cls_num].field[idx].field_address);
        field_tag = x_ref_tbl[cls_num].field[idx].field_tag;
        
        if((field_tag & 0x0800)!=0x0800){
            // none static field
            if ( (field_tag & 0x000F) == 0x0006 ){
                // field data is long type
                xil_printf("Field data\r\n");
                xil_printf("long_1 : %x\r\n",reference[offset&0x0000FFFF]);
                xil_printf("long_2 : %x\r\n",reference[(offset&0x0000FFFF) + 1]);
            }
            else if( (field_tag & 0x000F) == 0x0004 ){
                // field data is boolean | byte | char |short |int type
                // because I consider alignment problem,
                // so all of these type allocate 4 byte space
                xil_printf("Field data\r\n");
                xil_printf("other primitive data : %d\r\n",reference[offset&0x0000FFFF]);
            }
            else if( (field_tag & 0x000F) == 0x0001 ){
                // field data is array type
                xil_printf("Field data\r\n");
                debug_array_print((unsigned int*)reference[offset&0x0000FFFF]);
            }
            else if( (field_tag & 0x000F) == 0x0000 ){
                // field data is obj type
                xil_printf("Field data\r\n");
                debug_obj_print((unsigned int*)reference[offset&0x0000FFFF]);
            }
        }
    }
}

// From KVM
static short* getSystemProperty(short * key){
    short* value = NULL;

    /*
     * Currently, we define properties simply by going
     * through a set of if statements.  If the number of
     * properties becomes any larger, we should really
     * use an internal hashtable for the key/value pairs.
     */

    if (strcmp(key, "\0\0m\0i\0c\0r\0o\0e\0d\0i\0t\0i\0o\0n\0.\0c\0o\0n\0f\0i\0g\0u\0r\0a\0t\0i\0o\0n") == 0) {
        /* Important: This value should reflect the */
        /* version of the CLDC Specification supported */
        /* -- not the version number of the implementation */
        value = "\0C\0L\0D\0C\0-\01\0.\01";
        goto done;
    }

    if (strcmp(key, "\0m\0i\0c\0r\0o\0e\0d\0i\0t\0i\0o\0n\0.\0p\0l\0a\0t\0f\0o\0r\0m") == 0) {
#ifdef PLATFORMNAME
        value = PLATFORMNAME;
#else
        value = "\0g\0e\0n\0e\0r\0i\0c";
#endif
        goto done;
    }

    if (strcmp(key, "\0m\0i\0c\0r\0o\0e\0d\0i\0t\0i\0o\0n\0.\0e\0n\0c\0o\0d\0i\0n\0g") == 0) {
        value = "\0I\0S\0O\0-\08\08\05\09\0-\01";
        goto done;
    }

    if (strcmp(key, "\0m\0i\0c\0r\0o\0e\0d\0i\0t\0i\0o\0n\0.\0p\0r\0o\0f\0i\0l\0e\0s") == 0) {
        value = "";
        goto done;
    }

done:
    return value;
}

unsigned int* copyArray(unsigned int* src_ref){
    unsigned int*  newArray;
    unsigned int length;
    unsigned int idx;
    unsigned int flag;

    length = *(src_ref - 1);
    flag = *(src_ref - 2);
    heap_align32();
    *(unsigned int*)CURRENT_HEAP_PTR = flag;
    CURRENT_HEAP_PTR +=4;
    *(unsigned int*)CURRENT_HEAP_PTR = length;
    CURRENT_HEAP_PTR +=4;
    newArray = (unsigned int*)CURRENT_HEAP_PTR;
    
    /*
    heap[mt_table_count++] = flag;
    heap[mt_table_count++] = length;
    newArray = &heap[mt_table_count];
    */

    if ( (flag & 0xFC000000) == 0xC0000000 ){
        // array data is long type
        CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<3);
        /*
        mt_table_count = mt_table_count + (length<<1);
        */
        memcpy(newArray, src_ref, length<<3);
    }
    else if( (flag & 0xFC000000) == 0xA0000000 ){
        // array data is int type
        CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<2);
        /*
        mt_table_count = mt_table_count + length;
        */
        memcpy(newArray, src_ref, length<<2);
    }
    else if( (flag & 0xFC000000) == 0x90000000 ){
        // array data is char | short type
        if((length & 0x00000001) != 0){
            CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + ((length<<1)&0xFFFFFFF8) + 4;
        }
        else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<1);        
        /*
        if((length & 0x00000001) != 0){
            mt_table_count = mt_table_count + (length>>1) + 1;
        }
        else mt_table_count = mt_table_count + (length>>1);
        */

        memcpy(newArray, src_ref, length<<1);
    }
    else if( (flag & 0xFC000000) == 0x88000000 ){
        // array data is byte | boolean type
        if((length & 0x00000003) != 0){
            CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length&0xFFFFFFF8) + 4;
        }
        else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + length;
        /*
        if((length & 0x00000003) != 0){
            mt_table_count = mt_table_count + (length>>2) + 1;
        }
        else mt_table_count = mt_table_count + (length>>2);
        */
        memcpy(newArray, src_ref, length);
    }
    else if( (flag & 0xFC000000) == 0x24000000 ){
        // array data is array type
        CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<2);
        /*
        mt_table_count = mt_table_count + length;
        */
        for (idx=0 ; idx<length ; idx++){
            newArray[idx] = (unsigned int)copyArray((unsigned int *)src_ref[idx]);
        }
    }
    else if( (flag & 0xFC000000) == 0x20000000 ){
        // array data is obj type
        CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (length<<2);
        /*
        mt_table_count = mt_table_count + length;
        */
        for (idx=0 ; idx<length ; idx++){
            newArray[idx] = (unsigned int)copyObj((unsigned int *)src_ref[idx]);
        }
    }
    else{
        xil_printf("array data type error!!\r\n");
    }
	heap_align32();
    return newArray;
}

unsigned int* copyObj(unsigned int* src_ref){

    unsigned short idx;
    unsigned short cls_num;
    unsigned int   offset;
    unsigned short field_tag;
    unsigned int*  newObj;
    heap_align32();
	
    newObj = (unsigned int*)CURRENT_HEAP_PTR;
    /*
    newObj = &heap[mt_table_count];
    */
    cls_num = src_ref[0];
    newObj[0] = cls_num;

#if nativedebug
    xil_printf("copy object address : %x\r\n",CURRENT_HEAP_PTR);
    /*
    xil_printf("copy object address : %x\r\n",&heap[mt_table_count]);
    */
    xil_printf("object size         : %x\r\n",x_ref_tbl[cls_num].obj_size);
#endif

    CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (x_ref_tbl[cls_num].obj_size<<2);
    heap_align32();
	
	/*
    mt_table_count = mt_table_count + x_ref_tbl[cls_num].obj_size;
    */

    for (idx = 0; idx < x_ref_tbl[cls_num].field_cnt; idx++)
    {
        offset = x_ref_tbl[cls_num].field[idx].field_address;
        field_tag = x_ref_tbl[cls_num].field[idx].field_tag;

        if((field_tag & 0x0800)!=0x0800){
            // none static field
            
            // none static field
            if ( (field_tag & 0x000F) == 0x0006 ){
                // field data is long type
                newObj[offset&0x0000FFFF] = src_ref[offset&0x0000FFFF];
                newObj[(offset&0x0000FFFF)+1] = src_ref[(offset&0x0000FFFF)+1];
#if nativedebug
                xil_printf("copy long field data\r\n");
                xil_printf("content : %x\r\n",newObj[offset&0x0000FFFF]);
                xil_printf("content : %x\r\n",newObj[(offset&0x0000FFFF)+1]);
#endif
            }
            else if( (field_tag&0x000F) == 0x0004 ){
                // field data is boolean | byte | char |short |int type
                // because I consider alignment problem,
                // so all of these type allocate 4 byte space
                newObj[offset&0x0000FFFF] = src_ref[offset&0x0000FFFF];
#if nativedebug
                xil_printf("copy other primitive field data\r\n");
                xil_printf("content : %x\r\n",newObj[offset&0x0000FFFF]);
#endif
            }
            else if( (field_tag&0x000F) == 0x0001 ){
                // field data is array type
                newObj[offset&0x0000FFFF] = (unsigned int)
                    ((unsigned int*)src_ref[offset&0x0000FFFF]);
#if nativedebug
                xil_printf("copy array field data\r\n");
                xil_printf("content : %x\r\n",newObj[offset&0x0000FFFF]);
#endif
            }
            else if( (field_tag & 0x000F) == 0x0000 ){
                // field data is obj type
                newObj[offset&0x0000FFFF] = (unsigned int)copyObj
                    ((unsigned int*)src_ref[offset&0x0000FFFF]);
#if nativedebug
                xil_printf("copy object field data\r\n");
                xil_printf("content : %x\r\n",newObj[offset&0x0000FFFF]);
#endif
            }
            else{
                xil_printf("field data type error!!\r\n");
            }
        }
    }

    return newObj;
}


// Native function prototypes
void Java_java_lang_Object_getClass(uint8 core_id){
    //*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = *(unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
	cache_WB_flush (0);
	char IsClinit = 0;
	//unsigned int obj_cls_id = *(unsigned int*)(*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
	unsigned int obj_cls_id =  *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) ;
	unsigned int javaLangClassID = jar_load_class(core_id, sys_jar_image,sys_jar_size,
										"java\/lang\/Class.class",&IsClinit);
	
	heap_align32();
	//*JPL_TOS_C = CURRENT_HEAP_PTR;
	// note by T.H.Wu, 2013.9.9
	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = CURRENT_HEAP_PTR;
	*(unsigned int *)CURRENT_HEAP_PTR = javaLangClassID;
	*(unsigned int *)(CURRENT_HEAP_PTR + 4) = obj_cls_id;
	CURRENT_HEAP_PTR +=8;
	heap_align32();
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Object_getClass!!\r\n");
#endif
}
void Java_java_lang_Object_hashCode0(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Object_hashCode0!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_System_identityHashCode(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_System_identityHashCode!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Object_notify(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Object_notify!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Object_notifyAll(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Object_notifyAll!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Object_wait(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Object_wait!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_isInterface(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_isInterface!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_isPrimitive(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_isPrimitive!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_forName(uint8 core_id){
    // String Object structure [0]class, [1]value, [2]offset, [3]count

    unsigned int* stringObj;
    unsigned int idx;
    char IsClinit = 0;
    int i;
    unsigned int* newObj;
    cache_WB_flush (0);

    unsigned int javaLangClassID = 0;

    javaLangClassID = jar_load_class(core_id, sys_jar_image,sys_jar_size,
    									"java/lang/Class.class",&IsClinit);

    stringObj = (unsigned int *)(*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
    //memcpy(stringTemp, (short*)stringObj[1] + stringObj[2], stringObj[3]);
    for(i = stringObj[2]; i < stringObj[3]; ++ i){
    	stringTemp[i] = *((char *)stringObj[1] + i * 2 + 1);
    }

    for(idx=0 ; idx<stringObj[3]; idx++){
        if(stringTemp[idx] == '.') stringTemp[idx] = '/';
    }
    memcpy (&stringTemp[idx],".class",7);

    //cls_num = jar_load_class(core_id, NULL,0,stringTemp,&IsClinit);
	heap_align32();
    newObj = CURRENT_HEAP_PTR;
    CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + 8;
	heap_align32();

    //xil_printf("I'm at Class_forName. \r\n");
    //xil_printf("javaLangClassID: %x \r\n", javaLangClassID);
    *newObj = javaLangClassID;
    *(newObj + 1) = jar_load_class(core_id, sys_jar_image,sys_jar_size,stringTemp,&IsClinit);
    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = newObj;
    //xil_printf("stringTemp: %s\r\n", stringTemp);
    /*if (IsClinit == 0){
        *JPL_SERVICE_ARG1 = x_ref_tbl[cls_num].clinit_offset;
    }
    else *JPL_SERVICE_ARG1 = 0x0000ffff;*/

	// for debug, 2014.3.17
    //xil_printf("stringObj: %x \r\n", stringObj);
    //xil_printf("stringTemp: %s \r\n", stringTemp);
    //xil_printf("newObj: %x \r\n", newObj);
    //xil_printf("*newObj: %x \r\n", *newObj);
    //xil_printf("*(newObj + 1): %x \r\n", *(newObj + 1));
    //xil_printf("CURRENT_HEAP_PTR: %x \r\n\r\n", CURRENT_HEAP_PTR);

#if nativedebug
    xil_printf("Parse %s\r\n",stringTemp);
    xil_printf("Parse cls num   : %x\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
    xil_printf("<clinit> offset : %x\r\n",*JPL_SERVICE_ARG1);
    xil_printf("Invoke native moethod Java_java_lang_Class_forName!!\r\n");
#endif
}
void Java_java_lang_Class_newInstance(uint8 core_id){
    unsigned int cls_num;
    unsigned short idx;

    cls_num = *(unsigned int*)(*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) + 4);
	heap_align32();


    *(unsigned int*)CURRENT_HEAP_PTR = cls_num;
    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = CURRENT_HEAP_PTR;
    CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (x_ref_tbl[cls_num].obj_size<<2);
	heap_align32();
    /*
    heap[mt_table_count] = cls_num;
    parameterSpace[0] = (int)&heap[mt_table_count];
    mt_table_count = mt_table_count + x_ref_tbl[cls_num].obj_size;
    */
    
    if ( x_ref_tbl[cls_num].init_offset == 0){
        for(idx=0 ; idx<x_ref_tbl[cls_num].method_cnt ; idx++){
            if (x_ref_tbl[cls_num].method[idx].method_namel == 6
                && x_ref_tbl[cls_num].method[idx].descript_namel == 3
                && !(strncmp((char*)x_ref_tbl[cls_num].method[idx].method_name,(char*)"<init>",6))
                && !(strncmp((char*)x_ref_tbl[cls_num].method[idx].descript_name,(char*)"()V",3))){
                break;
            }
        }
        x_ref_tbl[cls_num].init_offset = x_ref_tbl[cls_num].method[idx].method_offset;
    }

    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1) = x_ref_tbl[cls_num].init_offset;
    //xil_printf("<Java_java_lang_Class_newInstance: %X>\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
#if nativedebug
    xil_printf("New class num : %x\r\n",cls_num);
    xil_printf("heap sapce    : %x\r\n",CURRENT_HEAP_PTR);
    /*
    xil_printf("heap sapce    : %x\r\n",heap);
    */
    xil_printf("Obj ref       : %x\r\n",*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));
    xil_printf("Obj size      : %x\r\n",x_ref_tbl[cls_num].obj_size);
    xil_printf("<init> offset : %x\r\n",*JPL_SERVICE_ARG1);
    xil_printf("Invoke native moethod Java_java_lang_Class_newInstance!!\r\n");
#endif
}
void Java_java_lang_Class_getName(uint8 core_id){
	unsigned int cls_num = *(unsigned int *)(*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) + 4);
	unsigned int cls_namel =  x_ref_tbl[cls_num].class_namel;
	unsigned int i;
	
	heap_align32();
	
	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = CURRENT_HEAP_PTR;

	*(unsigned int*)CURRENT_HEAP_PTR = JavaLangString;
    CURRENT_HEAP_PTR+=4;
    *(unsigned int*)CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + 20;
    CURRENT_HEAP_PTR+=4;
    *(unsigned int*)CURRENT_HEAP_PTR = 0;
    CURRENT_HEAP_PTR+=4;
    *(unsigned int*)CURRENT_HEAP_PTR = cls_namel;
    CURRENT_HEAP_PTR+=4;
    *(unsigned int*)CURRENT_HEAP_PTR = 0x50000000;
    CURRENT_HEAP_PTR+=4;
    *(unsigned int*)CURRENT_HEAP_PTR = cls_namel;
    CURRENT_HEAP_PTR+=4;

    unsigned char * utf8_ptr = x_ref_tbl[cls_num].class_name;

	for(i = 0; i < cls_namel;i++){
		((unsigned short *)CURRENT_HEAP_PTR)[i] = utf2unicode(&utf8_ptr);
	}

    if((cls_namel & 0x00000001) != 0){
        CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + ((cls_namel<<1)&0xFFFFFFFC) + 4;
    }
    else CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + (cls_namel<<1);

	heap_align32();
    xil_printf("getName result: %X\r\n", *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C));

#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_getName!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_isInstance(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_isInstance!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_isArray(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_isArray!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_isAssignableFrom(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_isAssignableFrom!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_getPrimitiveClass(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_getPrimitiveClass!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_exists(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_exists!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Class_getResourceAsStream0(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Class_getResourceAsStream0!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_activeCount(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_activeCount!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_currentThread(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_currentThread!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_yield(uint8 core_id){
    if (threadCount > 1) swithThread = 1;

#if nativedebug
    xil_printf("swith thread flag is %d\r\n",swithThread);
    xil_printf("Invoke native moethod Java_java_lang_Thread_yield!!\r\n");
#endif
}
void Java_java_lang_Thread_sleep(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_sleep!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_start(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_start!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_isAlive(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_isAlive!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_setPriority0(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_setPriority0!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_setPriority(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_setPriority!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_interrupt0(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_interrupt0!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Thread_interrupt(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Thread_interrupt!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Throwable_fillInStackTrace(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Throwable_fillInStackTrace!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Throwable_printStackTrace0(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Throwable_printStackTrace0!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Runtime_exitInternal(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Runtime_exitInternal!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Runtime_freeMemory(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Runtime_freeMemory!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Runtime_totalMemory(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Runtime_totalMemory!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_Runtime_gc(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Runtime_gc!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_System_arraycopy (uint8 core_id){
    int  length = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A);
    int  dstPos = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B);
    unsigned int* dst    = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    int  srcPos = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG2);
    unsigned int* src    = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_SERVICE_ARG1);

    int idx;
    int srcLength;
    int dstLength;
    int srcEnd;
    int dstEnd;
    unsigned int srcFlag;
    unsigned int dstFlag;

    srcLength = (int)*(src-1);
    dstLength = (int)*(dst-1);
    srcFlag   = *(src-2);
    dstFlag   = *(dst-2);
    srcEnd    = srcPos + length;
    dstEnd    = dstPos + length;
#if Chia_Che_Hsu_Debug
    printf("java_lang_System_arraycopy dst: %X\n", (unsigned int)dst);
    printf("java_lang_System_arraycopy dstPos: %d\n", dstPos);
    printf("java_lang_System_arraycopy src: %X\n", (unsigned int)src);
    printf("java_lang_System_arraycopy srcPos: %d\n", srcPos);
#endif
    if ((src == NULL) || (dst == NULL)) {
        xil_printf("NullPointerException\r\n");
        return;
    }

    if (srcFlag != dstFlag){
        // check the two arrays are same type
    	// change the type of char from 0x90000000 to 0x50000000 (modified by C.C. Hsu on 2013/1/15)
    	// The type of short is still 0x90000000
        xil_printf("ArrayStoreException\r\n");
        xil_printf("srcFlag: %X\r\n", srcFlag);
        xil_printf("src: %X\r\n", src);
        xil_printf("dstFlag: %X\r\n", dstFlag);
        xil_printf("dst: %X\r\n\r\n", dst);
        return;
    }

    if (     (length < 0) || (srcPos < 0) || (dstPos < 0)
          || (length > 0 && (srcEnd < 0 || dstEnd < 0))
          || (srcEnd > srcLength)
          || (dstEnd > dstLength)) {
#if nativedebug
        xil_printf("src : %x\r\n",length);
        xil_printf("dst : %x\r\n",srcPos);
        xil_printf("length : %d\r\n",length);
        xil_printf("srcPos : %d\r\n",srcPos);
        xil_printf("dstPos : %d\r\n",dstPos);
        xil_printf("srcEnd : %d\r\n",srcEnd);
        xil_printf("dstEnd : %d\r\n",dstEnd);
        xil_printf("srcLength : %d\r\n",srcLength);
        xil_printf("dstLength : %d\r\n",dstLength);
#endif
        xil_printf("ArrayIndexOutOfBoundsException\r\n");
        xil_printf("src : %X\r\n",src);
        xil_printf("dst : %X\r\n",dst);
        xil_printf("length : %X\r\n",length);
        xil_printf("srcPos : %X\r\n",srcPos);
        xil_printf("dstPos : %X\r\n",dstPos);
        xil_printf("srcEnd : %X\r\n",srcEnd);
        xil_printf("dstEnd : %X\r\n",dstEnd);
        xil_printf("srcLength : %X\r\n",srcLength);
        xil_printf("dstLength : %X\r\n",dstLength);
        return;
    }

    if ( (srcFlag & 0xFC000000) == 0xC0000000 ){
        // array data is long type
        memcpy((unsigned char *)dst+(dstPos<<3), (unsigned char *)src+(srcPos<<3), length<<3);
    }
    else if( (srcFlag & 0xFC000000) == 0xA0000000 ){
        // array data is int type
        memcpy((unsigned char *)dst+(dstPos<<2), (unsigned char *)src+(srcPos<<2), length<<2);
    }
    else if( ((srcFlag & 0xFC000000) == 0x90000000) || ((srcFlag & 0xFC000000) == 0x50000000)){
        // array data is char | short type
        memcpy((unsigned short *)dst + dstPos, (unsigned short *)src + srcPos, length<<1);
    }
    else if( (srcFlag & 0xFC000000) == 0x88000000 ){
        // array data is byte | boolean type
        memcpy((unsigned char *)dst+dstPos, (unsigned char *)src+srcPos, length);
    }
    else if( (srcFlag & 0xFC000000) == 0x24000000 ){
        // array data is array type
        for (idx=0 ; idx<length ; idx++){
            // waste memory, because always allocate new memory space(need modify)
            dst[dstPos+idx] = (unsigned int)copyArray((unsigned int *)src[srcPos+idx]);
        }
    }
    else if( (srcFlag & 0xFC000000) == 0x20000000 ){
        // array data is obj type
        for (idx=0 ; idx<length ; idx++){
            // waste memory, because always allocate new memory space(need modify)
            dst[dstPos+idx] = (unsigned int)copyObj((unsigned int *)src[srcPos+idx]);
        }
    }
    else{
        xil_printf("array data type error!!\r\n");
        xil_printf("srcFlag: %X\r\n", srcFlag);
    }

#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_System_arraycopy!!\r\n");
#endif
}
void Java_java_lang_System_currentTimeMillis(uint8 core_id){
   // *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = (*JPL_TOTAL_TIME_REG / (clock_rate*100));
	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = (*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOTAL_TIME_REG))/83333  ;
	  //*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = 0x123FF321;
#if nativedebug
    xil_printf("Already implement!! (But it can't be used on PC)\r\n");
    xil_printf("Invoke native moethod Java_java_lang_System_currentTimeMillis!!\r\n");
#endif
}

void Java_java_lang_System_currentTimeMillisHW(uint8 core_id){
   // *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = (*JPL_TOTAL_TIME_REG / (clock_rate*100));
	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_NONINTRPT_TIME_REG);
	  //*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = 0x123FF321;
#if nativedebug
    xil_printf("Already implement!! (But it can't be used on PC)\r\n");
    xil_printf("Invoke native moethod Java_java_lang_System_currentTimeMillisHW!!\r\n");
#endif
}

void Java_java_lang_System_currentTimeMillisINTRPT(uint8 core_id){
   // *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = (*JPL_TOTAL_TIME_REG / (clock_rate*100));
	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_INTRPT_TIME_REG);
	  //*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = 0x123FF321;
#if nativedebug
    xil_printf("Already implement!! (But it can't be used on PC)\r\n");
    xil_printf("Invoke native moethod Java_java_lang_System_currentTimeMillisINTRPT!!\r\n");
#endif
}

void Java_java_lang_System_getProperty0(uint8 core_id){

    // String Object structure [0]class, [1]value, [2]offset, [3]count
    unsigned int* stringObj;
    unsigned int* resultObj = NULL;
    unsigned short* value;
    int IsClinit = 0;
    int newCount = 0;
    unsigned short* newCharArray;

    stringObj = (unsigned int *)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);

    // because when system new a char array, no '\0' in the end
    // just fit the size
    
    if(JavaLangString==0){
        JavaLangString = jar_load_class(core_id, sys_jar_image, sys_jar_size,
        						(char *) "java\/lang\/String.class", &IsClinit);
    }
    
    if(!memcmp(stringObj[1], "\0m\0i\0c\0r\0o\0e\0d\0i\0t\0i\0o\0n\0.\0c\0o\0n\0f\0i\0g\0u\0r\0a\0t\0i\0o\0n", stringObj[3]*2)){

    		newCount = 8;
    		parameterSpace[0] = newCount;
    		newCharArray = recursive_new_array(5, 0, 1);
    		newCharArray[0] = 0x0043;
    		newCharArray[1] = 0x004C;
    		newCharArray[2] = 0x0044;
    		newCharArray[3] = 0x0043;
    		newCharArray[4] = 0x002D;
    		newCharArray[5] = 0x0031;
    		newCharArray[6] = 0x002E;
    		newCharArray[7] = 0x0031;
	}
    else if (!memcmp(stringObj[1], "\0m\0i\0c\0r\0o\0e\0d\0i\0t\0i\0o\0n\0.\0p\0l\0a\0t\0f\0o\0r\0m", stringObj[3]*2)){
            newCount = 7;
            parameterSpace[0] = newCount;
            newCharArray = recursive_new_array(5, 0, 1);
            newCharArray[0] = 0x0067;
            newCharArray[1] = 0x0065;
            newCharArray[2] = 0x006E;
            newCharArray[3] = 0x0065;
            newCharArray[4] = 0x0072;
            newCharArray[5] = 0x0069;
            newCharArray[6] = 0x0063;
    }
    else if (!memcmp(stringObj[1], "\0m\0i\0c\0r\0o\0e\0d\0i\0t\0i\0o\0n\0.\0e\0n\0c\0o\0d\0i\0n\0g", stringObj[3]*2)){
            newCount = 10;
            parameterSpace[0] = newCount;
            newCharArray = recursive_new_array(5, 0, 1);
            newCharArray[0] = 0x0049;
            newCharArray[1] = 0x0053;
            newCharArray[2] = 0x004F;
            newCharArray[3] = 0x002D;
            newCharArray[4] = 0x0038;
            newCharArray[5] = 0x0038;
            newCharArray[6] = 0x0035;
            newCharArray[7] = 0x0039;
            newCharArray[8] = 0x002D;
            newCharArray[9] = 0x0031;
    }
    else if (!memcmp(stringObj[1], "\0m\0i\0c\0r\0o\0e\0d\0i\0t\0i\0o\0n\0.\0p\0r\0o\0f\0i\0l\0e\0s", stringObj[3]*2)){
            newCount = 3;
            parameterSpace[0] = newCount;
            newCharArray = recursive_new_array(5, 0, 1);
            newCharArray[0] = 0x0050;
            newCharArray[1] = 0x0042;
            newCharArray[2] = 0x0050;
    }
    else
    {
    	newCharArray = 0;
    	newCount = 0;
    	*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = 0x00000000;
    	return;
    }

    heap_align32();
    resultObj = (unsigned int*)CURRENT_HEAP_PTR;
    CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + 16;
	heap_align32();

    resultObj[0] = JavaLangString;
    resultObj[1] = newCharArray;
    resultObj[2] = 0;
    resultObj[3] = newCount;

    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = (int)resultObj;

#if nativedebug
    xil_printf("Obj reference  : %x\r\n",resultObj);
    xil_printf("Property value : %s\r\n",value);
    xil_printf("Invoke native moethod Java_java_lang_System_getProperty0!!\r\n");
#endif
}
void Java_java_lang_System_getProperty(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_System_getProperty!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_String_charAt(uint8 core_id){

    int index;
    unsigned int this_length;
    unsigned int* thisObj;
    short* data;
    short result;
    
    cache_WB_flush (0);
    index = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B);
    thisObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    this_length = thisObj[3];

    if (index < 0 || index >= this_length) {
        xil_printf("StringIndexOutOfBoundsException!!\r\n");
    } else {
        data = (short*)thisObj[1];
        result = data[thisObj[2] + index];
        *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = (unsigned int)result;
    }
#if Chia_Che_Hsu_Debug
    printf("charAt debug1:%X\n", data[thisObj[2] + index]);
    printf("charAt debug2:%X\n", data[thisObj[2] + index + 1]);
    printf("charAt result:%X\n", (unsigned int)result);
#endif
    
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_String_charAt!!\r\n");
#endif
}
void Java_java_lang_String_equals(uint8 core_id){
    // String Object structure [0]class, [1]value, [2]offset, [3]count
    unsigned int* thisObj;
    unsigned int* otherObj;
    int result = 0;
    int IsClinit = 0;

    cache_WB_flush (0);
    otherObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B);
    thisObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    
    if(JavaLangString==0){
        JavaLangString = jar_load_class(core_id, sys_jar_image, sys_jar_size, (char *) "java\/lang\/String.class", &IsClinit);
    }
    
    if(thisObj == otherObj) result = 1;
    else if(otherObj != NULL && otherObj[0] == JavaLangString){
        if (thisObj[3] == otherObj[3]) {
            /* Both objects must have the same length */
            if (0 == memcmp((short*)thisObj[1] + thisObj[2],
                            (short*)otherObj[1] + otherObj[2],
                            thisObj[3])){
                /* Both objects must have the same characters */
                result = 1;
            }
        }
    }
    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = (unsigned int)result;

#if nativedebug
    xil_printf("Is equal : %d\r\n",result);
    xil_printf("Invoke native moethod Java_java_lang_String_equals!!\r\n");
#endif
}

void string_indexOf(uint8 core_id , int fromIndex){

    int ch;
    unsigned int* thisObj;
    int result;
    int i;
    short* data;
    
    ch = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B);
    thisObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    result = -1;
    
    if (fromIndex < thisObj[3]) {
        data = (short*)thisObj[1];
        /* Max is the largest position in the underlying char array */
        long max = thisObj[2] + thisObj[3];
        for (i = thisObj[2] + fromIndex; i < max; i++) {
            if (data[i] == ch) {
                result = i - thisObj[2];
                break;
            }
        }
    }
    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = result;
}


void Java_java_lang_String_indexOf__I(uint8 core_id){

    string_indexOf(core_id,0);
    
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_String_indexOf__I!!\r\n");
#endif
}
void Java_java_lang_String_indexOf__II(uint8 core_id){

    int fromIndex;
    fromIndex = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_A);
//    parameterSpace[0] = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B);
//    parameterSpace[1] = *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    
    if (fromIndex < 0) {
        fromIndex = 0;
    }
    string_indexOf(core_id,fromIndex);

#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_String_indexOf__II!!\r\n");
#endif
}


int unicode2utfstrlen(unsigned short *unistring, int unilength){

    int result_length = 0;
    
    for (; unilength > 0; unistring++, unilength--) {
        unsigned short ch = *unistring;
        if ((ch != 0) && (ch <= 0x7f)) /* 1 byte */
            result_length++;
        else if (ch <= 0x7FF)
            result_length += 2;        /* 2 byte character */
        else 
            result_length += 3;        /* 3 byte character */
    }
    return result_length;
}

char *unicode2utf(unsigned short *unistring, int length, char *buffer, int buflength)
{
    int i;
    unsigned short *uniptr;
    char *bufptr;
    unsigned bufleft;

    bufleft = buflength - 1; /* take note of null now! */

    for (i = length, uniptr = unistring, bufptr = buffer; --i >= 0; uniptr++) {
        unsigned short ch = *uniptr;
        if ((ch != 0) && (ch <=0x7f)) {
            if ((int)(--bufleft) < 0)     /* no space for character */
                break;
            *bufptr++ = (char)ch;
        } else if (ch <= 0x7FF) { 
            /* 11 bits or less. */
            unsigned char high_five = ch >> 6;
            unsigned char low_six = ch & 0x3F;
            if ((int)(bufleft -= 2) < 0)  /* no space for character */
                break;
            *bufptr++ = high_five | 0xC0; /* 110xxxxx */
            *bufptr++ = low_six | 0x80;   /* 10xxxxxx */
        } else {
            /* possibly full 16 bits. */
            char high_four = ch >> 12;
            char mid_six = (ch >> 6) & 0x3F;
            char low_six = ch & 0x3f;
            if ((int)(bufleft -= 3) < 0) /* no space for character */
                break;
            *bufptr++ = high_four | 0xE0; /* 1110xxxx */
            *bufptr++ = mid_six | 0x80;   /* 10xxxxxx */
            *bufptr++ = low_six | 0x80;   /* 10xxxxxx*/
        }
    }
    *bufptr = 0;
    return buffer;
}
 

void Java_java_lang_String_intern(uint8 core_id){

    unsigned int* thisObj;
    unsigned int* resultObj;
    int this_offset;
    int this_length;
    int utflen;
    
    thisObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    this_offset = thisObj[2];
    this_length = thisObj[3];
    


#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_String_intern!!\r\n");
#endif
}
void Java_java_lang_StringBuffer_append__I(uint8 core_id){	//not verified
	int i;
    unsigned int value;
    unsigned int* thisObj;
    unsigned int count, newCount, stringLength;
    char buffer[20];

    value = *(unsigned int *)GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B);
    thisObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    sprintf(buffer, "%d", value);
    count = thisObj[2];
    stringLength = strlen(buffer);
    newCount = count + stringLength * 2;
    char * utf8_ptr = buffer;
    short utf16_buffer[40];
    for(i = 0; i < stringLength; i++){
    	utf16_buffer[i] = utf2unicode(&utf8_ptr);
    }
#if nativedebug
    xil_printf("value        = %ld\r\n",value);
    xil_printf("value length = %ld\r\n",stringLength);
    xil_printf("newCount     = %ld\r\n",newCount);
#endif
    if(newCount > count){
        Java_java_lang_StringBuffer_expandCapacity(thisObj, newCount);
    }
    if(newCount <= *((unsigned int *)thisObj[1] - 1)){
    	memcpy((unsigned short*)thisObj[1] + thisObj[2], utf16_buffer, stringLength * 2);
    	thisObj[2] = newCount;
    }
    else{
    	printf("OutOfMemoryException in <Java_java_lang_StringBuffer_append__Ljava_lang_String_2>\n");
    	printf("capacity: %u\n", *((unsigned int *)thisObj[1] - 1));
    	printf("required size: %u\n", newCount);
    	printf("array ref:%X\n", thisObj[1]);
    	printf("CURRENT_HEAP_PTR:%X\n", CURRENT_HEAP_PTR);
    	//system("pause");	//pause not work
    }
#if nativedebug
    debug_obj_print(thisObj);
    xil_printf("Invoke native moethod Java_java_lang_StringBuffer_append__I!!\r\n");
#endif

}
void Java_java_lang_StringBuffer_append__Ljava_lang_String_2(uint8 core_id){
    // String Object structure [0]class, [1]value, [2]offset, [3]count
    // StringBuffer Object structure [0]class, [1]value, [2]count, [3]shared
    unsigned int* thisObj;
    unsigned int* otherObj;
    
    otherObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B); // String
    thisObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);  // StringBuffer

#if Chia_Che_Hsu_Debug
    printf("Java_java_lang_StringBuffer_append__Ljava_lang_String_2 start\n");
    printf("otherObj:%X\n", otherObj);
    printf("thisObj:%X\n", thisObj);
#endif

    if(otherObj == NULL){
		heap_align32();
    	otherObj = CURRENT_HEAP_PTR;
    	CURRENT_HEAP_PTR = CURRENT_HEAP_PTR + 16;
		heap_align32();
    	otherObj[0] = JavaLangString;
    	parameterSpace[0] = 4;
    	otherObj[1] = (unsigned int *)recursive_new_array(5, 0, 1);
    	*(unsigned short *)otherObj[1] = 0x006E;
    	*((unsigned short *)otherObj[1] + 1) = 0x0075;
    	*((unsigned short *)otherObj[1] + 2) = 0x006C;
    	*((unsigned short *)otherObj[1] + 3) = 0x006C;

    	otherObj[2] = 0;
    	otherObj[3] = 4;
    }

    unsigned int newCount = thisObj[2] + otherObj[3];

    if(newCount > *((unsigned int *)thisObj[1] - 1)){
    	Java_java_lang_StringBuffer_expandCapacity(thisObj, newCount);
    }
    if(newCount <= *((unsigned int *)thisObj[1] - 1)){
    	memcpy((unsigned short*)thisObj[1] + thisObj[2], otherObj[1], otherObj[3]*2);
    	thisObj[2] = newCount;
    }
    else{
    	printf("OutOfMemoryException in <Java_java_lang_StringBuffer_append__Ljava_lang_String_2>\n");
    	printf("capacity: %u\n", *((unsigned int *)thisObj[1] - 1));
    	printf("required size: %u\n", newCount);
    	printf("array ref:%X\n", thisObj[1]);
    	printf("CURRENT_HEAP_PTR:%X\n", CURRENT_HEAP_PTR);
    	//system("pause");	//pause not work
    }
}

void Java_java_lang_StringBuffer_expandCapacity(unsigned int* stringBufferObj, unsigned int minimunCapacity){
	unsigned int oldCapacity = *((unsigned int *)stringBufferObj[1] - 1);
	unsigned int newCapacity = (oldCapacity + 1) * 2;
#if Chia_Che_Hsu_Debug
    printf("Java_java_lang_StringBuffer_expandCapacity start\n");
    printf("stringBufferObj:%X\n", stringBufferObj);
    printf("minimunCapacity:%X\n", minimunCapacity);
#endif

	if(minimunCapacity > newCapacity)
		newCapacity = minimunCapacity;
	parameterSpace[0] = newCapacity;

	unsigned int* newValue = (unsigned int *)recursive_new_array(5, 0, 1);
	memcpy((unsigned short*)newValue, (unsigned short*)stringBufferObj[1], newCapacity);
	stringBufferObj[1] = (unsigned int)newValue;
	stringBufferObj[3] = 0;
}

void Java_java_lang_StringBuffer_toString(uint8 core_id){
    // String Object structure [0]class, [1]value, [2]offset, [3]count
    // StringBuffer Object structure [0]class, [1]value, [2]count, [3]shared
    unsigned int* thisObj;
    unsigned int* newObj;
    unsigned int count;
    int IsClinit = 0;

    if(JavaLangString==0){
        JavaLangString = jar_load_class(core_id, sys_jar_image, sys_jar_size, (char *) "java\/lang\/String.class", &IsClinit);
    }
    
	#if Chia_Che_Hsu_Debug
		printf("Java_java_lang_StringBuffer_toString start\n");
		printf("thisObj:%X\n", thisObj);
		printf("newObj:%X\n", newObj);
	#endif

    thisObj = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);
    thisObj[3] = 1;   //StringBuffer.setShared()
    count = thisObj[2];
	heap_align32();
    newObj = (unsigned int *)CURRENT_HEAP_PTR;
    CURRENT_HEAP_PTR += 16;
	heap_align32();
    newObj[0] = JavaLangString;
    newObj[3] = count;
    newObj[1] = thisObj[1];
    newObj[2] = 0;


    *GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C) = (int)newObj;
    /*thisObj[0] = JavaLangString;
    thisObj[3] = thisObj[2];
    thisObj[2] = 0;*/
#if Chia_Che_Hsu_Debug
	printf("Java_java_lang_StringBuffer_toString start\n");
	printf("thisObj:%X\n", thisObj);
	printf("newObj:%X\n", newObj);
	printf("CURRENT_HEAP_PTR:%X\n", CURRENT_HEAP_PTR);
#endif

#if nativedebug
    debug_obj_print(thisObj);
    xil_printf("Invoke native moethod Java_java_lang_StringBuffer_toString!!\r\n");
#endif
}
void Java_java_lang_Math_randomInt(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_Math_randomInt!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_lang_ref_WeakReference_initializeWeakReference(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_lang_ref_WeakReference_initializeWeakReference!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_java_util_Calendar_init(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_java_util_Calendar_init!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_com_sun_cldc_io_Waiter_waitForIO(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_com_sun_cldc_io_Waiter_waitForIO!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_com_sun_cldc_io_j2me_socket_Protocol_initializeInternal(uint8 core_id){
#if nativedebug
    xil_printf("Invoke native moethod Java_com_sun_cldc_io_j2me_socket_Protocol_initializeInternal!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}
void Java_com_sun_cldc_io_ConsoleOutputStream_write(uint8 core_id){
	unsigned char tmp_char = *((unsigned char *)GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B) + 3);

	/*xil_printf("---\r\n");
	xil_printf("|%x|\r\n",  *((unsigned int *)GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_B)));
	xil_printf("|%c|\r\n", tmp_char);
	xil_printf("|%d|\r\n", tmp_char);
	xil_printf("---\r\n\r\n");*/
	if(tmp_char != 0x0A)
		xil_printf("%c", tmp_char);
	else
		xil_printf("\r\n");

#if nativedebug
    xil_printf("Invoke native moethod Java_com_sun_cldc_io_ConsoleOutputStream_write!!\r\n");
    xil_printf("None implement!!\r\n");
#endif
}

#define JPC_debug                  ((volatile int *)JPL_MEM_ADDRESS + 0x20)
#define JPC_debug2                 ((volatile int *)JPL_MEM_ADDRESS + 0x24)



void Debug_checkSystemState( uint8 core_id){


	int temp = (unsigned int*)*GET_CTRL_REG_MEM0ADDR(core_id, JPL_TOS_C);

    //debug_number[temp]++; //de by zi jing
	xil_printf("[debug print core %d]: [%d]\r\n", core_id, temp);
	// debug by T.H.Wu , 2013.7.25

	if(temp==600004) {
		/*
		xil_printf("Debug_checkSystemState : cs (thread 0): %x %x %x \r\n",
																	*(((uint*)(0x5c0005a0))+0)
																, *(((uint*)(0x5c0005a0))+1)
																, *(((uint*)(0x5c0005a0))+2)
												);
		xil_printf("Debug_checkSystemState : cs (thread 1): %x %x %x \r\n",
																  *(((uint*)(0x5c0005b4))+0)
																, *(((uint*)(0x5c0005b4))+1)
																, *(((uint*)(0x5c0005b4))+2)
												);
		xil_printf("Debug_checkSystemState : bh: %x %x %x \r\n",
				*(((uint*)(0x5c0004c4))+0),
				*(((uint*)(0x5c0004c4))+1),
				*(((uint*)(0x5c0004c4))+2)
		);
		xil_printf("Debug_checkSystemState : bu: %x %x %x \r\n",
				*(((uint*)(0x5c0004d8))+0),
				*(((uint*)(0x5c0004d8))+1),
				*(((uint*)(0x5c0004d8))+2)
		);
		xil_printf("Debug_checkSystemState : bd: %x %x %x \r\n",
				*(((uint*)(0x5c0004ec))+0),
				*(((uint*)(0x5c0004ec))+1),
				*(((uint*)(0x5c0004ec))+2)
		);
		xil_printf("Debug_checkSystemState : sl: %x %x %x \r\n",
				*(((uint*)(0x5c000500))+0),
				*(((uint*)(0x5c000500))+1),
				*(((uint*)(0x5c000500))+2)
		);

		xil_printf("Debug_checkSystemState : col: %x \r\n", *(((uint*)(0x5C000458))+0)  );

		char input_cmd[50];
		//scanf("[test input cmd]:%c", input_cmd);
		*/
	}
	// set break point manually
	if(temp==92) {
		//xil_printf("Debug_checkSystemState : something wrong!! \r\n");
		/*
		int i = 0;
		int th0_stk_size = 0x30;
		xil_printf("Debug stack check : thread 0 \r\n");
		for(i=0 ; i<th0_stk_size;i++){
			xil_printf("[%x] %4x \r\n", i, *(((volatile uint*)(0x5bff0000))+i) );
		}
		xil_printf("Debug stack check : thread 1 \r\n");
		for(i=0 ; i<th0_stk_size;i++){
			xil_printf("[%x] %4x \r\n", i, *(((volatile uint*)(0x5bff1000))+i) );
		}
		*/
		//while(1);
	}

#if nativedebug
    xil_printf("Invoke native moethod Debug_checkSystemState!!\r\n");
#endif

    int i,tmp0,tmp1,now_mthd_id,jpc_reg,jpc_out,bytecodes_t,now_cls_id,B0,B1;
#if print_jpc_records
    print_reg(0x00000034, 0);
    print_reg(0x00000036, 0);
    xil_printf("\r\nnow_cls_id now_mthd_id jpc_reg bytecodes_t \r\n");
       for( i=0;i<256;i++){
               	*JPC_debug = 1<<9|i ;
               	*JPC_debug2= 1<<9|i ;

               	tmp0 = *JPC_debug;
               	tmp1 = *JPC_debug2;


               	now_mthd_id = (tmp0 & 0xffC00000)>>24;
               	jpc_reg     = (tmp0 & 0x00fff000)>>12;
               	jpc_out     = (tmp0 & 0x00000fff)   ;

               	bytecodes_t = (tmp1 & 0x0000ffff)    ;
               	now_cls_id  = (tmp1 & 0x00ff0000)>>16;
               	B0          = (tmp1 & 0x0f000000)>>24;
               	B1          = (tmp1 & 0xf0000000)>>28;

               	//debug_data=
               	//xil_printf("Print debug data:%8x  debug2: %8x   \r\n",*JPC_debug,*JPC_debug2);

               	xil_printf("%2x        %2x        %3x     %4x  %x %x\r\n",now_cls_id,now_mthd_id,jpc_reg,bytecodes_t,B1,B0);

               }
               *JPC_debug = 0;
               *JPC_debug2 = 0;
#endif
}




struct nativeMethod nativeMethodTable[54]={
    {0,1,Java_java_lang_Object_getClass},
    // modified by T.H.Wu , 2013.8.13 , because JAIP has not support native method info list in
    // cross reference table, so we can not let child class override the native method of parent class
    {0,0,Java_java_lang_Object_hashCode0},
    {1,0,Java_java_lang_System_identityHashCode},         // obj
    {0,0,Java_java_lang_Object_notify},
    {0,0,Java_java_lang_Object_notifyAll},
    {1,0,Java_java_lang_Object_wait},                     // l
    {0,0,Java_java_lang_Class_isInterface},
    {0,0,Java_java_lang_Class_isPrimitive},               // cldc no use, but kvm has declared its prototypes
    {1,1,Java_java_lang_Class_forName},                   // string
    {1,1,Java_java_lang_Class_newInstance},
    {0,0,Java_java_lang_Class_getName},
    {1,0,Java_java_lang_Class_isInstance},                // obj
    {0,0,Java_java_lang_Class_isArray},
    {1,0,Java_java_lang_Class_isAssignableFrom},          // class
    {0,0,Java_java_lang_Class_getPrimitiveClass},         // cldc no use, but kvm has declared its prototypes
    {0,0,Java_java_lang_Class_exists},                    // cldc no use, but kvm has declared its prototypes
    {0,0,Java_java_lang_Class_getResourceAsStream0},      // cldc no use, but kvm has declared its prototypes
    {0,0,Java_java_lang_Thread_activeCount},
    {0,0,Java_java_lang_Thread_currentThread},
    {0,0,Java_java_lang_Thread_yield},
    {1,0,Java_java_lang_Thread_sleep},                    // l
    {0,0,Java_java_lang_Thread_start},
    {0,0,Java_java_lang_Thread_isAlive},
    {1,0,Java_java_lang_Thread_setPriority0},             // i
    {1,0,Java_java_lang_Thread_setPriority},              // not a native method, but kvm has declared its prototypes
    {0,0,Java_java_lang_Thread_interrupt0},
    {0,0,Java_java_lang_Thread_interrupt},                // not a native method, but kvm has declared its prototypes
    {0,0,Java_java_lang_Throwable_fillInStackTrace},      // cldc no use, but kvm has declared its prototypes
    {1,0,Java_java_lang_Throwable_printStackTrace0},      // obj
    {1,0,Java_java_lang_Runtime_exitInternal},            // i
    {0,0,Java_java_lang_Runtime_freeMemory},
    {0,0,Java_java_lang_Runtime_totalMemory},
    {0,0,Java_java_lang_Runtime_gc},
    {5,0,Java_java_lang_System_arraycopy},                // obj, i, obj, i, i
    {0,1,Java_java_lang_System_currentTimeMillis},
    {1,1,Java_java_lang_System_getProperty0},             // string
    {0,0,Java_java_lang_System_getProperty},              // not a native method, but kvm has declared its prototypes
    {1,0,Java_java_lang_String_charAt},                   // i
    {2,1,Java_java_lang_String_equals},                   // obj + obj
    {1,0,Java_java_lang_String_indexOf__I},
    {2,0,Java_java_lang_String_indexOf__II},
    {0,0,Java_java_lang_String_intern},
    {1,1,Java_java_lang_StringBuffer_append__I},          // i
    {1,1,Java_java_lang_StringBuffer_append__Ljava_lang_String_2}, // string
    {1,1,Java_java_lang_StringBuffer_toString},           // 0 + obj
    {0,0,Java_java_lang_Math_randomInt},                  // not support, because most of math class are operation with float
    {0,0,Java_java_lang_ref_WeakReference_initializeWeakReference},
    {0,0,Java_java_util_Calendar_init},
    {0,0,Java_com_sun_cldc_io_Waiter_waitForIO},
    {0,0,Java_com_sun_cldc_io_j2me_socket_Protocol_initializeInternal},
    {1,0,Java_com_sun_cldc_io_ConsoleOutputStream_write},  // i
    {0,0,Debug_checkSystemState},
    {0,1,Java_java_lang_System_currentTimeMillisHW},
    {0,1,Java_java_lang_System_currentTimeMillisINTRPT}
};
