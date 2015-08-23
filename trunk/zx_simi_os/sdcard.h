/* ========================================================================== */
/*                                                                            */
/*   sdcard.h                                                                 */
/*   (c) 2001 Petr Simon                                                      */
/*                                                                            */
/*   Obsluha SD/MMC pametove karty                                            */
/*                                                                            */
/* ========================================================================== */

#ifndef _SDCARD_H_
#define _SDCARD_H_

#include "error.h"

//Bazova adresa SD karty
#define SD_ADDR 0xF7
//Adresy registru
#define SD_REG0 SD_ADDR+0x0000
#define SD_REG1 SD_ADDR+0x0100
#define SD_REG2 SD_ADDR+0x0200
#define SD_REG3 SD_ADDR+0x0300
#define SD_REG4 SD_ADDR+0x0400
#define SD_REG5 SD_ADDR+0x0500

/**
 * Precte datovy blok o velikosti 512 bajtu ze zadane adresy
 * 
 * /param sector 32bitova adresa sektoru  
 * /param *array ukazatel na pole. Je ocekavano pole o velikosti 512 bajtu  
 */ 
extern errc sdReadSector(unsigned long sector,unsigned char*);

#endif
