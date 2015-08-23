/* ========================================================================== */
/*                                                                            */
/*   error.h                                                                  */
/*   (c) 2011 Petr Simon                                                      */
/*                                                                            */
/*   Zpracovani chyb                                                          */
/*                                                                            */
/* ========================================================================== */

#ifndef _ERROR_H_
#define _ERROR_H_

typedef enum {
    ERR_OK = 0,                 //bez chyby

    //SD karta
    ERR_SDREADSECTOR,           //problem pri cteni sektoru
    ERR_SD_START_TOKEN,         //neobdrzel jsem startovni datovy token po prikazu CMD17/18/24
    
    ERR_MBR,                    //chyba MBR zaznamu 
    ERR_UNKNOWN_FS,             //neznamy souborovy system

    //FAT32 chyby
    ERR_FAT32_BOOT_SECTOR,      //chybny Boot Sector
    ERR_BAD_CLUSTER,            //vadny cluster
    ERR_CLUSTER_NOT_EXISTS,     //cluster neexistuje
    
    //TZX soubor
    ERR_TZX_HEADER,             //chybna hlavicka TZX souboru
    ERR_TZX_VERSION,            //nepodporovana verze
    ERR_TZX_UNKNOWN_DATA_BLOCK  //neznamy data block
} errc;

#endif
