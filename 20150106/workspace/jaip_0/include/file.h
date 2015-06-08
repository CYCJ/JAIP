/* /////////////////////////////////////////////////////////////////// */
/*																	*/
/*   System Software of Dual-Core Java Runtime Environment			*/
/*																	*/
/* ------------------------------------------------------------------- */
/*   File: file.c													*/
/*   Author: Chien-Fone Huang										*/
/*   Date: Sep/2009													*/
/* ------------------------------------------------------------------- */
/*   Implement some function to open the Java class file and create	*/
/*   Java Runtime image (.bin). Note that the file system is FAT16,	*/
/*   so the .class must be renamed as .cls							*/
/*																	*/
/*   Copyright, 2009.												*/
/*   Multimedia Embedded Systems Lab.								*/
/*   Department of Computer Science and Information engineering		*/
/*   National Chiao Tung University, Hsinchu 300, Taiwan			*/
/* ------------------------------------------------------------------- */
/*   MODIFICATIONS													*/
/*																	*/
/*   On Aug/5/2010 by Chun-Jen Tsai									*/
/*   1. Each JAR file in the system class path directory is read only  */
/*	once upon boot time. Class search in the JAR file is done in   */
/*	memory.														*/
/*   2. Fix a bug that caused by declare a large array as a local	*/
/*	variable, which corrupts the function call stack.			*/
/*   3. Reformat the program using 'indent.'						*/
/* /////////////////////////////////////////////////////////////////// */
#include <sysace_stdio.h>
// added by T.H.Wu , 2013.9.9
#include "../include/metypes.h"

#ifndef _FILE_H_
#define _FILE_H_

/* ------------------------------------------------------------------- */
/*				File Read Buffer Declaration					*/
/* ------------------------------------------------------------------- */

#define MAX_BUFFER_SIZE  1310720//327680//1310720//327680 //320K
#define MAX_DIR_ENTRIES  50

/* ------------------------------------------------------------------- */
/*				Function Prototypes Declaration					*/
/* ------------------------------------------------------------------- */

extern unsigned short global_num;
extern unsigned int DDR_image_space_address; // Offset to baseaddress(0x00001F00)

//added by zi-jing
extern unsigned short global_mthd_id;

// open the class file in CF card
// int open_class(char *class_name) ;
// The entries array

dirent fileent[MAX_DIR_ENTRIES];

//search the directory
void search_dir();
// modified by T.H.Wu , for multi-core JAIP use , 2013.9.9
//int jar_load_class(unsigned char*,unsigned long,char*, int*);
int jar_load_class(uint8, unsigned char*,unsigned long,char*, int*);
int Generate_New_Image(uint8, char* ,int);

// modified by T.H.Wu ,2013.9.10, multi-core 的 parser synchronization 暫時以 serial 的方式 執行
// added by T.H.Wu , 2013.9.10 , 實作一個 臨時用的 mutex , for parser
void init_temp_lock();
void release_monitor_selfbuilt(uint8);
void request_monitor_selfbuilt(uint8);


#endif
