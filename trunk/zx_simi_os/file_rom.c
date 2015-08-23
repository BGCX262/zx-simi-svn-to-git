#include <stdlib.h>
#include "textgui.h"
#include "error.h"
#include "filesystem.h"
#include "dma.h"
#include "task.h"
#include "file_rom.h"


errc loadFileRom(tFileSystemDirEntry *dir)
{
    unsigned long size, pocet,zdroj,targetAddr;
    unsigned char data[512];
    unsigned int memInd, sector;
    errc err;

    targetAddr = TASK_ROM0;
    
    sector=0;
    
    for (size = 0; size<(dir->size); size += 512) {

        //prectu odpovidajici sektor v souboru
        if ((err = fsReadFile(dir->cluster, sector, data)) != ERR_OK) return err;
        sector++;

        //ulozim cilovou adresu, kam budu ukladat soubor
        dmaSetDestAddr(targetAddr);
        targetAddr += 512;
    
        //konfiguracni registr
        dmaSetConfig(DMA_INC_DST | DMA_INC_SRC);

        //zdrojova adresa, z ktere se bude cist
        dmaSetSrcAddr(swAddr2hwAddr(((unsigned long)data)));

        //spocitam, kolik jeste musim prenest bajtu
        pocet = dir->size - size;
        if (pocet>512) pocet = 512;

        //spustim prenos
        dmaTransfer(pocet);
    }
    return ERR_OK;
}

errc loadFileRunRom(tFileSystemDirEntry *dir)
{
    unsigned char pole[3];
    unsigned char *ind;
    errc err;

    if ((err = loadFileRom(dir)) != ERR_OK) return err;

    ind = pole;
    
    ind += taskSetPC(ind,0,0);
                
    ind--;

    taskRun(ind,pole);
    return ERR_OK;
}
