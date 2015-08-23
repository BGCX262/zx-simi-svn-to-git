#include <stdlib.h>
#include <stdio.h>
#include "filesystem.h"
#include "dma.h"
#include "task.h"
#include "file_z80.h"
#include "error.h"

#define Z80_HW48K 0
#define Z80_HW128K 1

void z80storeByte(unsigned long *targetAddr, unsigned int *dest, unsigned char data)
{
    //vyberu spravnou banku
    if (*dest == 0) {
        *targetAddr = TASK_RAM5;
        dmaSetDestAddr(*targetAddr);
    }
    else if (*dest == 0x4000) {
        *targetAddr = TASK_RAM2;
        dmaSetDestAddr(*targetAddr);
    }
    else if (*dest == 0x8000) {
        *targetAddr = TASK_RAM0;
        dmaSetDestAddr(*targetAddr);
    }
    
    dmaSendByte(data);
    *dest += 1;
    *targetAddr += 1;
}


errc z80dataBlock(tFileSystemDirEntry *dir, unsigned long *sector, unsigned char *data, unsigned int *memIndParam, unsigned char hw)
{
    errc err;
    unsigned long targetAddr;
    unsigned char state,lastByte,compression,b0,b1,b2;
    unsigned int length,maxLength;
    unsigned int memInd;
    
    //pro vetsi rychlost si ulozim hodnotu na adrese *memIndParam do lokalni promenne
    memInd = *memIndParam;

    //prvni bajt hlavicky    
    b0 = data[memInd];
    memInd = (memInd + 1) & 0x1FF;
    if (memInd == 0) {
        if ((err = fsReadFile(dir->cluster, *sector, data)) != ERR_OK) return err;
        *sector = *sector + 1;
    }         

    //druhy bajt hlavicky
    b1 = data[memInd];
    memInd = (memInd + 1) & 0x1FF;
    if (memInd == 0) {
        if ((err = fsReadFile(dir->cluster, *sector, data)) != ERR_OK) return err;
        *sector = *sector + 1;
    }         
    
    //treti bajt hlavicky
    b2 = data[memInd];
    memInd = (memInd + 1) & 0x1FF;
    
    
    
    //zjistim delku bloku a soucasne i informaci, zda je blok komprimovan
    if (b0==0xFF && b1==0xFF) { //neni komprese
        maxLength = 0x4000;
        compression=0;
    }
    else { //komprese
        maxLength = (b0 | b1<<8);
        compression=1;
    }

    if (hw==Z80_HW48K) {
        if (b2==4) {
            targetAddr = TASK_RAM2;
        }
        else if (b2==5) {
            targetAddr = TASK_RAM0;
        }
        else if (b2==8) {
            targetAddr = TASK_RAM5;
        }
    } else {
        targetAddr = TASK_RAM_BASE_ADDR + (((unsigned long)(b2-3)) << 14);
    }
    
     
    dmaSetDestAddr(targetAddr);
    dmaSetConfig(DMA_INC_DST);
        
    state = 0;    

    for (length=0; length<maxLength; length++) {
        //prectu odpovidajici sektor v souboru
        if (memInd == 0) {
            if ((err = fsReadFile(dir->cluster, *sector, data)) != ERR_OK) return err;
            *sector = *sector + 1;
           
            dmaSetDestAddr(targetAddr);
            dmaSetConfig(DMA_INC_DST);
            dmaSetDestAddr(targetAddr);
        }


        switch(state) {
            case 0:
                if (compression!=0 && data[memInd]==0xED) {
                    state = 1;
                }
                else {
                    dmaSendByte(data[memInd]);
                    targetAddr += 1;
                }
                break;
            case 1:
                if (data[memInd]==0xED) {
                    state = 2;
                }
                else {
                    dmaSendByte(0xED);
                    dmaSendByte(data[memInd]);
                    targetAddr += 2;
                    state = 0;
                }
                break;
            case 2:
                lastByte = data[memInd];
                state = 3;
                break;
            case 3:
                dmaSetSrcAddr(swAddr2hwAddr(((unsigned int)data)+memInd));
                dmaTransfer(lastByte);
                targetAddr += lastByte;
                state = 0;
                break;
        }
        
        memInd = (memInd + 1) & 0x1FF;

    }

    *memIndParam = memInd;
   
    return ERR_OK;
}

errc z80version1(tFileSystemDirEntry *dir, unsigned long sector, unsigned char *data)
{

    errc err;
    unsigned long addr, targetAddr;
    unsigned int memInd, dest;
    unsigned char state,lastByte,i,compression;
    
    if ((data[12] & 0x20) == 0) compression = 0;
    else compression=1;

    dest = 0;
    
    state = 0;

    
    //prenesu snapshot do pameti. (dir->size)
    for (addr=30; addr<(dir->size); addr++) {

        //vypocitam si index do pole s daty. Pole je velke 512 bajtu
        memInd = addr & 0x1FF; 

        //prectu odpovidajici sektor v souboru
        if (memInd == 0) {
            if ((err = fsReadFile(dir->cluster, sector, data)) != ERR_OK) return err;
            sector++;
            dmaSetDestAddr(targetAddr);
            dmaSetConfig(DMA_INC_DST);
        }



        switch(state) {
            case 0:
                if (compression!=0 && data[memInd]==0xED) {
                    state = 1;
                }
                else if (compression!=0 && data[memInd]==0x00) {
                    state = 4;
                }
                else {
                    z80storeByte(&targetAddr,&dest,data[memInd]);
                }
                break;
            case 1:
                if (data[memInd]==0xED) {
                    state = 2;
                }
                else if (data[memInd]==0x00) {
                    z80storeByte(&targetAddr,&dest,0xED);
                    state = 4;
                }
                else {
                    z80storeByte(&targetAddr,&dest,0xED);
                    z80storeByte(&targetAddr,&dest,data[memInd]);
                    state = 0;
                }
                break;
            case 2:
                lastByte = data[memInd];
                state = 3;
                break;
            case 3:
                for (i=0;i<lastByte;i++)
                    z80storeByte(&targetAddr,&dest,data[memInd]);
                state = 0;
                break;
            case 4:
                if (data[memInd]==0xED) {
                    state = 5;
                }
                else {
                    z80storeByte(&targetAddr,&dest,0x00);
                    z80storeByte(&targetAddr,&dest,data[memInd]);
                    state = 0;
                }
                break;
            case 5:
                if (data[memInd]==0xED) {
                    state = 6;
                }
                else {
                    z80storeByte(&targetAddr,&dest,0x00);
                    z80storeByte(&targetAddr,&dest,0xED);
                    z80storeByte(&targetAddr,&dest,data[memInd]);
                    state = 0;
                }
                break;
            case 6:
                if (data[memInd]==0x00) {
                    state = 7;
                }
                else {               
                    z80storeByte(&targetAddr,&dest,0x00);
                    lastByte = data[memInd];
                    state = 3;
                }
                break;
        }
    }
    
    return ERR_OK;
}


errc loadFileZ80(tFileSystemDirEntry *dir)
{
    unsigned long addr;
    unsigned long sector;
    unsigned char data[512];
    unsigned char pole[256];
    unsigned int memInd;

    unsigned char *ind;
    unsigned char *uk;
    unsigned char hw,pages,i;
    errc err;


    //prectu prvni sektor
    if ((err =  fsReadFile(dir->cluster, 0, data)) != ERR_OK) return err;
    sector = 1;
    
    ind = pole;

    //interrupt control vector
    ind += taskSetI(ind,data[10]);
    
    //BC' DE' HL'   
    ind += taskSetL(ind,data[19]);
    ind += taskSetH(ind,data[20]);
    ind += taskSetE(ind,data[17]);
    ind += taskSetD(ind,data[18]);
    ind += taskSetC(ind,data[15]);
    ind += taskSetB(ind,data[16]);
    ind += taskSetEXX(ind);

    //stinovy registr AF'
    ind += taskSetAF(ind,data[22],data[21]);
    ind += taskSetEXAF(ind);
    
    //BC DE HL IY
    ind += taskSetL(ind,data[4]);
    ind += taskSetH(ind,data[5]);
    ind += taskSetE(ind,data[13]);
    ind += taskSetD(ind,data[14]);
    ind += taskSetC(ind,data[2]);
    ind += taskSetB(ind,data[3]);
    ind += taskSetIY(ind,data[23],data[24]);
    
    //BORDER
    if (data[12]==255) data[12] = 1; //kvuli kompatibilite. Pokud je to 255, pak se to ma interpretovat jako 1
    ind += taskSetBORDER(ind,(data[12]>>1) & 0x7);
    
    //IFF
    ind += taskSetIFF(ind,data[27]);
    
    //R
    ind += taskSetR(ind,data[11]);

    //AF
    ind += taskSetAF(ind,data[1],data[0]);

    //IX
    ind += taskSetIX(ind,data[25],data[26]);
    
    //SP
    ind += taskSetSP(ind,data[8],data[9]);

    //IM
    ind += taskSetIM(ind,data[29]&3);
    
    if (data[6]!=0 || data[7]!=0) { //PC != 0, takze se jedna o obraz verze 1
        //PC
        ind += taskSetPC(ind, data[6],data[7]);
        
        taskOut7FFD(0x10); //pro ZX 48K vyeru ROM1

        //nactu verzi 1
        if ((err = z80version1(dir,sector,data)) != ERR_OK) return err;
    }
    else if (data[30]==0x17 && data[31]==0) { //Z80 verze 2
        //PC
        ind += taskSetPC(ind, data[0x20],data[0x21]);

        //pripravim si hodnotu, ktera se pak posle na port 7FFD (strankovani pameti)
        if (hw==Z80_HW128K) taskOut7FFD(data[35]);
        else taskOut7FFD(0x10); //pro ZX 48K vyeru ROM1

        //datovy blok zacina na adrese 55
        memInd = 55;

        switch (data[34]) {
            case 0:
            case 1:
                hw = Z80_HW48K;
                pages = 3;
                break;
            case 3:
            case 4:
                hw = Z80_HW128K;
                pages = 8;
                break;
        }

        for (i=0;i<pages;i++)
            z80dataBlock(dir, &sector, data, &memInd, hw);
    }
    else if ((data[30]==0x36 || data[30]==0x37) && data[31]==0) { //Z80 verze 3
        //PC
        ind += taskSetPC(ind, data[0x20],data[0x21]);

        //zjistim zacatek datoveho bloku
        if (data[30]==0x36) memInd = 86;
        else memInd = 87; 

        switch (data[34]) {
            case 0:
            case 1:
            case 3:
                hw = Z80_HW48K;
                pages = 3;
                break;
            case 4:
            case 5:
            case 6:
                hw = Z80_HW128K;
                pages = 8;
                break;
        }

        //pripravim si hodnotu, ktera se pak posle na port 7FFD (strankovani pameti)
        if (hw==Z80_HW128K) taskOut7FFD(data[35]);
        else taskOut7FFD(0x10); //pro ZX 48K vyeru ROM1


        for (i=0;i<pages;i++)
            z80dataBlock(dir, &sector, data, &memInd, hw);
    }

    ind--;




    taskRun(ind,pole);
    return ERR_OK;
   
}
