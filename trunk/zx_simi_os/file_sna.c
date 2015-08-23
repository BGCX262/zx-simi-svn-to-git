#include <stdlib.h>
#include <stdio.h>
#include "error.h"
#include "filesystem.h"
#include "dma.h"
#include "task.h"
#include "file_sna.h"

#define SNA_HW48K 0
#define SNA_HW128K 1

errc loadFileSna(tFileSystemDirEntry *dir)
{
    unsigned long addr, sector, targetAddr;
    unsigned char data[512];
    unsigned char pole[256];
    unsigned int memInd;
    unsigned char *ind;
    errc err;
    unsigned char hw;
    unsigned char bank,bank_n;

    //prectu prvni sektor
    if ((err = fsReadFile(dir->cluster, 0, data)) != ERR_OK) return err;
    sector = 1;

    if (dir->size > 49179) hw = SNA_HW128K;
    else hw = SNA_HW48K;
    
    ind = pole;

    //interrupt control vector
    ind += taskSetI(ind,data[0]);
    
    //BC' DE' HL'   
    ind += taskSetL(ind,data[1]);
    ind += taskSetH(ind,data[2]);
    ind += taskSetE(ind,data[3]);
    ind += taskSetD(ind,data[4]);
    ind += taskSetC(ind,data[5]);
    ind += taskSetB(ind,data[6]);
    ind += taskSetEXX(ind);

    //stinovy registr AF'
    ind += taskSetAF(ind,data[7],data[8]);
    ind += taskSetEXAF(ind);
    
    //BC DE HL IY IX
    ind += taskSetL(ind,data[9]);
    ind += taskSetH(ind,data[10]);
    ind += taskSetE(ind,data[11]);
    ind += taskSetD(ind,data[12]);
    ind += taskSetC(ind,data[13]);
    ind += taskSetB(ind,data[14]);
    ind += taskSetIY(ind,data[15],data[16]);
    
    //BORDER
    ind += taskSetBORDER(ind,data[26]);
    
    //IFF
    ind += taskSetIFF(ind,data[19] & 4); //zajima me IFF2, ktery je na 2. bitu. Vzhledem k tomu, ze hned provedu RETN, IFF1 se stejne prepise
    
    //R
    ind += taskSetR(ind,data[20]);

    //AF
    ind += taskSetAF(ind,data[21],data[22]);

    //IX
    ind += taskSetIX(ind,data[17],data[18]);
    
    //SP
    ind += taskSetSP(ind,data[23],data[24]);

    //IM
    ind += taskSetIM(ind,data[25]);

    if (hw==SNA_HW48K) { //pokud je to 48K obraz, tak pridam instrukci RETN a vyberu ROM1    
        ind += taskSetRETN(ind);

        //budu vyuzivat ROM1
        taskOut7FFD(0x10);
    }

    //prenesu snapshot do pameti.
    //je to trochu komplikovanejsi, protoze na zacatku snapsotu byla hlavicka, takze je vse posunute o 27 bajtu.
    for (addr=27; addr<49179; addr+=512) {

        //vyberu spravnou banku
        if (addr==27) {
            targetAddr = TASK_RAM5;
        }
        else if (addr==27+0x4000) {
            targetAddr = TASK_RAM2;
        }
        else if (addr==27+0x8000) {
            targetAddr = TASK_RAM0;
        }

        //prenesu data z nacteneho sektoru od adresy 27. Je to posunute, protoze na zacatku sna souboru byla hlavicka o velikosti 27 bajtu.
        dmaSetSrcAddr(swAddr2hwAddr(((unsigned long)data)+27));
        dmaSetDestAddr(targetAddr);
        dmaSetConfig(DMA_INC_DST | DMA_INC_SRC);
        dmaTransfer(512-27);
        targetAddr += (512-27);

        //nactu novy sektor
        if ((err = fsReadFile(dir->cluster, sector, data)) != ERR_OK) return err;
        sector++;

        //ted prenesu prvnich 27 bajtu sektoru, cimz jsem v teto iteraci cyklu penesl celkem 512 bajtu.
        dmaSetSrcAddr(swAddr2hwAddr(((unsigned long)data)));
        dmaSetDestAddr(targetAddr);
        dmaSetConfig(DMA_INC_DST | DMA_INC_SRC);
        dmaTransfer(27);
        targetAddr += 27;
    }

    //pokud je to 128K snapshot, tak musim zpracovat zbytek obrazu    
    if (hw==SNA_HW128K) {
        //nastaveni PC
        ind += taskSetPC(ind, data[27], data[28]);
         //pripravim registr 7FFD (adresuje horni cast pameti)
        taskOut7FFD(data[29]);
        
        bank_n = (data[29] & 0x7);

        //pokud byla ve sna souboru na nejvyssi adrese ulozena jina banka nez 0, tak musim tuto banku presunout na spravne misto, aby se banka 0 uvolnila pro nasledne ukladani dat
        if (bank_n>0) {
            dmaSetSrcAddr(TASK_RAM0);
            dmaSetDestAddr(TASK_RAM_BASE_ADDR+((unsigned long)0x4000)*bank_n);
            dmaSetConfig(DMA_INC_DST | DMA_INC_SRC);
            dmaTransfer(0x4000);
        }

        bank = 0;

        //prenesu snapshot do pameti.
        //je to trochu komplikovanejsi, protoze na zacatku snapsotu byla hlavicka, takze je vse posunute o 27 bajtu.
        for (addr=31+0xC000; addr<(dir->size); addr+=512) {
    
            if ((addr & 0x3FFF)==31)
            {
                if (bank==2) bank++;
                if (bank==5) bank++;
                if (bank==bank_n) bank++;
                if (bank==2) bank++;
                if (bank==5) bank++;
                                
                targetAddr = TASK_RAM_BASE_ADDR+((unsigned long)0x4000)*bank;

                bank++;
            }
    
            //prenesu data z nacteneho sektoru od adresy 27. Je to posunute, protoze na zacatku sna souboru byla hlavicka o velikosti 27 bajtu.
            dmaSetSrcAddr(swAddr2hwAddr(((unsigned long)data)+31));
            dmaSetDestAddr(targetAddr);
            dmaSetConfig(DMA_INC_DST | DMA_INC_SRC);
            dmaTransfer(512-31);
            targetAddr += (512-31);
    
            //nactu novy sektor
            if ((err = fsReadFile(dir->cluster, sector, data)) != ERR_OK) return err;
            sector++;
    
            //ted prenesu prvnich 27 bajtu sektoru, cimz jsem v teto iteraci cyklu penesl celkem 512 bajtu.
            dmaSetSrcAddr(swAddr2hwAddr(((unsigned long)data)));
            dmaSetDestAddr(targetAddr);
            dmaSetConfig(DMA_INC_DST | DMA_INC_SRC);
            dmaTransfer(31);
            targetAddr += 31;
        }

    }

    //jeste zkratim o jeden bajt pole.
    ind--;

    //spustim program
    taskRun(ind,pole);
        
    return ERR_OK;
    
}
