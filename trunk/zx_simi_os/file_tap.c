#include <stdlib.h>
#include <stdio.h>
#include "textgui.h"
#include "error.h"
#include "filesystem.h"
#include "dma.h"
#include "task.h"
#include "file_tap.h"


errc tapLoadFile(tFileSystemDirEntry *dir)
{
    unsigned long addr, targetAddr;
    unsigned char pole[3];
    unsigned char *ind;
    unsigned char data[512];
    unsigned char state;
    unsigned int block_length, min;
    unsigned int memInd, sector;
    errc err;

    targetAddr = 0x80000;
   
    sector=0;
    
    state = 0;

    addr = 0;
    //prenesu snapshot do pameti. (dir->size)
    while (addr < (dir->size)) {

        //vypocitam si index do pole s daty. Pole je velke 512 bajtu
        memInd = addr & 0x1FF; 

        //prectu odpovidajici sektor v souboru
        if (memInd == 0) {
            if ((err = fsReadFile(dir->cluster, sector, data)) != ERR_OK) return err;
            sector++;
            dmaSetDestAddr(targetAddr);
            dmaSetConfig(DMA_INC_DST | DMA_INC_SRC);

        }

        switch(state) {
            //DATA BLOCK
            case 0: //DATA LENGTH lsb
                block_length = data[memInd];
                addr++;
                state = 1;
                break;
            case 1: //DATA LENGTH msb
                block_length |= (((unsigned int)data[memInd]) << 8);
                addr++;
                state = 2;
                break;
            //TAPE DATA
            case 2: //TAPE DATA
                min = 512 - memInd; 
                min = (block_length > min ? min : block_length);
                //nastavim DMA radic
                dmaSetSrcAddr(swAddr2hwAddr(((unsigned long)data)+memInd)); 
                dmaTransfer(min);
                targetAddr += min;
                block_length -= min;
                addr += min;
                if (block_length==0) state = 0;
                break;
        }
    }

    //pripravim ukazatel DMA na zacatek tape dat. ROMka pak muze cist kazetu pekne od zacatku    
    dmaSetSrcAddr(0x80000);
    dmaSetConfig(DMA_INC_SRC);
    
    //spustim aplikaci
    ind = pole;
    ind += taskSetPC(ind,0,0);
    ind--;
    taskRun(ind,pole);

    return ERR_OK;
}

