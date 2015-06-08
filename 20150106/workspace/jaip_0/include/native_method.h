#ifndef _NATIVE_METHOD_H_
#define _NATIVE_METHOD_H_

// added by T.H.Wu , 2013.9.9
#include "../include/metypes.h"
#define PARAMETER_SPACE_MAX_SIZE	8
#define CLOCK_PER_MILLISECOND   100000 // 100 MHz = 100000000 cycle/1s

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

//#define PARAMETER_SPACE_ADDRESS	0x000A0000

// modified by T.H.Wu , 2013.9.9 , for multi-core JAIP execution
// Native function prototypes , used currently since 2013.9.9
void Java_java_lang_Object_getClass(uint8);
void Java_java_lang_Object_hashCode0(uint8);
void Java_java_lang_System_identityHashCode(uint8);
void Java_java_lang_Object_notify(uint8);
void Java_java_lang_Object_notifyAll(uint8);
void Java_java_lang_Object_wait(uint8);
void Java_java_lang_Class_isInterface(uint8);
void Java_java_lang_Class_isPrimitive(uint8);
void Java_java_lang_Class_forName(uint8);
void Java_java_lang_Class_newInstance(uint8);
void Java_java_lang_Class_getName(uint8);
void Java_java_lang_Class_isInstance(uint8);
void Java_java_lang_Class_isArray(uint8);
void Java_java_lang_Class_isAssignableFrom(uint8);
void Java_java_lang_Class_getPrimitiveClass(uint8);
void Java_java_lang_Class_exists(uint8);
void Java_java_lang_Class_getResourceAsStream0(uint8);
void Java_java_lang_Thread_activeCount(uint8);
void Java_java_lang_Thread_currentThread(uint8);
void Java_java_lang_Thread_yield(uint8);
void Java_java_lang_Thread_sleep(uint8);
void Java_java_lang_Thread_start(uint8);
void Java_java_lang_Thread_isAlive(uint8);
void Java_java_lang_Thread_setPriority0(uint8);
void Java_java_lang_Thread_setPriority(uint8);
void Java_java_lang_Thread_interrupt0(uint8);
void Java_java_lang_Thread_interrupt(uint8);
void Java_java_lang_Throwable_fillInStackTrace(uint8);
void Java_java_lang_Throwable_printStackTrace0(uint8);
void Java_java_lang_Runtime_exitInternal(uint8);
void Java_java_lang_Runtime_freeMemory(uint8);
void Java_java_lang_Runtime_totalMemory(uint8);
void Java_java_lang_Runtime_gc(uint8);
void Java_java_lang_System_arraycopy (uint8);
void Java_java_lang_System_currentTimeMillis(uint8);
void Java_java_lang_System_currentTimeMillisHW(uint8);
void Java_java_lang_System_currentTimeMillisINTRPT(uint8);
void Java_java_lang_System_getProperty0(uint8);
void Java_java_lang_System_getProperty(uint8);
void Java_java_lang_String_charAt(uint8);
void Java_java_lang_String_equals(uint8);
void Java_java_lang_String_indexOf__I(uint8);
void Java_java_lang_String_indexOf__II(uint8);
void Java_java_lang_String_intern(uint8);
void Java_java_lang_StringBuffer_append__I(uint8);
void Java_java_lang_StringBuffer_append__Ljava_lang_String_2(uint8);
void Java_java_lang_StringBuffer_toString(uint8);
void Java_java_lang_Math_randomInt(uint8);
void Java_java_lang_ref_WeakReference_initializeWeakReference(uint8);
void Java_java_util_Calendar_init(uint8);
void Java_com_sun_cldc_io_Waiter_waitForIO(uint8);
void Java_com_sun_cldc_io_j2me_socket_Protocol_initializeInternal(uint8);
void Java_com_sun_cldc_io_ConsoleOutputStream_write(uint8);
void Debug_checkSystemState(uint8);


// for debug
void debug_array_print(unsigned int* );
void debug_obj_print(unsigned int* );

// help native method work
unsigned int* copyArray(unsigned int*);
unsigned int* copyObj(unsigned int*);
static short* getSystemProperty(short *);
void string_indexOf(uint8 ,int);

// modified by T.H.Wu , 2013.9.9 , for multi-core JAIP execution
//typedef void (*funcPtr)(void);
typedef void (*funcPtr)(uint8);

struct nativeMethod
{
	int popNum;	// arg nums and this obj reference(may be not)
	int returnFlag; // is the function need return value
	funcPtr invoke_native;
	//void (*invoke_native)(uint8);
} ;

#endif
