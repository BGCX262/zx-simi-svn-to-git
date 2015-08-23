/* ========================================================================== */
/*                                                                            */
/*   fat32.c                                                                  */
/*   (c) 2011 Petr Simon                                                      */
/*                                                                            */
/*   Knihovna pro praci se souborovym systemem FAT32                          */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>
#include <string.h>
#include "fat32.h"
#include "error.h"
#include "sdcard.h"
#include "filesystem.h"

/**
 * Precte Boot Sektor
 */ 
errc FAT32readBootSector(tFAT32BootSector *bootSector, unsigned long firstSector)
{
    unsigned char pole[512];
    errc err;
    //prectu Boot Sector
    if ((err = sdReadSector(firstSector,pole)) != ERR_OK) return err;
    //zkontroluji, zda se opravdu jedna o boot sector
    if (pole[0x1FE]!=0x55 || pole[0x1FF]!=0xAA) return ERR_FAT32_BOOT_SECTOR;
    //naplnim datove struktutury
    bootSector->sectorsCluster=pole[0x0D];
    bootSector->reservedSectors=(pole[0x0E + 1] << 8) | (pole[0x0E]);
    bootSector->numberOfFAT=pole[0x10];
    bootSector->numberOfTotalSectors=((unsigned long)pole[0x20 + 3]<<24) | ((unsigned long)pole[0x20 + 2]<<16) | (pole[0x20 + 1]<<8) | pole[0x20];
    bootSector->sizeOfFAT=((unsigned long)pole[0x24 + 3]<<24) | ((unsigned long)pole[0x24 + 2]<<16) | (pole[0x24 + 1]<<8) | pole[0x24];
    bootSector->rootCluster=((unsigned long)pole[0x2C + 3]<<24) | ((unsigned long)pole[0x2C + 2]<<16) | (pole[0x2C + 1]<<8) | pole[0x2C];

    //vypocitam si adresu sektoru zacatku prvni FAT tabulky
    bootSector->firstFATSector=firstSector + bootSector->reservedSectors;
    //vypocitam si adresu sektoru prvniho datoveho clusteru
    bootSector->firstDataSector=firstSector + bootSector->reservedSectors + bootSector->numberOfFAT * bootSector->sizeOfFAT + (bootSector->rootCluster - 2) * bootSector->sectorsCluster;
    //vypocitam si hodnotu maximalniho platneho clusteru
    bootSector->maxCluster=(bootSector->numberOfTotalSectors - bootSector->numberOfFAT * bootSector->sizeOfFAT - bootSector->reservedSectors) / bootSector->sectorsCluster;
/*
    printf("sectors/cluster: %x\n",bootSector->sectorsCluster);
    printf("Reserved sectors: %x\n",bootSector->reservedSectors);
    printf("number of FATs: %x\n",bootSector->numberOfFAT);
    printf("number of total sectors: %lx\n",bootSector->numberOfTotalSectors);
    printf("pocet sektoru v 1. FAT tabulce: %x\n",bootSector->sizeOfFAT);
    printf("root cluster: %lx\n",bootSector->rootCluster);

    printf("first FAT sector: %lx\n",bootSector->firstFATSector);
    printf("first data sector: %lx\n",bootSector->firstDataSector);
    printf("max cluster: %lx\n",bootSector->maxCluster);
*/
    return ERR_OK;
}

/**
 * Precte z FAT tabulky adresu nasledujiciho clusteru pro zadany cluster
 *
 * \param addr cislo clusteru, pro ktery chceme urcit naslednika
 * \param *next reference na promennou, do ktere se ulozi vysledek
 */
errc FAT32getNextAddrOfCluster(tFAT32BootSector *bootSector, unsigned long addr, unsigned long *next)
{
    unsigned char pole[512];
    errc err;
    unsigned long sektor;
    unsigned long tmp;

    //vypocitam si adresu cteneho sektoru. K zacatku FAT tabulky prictu hodnotu:
    //512 ... velikost sektoru
    //4 ... velikost jednoho zaznamu ve FAT je 4 bajty
    //podelim adresu touto hodnotou, cimz dostanu odpovidajici sektor
    sektor = bootSector->firstFATSector + addr/(512/4);

    //prectu si spravny sektor
    if ((err = sdReadSector(sektor,pole)) != ERR_OK) return err;

    //sirka jednoho zaznamu je 4 bajty. Modulo 512 zajistuje rozsah jednoho sektoru
    tmp = addr * 4 % 512;

    //z precteneho sektoru prectu odpovidajici zaznam na adrese
    *next=(pole[tmp + 3]<<24) | (pole[tmp + 2]<<16) | (pole[tmp + 1]<<8) | pole[tmp];

    return ERR_OK;
}


errc FAT32readFile(tFAT32BootSector *bootSector, unsigned long firstCluster, unsigned int sectorNumber, unsigned char *data)
{
    errc err;
    unsigned long first_sector;
    unsigned long cluster;
    
    cluster = firstCluster;

    //pokud chci cist sektor, ktery je uz v jinem clusteru, tak se musim do tohoto clusteru nejdrive dostat
    while (sectorNumber >= bootSector->sectorsCluster)
    {
        //snizim cislo sektoru o hodnotu poctu sektoru na cluster
        sectorNumber -= bootSector->sectorsCluster;
        //prectu z FAT tabulky cislo nasledujiciho clusteru
        if ((err = FAT32getNextAddrOfCluster(bootSector,cluster, &cluster)) != ERR_OK) return err;
    }

    //zjistim si adresu prvniho sektoru v danem clusteru
    first_sector = bootSector->firstDataSector + (cluster-2)*bootSector->sectorsCluster;

    if ((err = sdReadSector(first_sector+sectorNumber,data)) != ERR_OK) return err;

    return ERR_OK;
}

/**
 * Precte obsah adresare
 *
 * \param bootSector    ukazatel na strukturu s informacemi o FS
 * \param pos           poradove cislo souboru/adresare, od ktereho chci zacit vypisovat zaznamy (tzn. pocet zaznamu, ktere mam vynechat)
 * \param dir           vraceny vysledek
 */
errc FAT32readDir(tFAT32BootSector *bootSector, unsigned int pos, tFileSystemDir *dir)
{
    unsigned char pole[512];
    unsigned int i,i32;
    errc err;
    unsigned long first_sector;
    unsigned long sector;
    unsigned char longn,longn13;
    
    unsigned long cluster = dir->dirCluster;

    //inicializace datove struktury
    for (i=0;i<FS_DIR_SIZE;i++) {
        dir->dirEntry[i].useLongName = 0; //nepouzivat dlouhy nazev
        //inicializuji retezec (zapisu ukoncujici 0 na dulezita mista, kde jsou potreba)
        dir->dirEntry[i].longName[13] = 0;
        dir->dirEntry[i].longName[26] = 0;
        dir->dirEntry[i].longName[29] = 0;
    }
    
    //vynuluji aktualni pocet zaznamu v adresari
    dir->size = 0;  

    //projdu vsechny clustery daneho adresare
    do {
        //overim, zda sektor neni vadny
        if (cluster==0x0FFFFFF7) return ERR_BAD_CLUSTER;
        //overim, zda sektor existuje
        if (cluster>bootSector->maxCluster && cluster<=0x0FFFFFF6) return ERR_CLUSTER_NOT_EXISTS;

        //zjistim si adresu prvniho sektoru v danem clusteru
        first_sector = bootSector->firstDataSector + (cluster-2)*bootSector->sectorsCluster;

        //projdu vsechny sektory v danem clusteru
        for (sector=first_sector; sector < first_sector + bootSector->sectorsCluster; sector++)
        {
            //prectu sector
            if ((err = sdReadSector(sector,pole)) != ERR_OK) return err;
            //pocatecni inicializace. Slozka nema vic souboru, nez kolik jsem jich nacetl
            dir->moreFiles = 0;

            //projdu vsechny zaznamy v danem sektoru
            i=0;
            do {
                i32 = i*32;
                //pole[i*32]=0x00 ... konec zaznamu
                //pole[i*32]=0xE5 ... smazany soubor
                //pole[i*32+0x0B]=0x0F ... priznak dlouheho nazvu souboru.
                if (pole[i32]!=0x00 && pole[i32]!=0xE5)
                {
                    if (pos>0) { //pokud jsem jeste nevynechal dostatek zaznamu, tak dekrementuji tuto promennou a nebudu tento zaznam ukladat
                         if (pole[i32+0x0B]!=0x0F) pos--; //dekrementuji ale pouze pokud prave pracuji s kratkym nazvem souboru. Ten je povinny pro kazdy soubor
                    } else {
                        //pokud jsem jiz precetl dostatecny pocet zaznamu, tak koncim
                        if (FS_DIR_SIZE==dir->size) {
                            dir->moreFiles = 1; //poznacim si, ze slozka ma jeste vic souboru, nez kolik jsem jich nacetl
                            return ERR_OK;
                        }

                        //dale zvlast zpracovavam dlouhy a kratky nazev souboru
                        if (pole[i32+0x0B]==0x0F) { //dlouhy nazev souboru
                            //nastavim priznak, ze soubor ma ulozen dlouhy nazev
                            dir->dirEntry[dir->size].useLongName = 1;

                            //zjistim poradove cislo casti nazvu
                            longn = (pole[i32] & 0xF) - 1;
                            longn13 = longn*13;
                            //ulozim si nazev souboru do pameti
                            if (longn<3) { //posledni tri znaky nazvu souboru
                                dir->dirEntry[dir->size].longName[0+longn13] = pole[i32+0x01];
                                dir->dirEntry[dir->size].longName[1+longn13] = pole[i32+0x03];
                                dir->dirEntry[dir->size].longName[2+longn13] = pole[i32+0x05];
                            }
                            if (longn<2) { //prvnich 2*13 znaku z nazvu souboru                             
                                dir->dirEntry[dir->size].longName[3+longn13] = pole[i32+0x07];
                                dir->dirEntry[dir->size].longName[4+longn13] = pole[i32+0x09];
                                dir->dirEntry[dir->size].longName[5+longn13] = pole[i32+0x0E];
                                dir->dirEntry[dir->size].longName[6+longn13] = pole[i32+0x10];
                                dir->dirEntry[dir->size].longName[7+longn13] = pole[i32+0x12];
                                dir->dirEntry[dir->size].longName[8+longn13] = pole[i32+0x14];
                                dir->dirEntry[dir->size].longName[9+longn13] = pole[i32+0x16];
                                dir->dirEntry[dir->size].longName[10+longn13] = pole[i32+0x18];
                                dir->dirEntry[dir->size].longName[11+longn13] = pole[i32+0x1C];
                                dir->dirEntry[dir->size].longName[12+longn13] = pole[i32+0x1E];
                            }
                        }
                        else { //kratky nazev souboru
                            memcpy(dir->dirEntry[dir->size].name,pole+i32,8); //prekopiruju si ho do pameti
                            longn = 8;
                            do { //jedu zprava a odmazavam zbytecne mezery a davam misto nich 0
                                dir->dirEntry[dir->size].name[longn]=0;
                                longn--;
                            } while (dir->dirEntry[dir->size].name[longn] == ' '); //jakmile narazim na prvni znak, ktery neni mezera, tak koncim 
                            //pripona souboru
                            memcpy(dir->dirEntry[dir->size].ext,pole+8+i32,3);
                            dir->dirEntry[dir->size].ext[3]=0;
                            //atributy
                            dir->dirEntry[dir->size].attr = pole[0x0B+i32]; 
                            //adresa souboru/adresare, kam ukazuje tento zaznam
                            dir->dirEntry[dir->size].cluster = ((unsigned long)pole[0x14+1+i32]<<24) | ((unsigned long)pole[0x14+0+i32]<<16) | (pole[0x1A+1+i32]<<8) | (pole[0x1A+0+i32]);
                            //velikost souboru/adresare. U adresare je vzdy 0
                            dir->dirEntry[dir->size].size = ((unsigned long)pole[0x1C+3+i32]<<24) | ((unsigned long)pole[0x1C+2+i32]<<16) | (pole[0x1C+1+i32]<<8) | (pole[0x1C+0+i32]);
                            
                            dir->size++;
                        }                        
                    }
                }
                i++;

            } while (i<16 && pole[i32]!=0);
        }

        //prectu z FAT tabulky cislo nasledujiciho clusteru
        if ((err = FAT32getNextAddrOfCluster(bootSector,cluster, &cluster)) != ERR_OK) return err;
    //pokud je adresa nasledujiciho clusteru >= 2 a mensi nez maximalni povolena hodnota clusteru, tak opakuji
    } while(cluster >= 0x02 && cluster <= bootSector->maxCluster);

    return ERR_OK;
}
