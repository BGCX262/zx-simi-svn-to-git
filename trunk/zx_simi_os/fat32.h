/* ========================================================================== */
/*                                                                            */
/*   fat32.h                                                                  */
/*   (c) 2011 Petr Simon                                                      */
/*                                                                            */
/*   Knihovna pro praci se souborovym systemem FAT32                          */
/*                                                                            */
/* ========================================================================== */

#ifndef _FAT32_H_
#define _FAT32_H_

#include "error.h"
#include "filesystem.h"

typedef struct {
    unsigned char sectorsCluster;       //pocet sektoru na cluster
    unsigned int reservedSectors;       //rezervované sektory od zacatku partition do 1. tabulky FAT
    unsigned char numberOfFAT;          //pocet kopii FAT tabulky
    unsigned long numberOfTotalSectors; //pocet sektoru v partition
    unsigned int sizeOfFAT;             //pocet sektoru v 1. FAT tabulce
    unsigned long rootCluster;          //cislo prvniho clusteru rootu
    //vypocitane hodnoty
    unsigned long firstFATSector;       //cislo sektoru, kde zacina prvni fat tabulka
    unsigned long firstDataSector;      //cislo sektoru prvniho datoveho clusteru (root adresar)
    unsigned long maxCluster;           //Maximalni platny cluster
} tFAT32BootSector;


extern errc FAT32readBootSector(tFAT32BootSector *bootSector, unsigned long firstSector);

extern errc FAT32getNextAddrOfCluster(tFAT32BootSector *bootSector, unsigned long addr, unsigned long *next);

extern errc FAT32readDir(tFAT32BootSector *bootSector, unsigned int pos, tFileSystemDir *dir);

extern errc FAT32readFile(tFAT32BootSector *bootSector, unsigned long firstCluster, unsigned int sectorNumber, unsigned char *data);

#endif
