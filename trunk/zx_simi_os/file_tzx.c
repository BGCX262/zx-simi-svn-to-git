#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "textgui.h"
#include "error.h"
#include "filesystem.h"
#include "dma.h"
#include "task.h"
#include "file_tzx.h"

//stavy konecneho automatu, ktery pracovava TZX soubor
typedef enum {
    TZX_HEADER = 0,
    TZX_DATA_BLOCK,
    TZX_ID_10,
    TZX_ID_11,
    TZX_ID_12,
    TZX_ID_13,
    TZX_ID_14,
    TZX_ID_15,
    TZX_ID_18,
    TZX_ID_19,
    TZX_ID_20,
    TZX_ID_21,
    TZX_ID_2A,
    TZX_ID_2B,
    TZX_ID_30,
    TZX_ID_31,
    TZX_ID_32,
    TZX_ID_33,
    TZX_ID_35,
    TZX_SKIP,
    TZX_TAPE_DATA
} tzxState;

errc tzxLoadFile(tFileSystemDirEntry *dir)
{
    unsigned long addr, targetAddr, block_length;
    unsigned char pole[3];
    unsigned char *ind;
    unsigned char data[512];
    unsigned char state,offset;
    unsigned int min;
    unsigned int memInd, sector;
    errc err;

    targetAddr = 0x80000;
   
    sector=0;
    
    state = TZX_HEADER;

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
            case TZX_HEADER: //HEADER
                if (memcmp(data,"ZXTape!",7)!=0) return ERR_TZX_HEADER; //signature
                if (data[7]!=26) return ERR_TZX_HEADER; //end of file marker
                if (data[8]!=1) return ERR_TZX_VERSION; //end of file marker                    
                addr += 10;
                state = TZX_DATA_BLOCK;
                break;
            case TZX_DATA_BLOCK://DATA BLOCK
                switch (data[memInd]) {
                    case 0x10: state = TZX_ID_10; break;
                    case 0x11: state = TZX_ID_11; break;
                    case 0x12: state = TZX_ID_12; break;
                    case 0x13: state = TZX_ID_13; break;
                    case 0x14: state = TZX_ID_14; break;
                    case 0x15: state = TZX_ID_15; break;
                    case 0x18: state = TZX_ID_18; break;
                    case 0x19: state = TZX_ID_19; break;
                    case 0x20: state = TZX_ID_20; break;
                    case 0x21: state = TZX_ID_21; break;
                    case 0x22: state = TZX_DATA_BLOCK; break; //nema zadne telo
                    case 0x2A: state = TZX_ID_2A; break;
                    case 0x2B: state = TZX_ID_2B; break;
                    case 0x30: state = TZX_ID_30; break;
                    case 0x31: state = TZX_ID_31; break;
                    case 0x32: state = TZX_ID_32; break;
                    case 0x33: state = TZX_ID_33; break;
                    case 0x35: state = TZX_ID_35; break;
                    case 0x5A: block_length=9; state = TZX_SKIP; break; // skip block
                    default: return ERR_TZX_UNKNOWN_DATA_BLOCK; 
                }
                addr++;
                offset = 0;
                break;
            case TZX_ID_10: //Standard speed data block
                if (offset==2) block_length = data[memInd];
                if (offset==3) {
                    block_length |= (((unsigned long)data[memInd]) << 8);
                    state = TZX_TAPE_DATA;
                }
                offset++;
                addr++;
                break;
            case TZX_ID_11: //Turbo speed data block
                if (offset==15) block_length = data[memInd];
                if (offset==16) block_length |= (((unsigned long)data[memInd]) << 8);
                if (offset==17) {
                    block_length |= (((unsigned long)data[memInd]) << 16);
                    state = TZX_TAPE_DATA;
                }
                offset++;
                addr++;
                break;
            case TZX_ID_12: //Pure tone
                if (offset==3) state = TZX_DATA_BLOCK;
                offset++;
                addr++;
                break;
            case TZX_ID_13: //Pulse sequence
                block_length = data[memInd]*2;
                addr++;
                if (block_length != 0) state = TZX_SKIP;
                else state = TZX_DATA_BLOCK;
                break;
            case TZX_ID_14: //Pure data block
                if (offset==7) block_length = data[memInd];
                if (offset==8) block_length |= (((unsigned long)data[memInd]) << 8);
                if (offset==9) {
                    block_length |= (((unsigned long)data[memInd]) << 16);
                    state = TZX_TAPE_DATA;
                }
                offset++;
                addr++;
                break;
            case TZX_ID_15: //Direct recording block
                if (offset==5) block_length = data[memInd];
                if (offset==6) block_length |= (((unsigned long)data[memInd]) << 8);
                if (offset==7) {
                    block_length |= (((unsigned long)data[memInd]) << 16);
                    state = TZX_SKIP;
                }
                offset++;
                addr++;
                break;
            case TZX_ID_18: //CSW Recording
            case TZX_ID_19: //Generalized Data Block
            case TZX_ID_2A: //stop tape at 48k
            case TZX_ID_2B: //set signal
                if (offset==0) block_length = data[memInd];
                if (offset==1) block_length |= (((unsigned long)data[memInd]) << 8);
                if (offset==2) block_length |= (((unsigned long)data[memInd]) << 16);
                if (offset==3) {
                    block_length |= (((unsigned long)data[memInd]) << 24);
                    if (block_length != 0) state = TZX_SKIP;
                    else state = TZX_DATA_BLOCK;
                }
                offset++;
                addr++;
                break;
            case TZX_ID_20: //Pause (silence) or 'Stop the Tape' command
                if (offset==1) state = TZX_DATA_BLOCK;
                offset++;
                addr++;
                break;
            case TZX_ID_21: //Group start
            case TZX_ID_30: //Text description
                block_length = data[memInd];
                if (block_length!=0) state = TZX_SKIP;
                else state = TZX_DATA_BLOCK;
                addr++;
                break;
            case TZX_ID_31: //message
                if (offset==1) {
                    block_length = data[memInd];
                    if (block_length!=0) state = TZX_SKIP;
                    else state = TZX_DATA_BLOCK;
                }
                addr++;
                offset++;
                break;
          case TZX_ID_32: //archive info
                if (offset==0) block_length = data[memInd];
                if (offset==1) {
                    block_length |= (((unsigned long)data[memInd]) << 8);
                    if (block_length != 0) state = TZX_SKIP;
                    else state = TZX_DATA_BLOCK;
                }
                offset++;
                addr++;
                break;
          case TZX_ID_33: //hardware info
                block_length = data[memInd]*3;
                if (block_length != 0) state = TZX_SKIP;
                else state = TZX_DATA_BLOCK;
                addr++;
                break;                                                                                                                                                                            
            case TZX_ID_35: //Custom info block
                if (offset==16) block_length = data[memInd];
                if (offset==17) block_length |= (((unsigned long)data[memInd]) << 8);
                if (offset==18) block_length |= (((unsigned long)data[memInd]) << 16);
                if (offset==19) {
                    block_length |= (((unsigned long)data[memInd]) << 24);
                    if (block_length != 0) state = TZX_SKIP;
                    else state = TZX_DATA_BLOCK;
                }
                offset++;
                addr++;
                break;
            case TZX_TAPE_DATA: //TAPE DATA
                min = 512 - memInd; 
                min = (block_length > min ? min : block_length);
                //nastavim DMA radic
                dmaSetSrcAddr(swAddr2hwAddr(((unsigned long)data)+memInd)); 
                dmaTransfer(min);
                targetAddr += min;
                block_length -= min;
                addr += min;
                if (block_length==0) state = TZX_DATA_BLOCK;
                break;
            case TZX_SKIP: //preskoci zadany pocet bajtu
                addr++;
                block_length--;
                if (block_length==0) state = TZX_DATA_BLOCK;
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

