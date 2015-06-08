//////////////////////////////////////////////////////////////////////////////
// Filename:          D:\MMES_JavaPlatform\Java_v2.1\version_2.4\EDK/drivers/jpl_v1_00_a/src/jpl.c
// Version:           1.00.a
// Description:       jpl Driver Source File
// Date:              Tue Apr 21 17:31:33 2009 (by Create and Import Peripheral Wizard)
//////////////////////////////////////////////////////////////////////////////


/***************************** Include Files *******************************/

#include "../include/jpl.h"

/************************** Function Definitions ***************************/


/**
 *
 * User logic master module to send/receive bytes to/from remote system memory.
 * While sending, the bytes are read from user logic local FIFO and write to remote system memory.
 * While receiving, the bytes are read from remote system memory and write to user logic local FIFO.
 *
 * @param   BaseAddress is the base address of the JPL device.
 * @param   DstAddress is the destination system memory address from/to which the data will be fetched/stored.
 * @param   Size is the number of bytes to be sent.
 *
 * @return  None.
 *
 * @note    None.
 *
 */
void JPL_MasterSendByte(Xuint32 BaseAddress, Xuint32 DstAddress, int Size)
{
  /*
   * Set user logic master control register for write transfer.
   */
  XIo_Out8(BaseAddress+JPL_MST_CNTL_REG_OFFSET, MST_SGWR);

  /*
   * Set user logic master address register to drive IP2Bus_Mst_Addr signal.
   */
  XIo_Out32(BaseAddress+JPL_MST_ADDR_REG_OFFSET, DstAddress);

  /*
   * Set user logic master byte enable register to drive IP2Bus_Mst_BE signal.
   */
  XIo_Out16(BaseAddress+JPL_MST_BE_REG_OFFSET, 0xFFFF);

  /*
   * Set user logic master length register.
   */
  XIo_Out16(BaseAddress+JPL_MST_LEN_REG_OFFSET, (Xuint16) Size);
  /*
   * Start user logic master write transfer by writting special pattern to its go port.
   */
  XIo_Out8(BaseAddress+JPL_MST_GO_PORT_OFFSET, MST_START);
}

void JPL_MasterRecvByte(Xuint32 BaseAddress, Xuint32 DstAddress, int Size)
{
  /*
   * Set user logic master control register for read transfer.
   */
  XIo_Out8(BaseAddress+JPL_MST_CNTL_REG_OFFSET, MST_SGRD);

  /*
   * Set user logic master address register to drive IP2Bus_Mst_Addr signal.
   */
  XIo_Out32(BaseAddress+JPL_MST_ADDR_REG_OFFSET, DstAddress);

  /*
   * Set user logic master byte enable register to drive IP2Bus_Mst_BE signal.
   */
  XIo_Out16(BaseAddress+JPL_MST_BE_REG_OFFSET, 0xFFFF);

  /*
   * Set user logic master length register.
   */
  XIo_Out16(BaseAddress+JPL_MST_LEN_REG_OFFSET, (Xuint16) Size);
  /*
   * Start user logic master read transfer by writting special pattern to its go port.
   */
  XIo_Out8(BaseAddress+JPL_MST_GO_PORT_OFFSET, MST_START);
}

/**
 *
 * Enable all possible interrupts from JPL device.
 *
 * @param   baseaddr_p is the base address of the JPL device.
 *
 * @return  None.
 *
 * @note    None.
 *
 */
void JPL_EnableInterrupt(void * baseaddr_p)
{
  Xuint32 baseaddr;
  baseaddr = (Xuint32) baseaddr_p;

  /*
   * Enable all interrupt source from user logic.
   */
  JPL_mWriteReg(baseaddr, JPL_INTR_IPIER_OFFSET, 0x00000001);

  /*
   * Enable all possible interrupt sources from device.
   */
  /*
  JPL_mWriteReg(baseaddr, JPL_INTR_DIER_OFFSET,
    INTR_TERR_MASK
    | INTR_DPTO_MASK
    | INTR_IPIR_MASK
    );
    */

  /*
   * Set global interrupt enable.
   */
  JPL_mWriteReg(baseaddr, JPL_INTR_DGIER_OFFSET, INTR_GIE_MASK);
}

/**
 *
 * Example interrupt controller handler for JPL device.
 * This is to show example of how to toggle write back ISR to clear interrupts.
 *
 * @param   baseaddr_p is the base address of the JPL device.
 *
 * @return  None.
 *
 * @note    None.
 *
 */
void JPL_Intr_DefaultHandler(void * baseaddr_p)
{
  Xuint32 baseaddr;
  Xuint32 IntrStatus;
Xuint32 IpStatus;
  baseaddr = (Xuint32) baseaddr_p;

  /*
   * Get status from Device Interrupt Status Register.
   */
  IntrStatus = JPL_mReadReg(baseaddr, JPL_INTR_DISR_OFFSET);

  xil_printf("Device Interrupt! DISR value : 0x%08x \n\r", IntrStatus);

  /*
   * Verify the source of the interrupt is the user logic and clear the interrupt
   * source by toggle write baca to the IP ISR register.
   */
  if ( (IntrStatus & INTR_IPIR_MASK) == INTR_IPIR_MASK )
  {
    xil_printf("User logic interrupt! \n\r");
    IpStatus = JPL_mReadReg(baseaddr, JPL_INTR_IPISR_OFFSET);
    JPL_mWriteReg(baseaddr, JPL_INTR_IPISR_OFFSET, IpStatus);
  }

}

