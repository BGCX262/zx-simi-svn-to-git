/* ========================================================================== */
/*                                                                            */
/*   filesystem.c                                                             */
/*   (c) 2011 Petr Simon                                                      */
/*                                                                            */
/*   Knihovna pro praci se souborovym systemem                                */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>
#include "filesystem.h"
#include "sdcard.h"
#include "fat32.h"

static tPartitionTableEntry pTable;
static tFAT32BootSector bootSector;


/**
 * Precte MBR a nastavi datove struktury s partition tabulkou.
 * Inicializuje datove struktury odpovidajiciho souboroveho systemu
 */ 
errc fsStart(tFileSystemDir *dir)
{
    unsigned char pole[512];
    errc err;
    
    //prectu prvni sektro obsahujici MBR
    if ((err = sdReadSector(0,pole)) != ERR_OK) return err;
    if (pole[0x1FE]!=0x55 || pole[0x1FF]!=0xAA) return ERR_MBR;
    pTable.fileSystem=pole[0x01BE + 0x04];
    pTable.firstSector=((unsigned long)pole[0x01BE + 0x08 + 3]<<24) | ((unsigned long)pole[0x01BE + 0x08 + 2]<<16) | (pole[0x01BE + 0x08 + 1]<<8) | pole[0x01BE + 0x08];    
    pTable.size=((unsigned long)pole[0x01BE + 0x0C + 3]<<24) | ((unsigned long)pole[0x01BE + 0x0C + 2]<<16) | (pole[0x01BE + 0x0C + 1]<<8) | pole[0x01BE + 0x0C];


//    printf("file system: %x\n",pTable.fileSystem);
//    printf("first sector: %lx\n",pTable.firstSector);    
//    printf("first size: %lx\n",pTable.size);

    //inicializuji datove struktury soouboroveho systemu
    switch(pTable.fileSystem)
    {
        case 0x0B: //FAT32
            if ((err = FAT32readBootSector(&bootSector, pTable.firstSector)) != ERR_OK) return err;
            dir->dirCluster = bootSector.rootCluster;
            break;
        default: //Neznamy souborovy system
            return ERR_UNKNOWN_FS;
    }
    return ERR_OK;
}


/**
 * Precte obsah adresare
 *
 * \param pos       pocet zaznamu, ktere se maji preskocit
 */
errc fsDir(unsigned int pos, tFileSystemDir *dir)
{
    errc err;

    switch(pTable.fileSystem)
    {
        case 0x0B: //FAT32
            //pokud je cislo clusteru rovno nule, pak nastavim root jako aktualni adresar
            if (dir->dirCluster == 0) dir->dirCluster = bootSector.rootCluster;
            if ((err = FAT32readDir(&bootSector, pos,dir)) != ERR_OK) return err;
            break;
        default: //Neznamy souborovy system
            return ERR_UNKNOWN_FS;
    }
    return ERR_OK;
}


errc fsReadFile(unsigned long fileCluster, unsigned long sectorNumber, unsigned char *data)
{
    errc err;

    err = FAT32readFile(&bootSector, fileCluster, sectorNumber, data);
    
    return err;
}
