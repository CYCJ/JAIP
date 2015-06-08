/*****************************************************************************
* Filename:		C:\MCB_62/drivers/jaip_v1_00_a/src/jaip.h
* Version:		1.00.a
* Description:	jaip Driver Header File
* Date:			Sun Jul 31 17:32:54 2011 (by Create and Import Peripheral Wizard)
*****************************************************************************/

#ifndef JAIP_H
#define JAIP_H

/***************************** Include Files *******************************/

#include "xbasic_types.h"
#include "xstatus.h"
#include "xil_io.h"

/************************** Constant Definitions ***************************/


/**
 * User Logic Slave Space Offsets
 * -- SLV_REG0 : user logic slave module register 0
 * -- SLV_REG1 : user logic slave module register 1
 * -- SLV_REG2 : user logic slave module register 2
 * -- SLV_REG3 : user logic slave module register 3
 * -- SLV_REG4 : user logic slave module register 4
 * -- SLV_REG5 : user logic slave module register 5
 * -- SLV_REG6 : user logic slave module register 6
 * -- SLV_REG7 : user logic slave module register 7
 * -- SLV_REG8 : user logic slave module register 8
 * -- SLV_REG9 : user logic slave module register 9
 * -- SLV_REG10 : user logic slave module register 10
 * -- SLV_REG11 : user logic slave module register 11
 * -- SLV_REG12 : user logic slave module register 12
 * -- SLV_REG13 : user logic slave module register 13
 * -- SLV_REG14 : user logic slave module register 14
 * -- SLV_REG15 : user logic slave module register 15
 */
#define JAIP_USER_SLV_SPACE_OFFSET (0x00000000)
#define JAIP_SLV_REG0_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000000)
#define JAIP_SLV_REG1_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000004)
#define JAIP_SLV_REG2_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000008)
#define JAIP_SLV_REG3_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x0000000C)
#define JAIP_SLV_REG4_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000010)
#define JAIP_SLV_REG5_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000014)
#define JAIP_SLV_REG6_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000018)
#define JAIP_SLV_REG7_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x0000001C)
#define JAIP_SLV_REG8_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000020)
#define JAIP_SLV_REG9_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000024)
#define JAIP_SLV_REG10_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000028)
#define JAIP_SLV_REG11_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x0000002C)
#define JAIP_SLV_REG12_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000030)
#define JAIP_SLV_REG13_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000034)
#define JAIP_SLV_REG14_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x00000038)
#define JAIP_SLV_REG15_OFFSET (JAIP_USER_SLV_SPACE_OFFSET + 0x0000003C)

/**
 * User Logic Master Space Offsets
 * -- MST_CNTL_REG : user logic master module control register
 * -- MST_STAT_REG : user logic master module status register
 * -- MST_ADDR_REG : user logic master module address register
 * -- MST_BE_REG   : user logic master module byte enable register
 * -- MST_LEN_REG  : user logic master module length (data transfer in bytes) register
 * -- MST_GO_PORT  : user logic master module go bit (to start master operation)
 */
#define JAIP_USER_MST_SPACE_OFFSET (0x00000100)
#define JAIP_MST_CNTL_REG_OFFSET (JAIP_USER_MST_SPACE_OFFSET + 0x00000000)
#define JAIP_MST_STAT_REG_OFFSET (JAIP_USER_MST_SPACE_OFFSET + 0x00000001)
#define JAIP_MST_ADDR_REG_OFFSET (JAIP_USER_MST_SPACE_OFFSET + 0x00000004)
#define JAIP_MST_BE_REG_OFFSET (JAIP_USER_MST_SPACE_OFFSET + 0x00000008)
#define JAIP_MST_LEN_REG_OFFSET (JAIP_USER_MST_SPACE_OFFSET + 0x0000000C)
#define JAIP_MST_GO_PORT_OFFSET (JAIP_USER_MST_SPACE_OFFSET + 0x0000000F)

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
 * -- INTR_DGIER : device (peripheral) global interrupt enable register
 * -- INTR_ISR   : ip (user logic) interrupt status register
 * -- INTR_IER   : ip (user logic) interrupt enable register
 */
#define JAIP_INTR_CNTRL_SPACE_OFFSET (0x00000200)
#define JAIP_INTR_DGIER_OFFSET (JAIP_INTR_CNTRL_SPACE_OFFSET + 0x0000001C)
#define JAIP_INTR_IPISR_OFFSET (JAIP_INTR_CNTRL_SPACE_OFFSET + 0x00000020)
#define JAIP_INTR_IPIER_OFFSET (JAIP_INTR_CNTRL_SPACE_OFFSET + 0x00000028)

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
 * Write a value to a JAIP register. A 32 bit write is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is written.
 *
 * @param   BaseAddress is the base address of the JAIP device.
 * @param   RegOffset is the register offset from the base to write to.
 * @param   Data is the data written to the register.
 *
 * @return  None.
 *
 * @note
 * C-style signature:
 * 	void JAIP_mWriteReg(Xuint32 BaseAddress, unsigned RegOffset, Xuint32 Data)
 *
 */
#define JAIP_mWriteReg(BaseAddress, RegOffset, Data) \
 	Xil_Out32((BaseAddress) + (RegOffset), (Xuint32)(Data))

/**
 *
 * Read a value from a JAIP register. A 32 bit read is performed.
 * If the component is implemented in a smaller width, only the least
 * significant data is read from the register. The most significant data
 * will be read as 0.
 *
 * @param   BaseAddress is the base address of the JAIP device.
 * @param   RegOffset is the register offset from the base to write to.
 *
 * @return  Data is the data from the register.
 *
 * @note
 * C-style signature:
 * 	Xuint32 JAIP_mReadReg(Xuint32 BaseAddress, unsigned RegOffset)
 *
 */
#define JAIP_mReadReg(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (RegOffset))


/**
 *
 * Write/Read 32 bit value to/from JAIP user logic slave registers.
 *
 * @param   BaseAddress is the base address of the JAIP device.
 * @param   RegOffset is the offset from the slave register to write to or read from.
 * @param   Value is the data written to the register.
 *
 * @return  Data is the data from the user logic slave register.
 *
 * @note
 * C-style signature:
 * 	void JAIP_mWriteSlaveRegn(Xuint32 BaseAddress, unsigned RegOffset, Xuint32 Value)
 * 	Xuint32 JAIP_mReadSlaveRegn(Xuint32 BaseAddress, unsigned RegOffset)
 *
 */
#define JAIP_mWriteSlaveReg0(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG0_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg1(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG1_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg2(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG2_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg3(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG3_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg4(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG4_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg5(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG5_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg6(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG6_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg7(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG7_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg8(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG8_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg9(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG9_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg10(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG10_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg11(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG11_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg12(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG12_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg13(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG13_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg14(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG14_OFFSET) + (RegOffset), (Xuint32)(Value))
#define JAIP_mWriteSlaveReg15(BaseAddress, RegOffset, Value) \
 	Xil_Out32((BaseAddress) + (JAIP_SLV_REG15_OFFSET) + (RegOffset), (Xuint32)(Value))

#define JAIP_mReadSlaveReg0(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG0_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg1(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG1_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg2(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG2_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg3(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG3_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg4(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG4_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg5(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG5_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg6(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG6_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg7(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG7_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg8(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG8_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg9(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG9_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg10(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG10_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg11(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG11_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg12(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG12_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg13(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG13_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg14(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG14_OFFSET) + (RegOffset))
#define JAIP_mReadSlaveReg15(BaseAddress, RegOffset) \
 	Xil_In32((BaseAddress) + (JAIP_SLV_REG15_OFFSET) + (RegOffset))

/**
 *
 * Write/Read 32 bit value to/from JAIP user logic memory (BRAM).
 *
 * @param   Address is the memory address of the JAIP device.
 * @param   Data is the value written to user logic memory.
 *
 * @return  The data from the user logic memory.
 *
 * @note
 * C-style signature:
 * 	void JAIP_mWriteMemory(Xuint32 Address, Xuint32 Data)
 * 	Xuint32 JAIP_mReadMemory(Xuint32 Address)
 *
 */
#define JAIP_mWriteMemory(Address, Data) \
 	Xil_Out32(Address, (Xuint32)(Data))
#define JAIP_mReadMemory(Address) \
 	Xil_In32(Address)

/**
 *
 * Check status of JAIP user logic master module.
 *
 * @param   BaseAddress is the base address of the JAIP device.
 *
 * @return  Status is the result of status checking.
 *
 * @note
 * C-style signature:
 * 	bool JAIP_mMasterDone(Xuint32 BaseAddress)
 * 	bool JAIP_mMasterBusy(Xuint32 BaseAddress)
 * 	bool JAIP_mMasterError(Xuint32 BaseAddress)
 * 	bool JAIP_mMasterTimeout(Xuint32 BaseAddress)
 *
 */
#define JAIP_mMasterDone(BaseAddress) \
 	((((Xuint32) xil_io_in8((BaseAddress)+(JAIP_MST_STAT_REG_OFFSET)))<<16 & MST_DONE_MASK) == MST_DONE_MASK)
#define JAIP_mMasterBusy(BaseAddress) \
 	((((Xuint32) xil_io_in8((BaseAddress)+(JAIP_MST_STAT_REG_OFFSET)))<<16 & MST_BUSY_MASK) == MST_BUSY_MASK)
#define JAIP_mMasterError(BaseAddress) \
 	((((Xuint32) xil_io_in8((BaseAddress)+(JAIP_MST_STAT_REG_OFFSET)))<<16 & MST_ERROR_MASK) == MST_ERROR_MASK)
#define JAIP_mMasterTimeout(BaseAddress) \
 	((((Xuint32) xil_io_in8((BaseAddress)+(JAIP_MST_STAT_REG_OFFSET)))<<16 & MST_TIMEOUT_MASK) == MST_TIMEOUT_MASK)

/************************** Function Prototypes ****************************/


/**
 *
 * User logic master module to send/receive bytes to/from remote system memory.
 * While sending, the bytes are read from user logic local FIFO and write to remote memory.
 * While receiving, the bytes are read from remote memory and write to user logic local FIFO.
 *
 * @param   BaseAddress is the base address of the JAIP device.
 * @param   DstAddress is the destination memory address from/to which the data will be fetched/stored.
 * @param   Size is the number of bytes to be sent.
 *
 * @return  None.
 *
 * @note	None.
 *
 */
void JAIP_MasterSendByte(Xuint32 BaseAddress, Xuint32 DstAddress, int Size);
void JAIP_MasterRecvByte(Xuint32 BaseAddress, Xuint32 DstAddress, int Size);

/**
 *
 * Enable all possible interrupts from JAIP device.
 *
 * @param   baseaddr_p is the base address of the JAIP device.
 *
 * @return  None.
 *
 * @note	None.
 *
 */
void JAIP_EnableInterrupt(void * baseaddr_p);

/**
 *
 * Example interrupt controller handler.
 *
 * @param   baseaddr_p is the base address of the JAIP device.
 *
 * @return  None.
 *
 * @note	None.
 *
 */
void JAIP_Intr_DefaultHandler(void * baseaddr_p);

/**
 *
 * Run a self-test on the driver/device. Note this may be a destructive test if
 * resets of the device are performed.
 *
 * If the hardware system is not built correctly, this function may never
 * return to the caller.
 *
 * @param   baseaddr_p is the base address of the JAIP instance to be worked on.
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
XStatus JAIP_SelfTest(void * baseaddr_p);

#endif /** JAIP_H */
