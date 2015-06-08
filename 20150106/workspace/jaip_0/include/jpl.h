//////////////////////////////////////////////////////////////////////////////
// Filename:		D:\MMES_JavaPlatform\Java_v2.1\version_2.4\EDK/drivers/jpl_v1_00_a/src/jpl.h
// Version:		1.00.a
// Description:	jpl Driver Header File
// Date:			Tue Apr 21 17:31:33 2009 (by Create and Import Peripheral Wizard)
//////////////////////////////////////////////////////////////////////////////

#ifndef JPL_H
#define JPL_H

/***************************** Include Files *******************************/

#include "xbasic_types.h"
#include "xstatus.h"
#include "xio.h"

/************************** Constant Definitions ***************************/


/**
 * User Logic Master Space Offsets
 * -- MST_CNTL_REG : user logic master module control register
 * -- MST_STAT_REG : user logic master module status register
 * -- MST_ADDR_REG : user logic master module address register
 * -- MST_BE_REG   : user logic master module byte enable register
 * -- MST_LEN_REG  : user logic master module length (data transfer in bytes) register
 * -- MST_GO_PORT  : user logic master module go bit (to start master operation)
 */
#define JPL_USER_MST_SPACE_OFFSET (0x00000000)
#define JPL_MST_CNTL_REG_OFFSET (JPL_USER_MST_SPACE_OFFSET + 0x00000000)
#define JPL_MST_STAT_REG_OFFSET (JPL_USER_MST_SPACE_OFFSET + 0x00000001)
#define JPL_MST_ADDR_REG_OFFSET (JPL_USER_MST_SPACE_OFFSET + 0x00000004)
#define JPL_MST_BE_REG_OFFSET (JPL_USER_MST_SPACE_OFFSET + 0x00000008)
#define JPL_MST_LEN_REG_OFFSET (JPL_USER_MST_SPACE_OFFSET + 0x0000000C)
#define JPL_MST_GO_PORT_OFFSET (JPL_USER_MST_SPACE_OFFSET + 0x0000000F)

/**
 * User Logic Master Module Masks
 * -- MST_RD_MASK   : user logic master read request control
 * -- MST_WR_MASK   : user logic master write request control
 * -- MST_BL_MASK   : user logic master bus lock control
 * -- MST_BRST_MASK : user logic master burst assertion control
 * -- MST_DONE_MASK : user logic master transfer done status
 * -- MST_BSY_MASK  : user logic master busy status
 * -- MST_BRRD	: user logic master burst read request
 * -- MST_BRWR	: user logic master burst write request
 * -- MST_SGRD	: user logic master single read request
 * -- MST_SGWR	: user logic master single write request
 * -- MST_START	: user logic master to start transfer
 */
#define MST_RD_MASK (0x80000000UL)
#define MST_WR_MASK (0x40000000UL)
#define MST_BL_MASK (0x20000000UL)
#define MST_BRST_MASK (0x10000000UL)
#define MST_DONE_MASK (0x00800000UL)
#define MST_BSY_MASK (0x00400000UL)
#define MST_BRRD (0x90)
#define MST_BRWR (0x50)
#define MST_SGRD (0x80)
#define MST_SGWR (0x40)
#define MST_START (0x0A)

/**
 * Interrupt Controller Space Offsets
 * -- INTR_DISR  : device (peripheral) interrupt status register
 * -- INTR_DIPR  : device (peripheral) interrupt pending register
 * -- INTR_DIER  : device (peripheral) interrupt enable register
 * -- INTR_DIIR  : device (peripheral) interrupt id (priority encoder) register
 * -- INTR_DGIER : device (peripheral) global interrupt enable register
 * -- INTR_ISR   : ip (user logic) interrupt status register
 * -- INTR_IER   : ip (user logic) interrupt enable register
 */
#define JPL_INTR_CNTRL_SPACE_OFFSET (0x00000200)
#define JPL_INTR_DISR_OFFSET (JPL_INTR_CNTRL_SPACE_OFFSET + 0x00000000)
#define JPL_INTR_DIPR_OFFSET (JPL_INTR_CNTRL_SPACE_OFFSET + 0x00000004)
#define JPL_INTR_DIER_OFFSET (JPL_INTR_CNTRL_SPACE_OFFSET + 0x00000008)
#define JPL_INTR_DIIR_OFFSET (JPL_INTR_CNTRL_SPACE_OFFSET + 0x00000018)
#define JPL_INTR_DGIER_OFFSET (JPL_INTR_CNTRL_SPACE_OFFSET + 0x0000001C)
#define JPL_INTR_IPISR_OFFSET (JPL_INTR_CNTRL_SPACE_OFFSET + 0x00000020)
#define JPL_INTR_IPIER_OFFSET (JPL_INTR_CNTRL_SPACE_OFFSET + 0x00000028)

/**
 * Interrupt Controller Masks
 * -- INTR_TERR_MASK : transaction error
 * -- INTR_DPTO_MASK : data phase time-out
 * -- INTR_IPIR_MASK : ip interrupt requeset
 * -- INTR_RFDL_MASK : read packet fifo deadlock interrupt request
 * -- INTR_WFDL_MASK : write packet fifo deadlock interrupt request
 * -- INTR_IID_MASK  : interrupt id
 * -- INTR_GIE_MASK  : global interrupt enable
 * -- INTR_NOPEND	: the DIPR has no pending interrupts
 */
#define INTR_TERR_MASK (0x00000001UL)
#define INTR_DPTO_MASK (0x00000002UL)
#define INTR_IPIR_MASK (0x00000004UL)
#define INTR_RFDL_MASK (0x00000020UL)
#define INTR_WFDL_MASK (0x00000040UL)
#define INTR_IID_MASK (0x000000FFUL)
#define INTR_GIE_MASK (0x80000000UL)
#define INTR_NOPEND (0x80)

/**************************** Type Definitions *****************************/


/***************** Macros (Inline Functions) Definitions *******************/

/**
 *
 * Write a value to a JPL register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddress is the base address of the JPL device.
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void JPL_mWriteReg(Xuint32 BaseAddress, unsigned RegOffset, Xuint32 Data)
 *
 */
#define JPL_mWriteReg(BaseAddress, RegOffset, Data) \
 	XIo_Out32((BaseAddress) + (RegOffset), (Xuint32)(Data))

/**
 *
 * Read a value from a JPL register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddress is the base address of the JPL device.
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	Xuint32 JPL_mReadReg(Xuint32 BaseAddress, unsigned RegOffset)
 *
 */
#define JPL_mReadReg(BaseAddress, RegOffset) \
 	XIo_In32((BaseAddress) + (RegOffset))


/**
 *
 * Write/Read 32 bit value to/from JPL user logic memory (BRAM).
 *
 * @param   Address is the memory address of the JPL device.
 * @param   Data is the value written to user logic memory.
 *
 * @return  The data from the user logic memory.
 *
 * @note
 * C-style signature:
 * 	void JPL_mWriteMemory(Xuint32 Address, Xuint32 Data)
 * 	Xuint32 JPL_mReadMemory(Xuint32 Address)
 *
 */
#define JPL_mWriteMemory(Address, Data) \
 	XIo_Out32(Address, (Xuint32)(Data))
#define JPL_mReadMemory(Address) \
 	XIo_In32(Address)

/**
 *
 * Check status of JPL user logic master module.
 *
 * @param   BaseAddress is the base address of the JPL device.
 *
 * @return  Status is the result of status checking.
 *
 * @note
 * C-style signature:
 * 	bool JPL_mMasterDone(Xuint32 BaseAddress)
 * 	bool JPL_mMasterBusy(Xuint32 BaseAddress)
 * 	bool JPL_mMasterError(Xuint32 BaseAddress)
 * 	bool JPL_mMasterTimeout(Xuint32 BaseAddress)
 *
 */
#define JPL_mMasterDone(BaseAddress) \
 	((((Xuint32) XIo_In8((BaseAddress)+(JPL_MST_STAT_REG_OFFSET)))<<16 & MST_DONE_MASK) == MST_DONE_MASK)
#define JPL_mMasterBusy(BaseAddress) \
 	((((Xuint32) XIo_In8((BaseAddress)+(JPL_MST_STAT_REG_OFFSET)))<<16 & MST_BUSY_MASK) == MST_BUSY_MASK)
#define JPL_mMasterError(BaseAddress) \
 	((((Xuint32) XIo_In8((BaseAddress)+(JPL_MST_STAT_REG_OFFSET)))<<16 & MST_ERROR_MASK) == MST_ERROR_MASK)
#define JPL_mMasterTimeout(BaseAddress) \
 	((((Xuint32) XIo_In8((BaseAddress)+(JPL_MST_STAT_REG_OFFSET)))<<16 & MST_TIMEOUT_MASK) == MST_TIMEOUT_MASK)

/************************** Function Prototypes ****************************/


/**
 *
 * User logic master module to send/receive bytes to/from remote system memory.
 * While sending, the bytes are read from user logic local FIFO and write to remote memory.
 * While receiving, the bytes are read from remote memory and write to user logic local FIFO.
 *
 * @param   BaseAddress is the base address of the JPL device.
 * @param   DstAddress is the destination memory address from/to which the data will be fetched/stored.
 * @param   Size is the number of bytes to be sent.
 *
 * @return  None.
 *
 * @note	None.
 *
 */
void JPL_MasterSendByte(Xuint32 BaseAddress, Xuint32 DstAddress, int Size);
void JPL_MasterRecvByte(Xuint32 BaseAddress, Xuint32 DstAddress, int Size);

/**
 *
 * Enable all possible interrupts from JPL device.
 *
 * @param   baseaddr_p is the base address of the JPL device.
 *
 * @return  None.
 *
 * @note	None.
 *
 */
void JPL_EnableInterrupt(void * baseaddr_p);

/**
 *
 * Example interrupt controller handler.
 *
 * @param   baseaddr_p is the base address of the JPL device.
 *
 * @return  None.
 *
 * @note	None.
 *
 */
void JPL_Intr_DefaultHandler(void * baseaddr_p);

/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the JPL instance to be worked on.
 *
 * @return
 *
 *	- XST_SUCCESS   if all self-test code passed
 *	- XST_FAILURE   if any self-test code failed
 *
 * @note	Caching must be turned off for this function to work.
 * @note	Self test may fail if data memory and device are not on the same bus.
 *
 */
XStatus JPL_SelfTest(void * baseaddr_p);

#endif // JPL_H
