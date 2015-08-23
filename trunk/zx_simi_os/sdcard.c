/* ========================================================================== */
/*                                                                            */
/*   sdcard.c                                                                 */
/*   (c) 2001 Petr Simon                                                      */
/*                                                                            */
/*   Obsluha SD/MMC pametove karty                                            */
/*                                                                            */
/* ========================================================================== */

#include <stdio.h>
#include <spectrum.h>
#include <stdlib.h>
#include "sdcard.h"
#include "error.h"
#include "dma.h"

void sdReadCmd(unsigned long addr)
{
    outp(SD_REG0,0x11);                  //CMD17
    outp(SD_REG1,(addr >> 24) & 0xFF);   //adresa MSB
    outp(SD_REG2,(addr >> 16) & 0xFF);   //adresa
    outp(SD_REG3,(addr >> 8) & 0xFF);    //adresa
    outp(SD_REG4,addr & 0xFF);           //adresa LSB
    outp(SD_REG5,0x01);                  //potvrdim provedeni prikazu
//    printf("CMD17 addr=%lx\n",addr);
}

unsigned char sdReadByte()
{
    unsigned char data;
//    outp(SD_REG5,0x02); //reknu sdkarte, aby precetla jeden bajt
    data = inp(0x07F7);
    return data;
}

                                 
/**
 * Precte datovy blok o velikosti 512 bajtu ze zadane adresy
 * 
 * /param addr 32bitova adresa  
 * /param *array ukazatel na pole. Je ocekavano pole o velikosti 512 bajtu  
 */ 
errc sdReadSector(unsigned long sector,unsigned char *array)
{
    unsigned int CRC,i;
    unsigned char data;
   
    //odeslu karte prikaz CMD17 (cteni)
    //je potreba prevest adresu sektoru na adresu v bajtech. Sektor ma 512 bajtu, takze lze vypocitat pomoci posunu doleva o 9 bitu
    sdReadCmd(sector<<9);
    
    //cekam na prvni data token
    i = 0;
    do {
        data = sdReadByte();
        i++;
    } while (data!=0xFE && i<16);
    //pokud jsem po 9 pokusech neobdrzel startovaci token, koncim s chybou
    if (i==16) return ERR_SD_START_TOKEN;

    
    
    
    //konfiguracni registr
    dmaSetConfig(DMA_INC_DST | DMA_IORQ_SRC);

    dmaSetDestAddr(swAddr2hwAddr((unsigned long)array));

    dmaSetSrcAddr(0x07F7);
    
    dmaTransfer(512);
        
/*    
    //prectu blok dat o delce 512 bajtu
    for (i=0;i<512;i++)
    {
        array[i] = sdReadByte();
    }
*/    
    //prectu CRC
    CRC = sdReadByte() << 8 | sdReadByte();
//    printf("CRC:%x\n",CRC);
    return ERR_OK;
}

