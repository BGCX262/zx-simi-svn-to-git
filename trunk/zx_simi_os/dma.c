#include <stdlib.h>
#include "dma.h"

void dmaSetDestAddr(unsigned long addr) {
    outp(DMA_DEST_ADDR0,(addr      ) & 0xFF);  //nejnizsi bajt adresy
    outp(DMA_DEST_ADDR1,(addr >>  8) & 0xFF);  //prostredni bajt adresy
    outp(DMA_DEST_ADDR2,(addr >> 16) & 0xFF);  //nejvyssi bajt adresy
}

void dmaSetSrcAddr(unsigned long addr) {
    outp(DMA_SRC_ADDR0,(addr      ) & 0xFF);  //nejnizsi bajt adresy
    outp(DMA_SRC_ADDR1,(addr >>  8) & 0xFF);  //prostredni bajt adresy
    outp(DMA_SRC_ADDR2,(addr >> 16) & 0xFF);  //nejvyssi bajt adresy
}

void dmaSetConfig(unsigned char conf) {
    outp(DMA_CONFIG,conf);
}

void dmaSendByte(unsigned char byte) {
    outp(DMA_SEND_BYTE,byte);
} 


void dmaTransfer(unsigned int length) {
    outp(DMA_LENGTH0,(length     ) & 0xFF);
    outp(DMA_LENGTH1,(length >> 8) & 0xFF);
} 


unsigned long swAddr2hwAddr(unsigned long addr)
{
    //0x0000 - 0x3FFF
    if (addr<0x4000) return addr+0x60000;
    //0x4000 - 0x7FFF
    else if (addr<0x8000) return addr+0x14000-0x4000;
    //0x8000 - 0xBFFF
    else if (addr<0xC000) return addr;
    //0xC000 - 0xFFFF
    else return addr-0xC000; 
}

