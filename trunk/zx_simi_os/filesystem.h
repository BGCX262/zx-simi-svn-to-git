/* ========================================================================== */
/*                                                                            */
/*   filesystem.h                                                             */
/*   (c) 2011 Petr Simon                                                      */
/*                                                                            */
/*   Knihovna pro praci se souborovym systemem                                */
/*                                                                            */
/* ========================================================================== */

#ifndef _FILESYSTEM_H_
#define _FILESYSTEM_H_

#include "error.h"

typedef struct {
    unsigned char fileSystem;   //typ souboroveho systemu
    unsigned long firstSector;  //cislo prvniho sektoru
    unsigned long size;         //pocet sektoru
} tPartitionTableEntry;

typedef struct {
    unsigned char name[9];
    unsigned char ext[4];
    unsigned char longName[30];
    unsigned char useLongName;
    unsigned char attr;
    unsigned long size;
    unsigned long cluster;
} tFileSystemDirEntry;

//maximalni pocet ctenych zaznamu z adresare
#define FS_DIR_SIZE 22

typedef struct {
    unsigned int size;
    unsigned long dirCluster;   //cislo clusteru aktualniho adresare
    unsigned char moreFiles;    //priznak, ktery bude rikat, ze ve slozce je jeste vic souboru, nez kolik jsem jich prave obdrzel
    tFileSystemDirEntry dirEntry[FS_DIR_SIZE];
} tFileSystemDir;


extern errc fsStart(tFileSystemDir *dir);

extern errc fsDir(unsigned int pos, tFileSystemDir *dir);

extern errc fsReadFile(unsigned long fileCluster, unsigned long sectorNumber, unsigned char *data);

#endif
